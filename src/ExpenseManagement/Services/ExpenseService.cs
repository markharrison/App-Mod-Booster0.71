using ExpenseManagement.Models;
using Microsoft.Data.SqlClient;
using System.Data;

namespace ExpenseManagement.Services;

public interface IExpenseDataService
{
    Task<IReadOnlyList<ExpenseRecord>> FetchAllExpensesAsync(int? filterUserId = null, int? filterStatusId = null);
    Task<ExpenseRecord?> FetchExpenseByIdentifierAsync(int expenseIdentifier);
    Task<int> RegisterNewExpenseAsync(CreateExpenseRequest requestData);
    Task<bool> SubmitExpenseForReviewAsync(int expenseIdentifier);
    Task<bool> ProcessExpenseApprovalAsync(int expenseIdentifier, int reviewerIdentifier);
    Task<bool> ProcessExpenseRejectionAsync(int expenseIdentifier, int reviewerIdentifier);
    Task<IReadOnlyList<ExpenseCategory>> FetchActiveCategoriesAsync();
    Task<IReadOnlyList<UserProfile>> FetchActiveUsersAsync();
    Task<IReadOnlyList<ExpenseSummaryMetrics>> FetchExpenseSummaryDataAsync(int? filterUserId = null);
}

public sealed class ExpenseDataService : IExpenseDataService
{
    private readonly string? _dbConnectionString;
    private readonly ILogger<ExpenseDataService> _logWriter;
    private readonly bool _hasValidConfiguration;

    public ExpenseDataService(IConfiguration configReader, ILogger<ExpenseDataService> logWriter)
    {
        _logWriter = logWriter;
        _dbConnectionString = configReader.GetConnectionString("DefaultConnection");
        _hasValidConfiguration = !string.IsNullOrWhiteSpace(_dbConnectionString);
        
        if (!_hasValidConfiguration)
        {
            _logWriter.LogWarning("Database connection not configured - will use fallback data");
        }
    }

    public async Task<IReadOnlyList<ExpenseRecord>> FetchAllExpensesAsync(int? filterUserId = null, int? filterStatusId = null)
    {
        if (!_hasValidConfiguration)
        {
            return GenerateFallbackExpenseData();
        }

        try
        {
            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_GetExpenses", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;

            if (filterUserId.HasValue)
            {
                dbCommand.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = filterUserId.Value });
            }
            
            if (filterStatusId.HasValue)
            {
                dbCommand.Parameters.Add(new SqlParameter("@StatusId", SqlDbType.Int) { Value = filterStatusId.Value });
            }

            await dbConnection.OpenAsync();
            await using var dataReader = await dbCommand.ExecuteReaderAsync();

            var resultCollection = new List<ExpenseRecord>();
            while (await dataReader.ReadAsync())
            {
                resultCollection.Add(MapReaderToExpenseRecord(dataReader));
            }

