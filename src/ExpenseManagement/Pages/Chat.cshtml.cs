using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class ChatModel : PageModel
{
    private readonly IChatService _chatService;
    private readonly ILogger<ChatModel> _logger;

    public bool IsConfigured { get; private set; }

    public ChatModel(IChatService chatService, ILogger<ChatModel> logger)
    {
        _chatService = chatService;
        _logger = logger;
    }

    public void OnGet()
    {
        IsConfigured = _chatService.IsConfigured;
        _logger.LogInformation("Chat page loaded. IsConfigured: {IsConfigured}", IsConfigured);
    }
}
