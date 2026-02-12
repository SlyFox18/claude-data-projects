/*
================================================================================
PARTS OPEN TICKETS REPORT - PRODUCTION VERSION WITH ACCURATE WORK ORDER AGING
================================================================================

📋 BUSINESS PURPOSE:
This query provides comprehensive analysis of outstanding parts orders across all 
branches, with accurate aging calculations that properly handle Work Order creation 
dates from the RepairOrderDetail system.

🎯 KEY BUSINESS USE CASES:
• Parts Inventory Management: Track backorders and expedite aging orders
• Customer Service: Proactive follow-up on delayed orders by aging buckets  
• Financial Analysis: Monitor outstanding receivables and backorder impacts
• Branch Performance: Compare aging performance across locations
• Management Reporting: Executive dashboards showing parts operation health

📊 DATA ARCHITECTURE:
• Grain: One row per order (summary level with aggregated part metrics)
• Source Tables: insalord (orders), insalpar (parts), RepairOrderDetail (WO dates)
• Record Count: ~21,200 records covering ~2,550 unique orders
• Refresh Strategy: Real-time via ODBC for current aging calculations

🔧 WORK ORDER AGING SOLUTION:
Previous Issue: Work Orders were aging from ord_date instead of actual creation date
Current Solution: Uses RepairOrderDetail.CreationDate via optimized subqueries
Technical Approach: MIN() subqueries prevent record duplication (avoided 3x inflation)
Data Quality: Tracks which date source was used for each aging calculation

⚡ PERFORMANCE OPTIMIZATIONS:
• Subquery Strategy: Avoids JOINs that caused 21K→60K record explosion
• Indexed Lookups: Uses primary keys (RONumber, Branch) for RepairOrderDetail
• Selective Execution: Work Order date lookup only runs for type='W' records
• Query Folding: Maintains ODBC query folding for optimal database performance

📈 AGING LOGIC HIERARCHY (Most Accurate → Fallback):
1. Work Orders (type='W'): RepairOrderDetail.CreationDate (earliest if multiple)
2. Other Invoice Types: insalord.Created_On when available
3. Final Fallback: insalord.ord_date (ensures no NULL aging)

🎨 AGING BUCKETS & SORTING:
• 0-7 days (Sort: 1) - New orders requiring immediate attention
• 8-14 days (Sort: 2) - Early standard processing window
• 15-30 days (Sort: 3) - Extended standard processing window  
• 31-60 days (Sort: 4) - Aging orders needing review
• 61-90 days (Sort: 5) - Priority expediting required
• 90+ days (Sort: 6) - Critical aging requiring executive attention

💰 FINANCIAL METRICS:
• Order_Total_$$: Complete order value (all parts)
• $$_Available: Value of parts ready to ship
• $$_BackOrdered: Value stuck in backorder status
• Backorder_Pct: Percentage analysis for prioritization

🔍 DATA QUALITY TRACKING:
• Aging_Date_Source: Shows 'WO_Creation_Date', 'Created_On', or 'Order_Date'
• WO_Creation_Date: Exposes actual Work Order creation date for validation
• Branch validation through location name lookup

LAST UPDATED: [9/24/25] - Added 6-bucket aging per executive request (split 8-30 into 8-14 and 15-30)
DEVELOPER: [Brian Fox]
STAKEHOLDER APPROVED: [9/24/25 - includes Work Order aging requirement + 6-bucket aging refinement]
================================================================================
*/

