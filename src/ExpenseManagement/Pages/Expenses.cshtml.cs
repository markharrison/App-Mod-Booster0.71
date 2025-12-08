using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class ExpensesModel : PageModel
{
    private readonly IExpenseService _expenseService;
    private readonly ILogger<ExpensesModel> _logger;

    public List<Expense> Expenses { get; set; } = new();
    
    [BindProperty(SupportsGet = true)]
    public string? StatusFilter { get; set; }

    public ExpensesModel(IExpenseService expenseService, ILogger<ExpensesModel> logger)
    {
        _expenseService = expenseService;
        _logger = logger;
    }

    public async Task OnGetAsync()
    {
        ErrorInfo? error;

        if (!string.IsNullOrEmpty(StatusFilter))
        {
            (Expenses, error) = await _expenseService.GetExpensesByStatusAsync(StatusFilter);
        }
        else
        {
            (Expenses, error) = await _expenseService.GetAllExpensesAsync();
        }

        if (error != null)
        {
            ViewData["Error"] = error.Message;
            ViewData["ErrorLocation"] = error.Location;
            ViewData["ErrorGuidance"] = error.Guidance;
        }
    }

    public async Task<IActionResult> OnPostSubmitAsync(int id)
    {
        await _expenseService.SubmitExpenseAsync(id);
        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostDeleteAsync(int id)
    {
        await _expenseService.DeleteExpenseAsync(id);
        return RedirectToPage();
    }
}
