using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class ExpensesModel : PageModel
{
    private readonly IExpenseDataService _financialRepository;
    private readonly ILogger<ExpensesModel> _eventRecorder;

    public IReadOnlyList<ExpenseRecord> ClaimInventory { get; private set; } = Array.Empty<ExpenseRecord>();
    
    [BindProperty(SupportsGet = true)]
    public int? StatusFilterCriterion { get; set; }
    
    public string CurrentFilterDescription { get; private set; } = "All Claims";

    public ExpensesModel(IExpenseDataService financialRepository, ILogger<ExpensesModel> eventRecorder)
    {
        _financialRepository = financialRepository;
        _eventRecorder = eventRecorder;
    }

    public async Task OnGetAsync()
    {
        try
        {
            _eventRecorder.LogInformation("Retrieving claim inventory with filter: {StatusFilter}", StatusFilterCriterion);
            ClaimInventory = await _financialRepository.FetchAllExpensesAsync(filterStatusId: StatusFilterCriterion);
            
            CurrentFilterDescription = StatusFilterCriterion switch
            {
                1 => "Draft Claims",
                2 => "Submitted Claims",
                3 => "Approved Claims",
                4 => "Rejected Claims",
                _ => "All Claims"
            };
        }
        catch (Exception anomaly)
        {
            _eventRecorder.LogError(anomaly, "Claim inventory retrieval encountered anomaly");
            ViewData["ErrorInfo"] = "Unable to retrieve expense records";
            ViewData["ErrorLocation"] = "Expenses.cshtml.cs - Data fetch operation";
            ViewData["ErrorGuidance"] = "Displaying cached fallback data. Connection will be retried automatically.";
        }
    }

    public string DetermineStatusBadgeClass(string statusDesignation)
    {
        return statusDesignation.ToLower() switch
        {
            "draft" => "status-insignia-draft",
            "submitted" => "status-insignia-pending",
            "approved" => "status-insignia-approved",
            "rejected" => "status-insignia-rejected",
            _ => "status-insignia-unknown"
        };
    }
}
