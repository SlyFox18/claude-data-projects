/*
================================================================================
PARTS OPEN TICKETS DETAILS QUERY - WITH 6-BUCKET AGING & WORK ORDER DATES
================================================================================

PURPOSE:
This query provides line-by-line detail for parts orders, complementing the 
summary Parts_Open_Tickets report. Shows individual part numbers, quantities, 
and pricing details for each order.

ALIGNMENT NOTE:
This query uses IDENTICAL aging logic and field naming conventions as the 
summary query to ensure perfect data consistency across reports.

KEY FEATURES:
- Line-item level detail (one row per part per order)
- Accurate Work Order aging using RepairOrderDetail.CreationDate
- 6-bucket aging structure (0-7, 8-14, 15-30, 31-60, 61-90, 90+ days)
- Individual part numbers, quantities, and unit prices
- No aggregation/grouping (raw detail level)

BUSINESS USE CASES:
- Detailed parts analysis and inventory management
- Individual part backorder tracking  
- Line-item pricing analysis
- Drill-through from summary reports
- Part-level aging investigation

LAST UPDATED: [9/24/25] - Updated to match 6-bucket aging with Work Order dates
DEVELOPER: [Brian Fox]
STAKEHOLDER APPROVED: [9/24/25 - Executive 6-bucket aging requirement]
================================================================================
*/

let
  Source = Odbc.Query("dsn=EquipRDB64", "
SELECT 
    -- ===== BRANCH & LOCATION INFORMATION =====
    insalord.branch AS Location,
    (SELECT name FROM branch_name WHERE insalord.branch = branch_name.branch) AS Location_Name,

    -- ===== ORDER IDENTIFICATION =====
    -- Business Rule: Use RO Number when available, otherwise File Number
    CASE 
        WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
        ELSE insalord.ro_number
    END AS Order_No,
    
    insalord.ro_number AS RO_Number,
    insalord.file_no AS File_No,

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
    END AS Invoice_Type,

    -- ===== DATE FOUNDATION =====
    DATE(insalord.ord_date) AS Order_Date,          -- Original order placement date
    DATE(insalord.Created_On) AS Created_On,        -- System entry date (most types)
    
    -- ===== WORK ORDER CREATION DATE LOOKUP =====
    -- CRITICAL: Gets actual Work Order creation date from RepairOrderDetail
    -- Uses MIN() to handle multiple RepairOrderDetail records per Work Order
    -- Prevents record duplication that would inflate line counts
    (SELECT MIN(DATE(CreationDate)) 
     FROM RepairOrderDetail 
     WHERE RONumber = CASE 
       WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
       ELSE insalord.ro_number
     END
     AND Branch = insalord.branch) AS WO_Creation_Date,

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
    ) AS Days_Open,

    -- ===== 6-BUCKET AGING CLASSIFICATION =====
    -- Executive-requested aging categories for enhanced operational management
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
    END AS Aging,

    -- ===== AGING SORT ORDER =====
    -- Numeric sorting for Power BI to display aging buckets in logical order
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
    END AS Aging_Sort_Order,

    -- ===== DATA QUALITY & AUDIT TRAIL =====
    -- Tracks which date was actually used for aging calculation
    -- Essential for data validation and troubleshooting aging discrepancies
    CASE 
        WHEN insalord.type = 'W' AND (SELECT MIN(CreationDate) FROM RepairOrderDetail WHERE RONumber = CASE WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no ELSE insalord.ro_number END AND Branch = insalord.branch) IS NOT NULL THEN 'WO_Creation_Date'
        WHEN insalord.Created_On IS NOT NULL THEN 'Created_On'
        ELSE 'Order_Date'
    END AS Aging_Date_Source,

    -- ===== PART DETAIL INFORMATION =====
    -- Unique to detail query - individual part line items
    insalpar.part_no AS Part_No,                           -- Individual part number
    insalpar.order_qty AS Quantity_Ordered,               -- Quantity ordered for this part
    insalpar.unit_price AS Unit_Price,                     -- Unit price for this part
    (insalpar.unit_price * insalpar.order_qty) AS Line_Total,              -- Total line value
    ISNULL(insalpar.COMM_PART_QTY, 0) AS BackOrdered_QTY, -- Quantity backordered for this part
    
    -- ===== CALCULATED PART METRICS =====
    (insalpar.order_qty - ISNULL(insalpar.COMM_PART_QTY, 0)) AS Available_QTY,  -- Available quantity
    
    -- Line-level backorder percentage for individual part analysis
    CASE 
        WHEN insalpar.order_qty > 0 THEN 
            CAST(ISNULL(insalpar.COMM_PART_QTY, 0) * 100.0 / insalpar.order_qty AS DECIMAL(5,1))
        ELSE 0 
    END AS Line_Backorder_Pct,

    -- ===== CUSTOMER INFORMATION =====
    -- Consistent naming with summary query
    insalord.customer_no AS Contact_Code,                  -- System customer ID
    
    -- Enhanced customer name logic (Company name preferred, individual names as fallback)
    CASE 
        WHEN ISNULL(TRIM(c.company_name), '') = '' 
        THEN ISNULL(c.name, '') + ' ' + ISNULL(c.surname, '')
        ELSE ISNULL(TRIM(c.company_name), 'Internal Order')
    END AS Customer,

    -- ===== SALES TEAM INFORMATION =====
    -- Lookup salesperson name for customer service follow-up
    (SELECT ISNULL(name, '') + ' ' + ISNULL(surname, '') 
     FROM contact 
     WHERE insalord.salesman = contact.contact_code) AS Salesman

FROM 
    insalord
    INNER JOIN insalpar ON insalord.file_no = insalpar.file_no
    LEFT JOIN contact c ON insalord.customer_no = c.contact_code
    -- NOTE: RepairOrderDetail accessed via subqueries only (avoids record duplication)

WHERE 
    -- ===== BUSINESS FILTERS =====
    (insalord.type IS NULL OR insalord.type <> 'T')    -- Exclude internal transfers

ORDER BY 
    -- ===== BUSINESS-PRIORITY SORTING =====
    insalord.branch,                                    -- Group by location
    -- Order by aging (oldest first) within branch - matches summary query
    DATEDIFF(day, 
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
    ) DESC,
    CASE 
        WHEN ISNULL(insalord.ro_number, 0) = 0 THEN insalord.file_no
        ELSE insalord.ro_number
    END,
    insalpar.part_no;                                   -- Then by part number
")
in
  Source

/*
================================================================================
🚀 ALIGNMENT WITH SUMMARY QUERY:
================================================================================

✅ IDENTICAL FEATURES:
• Same 6-bucket aging logic (0-7, 8-14, 15-30, 31-60, 61-90, 90+ days)
• Same Work Order creation date lookup from RepairOrderDetail  
• Same aging hierarchy (WO Creation → Created_On → Order_Date)
• Same data quality tracking (Aging_Date_Source)
• Same invoice type decoding and customer name logic
• Same sort order values for Power BI compatibility

🔍 DETAIL-SPECIFIC FEATURES:
• Part_No: Individual part numbers for inventory analysis
• Quantity_Ordered: Line-item quantities
• Unit_Price: Individual part pricing
• Line_Total: Line-level financial values
• BackOrdered_QTY: Part-specific backorder quantities
• Available_QTY: Part-specific available quantities  
• Line_Backorder_Pct: Part-level backorder percentages

📊 PERFECT DRILL-THROUGH CAPABILITY:
This detail query now perfectly complements the summary query, enabling
seamless drill-through experiences in Power BI with consistent aging
buckets, date sources, and field naming conventions.

================================================================================
*/