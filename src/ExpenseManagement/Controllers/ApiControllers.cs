using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc;

namespace ExpenseManagement.Controllers;

/// <summary>
/// API controller for expense operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class ExpensesController : ControllerBase
{
    private readonly IExpenseService _expenseService;
    private readonly ILogger<ExpensesController> _logger;

    public ExpensesController(IExpenseService expenseService, ILogger<ExpensesController> logger)
    {
        _expenseService = expenseService;
        _logger = logger;
    }

    /// <summary>
    /// Get all expenses
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<Expense>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<Expense>>> GetAll()
    {
        var (expenses, error) = await _expenseService.GetAllExpensesAsync();
        if (error != null)
        {
            _logger.LogWarning("Error retrieving expenses: {Message}", error.Message);
        }
        return Ok(expenses);
    }

    /// <summary>
    /// Get a specific expense by ID
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Expense), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<Expense>> GetById(int id)
    {
        var (expense, error) = await _expenseService.GetExpenseByIdAsync(id);
        if (error != null)
        {
            _logger.LogWarning("Error retrieving expense {Id}: {Message}", id, error.Message);
            return NotFound();
        }
        if (expense == null)
        {
            return NotFound();
        }
        return Ok(expense);
    }

    /// <summary>
    /// Get expenses filtered by status
    /// </summary>
    [HttpGet("status/{status}")]
    [ProducesResponseType(typeof(List<Expense>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<Expense>>> GetByStatus(string status)
    {
        var (expenses, error) = await _expenseService.GetExpensesByStatusAsync(status);
        if (error != null)
        {
            _logger.LogWarning("Error retrieving expenses by status {Status}: {Message}", status, error.Message);
        }
        return Ok(expenses);
    }

    /// <summary>
    /// Get expenses for a specific user
    /// </summary>
    [HttpGet("user/{userId}")]
    [ProducesResponseType(typeof(List<Expense>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<Expense>>> GetByUser(int userId)
    {
        var (expenses, error) = await _expenseService.GetExpensesByUserAsync(userId);
        if (error != null)
        {
            _logger.LogWarning("Error retrieving expenses for user {UserId}: {Message}", userId, error.Message);
        }
        return Ok(expenses);
    }

    /// <summary>
    /// Get expense summary by status
    /// </summary>
    [HttpGet("summary")]
    [ProducesResponseType(typeof(List<ExpenseSummary>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<ExpenseSummary>>> GetSummary()
    {
        var (summary, error) = await _expenseService.GetExpenseSummaryAsync();
        if (error != null)
        {
            _logger.LogWarning("Error retrieving expense summary: {Message}", error.Message);
        }
        return Ok(summary);
    }

    /// <summary>
    /// Create a new expense
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(object), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Create([FromBody] CreateExpenseRequest request)
    {
        var (expenseId, error) = await _expenseService.CreateExpenseAsync(request);
        if (error != null)
        {
            _logger.LogError("Error creating expense: {Message}", error.Message);
            return BadRequest(new { error = error.Message, guidance = error.Guidance });
        }
        return CreatedAtAction(nameof(GetById), new { id = expenseId }, new { expenseId });
    }

    /// <summary>
    /// Submit an expense for approval
    /// </summary>
    [HttpPost("{id}/submit")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Submit(int id)
    {
        var (success, error) = await _expenseService.SubmitExpenseAsync(id);
        if (error != null)
        {
            _logger.LogError("Error submitting expense {Id}: {Message}", id, error.Message);
            return BadRequest(new { error = error.Message });
        }
        if (!success)
        {
            return BadRequest(new { error = "Expense not found or already submitted" });
        }
        return Ok(new { message = "Expense submitted successfully" });
    }

    /// <summary>
    /// Approve an expense
    /// </summary>
    [HttpPost("{id}/approve")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Approve(int id, [FromQuery] int reviewerId)
    {
        var (success, error) = await _expenseService.ApproveExpenseAsync(id, reviewerId);
        if (error != null)
        {
            _logger.LogError("Error approving expense {Id}: {Message}", id, error.Message);
            return BadRequest(new { error = error.Message });
        }
        if (!success)
        {
            return BadRequest(new { error = "Expense not found or not in submitted status" });
        }
        return Ok(new { message = "Expense approved successfully" });
    }

    /// <summary>
    /// Reject an expense
    /// </summary>
    [HttpPost("{id}/reject")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Reject(int id, [FromQuery] int reviewerId)
    {
        var (success, error) = await _expenseService.RejectExpenseAsync(id, reviewerId);
        if (error != null)
        {
            _logger.LogError("Error rejecting expense {Id}: {Message}", id, error.Message);
            return BadRequest(new { error = error.Message });
        }
        if (!success)
        {
            return BadRequest(new { error = "Expense not found or not in submitted status" });
        }
        return Ok(new { message = "Expense rejected successfully" });
    }

    /// <summary>
    /// Delete an expense
    /// </summary>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult> Delete(int id)
    {
        var (success, error) = await _expenseService.DeleteExpenseAsync(id);
        if (error != null)
        {
            _logger.LogError("Error deleting expense {Id}: {Message}", id, error.Message);
            return BadRequest(new { error = error.Message });
        }
        if (!success)
        {
            return NotFound();
        }
        return Ok(new { message = "Expense deleted successfully" });
    }
}

/// <summary>
/// API controller for category operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class CategoriesController : ControllerBase
{
    private readonly IExpenseService _expenseService;

    public CategoriesController(IExpenseService expenseService)
    {
        _expenseService = expenseService;
    }

    /// <summary>
    /// Get all expense categories
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<Category>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<Category>>> GetAll()
    {
        var (categories, _) = await _expenseService.GetCategoriesAsync();
        return Ok(categories);
    }
}

/// <summary>
/// API controller for user operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class UsersController : ControllerBase
{
    private readonly IExpenseService _expenseService;

    public UsersController(IExpenseService expenseService)
    {
        _expenseService = expenseService;
    }

    /// <summary>
    /// Get all users
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<User>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<User>>> GetAll()
    {
        var (users, _) = await _expenseService.GetUsersAsync();
        return Ok(users);
    }
}

/// <summary>
/// API controller for status operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class StatusesController : ControllerBase
{
    private readonly IExpenseService _expenseService;

    public StatusesController(IExpenseService expenseService)
    {
        _expenseService = expenseService;
    }

    /// <summary>
    /// Get all expense statuses
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<ExpenseStatus>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<ExpenseStatus>>> GetAll()
    {
        var (statuses, _) = await _expenseService.GetStatusesAsync();
        return Ok(statuses);
    }
}

/// <summary>
/// API controller for chat operations
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class ChatController : ControllerBase
{
    private readonly IChatService _chatService;
    private readonly ILogger<ChatController> _logger;

    public ChatController(IChatService chatService, ILogger<ChatController> logger)
    {
        _chatService = chatService;
        _logger = logger;
    }

    /// <summary>
    /// Check if chat is configured
    /// </summary>
    [HttpGet("status")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public ActionResult GetStatus()
    {
        return Ok(new { configured = _chatService.IsConfigured });
    }

    /// <summary>
    /// Send a chat message
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(ChatResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ChatResponse>> SendMessage([FromBody] ChatRequest request)
    {
        _logger.LogInformation("Received chat message: {Message}", request.Message);
        var response = await _chatService.SendMessageAsync(request.Message, request.History);
        return Ok(response);
    }
}
