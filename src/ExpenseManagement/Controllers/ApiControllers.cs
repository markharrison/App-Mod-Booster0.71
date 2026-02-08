using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc;

namespace ExpenseManagement.Controllers;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class ExpensesController : ControllerBase
{
    private readonly IExpenseDataService _dataService;
    private readonly ILogger<ExpensesController> _logWriter;

    public ExpensesController(IExpenseDataService dataService, ILogger<ExpensesController> logWriter)
    {
        _dataService = dataService;
        _logWriter = logWriter;
    }

    /// <summary>
    /// Retrieves all expense records with optional filtering
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ExpenseRecord>>> GetAllExpenses(
        [FromQuery] int? userId = null, 
        [FromQuery] int? statusId = null)
    {
        _logWriter.LogInformation("Fetching expenses - UserId filter: {UserId}, Status filter: {StatusId}", 
            userId, statusId);
        
        var records = await _dataService.FetchAllExpensesAsync(userId, statusId);
        return Ok(records);
    }

    /// <summary>
    /// Retrieves a specific expense by its identifier
    /// </summary>
    [HttpGet("{expenseId:int}")]
    public async Task<ActionResult<ExpenseRecord>> GetExpenseById(int expenseId)
    {
        _logWriter.LogInformation("Fetching expense {ExpenseId}", expenseId);
        
        var record = await _dataService.FetchExpenseByIdentifierAsync(expenseId);
        
        if (record == null)
        {
            return NotFound(new { message = $"Expense {expenseId} not found" });
        }
        
        return Ok(record);
    }

    /// <summary>
    /// Creates a new expense record
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<object>> CreateExpense([FromBody] CreateExpenseRequest requestData)
    {
        _logWriter.LogInformation("Creating expense for user {UserId}, amount £{Amount}", 
            requestData.UserId, requestData.Amount);
        
        var newId = await _dataService.RegisterNewExpenseAsync(requestData);
        
        if (newId <= 0)
        {
            return BadRequest(new { message = "Failed to create expense" });
        }
        
        return CreatedAtAction(
            nameof(GetExpenseById), 
            new { expenseId = newId }, 
            new { expenseId = newId, message = "Expense created successfully" });
    }

    /// <summary>
    /// Submits a draft expense for approval
    /// </summary>
    [HttpPost("{expenseId:int}/submit")]
    public async Task<ActionResult<object>> SubmitExpense(int expenseId)
    {
        _logWriter.LogInformation("Submitting expense {ExpenseId}", expenseId);
        
        var submitted = await _dataService.SubmitExpenseForReviewAsync(expenseId);
        
        if (!submitted)
        {
            return BadRequest(new { message = "Failed to submit expense - check status" });
        }
        
        return Ok(new { message = $"Expense {expenseId} submitted for review" });
    }

    /// <summary>
    /// Approves a submitted expense
    /// </summary>
    [HttpPost("{expenseId:int}/approve")]
    public async Task<ActionResult<object>> ApproveExpense(int expenseId, [FromBody] int reviewerId)
    {
        _logWriter.LogInformation("Approving expense {ExpenseId} by reviewer {ReviewerId}", 
            expenseId, reviewerId);
        
        var approved = await _dataService.ProcessExpenseApprovalAsync(expenseId, reviewerId);
        
        if (!approved)
        {
            return BadRequest(new { message = "Failed to approve expense - check status" });
        }
        
        return Ok(new { message = $"Expense {expenseId} approved" });
    }

    /// <summary>
    /// Rejects a submitted expense
    /// </summary>
    [HttpPost("{expenseId:int}/reject")]
    public async Task<ActionResult<object>> RejectExpense(int expenseId, [FromBody] int reviewerId)
    {
        _logWriter.LogInformation("Rejecting expense {ExpenseId} by reviewer {ReviewerId}", 
            expenseId, reviewerId);
        
        var rejected = await _dataService.ProcessExpenseRejectionAsync(expenseId, reviewerId);
        
        if (!rejected)
        {
            return BadRequest(new { message = "Failed to reject expense - check status" });
        }
        
        return Ok(new { message = $"Expense {expenseId} rejected" });
    }

    /// <summary>
    /// Retrieves expense summary metrics grouped by status
    /// </summary>
    [HttpGet("summary")]
    public async Task<ActionResult<IReadOnlyList<ExpenseSummaryMetrics>>> GetExpenseSummary(
        [FromQuery] int? userId = null)
    {
        _logWriter.LogInformation("Fetching summary - UserId filter: {UserId}", userId);
        
        var metrics = await _dataService.FetchExpenseSummaryDataAsync(userId);
        return Ok(metrics);
    }
}

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class CategoriesController : ControllerBase
{
    private readonly IExpenseDataService _dataService;
    private readonly ILogger<CategoriesController> _logWriter;

    public CategoriesController(IExpenseDataService dataService, ILogger<CategoriesController> logWriter)
    {
        _dataService = dataService;
        _logWriter = logWriter;
    }

    /// <summary>
    /// Retrieves all active expense categories
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ExpenseCategory>>> GetCategories()
    {
        _logWriter.LogInformation("Fetching active categories");
        
        var categories = await _dataService.FetchActiveCategoriesAsync();
        return Ok(categories);
    }
}

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class UsersController : ControllerBase
{
    private readonly IExpenseDataService _dataService;
    private readonly ILogger<UsersController> _logWriter;

    public UsersController(IExpenseDataService dataService, ILogger<UsersController> logWriter)
    {
        _dataService = dataService;
        _logWriter = logWriter;
    }

    /// <summary>
    /// Retrieves all active user profiles
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<UserProfile>>> GetUsers()
    {
        _logWriter.LogInformation("Fetching active users");
        
        var users = await _dataService.FetchActiveUsersAsync();
        return Ok(users);
    }
}
