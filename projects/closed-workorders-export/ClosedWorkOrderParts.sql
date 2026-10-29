-- ClosedWorkOrderParts.sql
-- Purpose:  Part lines for the work orders in ClosedWorkOrders.csv, for Casey's alert dashboard
--           (asked 2026-10-27). Join to ClosedWorkOrders.csv on WorkOrder.
-- Grain:    one row per part transaction line (sale or credit) on a work order closed since
--           2024-08-01, John Deere machine with a PIN, stock units included: the same work orders
--           as ClosedWorkOrders.sql. ~357k lines in Oct 2026.
-- Output:   the query builds the whole CSV itself and returns ONE row (LineCount, Csv). As JSON,
--           357k rows would be ~70 MB, too close to Power Automate's 100 MB message limit; as one
--           CSV string it is ~33 MB. The flow writes Csv as-is if LineCount >= 300,000.
-- Source:   DP_Presentation SQL endpoint (Prod):
--             Silver_WkRoFile, Silver_WkVehFl  (work order filter, as ClosedWorkOrders.sql)
--             Silver_WkInvReg                  (WO -> its invoice numbers)
--             Silver_InTrans                   (part lines; RONumber = invoice number)
--             dim_Parts                        (part description; unique per PartNumber, no
--                                               trailing-space/case twins, covers every line)
-- Matching: part lines are matched to the WO's invoices on invoice number ALONE, not branch:
--           some WOs draw parts from another store's stock (e.g. branch 91 WOs from branch 8,
--           6 from 92), and those lines carry the stock branch (PartBranch). Checked 2026-10-27
--           on the flow's own output: all 41,070 WOs tie to WkInvReg PartsValue to the penny
--           ($59,447,863.90); no WO picks up lines from two branch families. To guard against reused
--           invoice numbers, a line must be dated on or after the WO's open date (no real line
--           was earlier).
-- Notes:    Type I = sale, C = credit/return (negative Quantity and LineTotal). P/A rows carry
--           no sale value and are left out. UnitPrice = LineTotal / Quantity (blank when Qty = 0).
--           Description is the part master's, not InTrans.Description (that is a transaction
--           note, "Inv No. 1234567", on 96% of lines).
--           Franchise ZP lines are fees, freight and discounts, kept so lines add up to
--           PartsInvoiced. Text fields are always quoted; embedded quotes are doubled and
--           line breaks in Description become spaces.
--           Run by the Power Automate flow "Closed Work Order Parts Export - Biweekly".

WITH veh_ci AS (
    SELECT UPPER(TRIM(Registration)) AS RegKey, MIN(VIN) AS VIN, MIN(Make) AS Make
    FROM dbo.Silver_WkVehFl
    GROUP BY UPPER(TRIM(Registration))
    HAVING COUNT(*) = 1
),
wo_veh AS (
    SELECT r.Branch, r.WorkOrder, r.CreatedOn, r.ClosedDate,
           TRIM(COALESCE(ve.VIN, vc.VIN)) AS MachinePIN,
           UPPER(TRIM(COALESCE(ve.Make, vc.Make))) AS Make
    FROM dbo.Silver_WkRoFile r
    LEFT JOIN dbo.Silver_WkVehFl ve ON ve.Registration = r.Registration
    LEFT JOIN veh_ci vc ON ve.Registration IS NULL AND vc.RegKey = UPPER(TRIM(r.Registration))
    WHERE r.IsClosed = 'Y'
      AND r.ClosedDate >= '2024-08-01'
),
wo AS (
    SELECT Branch, WorkOrder, CreatedOn, ClosedDate
    FROM wo_veh
    WHERE COALESCE(MachinePIN, '') <> ''
      AND (Make LIKE '%DEER%' OR Make IN ('JD', 'HAGIE'))
),
inv AS (
    SELECT DISTINCT wo.Branch, wo.WorkOrder, wo.CreatedOn, wo.ClosedDate, i.InvoiceNumber
    FROM dbo.Silver_WkInvReg i
    JOIN wo ON wo.Branch = i.Branch AND wo.WorkOrder = i.WorkOrder
),
lines AS (
    SELECT inv.WorkOrder, inv.Branch, CAST(inv.ClosedDate AS date) AS ClosedDate,
           t.Branch AS PartBranch, TRIM(t.JobCode) AS JobCode, t.PartNumber,
           COALESCE(p.Description, t.Description) AS Description,
           t.Qty, t.SaleValue, t.TransDatetime, t.TransId
    FROM inv
    JOIN dbo.Silver_InTrans t
      ON t.RONumber = inv.InvoiceNumber
     AND t.TransDatetime >= CAST(inv.CreatedOn AS date)
    LEFT JOIN dbo.dim_Parts p ON p.PartNumber = t.PartNumber
    WHERE t.Type IN ('I', 'C')
),
csv_lines AS (
    SELECT ClosedDate, WorkOrder, TransDatetime, TransId, PartBranch,
           CONCAT(
               CAST(WorkOrder AS varchar(12)), ',',
               '"', Branch, '",',
               CONVERT(varchar(10), ClosedDate, 23), ',',
               '"', PartBranch, '",',
               '"', REPLACE(COALESCE(JobCode, ''), '"', '""'), '",',
               '"', REPLACE(COALESCE(PartNumber, ''), '"', '""'), '",',
               '"', REPLACE(REPLACE(REPLACE(COALESCE(Description, ''), '"', '""'), CHAR(13), ' '), CHAR(10), ' '), '",',
               CAST(Qty AS varchar(20)), ',',
               CASE WHEN Qty <> 0 THEN CAST(CAST(ROUND(SaleValue / Qty, 2) AS decimal(12, 2)) AS varchar(20)) ELSE '' END, ',',
               CAST(SaleValue AS varchar(20))
           ) AS Line
    FROM lines
)
SELECT
    COUNT(*) AS LineCount,
    CONCAT(
        'WorkOrder,Branch,ClosedDate,PartBranch,JobCode,PartNumber,Description,Quantity,UnitPrice,LineTotal',
        CHAR(13), CHAR(10),
        STRING_AGG(CAST(Line AS varchar(max)), CHAR(13) + CHAR(10))
            WITHIN GROUP (ORDER BY ClosedDate DESC, WorkOrder, TransDatetime, TransId, PartBranch),
        CHAR(13), CHAR(10)
    ) AS Csv
FROM csv_lines;
