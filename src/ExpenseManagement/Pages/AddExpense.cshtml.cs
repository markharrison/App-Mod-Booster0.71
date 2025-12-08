using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class AddExpenseModel : PageModel
{
    private readonly IExpenseService _expenseService;
    private readonly ILogger<AddExpenseModel> _logger;

    public List<Category> Categories { get; set; } = new();
    public List<User> Users { get; set; } = new();

    [BindProperty]
    public decimal Amount { get; set; }

    [BindProperty]
    public DateTime ExpenseDate { get; set; } = DateTime.Today;

    [BindProperty]
    public int CategoryId { get; set; } = 1;

    [BindProperty]
    public int UserId { get; set; } = 1;

    [BindProperty]
    public string? Description { get; set; }

    public AddExpenseModel(IExpenseService expenseService, ILogger<AddExpenseModel> logger)
    {
        _expenseService = expenseService;
        _logger = logger;
    }

    public async Task OnGetAsync()
    {
        await LoadDataAsync();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        await LoadDataAsync();

        if (!ModelState.IsValid)
        {
            return Page();
        }

        var request = new CreateExpenseRequest
        {
            UserId = UserId,
            CategoryId = CategoryId,
            Amount = Amount,
            ExpenseDate = ExpenseDate,
            Description = Description
        };

        var (expenseId, error) = await _expenseService.CreateExpenseAsync(request);

        if (error != null)
        {
            ViewData["Error"] = error.Message;
            ViewData["ErrorLocation"] = error.Location;
            ViewData["ErrorGuidance"] = error.Guidance;
            return Page();
        }

        return RedirectToPage("/Expenses");
    }

    private async Task LoadDataAsync()
    {
        var (categories, catError) = await _expenseService.GetCategoriesAsync();
        var (users, userError) = await _expenseService.GetUsersAsync();

        Categories = categories;
        Users = users;

        var error = catError ?? userError;
        if (error != null)
        {
            ViewData["Error"] = error.Message;
            ViewData["ErrorLocation"] = error.Location;
            ViewData["ErrorGuidance"] = error.Guidance;
        }
    }
}
