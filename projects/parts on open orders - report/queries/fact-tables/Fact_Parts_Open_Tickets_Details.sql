-- ================================================================================
-- VIEW: vw_Fact_Parts_Open_Tickets_Details
-- PURPOSE: Line-item detail for parts orders (complementary to summary)
-- MAPPED TO: Lakehouse tables with normalized column names
-- ================================================================================

CREATE VIEW vw_Fact_Parts_Open_Tickets_Details AS

SELECT 
  -- ===== BRANCH & LOCATION INFORMATION =====
  insalord.Branch AS Location,
  
  -- Location Name Lookup (with TOP 1 safety)
  (SELECT TOP 1 name FROM Branch_Name WHERE insalord.Branch = Branch_Name.branch) AS Location_Name,

  -- ===== ORDER IDENTIFICATION =====
  -- Business Rule: Use RO Number when available, otherwise File Number
  CASE 
    WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
    ELSE insalord.RONumber
  END AS Order_No,
  
  insalord.RONumber AS RO_Number,
  insalord.FileNumber AS File_No,

  -- ===== INVOICE TYPE CLASSIFICATION =====
  CASE insalord.OrderType
    WHEN 'O' THEN 'Pending Ticket'
    WHEN 'P' THEN 'Picking Slip'
    WHEN 'Q' THEN 'Quote'
    WHEN 'W' THEN 'Work Order'
    WHEN 'T' THEN 'Transfer'
    WHEN 'I' THEN 'Invoice'
    ELSE ISNULL(insalord.OrderType, 'Unknown')
  END AS Invoice_Type,

  -- ===== DATE FOUNDATION =====
  CAST(insalord.OrderDate AS DATE) AS Order_Date,
  CAST(insalord.CreatedDate AS DATE) AS Created_On,
  
  -- ===== WORK ORDER CREATION DATE LOOKUP =====
  (SELECT MIN(CAST(RepairOrderDetail.CreationDate AS DATE))
   FROM RepairOrderDetail 
   WHERE RepairOrderDetail.WorkOrder = CASE 
     WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
     ELSE insalord.RONumber
   END
   AND RepairOrderDetail.Branch = insalord.Branch) AS WO_Creation_Date,

  -- ===== ENHANCED AGING CALCULATION =====
  CASE 
    WHEN insalord.OrderType = 'W' THEN 
      DATEDIFF(day, 
        CAST(ISNULL(
          (SELECT MIN(RepairOrderDetail.CreationDate) 
           FROM RepairOrderDetail 
           WHERE RepairOrderDetail.WorkOrder = CASE 
             WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
             ELSE insalord.RONumber
           END
           AND RepairOrderDetail.Branch = insalord.Branch), 
          ISNULL(insalord.CreatedDate, insalord.OrderDate)
        ) AS DATE), 
        GETDATE()
      )
    ELSE 
      DATEDIFF(day, 
        CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), 
        GETDATE()
      )
  END AS Days_Open,

  -- ===== 6-BUCKET AGING CLASSIFICATION =====
  CASE 
    WHEN insalord.OrderType = 'W' THEN 
      CASE 
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 0 AND 7 THEN '0-7 days'
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 8 AND 14 THEN '8-14 days'
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 15 AND 30 THEN '15-30 days'
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 31 AND 60 THEN '31-60 days'
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 61 AND 90 THEN '61-90 days'
        ELSE '90+ days'
      END
    ELSE 
      CASE 
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 0 AND 7 THEN '0-7 days'
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 8 AND 14 THEN '8-14 days'
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 15 AND 30 THEN '15-30 days'
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 31 AND 60 THEN '31-60 days'
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 61 AND 90 THEN '61-90 days'
        ELSE '90+ days'
      END
  END AS Aging,

  -- ===== AGING SORT ORDER =====
  CASE 
    WHEN insalord.OrderType = 'W' THEN 
      CASE 
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 0 AND 7 THEN 1
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 8 AND 14 THEN 2
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 15 AND 30 THEN 3
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 31 AND 60 THEN 4
        WHEN DATEDIFF(day, 
          CAST(ISNULL(
            (SELECT MIN(RepairOrderDetail.CreationDate) 
             FROM RepairOrderDetail 
             WHERE RepairOrderDetail.WorkOrder = CASE 
               WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
               ELSE insalord.RONumber
             END
             AND RepairOrderDetail.Branch = insalord.Branch), 
            ISNULL(insalord.CreatedDate, insalord.OrderDate)
          ) AS DATE), 
          GETDATE()
        ) BETWEEN 61 AND 90 THEN 5
        ELSE 6
      END
    ELSE 
      CASE 
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 0 AND 7 THEN 1
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 8 AND 14 THEN 2
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 15 AND 30 THEN 3
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 31 AND 60 THEN 4
        WHEN DATEDIFF(day, CAST(ISNULL(insalord.CreatedDate, insalord.OrderDate) AS DATE), GETDATE()) BETWEEN 61 AND 90 THEN 5
        ELSE 6
      END
  END AS Aging_Sort_Order,

  -- ===== DATA QUALITY & AUDIT TRAIL =====
  CASE 
    WHEN insalord.OrderType = 'W' AND 
         (SELECT MIN(RepairOrderDetail.CreationDate) 
          FROM RepairOrderDetail 
          WHERE RepairOrderDetail.WorkOrder = CASE 
            WHEN ISNULL(insalord.RONumber, 0) = 0 THEN insalord.FileNumber
            ELSE insalord.RONumber
          END
          AND RepairOrderDetail.Branch = insalord.Branch) IS NOT NULL 
    THEN 'WO_Creation_Date'
    WHEN insalord.CreatedDate IS NOT NULL THEN 'Created_On'
    ELSE 'Order_Date'
  END AS Aging_Date_Source,

  -- ===== PART DETAIL INFORMATION =====
  insalpar.PartNumber AS Part_No,
  insalpar.OrderQty AS Quantity_Ordered,
  insalpar.UnitPrice AS Unit_Price,
  (insalpar.UnitPrice * insalpar.OrderQty) AS Line_Total,
  ISNULL(insalpar.BackorderQty, 0) AS BackOrdered_QTY,
  
  -- ===== CALCULATED PART METRICS =====
  (insalpar.OrderQty - ISNULL(insalpar.BackorderQty, 0)) AS Available_QTY,
  
  -- Line-level backorder percentage
  CASE 
    WHEN insalpar.OrderQty > 0 THEN 
      CAST(ISNULL(insalpar.BackorderQty, 0) * 100.0 / insalpar.OrderQty AS DECIMAL(5,1))
    ELSE 0 
  END AS Line_Backorder_Pct,

  -- ===== CUSTOMER INFORMATION =====
  insalord.CustomerNumber AS Contact_Code,
  
  -- Customer name logic (with TOP 1 safety)
  CASE 
    WHEN ISNULL(TRIM((SELECT TOP 1 c.CompanyName FROM contact c WHERE c.ContactID = insalord.CustomerNumber)), '') = '' 
    THEN ISNULL((SELECT TOP 1 c.FirstName FROM contact c WHERE c.ContactID = insalord.CustomerNumber), '') 
         + ' ' + 
         ISNULL((SELECT TOP 1 c.LastName FROM contact c WHERE c.ContactID = insalord.CustomerNumber), '')
    ELSE ISNULL((SELECT TOP 1 TRIM(c.CompanyName) FROM contact c WHERE c.ContactID = insalord.CustomerNumber), 'Internal Order')
  END AS Customer,

  -- ===== SALES TEAM INFORMATION =====
  (SELECT TOP 1 ISNULL(FirstName, '') + ' ' + ISNULL(LastName, '') 
   FROM contact 
   WHERE insalord.Salesperson = contact.ContactID) AS Salesman

FROM 
  Insalord AS insalord
  INNER JOIN insalpar ON insalord.FileNumber = insalpar.FileNumber

WHERE 
  (insalord.OrderType IS NULL OR insalord.OrderType <> 'T')

GO