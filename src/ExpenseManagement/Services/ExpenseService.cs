using Microsoft.Data.SqlClient;
using ExpenseManagement.Models;
using System.Data;

namespace ExpenseManagement.Services;

public class ExpenseService
{
    private readonly string _connectionString;
    private readonly ILogger<ExpenseService> _logger;

    public ExpenseService(IConfiguration configuration, ILogger<ExpenseService> logger)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection") 
            ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");
        _logger = logger;
    }

    public async Task<List<Expense>> GetAllExpensesAsync()
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.GetExpenses", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            var expenses = new List<Expense>();
            while (await reader.ReadAsync())
            {
                expenses.Add(MapExpenseFromReader(reader));
            }
            
            return expenses;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving all expenses");
            throw;
        }
    }

    public async Task<List<Expense>> GetExpensesByStatusAsync(string statusName)
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.GetExpensesByStatus", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.AddWithValue("@StatusName", statusName);

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            var expenses = new List<Expense>();
            while (await reader.ReadAsync())
            {
                expenses.Add(MapExpenseFromReader(reader));
            }
            
            return expenses;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving expenses by status: {StatusName}", statusName);
            throw;
        }
    }

    public async Task<Expense?> GetExpenseByIdAsync(int expenseId)
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.GetExpenseById", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.AddWithValue("@ExpenseId", expenseId);

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            if (await reader.ReadAsync())
            {
                return MapExpenseFromReader(reader);
            }
            
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving expense {ExpenseId}", expenseId);
            throw;
        }
    }

    public async Task<Expense> CreateExpenseAsync(Expense expense)
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.CreateExpense", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            
            command.Parameters.AddWithValue("@UserId", expense.UserId);
            command.Parameters.AddWithValue("@CategoryId", expense.CategoryId);
            command.Parameters.AddWithValue("@StatusId", expense.StatusId);
            command.Parameters.AddWithValue("@AmountMinor", expense.AmountMinor);
            command.Parameters.AddWithValue("@Currency", expense.Currency);
            command.Parameters.AddWithValue("@ExpenseDate", expense.ExpenseDate);
            command.Parameters.AddWithValue("@Description", (object?)expense.Description ?? DBNull.Value);
            command.Parameters.AddWithValue("@ReceiptFile", (object?)expense.ReceiptFile ?? DBNull.Value);

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            if (await reader.ReadAsync())
            {
                return MapExpenseFromReader(reader);
            }
            
            throw new InvalidOperationException("Failed to create expense");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating expense");
            throw;
        }
    }

    public async Task<Expense> UpdateExpenseStatusAsync(int expenseId, string statusName, int? reviewedBy = null)
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.UpdateExpenseStatus", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            
            command.Parameters.AddWithValue("@ExpenseId", expenseId);
            command.Parameters.AddWithValue("@StatusName", statusName);
            command.Parameters.AddWithValue("@ReviewedBy", (object?)reviewedBy ?? DBNull.Value);

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            if (await reader.ReadAsync())
            {
                return MapExpenseFromReader(reader);
            }
            
            throw new InvalidOperationException("Failed to update expense status");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating expense status");
            throw;
        }
    }

    public async Task<List<Expense>> SearchExpensesAsync(string searchTerm)
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.SearchExpenses", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.AddWithValue("@SearchTerm", searchTerm);

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            var expenses = new List<Expense>();
            while (await reader.ReadAsync())
            {
                expenses.Add(MapExpenseFromReader(reader));
            }
            
            return expenses;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching expenses: {SearchTerm}", searchTerm);
            throw;
        }
    }

    public async Task<bool> DeleteExpenseAsync(int expenseId)
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.DeleteExpense", connection)
            {
                CommandType = CommandType.StoredProcedure
            };
            command.Parameters.AddWithValue("@ExpenseId", expenseId);

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            if (await reader.ReadAsync())
            {
                return reader.GetInt32(reader.GetOrdinal("Success")) == 1;
            }
            
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting expense {ExpenseId}", expenseId);
            throw;
        }
    }

    public async Task<List<ExpenseCategory>> GetCategoriesAsync()
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.GetCategories", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            var categories = new List<ExpenseCategory>();
            while (await reader.ReadAsync())
            {
                categories.Add(new ExpenseCategory
                {
                    CategoryId = reader.GetInt32(reader.GetOrdinal("CategoryId")),
                    CategoryName = reader.GetString(reader.GetOrdinal("CategoryName")),
                    IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive"))
                });
            }
            
            return categories;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving categories");
            throw;
        }
    }

    public async Task<List<ExpenseStatus>> GetStatusesAsync()
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.GetStatuses", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            var statuses = new List<ExpenseStatus>();
            while (await reader.ReadAsync())
            {
                statuses.Add(new ExpenseStatus
                {
                    StatusId = reader.GetInt32(reader.GetOrdinal("StatusId")),
                    StatusName = reader.GetString(reader.GetOrdinal("StatusName"))
                });
            }
            
            return statuses;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving statuses");
            throw;
        }
    }

    public async Task<List<User>> GetUsersAsync()
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            using var command = new SqlCommand("dbo.GetUsers", connection)
            {
                CommandType = CommandType.StoredProcedure
            };

            await connection.OpenAsync();
            using var reader = await command.ExecuteReaderAsync();
            
            var users = new List<User>();
            while (await reader.ReadAsync())
            {
                users.Add(new User
                {
                    UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
                    UserName = reader.GetString(reader.GetOrdinal("UserName")),
                    Email = reader.GetString(reader.GetOrdinal("Email")),
                    RoleId = reader.GetInt32(reader.GetOrdinal("RoleId")),
                    ManagerId = reader.IsDBNull(reader.GetOrdinal("ManagerId")) 
                        ? null 
                        : reader.GetInt32(reader.GetOrdinal("ManagerId")),
                    IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive")),
                    CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
                    RoleName = reader.GetString(reader.GetOrdinal("RoleName")),
                    ManagerName = reader.IsDBNull(reader.GetOrdinal("ManagerName")) 
                        ? null 
                        : reader.GetString(reader.GetOrdinal("ManagerName"))
                });
            }
            
            return users;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving users");
            throw;
        }
    }

    private static Expense MapExpenseFromReader(SqlDataReader reader)
    {
        return new Expense
        {
            ExpenseId = reader.GetInt32(reader.GetOrdinal("ExpenseId")),
            UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
            CategoryId = reader.GetInt32(reader.GetOrdinal("CategoryId")),
            StatusId = reader.GetInt32(reader.GetOrdinal("StatusId")),
            AmountMinor = reader.GetInt32(reader.GetOrdinal("AmountMinor")),
            Currency = reader.GetString(reader.GetOrdinal("Currency")),
            ExpenseDate = reader.GetDateTime(reader.GetOrdinal("ExpenseDate")),
            Description = reader.IsDBNull(reader.GetOrdinal("Description")) 
                ? null 
                : reader.GetString(reader.GetOrdinal("Description")),
            ReceiptFile = reader.IsDBNull(reader.GetOrdinal("ReceiptFile")) 
                ? null 
                : reader.GetString(reader.GetOrdinal("ReceiptFile")),
            SubmittedAt = reader.IsDBNull(reader.GetOrdinal("SubmittedAt")) 
                ? null 
                : reader.GetDateTime(reader.GetOrdinal("SubmittedAt")),
            ReviewedBy = reader.IsDBNull(reader.GetOrdinal("ReviewedBy")) 
                ? null 
                : reader.GetInt32(reader.GetOrdinal("ReviewedBy")),
            ReviewedAt = reader.IsDBNull(reader.GetOrdinal("ReviewedAt")) 
                ? null 
                : reader.GetDateTime(reader.GetOrdinal("ReviewedAt")),
            CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
            UserName = reader.GetString(reader.GetOrdinal("UserName")),
            CategoryName = reader.GetString(reader.GetOrdinal("CategoryName")),
            StatusName = reader.GetString(reader.GetOrdinal("StatusName")),
            ReviewerName = reader.IsDBNull(reader.GetOrdinal("ReviewerName")) 
                ? null 
                : reader.GetString(reader.GetOrdinal("ReviewerName"))
        };
    }
}
