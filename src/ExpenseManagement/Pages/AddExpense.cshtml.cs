using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class AddExpenseModel : PageModel
{
    private readonly IExpenseDataService _financialRepository;
    private readonly ILogger<AddExpenseModel> _eventRecorder;

    [BindProperty]
    public int SelectedCategoryIdentifier { get; set; }
    
    [BindProperty]
    public decimal MonetaryQuantity { get; set; }
    
    [BindProperty]
    public DateTime TransactionTimestamp { get; set; } = DateTime.Today;
    
    [BindProperty]
    public string? NarrativeDetails { get; set; }

    public IReadOnlyList<ExpenseCategory> AvailableTaxonomies { get; private set; } = Array.Empty<ExpenseCategory>();
    public bool SubmissionSuccessful { get; private set; }
    public int GeneratedClaimIdentifier { get; private set; }

    public AddExpenseModel(IExpenseDataService financialRepository, ILogger<AddExpenseModel> eventRecorder)
    {
        _financialRepository = financialRepository;
        _eventRecorder = eventRecorder;
    }

    public async Task OnGetAsync()
    {
        await LoadCategoryTaxonomyAsync();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        await LoadCategoryTaxonomyAsync();

        if (!ModelState.IsValid)
        {
            return Page();
        }

        if (SelectedCategoryIdentifier <= 0)
        {
            ViewData["ErrorInfo"] = "Category selection required";
            return Page();
        }

        if (MonetaryQuantity <= 0)
        {
            ViewData["ErrorInfo"] = "Amount must be greater than zero";
            return Page();
        }

        var claimBlueprint = new CreateExpenseRequest
        {
            UserId = 1,
            CategoryId = SelectedCategoryIdentifier,
            Amount = MonetaryQuantity,
            Currency = "GBP",
            ExpenseDate = TransactionTimestamp,
            Description = NarrativeDetails
        };

        try
        {
            _eventRecorder.LogInformation("Initiating claim registration for £{Amount}", MonetaryQuantity);
            GeneratedClaimIdentifier = await _financialRepository.RegisterNewExpenseAsync(claimBlueprint);
            
            if (GeneratedClaimIdentifier > 0)
            {
                SubmissionSuccessful = true;
                _eventRecorder.LogInformation("Claim #{ClaimId} registered successfully", GeneratedClaimIdentifier);
                
                SelectedCategoryIdentifier = 0;
                MonetaryQuantity = 0;
                TransactionTimestamp = DateTime.Today;
                NarrativeDetails = null;
                ModelState.Clear();
            }
            else
            {
                ViewData["ErrorInfo"] = "Claim registration failed - database unavailable";
                ViewData["ErrorGuidance"] = "Please verify your connection and retry";
            }
        }
        catch (Exception anomaly)
        {
            _eventRecorder.LogError(anomaly, "Claim registration encountered critical anomaly");
            ViewData["ErrorInfo"] = "Unexpected failure during claim submission";
            ViewData["ErrorLocation"] = "AddExpense.cshtml.cs - Registration phase";
            ViewData["ErrorGuidance"] = "System administrators have been notified. Please retry shortly.";
        }

        return Page();
    }

    private async Task LoadCategoryTaxonomyAsync()
    {
        try
        {
            AvailableTaxonomies = await _financialRepository.FetchActiveCategoriesAsync();
        }
        catch (Exception anomaly)
        {
            _eventRecorder.LogError(anomaly, "Category taxonomy retrieval failed");
            AvailableTaxonomies = Array.Empty<ExpenseCategory>();
        }
    }
}
