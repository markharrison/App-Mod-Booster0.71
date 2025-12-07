-- Stored Procedures for Expense Management System
-- All data access should go through these stored procedures
-- Uses CREATE OR ALTER for idempotent deployment
GO

-- =============================================
-- Get all expenses with user and category details
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetAllExpenses]
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        e.ExpenseId,
        e.UserId,
        u.UserName,
        u.Email,
        e.CategoryId,
        c.CategoryName,
        e.StatusId,
        s.StatusName,
        e.AmountMinor,
        CAST(e.AmountMinor / 100.0 AS DECIMAL(10,2)) AS AmountDecimal,
        e.Currency,
        e.ExpenseDate,
        e.Description,
        e.ReceiptFile,
        e.SubmittedAt,
        e.ReviewedBy,
        reviewer.UserName AS ReviewedByName,
        e.ReviewedAt,
        e.CreatedAt
    FROM dbo.Expenses e
    INNER JOIN dbo.Users u ON e.UserId = u.UserId
    INNER JOIN dbo.ExpenseCategories c ON e.CategoryId = c.CategoryId
    INNER JOIN dbo.ExpenseStatus s ON e.StatusId = s.StatusId
    LEFT JOIN dbo.Users reviewer ON e.ReviewedBy = reviewer.UserId
    ORDER BY e.CreatedAt DESC;
END
GO

-- =============================================
-- Get expenses by status
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetExpensesByStatus]
    @StatusName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        e.ExpenseId,
        e.UserId,
        u.UserName,
        u.Email,
        e.CategoryId,
        c.CategoryName,
        e.StatusId,
        s.StatusName,
        e.AmountMinor,
        CAST(e.AmountMinor / 100.0 AS DECIMAL(10,2)) AS AmountDecimal,
        e.Currency,
        e.ExpenseDate,
        e.Description,
        e.ReceiptFile,
        e.SubmittedAt,
        e.ReviewedBy,
        reviewer.UserName AS ReviewedByName,
        e.ReviewedAt,
        e.CreatedAt
    FROM dbo.Expenses e
    INNER JOIN dbo.Users u ON e.UserId = u.UserId
    INNER JOIN dbo.ExpenseCategories c ON e.CategoryId = c.CategoryId
    INNER JOIN dbo.ExpenseStatus s ON e.StatusId = s.StatusId
    LEFT JOIN dbo.Users reviewer ON e.ReviewedBy = reviewer.UserId
    WHERE s.StatusName = @StatusName
    ORDER BY e.CreatedAt DESC;
END
GO

-- =============================================
-- Get expenses by user
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetExpensesByUser]
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        e.ExpenseId,
        e.UserId,
        u.UserName,
        u.Email,
        e.CategoryId,
        c.CategoryName,
        e.StatusId,
        s.StatusName,
        e.AmountMinor,
        CAST(e.AmountMinor / 100.0 AS DECIMAL(10,2)) AS AmountDecimal,
        e.Currency,
        e.ExpenseDate,
        e.Description,
        e.ReceiptFile,
        e.SubmittedAt,
        e.ReviewedBy,
        reviewer.UserName AS ReviewedByName,
        e.ReviewedAt,
        e.CreatedAt
    FROM dbo.Expenses e
    INNER JOIN dbo.Users u ON e.UserId = u.UserId
    INNER JOIN dbo.ExpenseCategories c ON e.CategoryId = c.CategoryId
    INNER JOIN dbo.ExpenseStatus s ON e.StatusId = s.StatusId
    LEFT JOIN dbo.Users reviewer ON e.ReviewedBy = reviewer.UserId
    WHERE e.UserId = @UserId
    ORDER BY e.CreatedAt DESC;
END
GO

-- =============================================
-- Get a single expense by ID
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetExpenseById]
    @ExpenseId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        e.ExpenseId,
        e.UserId,
        u.UserName,
        u.Email,
        e.CategoryId,
        c.CategoryName,
        e.StatusId,
        s.StatusName,
        e.AmountMinor,
        CAST(e.AmountMinor / 100.0 AS DECIMAL(10,2)) AS AmountDecimal,
        e.Currency,
        e.ExpenseDate,
        e.Description,
        e.ReceiptFile,
        e.SubmittedAt,
        e.ReviewedBy,
        reviewer.UserName AS ReviewedByName,
        e.ReviewedAt,
        e.CreatedAt
    FROM dbo.Expenses e
    INNER JOIN dbo.Users u ON e.UserId = u.UserId
    INNER JOIN dbo.ExpenseCategories c ON e.CategoryId = c.CategoryId
    INNER JOIN dbo.ExpenseStatus s ON e.StatusId = s.StatusId
    LEFT JOIN dbo.Users reviewer ON e.ReviewedBy = reviewer.UserId
    WHERE e.ExpenseId = @ExpenseId;
END
GO

-- =============================================
-- Create a new expense
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[CreateExpense]
    @UserId INT,
    @CategoryId INT,
    @AmountMinor INT,
    @Currency NVARCHAR(3) = 'GBP',
    @ExpenseDate DATE,
    @Description NVARCHAR(1000) = NULL,
    @ReceiptFile NVARCHAR(500) = NULL,
    @StatusName NVARCHAR(50) = 'Draft'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StatusId INT;
    DECLARE @NewExpenseId INT;
    
    -- Get the status ID
    SELECT @StatusId = StatusId 
    FROM dbo.ExpenseStatus 
    WHERE StatusName = @StatusName;
    
    IF @StatusId IS NULL
    BEGIN
        RAISERROR('Invalid status name: %s', 16, 1, @StatusName);
        RETURN;
    END
    
    -- Insert the expense
    INSERT INTO dbo.Expenses (
        UserId, 
        CategoryId, 
        StatusId, 
        AmountMinor, 
        Currency, 
        ExpenseDate, 
        Description, 
        ReceiptFile,
        SubmittedAt,
        CreatedAt
    )
    VALUES (
        @UserId,
        @CategoryId,
        @StatusId,
        @AmountMinor,
        @Currency,
        @ExpenseDate,
        @Description,
        @ReceiptFile,
        CASE WHEN @StatusName = 'Submitted' THEN SYSUTCDATETIME() ELSE NULL END,
        SYSUTCDATETIME()
    );
    
    SET @NewExpenseId = SCOPE_IDENTITY();
    
    -- Return the newly created expense
    EXEC [dbo].[GetExpenseById] @ExpenseId = @NewExpenseId;
