-- ================================================================================
-- DROP AND RECREATE VIEW: vw_Fact_Parts_Open_Tickets (CORRECTED VERSION 2)
-- FIXES:
--   1. Added Deposit to GROUP BY (was causing aggregation errors)
--   2. Fixed RepairOrderDetail WorkOrder lookup to use Order_No logic
--   3. CRITICAL: Fixed aging calculation to match old report fallback logic
-- ================================================================================

-- Drop the view if it exists
IF OBJECT_ID('vw_Fact_Parts_Open_Tickets', 'V') IS NOT NULL
    DROP VIEW vw_Fact_Parts_Open_Tickets;
GO

-- Create the corrected view
CREATE VIEW vw_Fact_Parts_Open_Tickets AS

SELECT
  insalord.Branch AS Location,

  -- Location Name Lookup (with TOP 1 safety)
  (SELECT TOP 1 name FROM Branch_Name WHERE insalord.Branch = Branch_Name.branch) AS Location_Name,

  -- Order Number logic (RO Number takes precedence over File Number)
  CASE
    WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
    ELSE insalord.RONumber
  END AS Order_No,

  -- Invoice Type decoding
  CASE insalord.OrderType
    WHEN 'O' THEN 'Pending Ticket'
    WHEN 'P' THEN 'Picking Slip'
    WHEN 'Q' THEN 'Quote'
    WHEN 'W' THEN 'Work Order'
    WHEN 'T' THEN 'Transfer'
    ELSE insalord.OrderType
  END AS Invoice_Type,

  -- Dates
  CAST(insalord.OrderDate AS DATE) AS Order_Date,
  CAST(insalord.CreatedDate AS DATE) AS Created_On,

  -- Work Order Creation Date Lookup (FIXED: Uses proper Order_No logic)
  (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
   FROM RepairOrderDetail
   WHERE RepairOrderDetail.WorkOrder = CASE
       WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
       ELSE insalord.RONumber
     END
     AND RepairOrderDetail.Branch = insalord.Branch) AS WO_Creation_Date,

  -- CRITICAL: Calculate the SINGLE aging date that will be used (matches old logic exactly)
  CAST(
    CASE
      WHEN insalord.OrderType = 'W' THEN
        -- For Work Orders: Use RepairOrderDetail.CreationDate, with fallback to Created_On, then Order_Date
        ISNULL(
          (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
           FROM RepairOrderDetail
           WHERE RepairOrderDetail.WorkOrder = CASE
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch),
          ISNULL(insalord.CreatedDate, insalord.OrderDate)
        )
      ELSE
        -- For non-Work Orders: Use Created_On with Order_Date fallback
        ISNULL(insalord.CreatedDate, insalord.OrderDate)
    END
  AS DATE) AS Aging_Base_Date,

  -- Days Open Calculation (using the single aging base date)
  DATEDIFF(day,
    CAST(
      CASE
        WHEN insalord.OrderType = 'W' THEN
          ISNULL(
            (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
             FROM RepairOrderDetail
             WHERE RepairOrderDetail.WorkOrder = CASE
                 WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                 ELSE insalord.RONumber
               END
               AND RepairOrderDetail.Branch = insalord.Branch),
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          )
        ELSE
          ISNULL(insalord.CreatedDate, insalord.OrderDate)
      END
    AS DATE),
    GETDATE()
  ) AS Days_Open,

  -- 6-Bucket Aging Classification (using the single aging base date)
  CASE
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 0 AND 7 THEN '0-7 days'
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 8 AND 14 THEN '8-14 days'
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 15 AND 30 THEN '15-30 days'
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 31 AND 60 THEN '31-60 days'
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 61 AND 90 THEN '61-90 days'
    ELSE '90+ days'
  END AS Aging,

  -- Aging Sort Order (using the single aging base date)
  CASE
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 0 AND 7 THEN 1
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 8 AND 14 THEN 2
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 15 AND 30 THEN 3
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 31 AND 60 THEN 4
    WHEN DATEDIFF(day,
      CAST(
        CASE
          WHEN insalord.OrderType = 'W' THEN
            ISNULL(
              (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
               FROM RepairOrderDetail
               WHERE RepairOrderDetail.WorkOrder = CASE
                   WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
                   ELSE insalord.RONumber
                 END
                 AND RepairOrderDetail.Branch = insalord.Branch),
              ISNULL(insalord.CreatedDate, insalord.OrderDate)
            )
          ELSE
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
        END
      AS DATE),
      GETDATE()
    ) BETWEEN 61 AND 90 THEN 5
    ELSE 6
  END AS Aging_Sort_Order,

  -- Data Quality: Track which date was used for aging
  CASE
    WHEN insalord.OrderType = 'W' AND
         (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
          FROM RepairOrderDetail
          WHERE RepairOrderDetail.WorkOrder = CASE
              WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
              ELSE insalord.RONumber
            END
            AND RepairOrderDetail.Branch = insalord.Branch) IS NOT NULL
    THEN 'WO_Creation_Date'
    WHEN insalord.CreatedDate IS NOT NULL
    THEN 'Created_On'
    ELSE 'Order_Date'
  END AS Aging_Date_Source,

  -- Order Totals and Backorders
  SUM(insalpar.OrderQty) AS [#_Parts_On_Order],
  SUM(ISNULL(insalpar.BackorderQty, 0)) AS [#_On_Back_Order],
  SUM(insalpar.UnitPrice * insalpar.OrderQty) AS [Order_Total_$$],
  SUM(insalpar.UnitPrice * (insalpar.OrderQty - ISNULL(insalpar.BackorderQty, 0))) AS [$$_Available],
  SUM(insalpar.UnitPrice * ISNULL(insalpar.BackorderQty, 0)) AS [$$_BackOrdered],

  -- Backorder Percentage
  CASE
    WHEN SUM(insalpar.OrderQty) > 0
    THEN (SUM(ISNULL(insalpar.BackorderQty, 0)) * 100.0) / SUM(insalpar.OrderQty)
    ELSE 0
  END AS Backorder_Pct,

  -- Deposit
  MAX(ISNULL(insalord.Deposit, 0)) AS Deposit,

  -- Salesman Name (with TOP 1 safety)
  (SELECT TOP 1 FirstName + ' ' + LastName
   FROM contact
   WHERE insalord.Salesperson = contact.ContactID) AS Salesman,

  -- Customer Details
  insalord.CustomerNumber AS Contact_Code,

  -- AR Account (with TOP 1 safety)
  ISNULL((
    SELECT TOP 1 ArMaster_Customer.CustomerNumber
    FROM ArMaster_Customer
    WHERE ArMaster_Customer.ContactID = insalord.CustomerNumber
  ), 0) AS AR_Acct,

  -- Customer Name (Company vs Individual logic, with TOP 1 safety)
  CASE
    WHEN ISNULL(TRIM((
        SELECT TOP 1 c.CompanyName
        FROM contact c
        WHERE c.ContactID = insalord.CustomerNumber
      )), '') = ''
    THEN
      ISNULL((SELECT TOP 1 c.FirstName FROM contact c WHERE c.ContactID = insalord.CustomerNumber), '')
      + ' ' +
      ISNULL((SELECT TOP 1 c.LastName FROM contact c WHERE c.ContactID = insalord.CustomerNumber), '')
    ELSE
      ISNULL((
        SELECT TOP 1 TRIM(c.CompanyName)
        FROM contact c
        WHERE c.ContactID = insalord.CustomerNumber
      ), 'Internal Order')
  END AS Customer

FROM
  Insalord AS insalord
  INNER JOIN insalpar ON insalpar.FileNumber = insalord.FileNumber

WHERE
  (insalord.OrderType IS NULL OR insalord.OrderType <> 'T')

GROUP BY
  insalord.Branch,
  insalord.FileNumber,
  insalord.RONumber,
  insalord.OrderType,
  insalord.OrderDate,
  insalord.CreatedDate,
  insalord.CustomerNumber,
  insalord.Salesperson,
  insalord.Deposit  -- ✅ CRITICAL FIX: Added to GROUP BY

GO
