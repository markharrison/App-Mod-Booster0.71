using ExpenseManagement.Services;

var appBuilder = WebApplication.CreateBuilder(args);

appBuilder.Services.AddRazorPages();
appBuilder.Services.AddControllers();

appBuilder.Services.AddEndpointsApiExplorer();
appBuilder.Services.AddSwaggerGen(swaggerConfig =>
{
    swaggerConfig.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    {
        Title = "Expense Management API",
        Version = "v1",
        Description = "REST API for expense tracking and approval workflows"
    });
});

appBuilder.Services.AddApplicationInsightsTelemetry();

appBuilder.Services.AddScoped<IExpenseDataService, ExpenseDataService>();
appBuilder.Services.AddScoped<IAiChatService, AzureOpenAiChatService>();

appBuilder.Services.AddLogging(loggingConfig =>
{
    loggingConfig.AddConsole();
    loggingConfig.AddDebug();
    loggingConfig.AddApplicationInsights();
});

var webApp = appBuilder.Build();

if (webApp.Environment.IsDevelopment())
{
    webApp.UseDeveloperExceptionPage();
}
else
{
    webApp.UseExceptionHandler("/Error");
    webApp.UseHsts();
}

webApp.UseSwagger();
webApp.UseSwaggerUI(swaggerUiConfig =>
{
    swaggerUiConfig.SwaggerEndpoint("/swagger/v1/swagger.json", "Expense Management API v1");
    swaggerUiConfig.RoutePrefix = "swagger";
});

webApp.UseHttpsRedirection();
webApp.UseStaticFiles();
webApp.UseRouting();
webApp.UseAuthorization();

webApp.MapRazorPages();
webApp.MapControllers();

webApp.Run();

// Make Program class accessible to tests
public partial class Program { }
