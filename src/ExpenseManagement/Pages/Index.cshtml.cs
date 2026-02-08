using ExpenseManagement.Models;
using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class IndexModel : PageModel
{
    private readonly IExpenseDataService _financialRepository;
    private readonly ILogger<IndexModel> _eventRecorder;

    public IReadOnlyList<ExpenseSummaryMetrics> MetricSpheres { get; private set; } = Array.Empty<ExpenseSummaryMetrics>();
    public int TotalClaimVolume { get; private set; }
    public decimal AggregatedFinancialValue { get; private set; }

    public IndexModel(IExpenseDataService financialRepository, ILogger<IndexModel> eventRecorder)
    {
        _financialRepository = financialRepository;
        _eventRecorder = eventRecorder;
    }

    public async Task OnGetAsync()
    {
        try
        {
            _eventRecorder.LogInformation("Dashboard metrics computation initiated");
            MetricSpheres = await _financialRepository.FetchExpenseSummaryDataAsync();
            
            TotalClaimVolume = MetricSpheres.Sum(sphere => sphere.ExpenseCount);
            AggregatedFinancialValue = MetricSpheres.Sum(sphere => sphere.TotalAmount);
        }
        catch (Exception anomaly)
        {
            _eventRecorder.LogError(anomaly, "Metric sphere generation encountered anomaly");
            ViewData["ErrorInfo"] = "Dashboard metrics temporarily unavailable";
            ViewData["ErrorLocation"] = "Index.cshtml.cs - Metric computation phase";
            ViewData["ErrorGuidance"] = "The system is displaying cached data. Refresh to retry.";
        }
    }
}
