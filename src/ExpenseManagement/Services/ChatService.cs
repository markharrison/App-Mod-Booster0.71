using Azure;
using Azure.AI.OpenAI;
using Azure.Core;
using Azure.Identity;
using ExpenseManagement.Models;
using OpenAI.Chat;
using System.ClientModel;
using System.Text.Json;

namespace ExpenseManagement.Services;

public interface IAiChatService
{
    bool IsConfigured { get; }
    Task<string> ProcessUserMessageAsync(string userMessage, int currentUserId);
}

public sealed class AzureOpenAiChatService : IAiChatService
{
    private readonly string? _aiEndpointUrl;
    private readonly string? _deployedModelIdentifier;
    private readonly string? _managedIdentityClientId;
    private readonly IExpenseDataService _expenseDataAccess;
    private readonly ILogger<AzureOpenAiChatService> _logWriter;
    private readonly List<ChatMessage> _conversationHistory = new();

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_aiEndpointUrl) && 
                                 !string.IsNullOrWhiteSpace(_deployedModelIdentifier);

    public AzureOpenAiChatService(
        IConfiguration configReader,
        IExpenseDataService expenseDataAccess,
        ILogger<AzureOpenAiChatService> logWriter)
    {
        _expenseDataAccess = expenseDataAccess;
        _logWriter = logWriter;
        _aiEndpointUrl = configReader["GenAISettings:OpenAIEndpoint"];
        _deployedModelIdentifier = configReader["GenAISettings:OpenAIModelName"];
        _managedIdentityClientId = configReader["ManagedIdentityClientId"];

        if (!IsConfigured)
        {
            _logWriter.LogInformation("Azure OpenAI not configured - chat will show fallback message");
        }
    }

    public async Task<string> ProcessUserMessageAsync(string userMessage, int currentUserId)
    {
        if (!IsConfigured)
        {
            return "AI Chat is not available yet. To enable it, redeploy using the -DeployGenAI switch.";
        }

        try
        {
            var authCredential = CreateAuthenticationCredential();
            var openAiClient = new AzureOpenAIClient(new Uri(_aiEndpointUrl!), authCredential);
            var chatClient = openAiClient.GetChatClient(_deployedModelIdentifier!);

            _conversationHistory.Add(ChatMessage.CreateUserMessage(userMessage));

            var toolDefinitions = BuildAvailableFunctionTools();
            var chatOptions = new ChatCompletionOptions();
            foreach (var tool in toolDefinitions)
            {
                chatOptions.Tools.Add(tool);
            }

            var chatResponse = await chatClient.CompleteChatAsync(_conversationHistory, chatOptions);
            var finishReason = chatResponse.Value.FinishReason;

            while (finishReason == ChatFinishReason.ToolCalls)
            {
                _conversationHistory.Add(ChatMessage.CreateAssistantMessage(chatResponse.Value));

                foreach (var toolCall in chatResponse.Value.ToolCalls)
                {
                    var functionName = toolCall.FunctionName;
                    var functionArgs = toolCall.FunctionArguments;

                    _logWriter.LogInformation("AI requesting function: {FunctionName} with args: {Args}", 
                        functionName, functionArgs);

                    var executionResult = await ExecuteFunctionByNameAsync(functionName, functionArgs, currentUserId);
                    _conversationHistory.Add(ChatMessage.CreateToolMessage(toolCall.Id, executionResult));
                }

                chatResponse = await chatClient.CompleteChatAsync(_conversationHistory, chatOptions);
                finishReason = chatResponse.Value.FinishReason;
            }

            var finalResponse = chatResponse.Value.Content[0].Text;
            _conversationHistory.Add(ChatMessage.CreateAssistantMessage(finalResponse));

            return finalResponse;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Chat processing failed");
            return $"I encountered an error: {ex.Message}. Please try again.";
        }
    }

    private TokenCredential CreateAuthenticationCredential()
    {
        if (!string.IsNullOrWhiteSpace(_managedIdentityClientId))
        {
            _logWriter.LogInformation("Using ManagedIdentityCredential with client ID: {ClientId}", 
                _managedIdentityClientId);
            return new ManagedIdentityCredential(_managedIdentityClientId);
        }

        _logWriter.LogInformation("Using DefaultAzureCredential");
        return new DefaultAzureCredential();
    }

    private List<ChatTool> BuildAvailableFunctionTools()
    {
        var tools = new List<ChatTool>();

        var retrieveExpensesSchema = BinaryData.FromString("""
            {
                "type": "object",
                "properties": {
                    "user_id": { "type": "integer", "description": "Filter by user ID (optional)" },
                    "status_id": { "type": "integer", "description": "Filter by status: 1=Draft, 2=Submitted, 3=Approved, 4=Rejected (optional)" }
                }
            }
            """);
        tools.Add(ChatTool.CreateFunctionTool(
            "retrieve_expenses",
            "Fetches expense records from the database with optional filters",
            retrieveExpensesSchema
        ));

        var createExpenseSchema = BinaryData.FromString("""
            {
                "type": "object",
                "required": ["category_id", "amount", "expense_date"],
                "properties": {
                    "category_id": { "type": "integer", "description": "Expense category: 1=Travel, 2=Meals, 3=Accommodation, 4=Office Supplies" },
                    "amount": { "type": "number", "description": "Expense amount in GBP" },
                    "expense_date": { "type": "string", "format": "date", "description": "Date of expense (YYYY-MM-DD)" },
                    "description": { "type": "string", "description": "Optional expense description" }
                }
            }
            """);
        tools.Add(ChatTool.CreateFunctionTool(
            "create_expense_record",
            "Creates a new expense entry in the database",
            createExpenseSchema
        ));

        var approveExpenseSchema = BinaryData.FromString("""
            {
                "type": "object",
                "required": ["expense_id"],
                "properties": {
                    "expense_id": { "type": "integer", "description": "The ID of the expense to approve" }
                }
            }
            """);
        tools.Add(ChatTool.CreateFunctionTool(
            "approve_expense_record",
            "Approves a submitted expense (requires manager role)",
            approveExpenseSchema
        ));

        return tools;
    }

    private async Task<string> ExecuteFunctionByNameAsync(string functionName, BinaryData argumentsJson, int currentUserId)
    {
        try
        {
            var argsDocument = JsonDocument.Parse(argumentsJson.ToString());
            var argsRoot = argsDocument.RootElement;

            return functionName switch
            {
                "retrieve_expenses" => await HandleRetrieveExpensesAsync(argsRoot),
                "create_expense_record" => await HandleCreateExpenseAsync(argsRoot, currentUserId),
                "approve_expense_record" => await HandleApproveExpenseAsync(argsRoot, currentUserId),
                _ => JsonSerializer.Serialize(new { error = $"Unknown function: {functionName}" })
            };
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Function execution failed: {FunctionName}", functionName);
            return JsonSerializer.Serialize(new { error = ex.Message });
        }
    }

    private async Task<string> HandleRetrieveExpensesAsync(JsonElement args)
    {
        var userIdFilter = args.TryGetProperty("user_id", out var userIdProp) && userIdProp.ValueKind == JsonValueKind.Number
            ? (int?)userIdProp.GetInt32()
            : null;

        var statusIdFilter = args.TryGetProperty("status_id", out var statusIdProp) && statusIdProp.ValueKind == JsonValueKind.Number
            ? (int?)statusIdProp.GetInt32()
            : null;

        var expenses = await _expenseDataAccess.FetchAllExpensesAsync(userIdFilter, statusIdFilter);

        var simplifiedData = expenses.Select(e => new
        {
            id = e.ExpenseId,
            user = e.UserName,
            category = e.CategoryName,
            amount = $"£{e.Amount:F2}",
            date = e.ExpenseDate.ToString("yyyy-MM-dd"),
            status = e.StatusName,
            description = e.Description ?? ""
        });

        return JsonSerializer.Serialize(new { success = true, expenses = simplifiedData, count = expenses.Count });
    }

    private async Task<string> HandleCreateExpenseAsync(JsonElement args, int currentUserId)
    {
        if (!args.TryGetProperty("category_id", out var categoryProp) ||
            !args.TryGetProperty("amount", out var amountProp) ||
            !args.TryGetProperty("expense_date", out var dateProp))
        {
            return JsonSerializer.Serialize(new { success = false, error = "Missing required fields" });
        }

        var newExpense = new CreateExpenseRequest
        {
            UserId = currentUserId,
            CategoryId = categoryProp.GetInt32(),
            Amount = (decimal)amountProp.GetDouble(),
            ExpenseDate = DateTime.Parse(dateProp.GetString() ?? DateTime.Now.ToString("yyyy-MM-dd")),
            Description = args.TryGetProperty("description", out var descProp) 
                ? descProp.GetString() 
                : null
        };

        var newId = await _expenseDataAccess.RegisterNewExpenseAsync(newExpense);

        if (newId > 0)
        {
            return JsonSerializer.Serialize(new { success = true, expense_id = newId, message = "Expense created successfully" });
        }

        return JsonSerializer.Serialize(new { success = false, error = "Failed to create expense" });
    }

    private async Task<string> HandleApproveExpenseAsync(JsonElement args, int currentUserId)
    {
        if (!args.TryGetProperty("expense_id", out var expenseIdProp))
        {
            return JsonSerializer.Serialize(new { success = false, error = "Missing expense_id" });
        }

        var expenseId = expenseIdProp.GetInt32();
        var approved = await _expenseDataAccess.ProcessExpenseApprovalAsync(expenseId, currentUserId);

        if (approved)
        {
            return JsonSerializer.Serialize(new { success = true, message = $"Expense {expenseId} approved" });
        }

        return JsonSerializer.Serialize(new { success = false, error = "Failed to approve - check expense status" });
    }
}