END
GO

-- =============================================
-- Update expense status (for approve/reject)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UpdateExpenseStatus]
    @ExpenseId INT,
    @StatusName NVARCHAR(50),
    @ReviewedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StatusId INT;
    
    -- Get the status ID
    SELECT @StatusId = StatusId 
    FROM dbo.ExpenseStatus 
    WHERE StatusName = @StatusName;
    
    IF @StatusId IS NULL
    BEGIN
        RAISERROR('Invalid status name: %s', 16, 1, @StatusName);
        RETURN;
    END
    
    -- Update the expense
    UPDATE dbo.Expenses
    SET 
        StatusId = @StatusId,
        SubmittedAt = CASE 
            WHEN @StatusName = 'Submitted' AND SubmittedAt IS NULL 
            THEN SYSUTCDATETIME() 
            ELSE SubmittedAt 
        END,
        ReviewedBy = CASE 
            WHEN @StatusName IN ('Approved', 'Rejected') 
            THEN COALESCE(@ReviewedBy, ReviewedBy) 
            ELSE ReviewedBy 
        END,
        ReviewedAt = CASE 
            WHEN @StatusName IN ('Approved', 'Rejected') 
            THEN SYSUTCDATETIME() 
            ELSE ReviewedAt 
        END
    WHERE ExpenseId = @ExpenseId;
    
    -- Return the updated expense
    EXEC [dbo].[GetExpenseById] @ExpenseId = @ExpenseId;
END
GO

-- =============================================
-- Delete an expense (only if in Draft status)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DeleteExpense]
    @ExpenseId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StatusName NVARCHAR(50);
    
    -- Check if expense is in Draft status
    SELECT @StatusName = s.StatusName
    FROM dbo.Expenses e
    INNER JOIN dbo.ExpenseStatus s ON e.StatusId = s.StatusId
    WHERE e.ExpenseId = @ExpenseId;
    
    IF @StatusName IS NULL
    BEGIN
        RAISERROR('Expense not found', 16, 1);
        RETURN;
    END
    
    IF @StatusName <> 'Draft'
    BEGIN
        RAISERROR('Only expenses in Draft status can be deleted', 16, 1);
        RETURN;
    END
    
    DELETE FROM dbo.Expenses
    WHERE ExpenseId = @ExpenseId;
    
    SELECT 1 AS Success;
END
GO

-- =============================================
-- Get all expense categories
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetExpenseCategories]
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CategoryId,
        CategoryName,
        IsActive
    FROM dbo.ExpenseCategories
    WHERE IsActive = 1
    ORDER BY CategoryName;
END
GO

-- =============================================
-- Get all expense statuses
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetExpenseStatuses]
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        StatusId,
        StatusName
    FROM dbo.ExpenseStatus
    ORDER BY StatusId;
END
GO

-- =============================================
-- Get all users
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetUsers]
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        u.UserId,
        u.UserName,
        u.Email,
        u.RoleId,
        r.RoleName,
        u.ManagerId,
        m.UserName AS ManagerName,
        u.IsActive,
        u.CreatedAt
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
    LEFT JOIN dbo.Users m ON u.ManagerId = m.UserId
    WHERE u.IsActive = 1
    ORDER BY u.UserName;
END
GO

-- =============================================
-- Search expenses by description
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SearchExpenses]
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        e.ExpenseId,
        e.UserId,
        u.UserName,
        u.Email,
        e.CategoryId,
        c.CategoryName,
        e.StatusId,
        s.StatusName,
        e.AmountMinor,
        CAST(e.AmountMinor / 100.0 AS DECIMAL(10,2)) AS AmountDecimal,
        e.Currency,
        e.ExpenseDate,
        e.Description,
        e.ReceiptFile,
        e.SubmittedAt,
        e.ReviewedBy,
        reviewer.UserName AS ReviewedByName,
        e.ReviewedAt,
        e.CreatedAt
    FROM dbo.Expenses e
    INNER JOIN dbo.Users u ON e.UserId = u.UserId
    INNER JOIN dbo.ExpenseCategories c ON e.CategoryId = c.CategoryId
    INNER JOIN dbo.ExpenseStatus s ON e.StatusId = s.StatusId
    LEFT JOIN dbo.Users reviewer ON e.ReviewedBy = reviewer.UserId
    WHERE 
        e.Description LIKE '%' + @SearchTerm + '%'
        OR c.CategoryName LIKE '%' + @SearchTerm + '%'
        OR u.UserName LIKE '%' + @SearchTerm + '%'
    ORDER BY e.CreatedAt DESC;
END
GO

-- =============================================
-- Get expense summary statistics
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetExpenseSummary]
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.StatusName,
        COUNT(*) AS ExpenseCount,
        CAST(SUM(e.AmountMinor) / 100.0 AS DECIMAL(10,2)) AS TotalAmount
    FROM dbo.Expenses e
    INNER JOIN dbo.ExpenseStatus s ON e.StatusId = s.StatusId
    GROUP BY s.StatusName
    ORDER BY s.StatusId;
END
GO

PRINT 'Stored procedures created successfully';
GO
