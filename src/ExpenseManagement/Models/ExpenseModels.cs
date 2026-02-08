namespace ExpenseManagement.Models;

public sealed class ExpenseRecord
{
    public int ExpenseId { get; init; }
    public int UserId { get; init; }
    public string UserName { get; init; } = string.Empty;
    public int CategoryId { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public int StatusId { get; init; }
    public string StatusName { get; init; } = string.Empty;
    public int AmountMinor { get; init; }
    public decimal Amount { get; init; }
    public string Currency { get; init; } = "GBP";
    public DateTime ExpenseDate { get; init; }
    public string? Description { get; init; }
    public string? ReceiptFile { get; init; }
    public DateTime? SubmittedAt { get; init; }
    public int? ReviewedBy { get; init; }
    public string? ReviewerName { get; init; }
    public DateTime? ReviewedAt { get; init; }
    public DateTime CreatedAt { get; init; }
}

public sealed class ExpenseCategory
{
    public int CategoryId { get; init; }
    public string CategoryName { get; init; } = string.Empty;
    public bool IsActive { get; init; }
}

public sealed class ExpenseStatusInfo
{
    public int StatusId { get; init; }
    public string StatusName { get; init; } = string.Empty;
}

public sealed class UserProfile
{
    public int UserId { get; init; }
    public string UserName { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public int RoleId { get; init; }
    public string RoleName { get; init; } = string.Empty;
    public int? ManagerId { get; init; }
    public string? ManagerName { get; init; }
    public bool IsActive { get; init; }
    public DateTime CreatedAt { get; init; }
}

public sealed class ExpenseSummaryMetrics
{
    public string StatusName { get; init; } = string.Empty;
    public int ExpenseCount { get; init; }
    public decimal TotalAmount { get; init; }
}

public sealed class CreateExpenseRequest
{
    public int UserId { get; set; }
    public int CategoryId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "GBP";
    public DateTime ExpenseDate { get; set; }
    public string? Description { get; set; }
    public string? ReceiptFile { get; set; }
}

public sealed class ReviewExpenseRequest
{
    public int ExpenseId { get; set; }
    public int ReviewerId { get; set; }
    public bool Approved { get; set; }
}
