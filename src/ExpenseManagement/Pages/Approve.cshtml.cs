using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class ApproveModel : PageModel
{
    private readonly IExpenseService _expenseService;
    private readonly ILogger<ApproveModel> _logger;

    public List<Expense> PendingExpenses { get; set; } = new();
    public List<User> Managers { get; set; } = new();

    public ApproveModel(IExpenseService expenseService, ILogger<ApproveModel> logger)
    {
        _expenseService = expenseService;
        _logger = logger;
    }

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
    }

    public async Task<IActionResult> OnPostApproveAsync(int id, int reviewerId)
    {
        var (success, error) = await _expenseService.ApproveExpenseAsync(id, reviewerId);
        
        if (error != null)
        {
            _logger.LogError("Error approving expense: {Message}", error.Message);
        }

        return RedirectToPage();
    }

    public async Task<IActionResult> OnPostRejectAsync(int id, int reviewerId)
    {
        var (success, error) = await _expenseService.RejectExpenseAsync(id, reviewerId);
        
        if (error != null)
        {
            _logger.LogError("Error rejecting expense: {Message}", error.Message);
        }

        return RedirectToPage();
    }

    private async Task LoadDataAsync()
    {
        var (expenses, expenseError) = await _expenseService.GetExpensesByStatusAsync("Submitted");
        var (users, userError) = await _expenseService.GetUsersAsync();

        PendingExpenses = expenses;
        Managers = users.Where(u => u.RoleName == "Manager").ToList();

        var error = expenseError ?? userError;
        if (error != null)
        {
            ViewData["Error"] = error.Message;
            ViewData["ErrorLocation"] = error.Location;
            ViewData["ErrorGuidance"] = error.Guidance;
        }
    }
}
