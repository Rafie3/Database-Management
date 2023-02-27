-- 1. Create a database named db_{yourfirstname}

SET NOCOUNT ON;
-- Check if the database already exists
IF EXISTS
(
    SELECT name
    FROM master.dbo.sysdatabases
    WHERE name = N'db_Nargis'
)
    BEGIN
        SELECT 'Database already exists in the system!' AS MESSAGE
    END;
--  If the database does not exist in the system, then create it
ELSE
    BEGIN
        /* Create database */
        CREATE DATABASE db_Nargis
        SELECT 'db_Nargis is created!' AS MESSAGE
    END;

/* Change to the db_Nargis database */
USE db_Nargis;
GO


SET NOCOUNT ON;
-- 2. Create Customer table with at least the following columns: 
/* Create tables */
CREATE TABLE Customer (
    ID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL
);
GO
 -- 3. Create Orders table as follows: 
CREATE TABLE Orders (
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL
);
GO

-- DROP TABLE Customer;
-- GO

-- 4. Use triggers to impose the following constraints
    -- a)A Customer with Orders cannot be deleted from Customer table. 
    -- b)Create a custom error and use Raiserror to notify when delete Customer with Orders fails.

CREATE OR ALTER TRIGGER Customer_Deletion_Trigger
ON Customer
FOR DELETE
AS
BEGIN
    -- Check if any deleted customer has orders in the Orders table
    IF EXISTS(SELECT * 
                FROM deleted D JOIN Orders O ON D.CustomerID = o.CustomerID
                    where D.CustomerID = O.CustomerID)
    BEGIN
        -- If there are orders for the deleted customer, roll back the delete operation and raise the error
        ROLLBACK TRANSACTION;
        RAISERROR('Error: Cannot delete customer with orders.', 16, 1);
    END
END
GO

-- Add Data 
INSERT INTO Customer(ID, CustomerID, FirstName, LastName )
VALUES( 1, 1, 'Nargis', 'Nargis' );

INSERT INTO Customer(ID, CustomerId, FirstName, LastName )
VALUES( 2, 2, 'Ahmad', 'Ali' );

INSERT INTO Customer(ID, CustomerId, FirstName, LastName )
VALUES( 7, 7, 'Jessica', 'John' );

INSERT INTO Orders( OrderID, CustomerID, OrderDate )
VALUES( 1, 1, CONVERT(datetime, GETDATE()) );

INSERT INTO Orders( OrderID, CustomerID, OrderDate )
VALUES( 3, 2, CONVERT(datetime, GETDATE()) );
  GO

-- Deletion Trigger
DELETE Customer
WHERE CustomerID = 2;
	GO

-- 4. c)If CustomerID is updated in Customers, referencing rows in Orders must be updated accordingly.
CREATE TRIGGER UpdateCustomerID_Trigger
ON Customer
AFTER UPDATE AS
IF UPDATE(CustomerID)
BEGIN
     UPDATE Orders
            -- Update the customerID in Orders table if CustomerID is updated in Customers table 
           SET CustomerID = inserted.CustomerID
           FROM Orders, deleted, inserted
           WHERE deleted.CustomerID = Orders.CustomerID
END
GO

-- Testing the trigger
UPDATE Customer
  SET 
      CustomerID = 13
WHERE CustomerID = 1;
SELECT *
FROM Orders;
GO

-- 4. d)Updating and Insertion of rows in Orders table must verify that CustomerID exists in Customer table, otherwise Raiserror to notify.
CREATE TRIGGER VerifyCustomerID
ON Orders
AFTER INSERT, UPDATE
AS
BEGIN
    -- Raise error if CustomerID does not exist in Customer table
    IF NOT EXISTS(SELECT CustomerID FROM Customer WHERE CustomerID IN (SELECT CustomerID FROM inserted))
    BEGIN
        RAISERROR ('CustomerID does not exist in Customer table.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- testing update triggers on CustomerID on Orders --
UPDATE Orders
  SET CustomerID = 15
WHERE OrderID = 3;
GO
-- testing insert triggers on CustomerID on Orders --
INSERT INTO Orders( OrderID, CustomerID, OrderDate )
VALUES( 5, 15, CONVERT(datetime, GETDATE()) );
GO

-- 5. Create a scalar function named fn_CheckName(@FirstName, @LastName) to check that the FirstName and LastName are not the same. 
CREATE FUNCTION fn_CheckName
(
    @FirstName VARCHAR(50),
    @LastName VARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT

    IF @FirstName = @LastName
        SET @Result = 0
    ELSE
        SET @Result = 1

    RETURN @Result
END
GO

-- Test the scalar function: fn_CheckName
SELECT *, dbo.fn_CheckName(FirstName, LastName)
FROM Customer
WHERE CustomerID = 2;
GO

SELECT * FROM Customer; 
GO

-- 6. Create a stored procedure called sp_InsertCustomer that would take Firstname and Lastname and optional CustomerID as parameters and Insert into Customer table.
    -- a) If CustomerID is not provided, increment the last CustomerID and use that.
    -- b) Use the fn_CheckName function to verify that the customer name is correct. Do not insert record if verification fails. 