let
  Source = Odbc.Query("dsn=EquipRDB64", "
SELECT 
  -- ===== BRANCH & LOCATION INFORMATION =====
  insalord.branch as Location,
  'Location_Name' = (SELECT name FROM branch_name WHERE insalord.branch = branch_name.branch),

  -- ===== ORDER IDENTIFICATION =====
  -- Business Rule: Use RO Number when available, otherwise File Number
  CASE 
    WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
    ELSE insalord.ro_number
  END AS 'Order_No',

  -- ===== INVOICE TYPE CLASSIFICATION =====
  -- Provides business-friendly descriptions for system codes
  CASE insalord.type
    WHEN 'O' THEN 'Pending Ticket'    -- Open orders awaiting processing
    WHEN 'P' THEN 'Picking Slip'      -- Ready for warehouse picking
    WHEN 'Q' THEN 'Quote'             -- Customer quotation
    WHEN 'W' THEN 'Work Order'        -- Service work orders (special aging)
    WHEN 'T' THEN 'Transfer'          -- Internal transfers (excluded)
    WHEN 'I' THEN 'Invoice'           -- Invoiced orders
    ELSE ISNULL(insalord.type, 'Unknown')  -- Handle NULL/unexpected types
  END AS 'Invoice_Type',

  -- ===== DATE FOUNDATION =====
  DATE(insalord.ord_date) AS 'Order_Date',          -- Original order placement date
  DATE(insalord.Created_On) AS 'Created_On',        -- System entry date (most types)
  
  -- ===== WORK ORDER CREATION DATE LOOKUP =====
  -- CRITICAL: Gets actual Work Order creation date from RepairOrderDetail
  -- Uses MIN() to handle multiple RepairOrderDetail records per Work Order
  -- Prevents record duplication that inflated counts from 21K to 60K records
  (SELECT MIN(DATE(CreationDate)) 
   FROM RepairOrderDetail 
   WHERE RONumber = CASE 
     WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
     ELSE insalord.ro_number
   END
   AND Branch = insalord.branch) AS 'WO_Creation_Date',
  
  -- ===== ENHANCED AGING CALCULATION =====
  -- BUSINESS LOGIC: Uses most accurate date available per invoice type
  -- Work Orders: RepairOrderDetail.CreationDate (actual WO creation)
  -- Other Types: Created_On when available, ord_date as fallback
  DATEDIFF(day, 
    DATE(
      CASE 
        WHEN insalord.type = 'W' THEN 
          -- For Work Orders: Use RepairOrderDetail date, fallback to standard logic
          ISNULL((SELECT MIN(CreationDate) 
                  FROM RepairOrderDetail 
                  WHERE RONumber = CASE 
                    WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                    ELSE insalord.ro_number
                  END
                  AND Branch = insalord.branch), 
                 ISNULL(insalord.Created_On, insalord.ord_date))
        ELSE 
          -- For non-Work Orders: Standard Created_On with ord_date fallback
          ISNULL(insalord.Created_On, insalord.ord_date)
      END
    ), 
    GETDATE()
  ) AS 'Days_Open',
  
  -- ===== AGING BUCKET CLASSIFICATION =====
  -- Business-defined aging categories for operational management
  CASE
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 0 AND 7 THEN '0-7 days'       -- Fresh orders, normal processing
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 8 AND 14 THEN '8-14 days'     -- Early standard processing window
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 15 AND 30 THEN '15-30 days'   -- Extended standard processing window
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 31 AND 60 THEN '31-60 days'   -- Aging, needs attention
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 61 AND 90 THEN '61-90 days'   -- Priority expediting required
    ELSE '90+ days'                          -- Critical aging, executive attention
  END AS 'Aging',
  
  -- ===== AGING SORT ORDER =====
  -- Numeric sorting for Power BI to display aging buckets in logical order
  -- Set via Column Tools > Sort by Column in Power BI Data view
  CASE
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 0 AND 7 THEN 1
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 8 AND 14 THEN 2
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 15 AND 30 THEN 3
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 31 AND 60 THEN 4
    WHEN DATEDIFF(day, 
      DATE(
        CASE 
          WHEN insalord.type = 'W' THEN 
            ISNULL((SELECT MIN(CreationDate) 
                    FROM RepairOrderDetail 
                    WHERE RONumber = CASE 
                      WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
                      ELSE insalord.ro_number
                    END
                    AND Branch = insalord.branch), 
                   ISNULL(insalord.Created_On, insalord.ord_date))
          ELSE ISNULL(insalord.Created_On, insalord.ord_date)
        END
      ), 
      GETDATE()
    ) BETWEEN 61 AND 90 THEN 5
    ELSE 6
  END AS 'Aging_Sort_Order',
  
  -- ===== DATA QUALITY & AUDIT TRAIL =====
  -- Tracks which date was actually used for aging calculation
  -- Essential for data validation and troubleshooting aging discrepancies
  CASE 
    WHEN insalord.type = 'W' AND (SELECT MIN(CreationDate) FROM RepairOrderDetail WHERE RONumber = CASE WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no ELSE insalord.ro_number END AND Branch = insalord.branch) IS NOT NULL THEN 'WO_Creation_Date'
    WHEN insalord.Created_On IS NOT NULL THEN 'Created_On'
    ELSE 'Order_Date'
  END AS 'Aging_Date_Source',

  -- ===== PARTS QUANTITY METRICS =====
  SUM(insalpar.order_qty) AS '#_Parts_On_Order',                    -- Total parts quantity ordered
  SUM(ISNULL(COMM_PART_QTY, 0)) AS '#_On_Back_Order',              -- Parts currently backordered
  
  -- ===== FINANCIAL SUMMARY METRICS =====
  SUM(insalpar.unit_price * insalpar.order_qty) AS 'Order_Total_$$',              -- Total order value
  SUM(insalpar.unit_price * (insalpar.order_qty - ISNULL(COMM_PART_QTY, 0))) AS '$$_Available',   -- Value ready to ship
  SUM(insalpar.unit_price * ISNULL(COMM_PART_QTY, 0)) AS '$$_BackOrdered',        -- Value stuck in backorder
  
  -- ===== BACKORDER ANALYSIS =====
  -- Percentage calculation for prioritizing high-impact backorders
  CASE 
    WHEN SUM(insalpar.order_qty) > 0 THEN 
      CAST(SUM(ISNULL(COMM_PART_QTY, 0)) * 100.0 / SUM(insalpar.order_qty) AS DECIMAL(5,1))
    ELSE 0 
  END AS 'Backorder_Pct',

  -- ===== FINANCIAL INFORMATION =====
  MAX(ISNULL(insalord.deposit, 0)) AS 'Deposit',                   -- Customer deposit amount

  -- ===== SALES TEAM INFORMATION =====
  -- Lookup salesperson name for customer service follow-up
  (SELECT ISNULL(name, '') + ' ' + ISNULL(surname, '') 
   FROM contact 
   WHERE insalord.salesman = contact.contact_code) AS 'Salesman',

  -- ===== CUSTOMER INFORMATION =====
  insalord.customer_no AS 'Contact_Code',                          -- System customer ID
  
  -- AR Account lookup for financial integration
  ISNULL((
    SELECT armaster_customer.customer_no
    FROM armaster_customer
    WHERE armaster_customer.contact_code = insalord.customer_no
  ), 0) AS 'AR_Acct',

  -- Enhanced customer name logic (Company name preferred, individual names as fallback)
  CASE 
    WHEN ISNULL(TRIM((SELECT company_name FROM contact WHERE contact_code = insalord.customer_no)), '') = '' 
    THEN 
      ISNULL((SELECT name FROM contact WHERE contact_code = insalord.customer_no), '') 
      + ' ' + 
      ISNULL((SELECT surname FROM contact WHERE contact_code = insalord.customer_no), '')
    ELSE
      ISNULL((SELECT TRIM(company_name) FROM contact WHERE contact_code = insalord.customer_no), 'Internal Order')
  END AS 'Customer'

FROM 
  insalord
  INNER JOIN insalpar ON insalpar.file_no = insalord.file_no
  -- NOTE: RepairOrderDetail accessed via subqueries only (avoids record duplication)

WHERE 
  -- ===== BUSINESS FILTERS =====
  (insalord.type IS NULL OR insalord.type <> 'T')    -- Exclude internal transfers
  AND (insalord.branch IS NULL OR NULL IS NULL)       -- Branch filter placeholder (currently open)

GROUP BY 
  -- ===== GROUPING FOR ORDER-LEVEL SUMMARY =====
  insalord.branch,
  insalord.file_no,
  insalord.ro_number,
  insalord.type,
  insalord.ord_date,
  insalord.Created_On,
  insalord.customer_no,
  insalord.salesman,
  insalord.deposit

ORDER BY 
  -- ===== BUSINESS-PRIORITY SORTING =====
  insalord.branch,                        -- Group by location
  insalord.ro_number,                     -- Then by order number
  insalord.file_no;                       -- File number as secondary sort

")
in
  Source

/*
================================================================================
🚀 POWER BI SETUP INSTRUCTIONS:
================================================================================

1. AGING COLUMN SORTING:
   • Data View > Click 'Aging' column
   • Column Tools > Sort by Column > Select 'Aging_Sort_Order'
   • Right-click 'Aging_Sort_Order' > Hide in report view

2. RECOMMENDED MEASURES:
   • Average Days Open: AVERAGE(Parts_Open_Tickets[Days_Open])
   • % Orders 30+ Days: DIVIDE(COUNTROWS(FILTER(Parts_Open_Tickets, [Days_Open] > 30)), COUNTROWS(Parts_Open_Tickets))
   • % Orders in Early Processing (8-14 days): DIVIDE(COUNTROWS(FILTER(Parts_Open_Tickets, [Aging] = "8-14 days")), COUNTROWS(Parts_Open_Tickets))
   • % Orders in Extended Processing (15-30 days): DIVIDE(COUNTROWS(FILTER(Parts_Open_Tickets, [Aging] = "15-30 days")), COUNTROWS(Parts_Open_Tickets))
   • Total Backorder Impact: SUM(Parts_Open_Tickets[$_BackOrdered])

3. SUGGESTED VISUALIZATIONS:
   • Aging Distribution: Donut chart (Aging vs Order count)
   • Branch Performance: Matrix (Location vs Aging buckets)
   • Financial Impact: Bar chart (Aging vs $$_BackOrdered)
   • Trend Analysis: Line chart (Date slicer + Aging over time)

4. DATA QUALITY MONITORING:
   • Create slicer on 'Aging_Date_Source' to validate date usage
   • Monitor 'WO_Creation_Date' vs 'Created_On' for Work Orders
   • Set up alerts for 90+ day aging bucket increases

================================================================================
✅ QUERY VALIDATION CHECKLIST:
================================================================================
□ Record count ~21,200 (matches pre-RepairOrderDetail baseline)
□ Work Orders show 'WO_Creation_Date' in Aging_Date_Source
□ Aging buckets sort correctly (0-7, 8-14, 15-30, 31-60, 61-90, 90+)
□ Financial totals balance (Order_Total = Available + BackOrdered)
□ No duplicate orders (Unique_Orders count unchanged)
□ Branch names populate correctly
□ Customer names display properly (company vs individual)

================================================================================
*/