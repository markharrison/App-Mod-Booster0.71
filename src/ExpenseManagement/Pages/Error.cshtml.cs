using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Diagnostics;

namespace ExpenseManagement.Pages;

[ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
[IgnoreAntiforgeryToken]
public class ErrorModel : PageModel
{
    public string? RequestIdentifierToken { get; set; }
    public string? FaultNarrative { get; set; }
    public string? FaultCoordinates { get; set; }
    public string? RemediationGuidance { get; set; }

    private readonly ILogger<ErrorModel> _eventRecorder;

    public ErrorModel(ILogger<ErrorModel> eventRecorder)
    {
        _eventRecorder = eventRecorder;
    }

    public void OnGet()
    {
        RequestIdentifierToken = Activity.Current?.Id ?? HttpContext.TraceIdentifier;
        
        FaultNarrative = ViewData["ErrorInfo"] as string 
                        ?? "An unexpected system fault has occurred";
        
        FaultCoordinates = ViewData["ErrorLocation"] as string 
                          ?? "Location information unavailable";
        
        RemediationGuidance = ViewData["ErrorGuidance"] as string 
                             ?? DetermineContextualGuidance();

        _eventRecorder.LogError("Error page rendered - Request ID: {RequestId}, Fault: {Fault}", 
            RequestIdentifierToken, FaultNarrative);
    }

    private string DetermineContextualGuidance()
    {
        var faultDescription = FaultNarrative?.ToLower() ?? "";

        if (faultDescription.Contains("managed identity") || faultDescription.Contains("authentication"))
        {
            return "Managed Identity authentication requires proper Azure configuration. " +
                   "Verify that the App Service has a User-Assigned Managed Identity configured, " +
                   "and that this identity has been granted appropriate database permissions.";
        }

        if (faultDescription.Contains("database") || faultDescription.Contains("connection"))
        {
            return "Database connectivity issue detected. Verify that the connection string is properly configured " +
                   "and that the Azure SQL firewall allows connections from this App Service.";
        }

        if (faultDescription.Contains("openai") || faultDescription.Contains("genai"))
        {
            return "Azure OpenAI service is not configured. To enable AI features, redeploy using the -DeployGenAI switch.";
        }

        return "Please review the system logs for additional diagnostic information. " +
               "If the issue persists, contact your system administrator.";
    }
}
