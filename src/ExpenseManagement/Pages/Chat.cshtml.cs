using ExpenseManagement.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ExpenseManagement.Pages;

public class ChatModel : PageModel
{
    private readonly IAiChatService _neuralConcierge;
    private readonly ILogger<ChatModel> _eventRecorder;

    public bool IntelligenceEngineAvailable { get; private set; }

    public ChatModel(IAiChatService neuralConcierge, ILogger<ChatModel> eventRecorder)
    {
        _neuralConcierge = neuralConcierge;
        _eventRecorder = eventRecorder;
    }

    public void OnGet()
    {
        IntelligenceEngineAvailable = _neuralConcierge.IsConfigured;
        
        if (!IntelligenceEngineAvailable)
        {
            _eventRecorder.LogInformation("Neural concierge not configured - displaying availability notice");
        }
        else
        {
            _eventRecorder.LogInformation("Neural concierge active and ready for conversation");
        }
    }
}
