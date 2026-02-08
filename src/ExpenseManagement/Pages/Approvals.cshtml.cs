using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class ApprovalsModel : PageModel
{
    private readonly IExpenseDataService _financialRepository;
    private readonly ILogger<ApprovalsModel> _eventRecorder;

    public IReadOnlyList<ExpenseRecord> PendingVerdictQueue { get; private set; } = Array.Empty<ExpenseRecord>();
    public bool VerdictRenderingComplete { get; private set; }
    public string? VerdictOutcomeMessage { get; private set; }

    public ApprovalsModel(IExpenseDataService financialRepository, ILogger<ApprovalsModel> eventRecorder)
    {
        _financialRepository = financialRepository;
        _eventRecorder = eventRecorder;
    }

    public async Task OnGetAsync()
    {
        await LoadPendingVerdictQueueAsync();
    }

    public async Task<IActionResult> OnPostRenderVerdictAsync(int claimIdentifier, string verdictDecision)
    {
        const int ReviewerCredentialId = 2;
        
        try
        {
            bool verdictExecuted = false;

            if (verdictDecision == "approve")
            {
                _eventRecorder.LogInformation("Executing approval verdict for claim #{ClaimId}", claimIdentifier);
                verdictExecuted = await _financialRepository.ProcessExpenseApprovalAsync(claimIdentifier, ReviewerCredentialId);
                VerdictOutcomeMessage = verdictExecuted 
                    ? $"✅ Claim #{claimIdentifier} has been approved successfully" 
                    : "⚠️ Approval verdict could not be executed - verify claim status";
            }
            else if (verdictDecision == "reject")
            {
                _eventRecorder.LogInformation("Executing rejection verdict for claim #{ClaimId}", claimIdentifier);
                verdictExecuted = await _financialRepository.ProcessExpenseRejectionAsync(claimIdentifier, ReviewerCredentialId);
                VerdictOutcomeMessage = verdictExecuted 
                    ? $"❌ Claim #{claimIdentifier} has been rejected" 
                    : "⚠️ Rejection verdict could not be executed - verify claim status";
            }
            else
            {
                VerdictOutcomeMessage = "⚠️ Invalid verdict decision received";
            }

            VerdictRenderingComplete = verdictExecuted;
        }
        catch (Exception anomaly)
        {
            _eventRecorder.LogError(anomaly, "Verdict execution encountered critical anomaly for claim #{ClaimId}", claimIdentifier);
            ViewData["ErrorInfo"] = "Verdict execution failed";
            ViewData["ErrorLocation"] = "Approvals.cshtml.cs - Verdict rendering phase";
            ViewData["ErrorGuidance"] = "The system encountered an issue. Please verify claim status and retry.";
        }

        await LoadPendingVerdictQueueAsync();
        return Page();
    }

    private async Task LoadPendingVerdictQueueAsync()
    {
        try
        {
            const int SubmittedStatusCode = 2;
            PendingVerdictQueue = await _financialRepository.FetchAllExpensesAsync(filterStatusId: SubmittedStatusCode);
            _eventRecorder.LogInformation("Loaded {Count} claims awaiting verdict", PendingVerdictQueue.Count);
        }
        catch (Exception anomaly)
        {
            _eventRecorder.LogError(anomaly, "Failed to load pending verdict queue");
            PendingVerdictQueue = Array.Empty<ExpenseRecord>();
        }
    }
}