CREATE PROCEDURE sp_InsertCustomer
    @FirstName VARCHAR(50),
    @LastName VARCHAR(50),
    @CustomerID INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Check if the customer first name and last name not equal
    IF dbo.fn_CheckName(@FirstName, @LastName) = 0
        BEGIN
            RAISERROR('Error: Invalid customer name.', 16, 1);
            RETURN;
        END

    -- If no CustomerID was provided, generate a new one by incrementing the last CustomerID and use that
    IF @CustomerID IS NULL
        BEGIN
            SELECT @CustomerID = MAX(CustomerID) + 1 FROM Customer;
        END

    -- Insert the new customer record
    INSERT INTO Customer (ID, CustomerID, FirstName, LastName)
    VALUES (@CustomerID, @CustomerID, @FirstName, @LastName);

    SELECT @CustomerID;
END
GO

-- Verify if same name doesn't insert
exec dbo.sp_InsertCustomer @FirstName = N'Nargis', @LastName = N'Nargis';
exec dbo.sp_InsertCustomer @FirstName = N'Murad', @LastName = N'Ali', @CustomerID = 10;

-- Drop procedure
DROP PROCEDURE dbo.sp_InsertCustomer;

-- Check Customers Table
SELECT * FROM Customer;
GO

-- Create table CusAudit
CREATE TABLE CusAudit
        (
         CustomerID INT NOT NULL,  
         OldFirstName  NVARCHAR(50) NOT NULL, 
         OldLastName   NVARCHAR(50) NOT NULL,           
         NewFirstName  NVARCHAR(50) NOT NULL, 
         NewLastName   NVARCHAR(50) NOT NULL,          
         UpdatedOn  DATETIME NOT NULL,
         UpdatedBy  NVARCHAR(50) NOT NULL, 
        );
GO

-- DROP TABLE CusAudit; 
-- GO

-- 7. Log all updates to Customer table to CusAudit table. Indicate the previous and new values of data, the date and time and the login name of the person who made the changes.
CREATE TRIGGER CustomerUpdateTrigger
ON Customer
FOR UPDATE
AS
BEGIN
	-- Declartion of variables 
    DECLARE @NewFirstName VARCHAR(50), @NewLastName VARCHAR(50);
    DECLARE @OldFirstName VARCHAR(50), @OldLastName VARCHAR(50);
    DECLARE @LoginName VARCHAR(50);
	-- Initiation 
    SELECT @OldFirstName = d.FirstName, @OldLastName = d.LastName
    FROM deleted d;
    SELECT @NewFirstName = i.FirstName, @NewLastName = i.LastName
    FROM inserted i;
    SET @LoginName = SUSER_SNAME();
	-- Insert into the CusAudit table
    INSERT INTO CusAudit (CustomerID, OldFirstName, OldLastName, NewFirstName, NewLastName, UpdatedOn, UpdatedBy)
    SELECT d.CustomerID, @OldFirstName, @OldLastName, @NewFirstName, @NewLastName, GETDATE(), @LoginName
    FROM deleted d;
END
GO

-- Test the trigger for insert 
INSERT INTO Customer
VALUES(4, 4, 'Maddie', 'Bruce' );

INSERT INTO Customer
VALUES(5, 5, 'Will', 'Yong' );
GO

SELECT *
FROM Customer;

SELECT *
FROM CusAudit;
GO

-- Test the trigger for update 
UPDATE Customer
  SET LastName = 'John'
WHERE CustomerID = 5;
GO

SELECT *
FROM CusAudit
ORDER BY CustomerID;
GO