            return resultCollection;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Database query failed at {Location}", 
                $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return GenerateFallbackExpenseData();
        }
    }

    public async Task<ExpenseRecord?> FetchExpenseByIdentifierAsync(int expenseIdentifier)
    {
        if (!_hasValidConfiguration)
        {
            return GenerateFallbackExpenseData().FirstOrDefault(e => e.ExpenseId == expenseIdentifier);
        }

        try
        {
            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_GetExpenseById", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;
            dbCommand.Parameters.Add(new SqlParameter("@ExpenseId", SqlDbType.Int) { Value = expenseIdentifier });

            await dbConnection.OpenAsync();
            await using var dataReader = await dbCommand.ExecuteReaderAsync();

            if (await dataReader.ReadAsync())
            {
                return MapReaderToExpenseRecord(dataReader);
            }

            return null;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Failed to fetch expense {ExpenseId} at {Location}", 
                expenseIdentifier, $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return null;
        }
    }

    public async Task<int> RegisterNewExpenseAsync(CreateExpenseRequest requestData)
    {
        if (!_hasValidConfiguration)
        {
            _logWriter.LogWarning("Cannot create expense - no database connection");
            return -1;
        }

        try
        {
            var amountInMinorUnits = ConvertDecimalToMinorUnits(requestData.Amount);

            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_CreateExpense", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;
            
            dbCommand.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = requestData.UserId });
            dbCommand.Parameters.Add(new SqlParameter("@CategoryId", SqlDbType.Int) { Value = requestData.CategoryId });
            dbCommand.Parameters.Add(new SqlParameter("@AmountMinor", SqlDbType.Int) { Value = amountInMinorUnits });
            dbCommand.Parameters.Add(new SqlParameter("@Currency", SqlDbType.NVarChar, 3) { Value = requestData.Currency });
            dbCommand.Parameters.Add(new SqlParameter("@ExpenseDate", SqlDbType.Date) { Value = requestData.ExpenseDate });
            
            if (!string.IsNullOrWhiteSpace(requestData.Description))
            {
                dbCommand.Parameters.Add(new SqlParameter("@Description", SqlDbType.NVarChar, 1000) { Value = requestData.Description });
            }
            
            if (!string.IsNullOrWhiteSpace(requestData.ReceiptFile))
            {
                dbCommand.Parameters.Add(new SqlParameter("@ReceiptFile", SqlDbType.NVarChar, 500) { Value = requestData.ReceiptFile });
            }

            await dbConnection.OpenAsync();
            var resultScalar = await dbCommand.ExecuteScalarAsync();
            
            return resultScalar != null ? Convert.ToInt32(resultScalar) : -1;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Failed to create expense at {Location}", 
                $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return -1;
        }
    }

    public async Task<bool> SubmitExpenseForReviewAsync(int expenseIdentifier)
    {
        if (!_hasValidConfiguration) return false;

        try
        {
            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_SubmitExpense", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;
            dbCommand.Parameters.Add(new SqlParameter("@ExpenseId", SqlDbType.Int) { Value = expenseIdentifier });

            await dbConnection.OpenAsync();
            await using var dataReader = await dbCommand.ExecuteReaderAsync();
            
            if (await dataReader.ReadAsync())
            {
                var affectedRows = dataReader.GetInt32(0);
                return affectedRows > 0;
            }

            return false;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Failed to submit expense {ExpenseId} at {Location}", 
                expenseIdentifier, $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return false;
        }
    }

    public async Task<bool> ProcessExpenseApprovalAsync(int expenseIdentifier, int reviewerIdentifier)
    {
        if (!_hasValidConfiguration) return false;

        try
        {
            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_ApproveExpense", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;
            dbCommand.Parameters.Add(new SqlParameter("@ExpenseId", SqlDbType.Int) { Value = expenseIdentifier });
            dbCommand.Parameters.Add(new SqlParameter("@ReviewerId", SqlDbType.Int) { Value = reviewerIdentifier });

            await dbConnection.OpenAsync();
            await using var dataReader = await dbCommand.ExecuteReaderAsync();
            
            if (await dataReader.ReadAsync())
            {
                var affectedRows = dataReader.GetInt32(0);
                return affectedRows > 0;
            }

            return false;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Failed to approve expense {ExpenseId} at {Location}", 
                expenseIdentifier, $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return false;
        }
    }

    public async Task<bool> ProcessExpenseRejectionAsync(int expenseIdentifier, int reviewerIdentifier)
    {
        if (!_hasValidConfiguration) return false;

        try
        {
            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_RejectExpense", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;
            dbCommand.Parameters.Add(new SqlParameter("@ExpenseId", SqlDbType.Int) { Value = expenseIdentifier });
            dbCommand.Parameters.Add(new SqlParameter("@ReviewerId", SqlDbType.Int) { Value = reviewerIdentifier });

            await dbConnection.OpenAsync();
            await using var dataReader = await dbCommand.ExecuteReaderAsync();
            
            if (await dataReader.ReadAsync())
            {
                var affectedRows = dataReader.GetInt32(0);
                return affectedRows > 0;
            }

            return false;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Failed to reject expense {ExpenseId} at {Location}", 
                expenseIdentifier, $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return false;
        }
    }

    public async Task<IReadOnlyList<ExpenseCategory>> FetchActiveCategoriesAsync()
    {
        if (!_hasValidConfiguration)
        {
            return GenerateFallbackCategoryData();
        }

        try
        {
            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_GetCategories", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;

            await dbConnection.OpenAsync();
            await using var dataReader = await dbCommand.ExecuteReaderAsync();

            var resultCollection = new List<ExpenseCategory>();
            while (await dataReader.ReadAsync())
            {
                resultCollection.Add(new ExpenseCategory
                {
                    CategoryId = dataReader.GetInt32(dataReader.GetOrdinal("CategoryId")),
                    CategoryName = dataReader.GetString(dataReader.GetOrdinal("CategoryName")),
                    IsActive = dataReader.GetBoolean(dataReader.GetOrdinal("IsActive"))
                });
            }

            return resultCollection;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Failed to fetch categories at {Location}", 
                $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return GenerateFallbackCategoryData();
        }
    }

    public async Task<IReadOnlyList<UserProfile>> FetchActiveUsersAsync()
    {
        if (!_hasValidConfiguration)
        {
            return GenerateFallbackUserData();
        }

        try
        {
            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_GetUsers", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;

            await dbConnection.OpenAsync();
            await using var dataReader = await dbCommand.ExecuteReaderAsync();

            var resultCollection = new List<UserProfile>();
            while (await dataReader.ReadAsync())
            {
                resultCollection.Add(new UserProfile
                {
                    UserId = dataReader.GetInt32(dataReader.GetOrdinal("UserId")),
                    UserName = dataReader.GetString(dataReader.GetOrdinal("UserName")),
                    Email = dataReader.GetString(dataReader.GetOrdinal("Email")),
                    RoleId = dataReader.GetInt32(dataReader.GetOrdinal("RoleId")),
                    RoleName = dataReader.GetString(dataReader.GetOrdinal("RoleName")),
                    ManagerId = dataReader.IsDBNull(dataReader.GetOrdinal("ManagerId")) 
                        ? null 
                        : dataReader.GetInt32(dataReader.GetOrdinal("ManagerId")),
                    ManagerName = dataReader.IsDBNull(dataReader.GetOrdinal("ManagerName")) 
                        ? null 
                        : dataReader.GetString(dataReader.GetOrdinal("ManagerName")),
                    IsActive = dataReader.GetBoolean(dataReader.GetOrdinal("IsActive")),
                    CreatedAt = dataReader.GetDateTime(dataReader.GetOrdinal("CreatedAt"))
                });
            }

            return resultCollection;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Failed to fetch users at {Location}", 
                $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return GenerateFallbackUserData();
        }
    }

    public async Task<IReadOnlyList<ExpenseSummaryMetrics>> FetchExpenseSummaryDataAsync(int? filterUserId = null)
    {
        if (!_hasValidConfiguration)
        {
            return GenerateFallbackSummaryData();
        }

        try
        {
            await using var dbConnection = new SqlConnection(_dbConnectionString);
            await using var dbCommand = new SqlCommand("usp_GetExpenseSummary", dbConnection);
            dbCommand.CommandType = CommandType.StoredProcedure;

            if (filterUserId.HasValue)
            {
                dbCommand.Parameters.Add(new SqlParameter("@UserId", SqlDbType.Int) { Value = filterUserId.Value });
            }

            await dbConnection.OpenAsync();
            await using var dataReader = await dbCommand.ExecuteReaderAsync();

            var resultCollection = new List<ExpenseSummaryMetrics>();
            while (await dataReader.ReadAsync())
            {
                resultCollection.Add(new ExpenseSummaryMetrics
                {
                    StatusName = dataReader.GetString(dataReader.GetOrdinal("StatusName")),
                    ExpenseCount = dataReader.GetInt32(dataReader.GetOrdinal("ExpenseCount")),
                    TotalAmount = dataReader.GetDecimal(dataReader.GetOrdinal("TotalAmount"))
                });
            }

            return resultCollection;
        }
        catch (Exception ex)
        {
            _logWriter.LogError(ex, "Failed to fetch summary at {Location}", 
                $"{nameof(ExpenseDataService)}.cs:Line {GetCurrentLineNumber()}");
            return GenerateFallbackSummaryData();
        }
    }

    private static ExpenseRecord MapReaderToExpenseRecord(SqlDataReader dataReader)
    {
        return new ExpenseRecord
        {
            ExpenseId = dataReader.GetInt32(dataReader.GetOrdinal("ExpenseId")),
            UserId = dataReader.GetInt32(dataReader.GetOrdinal("UserId")),
            UserName = dataReader.GetString(dataReader.GetOrdinal("UserName")),
            CategoryId = dataReader.GetInt32(dataReader.GetOrdinal("CategoryId")),
            CategoryName = dataReader.GetString(dataReader.GetOrdinal("CategoryName")),
            StatusId = dataReader.GetInt32(dataReader.GetOrdinal("StatusId")),
            StatusName = dataReader.GetString(dataReader.GetOrdinal("StatusName")),
            AmountMinor = dataReader.GetInt32(dataReader.GetOrdinal("AmountMinor")),
            Amount = dataReader.GetDecimal(dataReader.GetOrdinal("AmountDecimal")),
            Currency = dataReader.GetString(dataReader.GetOrdinal("Currency")),
            ExpenseDate = dataReader.GetDateTime(dataReader.GetOrdinal("ExpenseDate")),
            Description = dataReader.IsDBNull(dataReader.GetOrdinal("Description")) 
                ? null 
                : dataReader.GetString(dataReader.GetOrdinal("Description")),
            ReceiptFile = dataReader.IsDBNull(dataReader.GetOrdinal("ReceiptFile")) 
                ? null 
                : dataReader.GetString(dataReader.GetOrdinal("ReceiptFile")),
            SubmittedAt = dataReader.IsDBNull(dataReader.GetOrdinal("SubmittedAt")) 
                ? null 
                : dataReader.GetDateTime(dataReader.GetOrdinal("SubmittedAt")),
            ReviewedBy = dataReader.IsDBNull(dataReader.GetOrdinal("ReviewedBy")) 
                ? null 
                : dataReader.GetInt32(dataReader.GetOrdinal("ReviewedBy")),
            ReviewerName = dataReader.IsDBNull(dataReader.GetOrdinal("ReviewedByName")) 
                ? null 
                : dataReader.GetString(dataReader.GetOrdinal("ReviewedByName")),
            ReviewedAt = dataReader.IsDBNull(dataReader.GetOrdinal("ReviewedAt")) 
                ? null 
                : dataReader.GetDateTime(dataReader.GetOrdinal("ReviewedAt")),
            CreatedAt = dataReader.GetDateTime(dataReader.GetOrdinal("CreatedAt"))
        };
    }

    private static int ConvertDecimalToMinorUnits(decimal amount) => (int)(amount * 100);

    private static int GetCurrentLineNumber([System.Runtime.CompilerServices.CallerLineNumber] int lineNumber = 0) => lineNumber;

    private static IReadOnlyList<ExpenseRecord> GenerateFallbackExpenseData()
    {
        var baseDate = DateTime.Now.AddDays(-30);
        return new List<ExpenseRecord>
        {
            new() { ExpenseId = 1, UserId = 1, UserName = "Alice Johnson", CategoryId = 1, CategoryName = "Travel", 
                    StatusId = 2, StatusName = "Submitted", Amount = 125.50m, AmountMinor = 12550, Currency = "GBP",
                    ExpenseDate = baseDate.AddDays(5), Description = "Train tickets London-Manchester", 
                    SubmittedAt = baseDate.AddDays(6), CreatedAt = baseDate.AddDays(5) },
            new() { ExpenseId = 2, UserId = 2, UserName = "Bob Smith", CategoryId = 2, CategoryName = "Meals", 
                    StatusId = 3, StatusName = "Approved", Amount = 45.00m, AmountMinor = 4500, Currency = "GBP",
                    ExpenseDate = baseDate.AddDays(10), Description = "Team lunch with client", 
                    ReviewedBy = 3, ReviewerName = "Carol Manager", SubmittedAt = baseDate.AddDays(11), 
                    ReviewedAt = baseDate.AddDays(12), CreatedAt = baseDate.AddDays(10) },
            new() { ExpenseId = 3, UserId = 1, UserName = "Alice Johnson", CategoryId = 3, CategoryName = "Accommodation", 
                    StatusId = 1, StatusName = "Draft", Amount = 180.00m, AmountMinor = 18000, Currency = "GBP",
                    ExpenseDate = baseDate.AddDays(15), Description = "Hotel overnight Birmingham", 
                    CreatedAt = baseDate.AddDays(15) }
        };
    }

    private static IReadOnlyList<ExpenseCategory> GenerateFallbackCategoryData()
    {
        return new List<ExpenseCategory>
        {
            new() { CategoryId = 1, CategoryName = "Travel", IsActive = true },
            new() { CategoryId = 2, CategoryName = "Meals", IsActive = true },
            new() { CategoryId = 3, CategoryName = "Accommodation", IsActive = true },
            new() { CategoryId = 4, CategoryName = "Office Supplies", IsActive = true }
        };
    }

    private static IReadOnlyList<UserProfile> GenerateFallbackUserData()
    {
        return new List<UserProfile>
        {
            new() { UserId = 1, UserName = "Alice Johnson", Email = "alice@example.com", 
                    RoleId = 1, RoleName = "Employee", ManagerId = 3, ManagerName = "Carol Manager", 
                    IsActive = true, CreatedAt = DateTime.Now.AddMonths(-6) },
            new() { UserId = 2, UserName = "Bob Smith", Email = "bob@example.com", 
                    RoleId = 1, RoleName = "Employee", ManagerId = 3, ManagerName = "Carol Manager", 
                    IsActive = true, CreatedAt = DateTime.Now.AddMonths(-8) },
            new() { UserId = 3, UserName = "Carol Manager", Email = "carol@example.com", 
                    RoleId = 2, RoleName = "Manager", IsActive = true, CreatedAt = DateTime.Now.AddYears(-2) }
        };
    }

    private static IReadOnlyList<ExpenseSummaryMetrics> GenerateFallbackSummaryData()
    {
        return new List<ExpenseSummaryMetrics>
        {
            new() { StatusName = "Approved", ExpenseCount = 5, TotalAmount = 450.00m },
            new() { StatusName = "Draft", ExpenseCount = 2, TotalAmount = 200.00m },
            new() { StatusName = "Submitted", ExpenseCount = 3, TotalAmount = 275.50m }
        };
    }
}
