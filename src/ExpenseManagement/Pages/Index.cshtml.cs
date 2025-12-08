using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class IndexModel : PageModel
{
    private readonly IExpenseService _expenseService;
    private readonly ILogger<IndexModel> _logger;

    public List<ExpenseSummary> Summary { get; set; } = new();
    public List<Expense> RecentExpenses { get; set; } = new();

    public IndexModel(IExpenseService expenseService, ILogger<IndexModel> logger)
    {
        _expenseService = expenseService;
        _logger = logger;
    }

    public async Task OnGetAsync()
    {
        var (summary, summaryError) = await _expenseService.GetExpenseSummaryAsync();
        var (expenses, expenseError) = await _expenseService.GetAllExpensesAsync();

        Summary = summary;
        RecentExpenses = expenses;

        var error = summaryError ?? expenseError;
        if (error != null)
        {
            ViewData["Error"] = error.Message;
            ViewData["ErrorLocation"] = error.Location;
            ViewData["ErrorGuidance"] = error.Guidance;
        }
    }
}
