-- ClosedWorkOrders.sql
-- Purpose:  Daily CSV feed for Casey's tractor-alert dashboard, which matches alert tickets to
--           work orders (by WO number, or by MachinePIN within 30 days of OpenedDate) and puts
--           dollar figures on them.
-- Grain:    one row per work order closed since 2024-08-01 (Andrea's alert history starts Aug 2024),
--           ~35k rows in Oct 2026. Overwrites ClosedWorkOrders.csv daily; the flow skips the write
--           (and fails) if fewer than 30,000 rows come back, so a bad run never replaces a good file.
--           WO numbers are effectively unique company-wide (4 reuses in 720k WOs of history).
-- Filters:  (Casey, 2026-10-15) John Deere machines only, machine PIN present, no stock units.
--           Work orders carry no 'D' franchise (theirs are AG/CP/OT/CW), so "John Deere" is the
--           machine's Make, matched loosely because Make is free text ('JOHN DEER', 'JD', 'DEERE').
-- Source:   DP_Presentation SQL endpoint (Prod), Silver shortcuts:
--             Silver_WkRoFile  (WO header: dates, account, REG, stock flag)
--             Silver_WkVehFl   (REG -> machine PIN/VIN, make; REG is unique)
--             Silver_WkInvReg  (invoice register: labor/parts/other/sublet/total per invoice, ROType)
--             Silver_WkOthSub  (job lines: job code, job type, invoiced labor + parts per job)
--             CustomerLookup   (account -> display name; same lookup the Gold service facts use)
-- Notes:    Pay type (ROType/JobType): R = customer pay, W = warranty, I = internal, S = other.
--           MiscInvoiced = other charges + sublet. WorkOrderTotal = labor + parts + misc, no tax.
--           JobDetail lists every job as "JobCode (JobType): L labor + P parts = total", separated
--           by " | ". Job dollars are labor + parts only (misc is billed per invoice, not per job),
--           so the job totals add up to LaborInvoiced + PartsInvoiced.
--           Run by the Power Automate flow "Closed Work Orders Export - Daily".

WITH wo AS (
    SELECT r.Branch, r.WorkOrder, r.CreatedOn, r.ClosedDate, r.AccountNumber, TRIM(v.VIN) AS MachinePIN
    FROM dbo.Silver_WkRoFile r
    JOIN dbo.Silver_WkVehFl v ON v.Registration = r.Registration
    WHERE r.IsClosed = 'Y'
      AND r.ClosedDate >= '2024-08-01'
      AND COALESCE(r.CustomerVehicleFlag, '') <> 'S'
      AND COALESCE(TRIM(v.VIN), '') <> ''
      AND (UPPER(v.Make) LIKE '%DEER%' OR UPPER(TRIM(v.Make)) = 'JD')
),
lines AS (
    SELECT s.Branch, s.WorkOrder, TRIM(s.JobCode) AS JobCode, TRIM(s.JobType) AS JobType,
           COALESCE(s.InvLabor, 0) AS InvLabor, COALESCE(s.InvParts, 0) AS InvParts
    FROM dbo.Silver_WkOthSub s
    JOIN wo ON wo.Branch = s.Branch AND wo.WorkOrder = s.WorkOrder
),
totals AS (
    -- Invoice register: one row per invoice; a WO can have several (one per pay type).
    -- InvoiceTotal = LabourCharged + PartsValue + OtherValue + SubletValue (no tax), and
    -- labor/parts tie to the WkOthSub job lines exactly (checked 2026-10-15).
    SELECT i.Branch, i.WorkOrder,
        SUM(COALESCE(i.LabourCharged, 0)) AS LaborInvoiced,
        SUM(COALESCE(i.PartsValue, 0)) AS PartsInvoiced,
        SUM(COALESCE(i.OtherValue, 0) + COALESCE(i.SubletValue, 0)) AS MiscInvoiced,
        SUM(COALESCE(i.InvoiceTotal, 0)) AS WorkOrderTotal,
        SUM(CASE WHEN i.ROType = 'R' THEN COALESCE(i.InvoiceTotal, 0) ELSE 0 END) AS CustomerPayTotal,
        SUM(CASE WHEN i.ROType = 'W' THEN COALESCE(i.InvoiceTotal, 0) ELSE 0 END) AS WarrantyTotal
    FROM dbo.Silver_WkInvReg i
    JOIN wo ON wo.Branch = i.Branch AND wo.WorkOrder = i.WorkOrder
    GROUP BY i.Branch, i.WorkOrder
),
codes AS (
    SELECT Branch, WorkOrder,
           STRING_AGG(CAST(JobCode AS varchar(max)), '; ') WITHIN GROUP (ORDER BY JobCode) AS JobCodes
    FROM (SELECT DISTINCT Branch, WorkOrder, JobCode FROM lines WHERE JobCode <> '') x
    GROUP BY Branch, WorkOrder
),
types AS (
    SELECT Branch, WorkOrder,
           STRING_AGG(JobType, '; ') WITHIN GROUP (ORDER BY JobType) AS JobTypes
    FROM (SELECT DISTINCT Branch, WorkOrder, JobType FROM lines WHERE JobType <> '') x
    GROUP BY Branch, WorkOrder
),
detail AS (
    SELECT Branch, WorkOrder,
           STRING_AGG(CAST(
               CONCAT(JobCode, ' (', JobType, '): L ', CAST(CAST(InvLabor AS decimal(12, 2)) AS varchar(20)),
                      ' + P ', CAST(CAST(InvParts AS decimal(12, 2)) AS varchar(20)),
                      ' = ', CAST(CAST(InvLabor + InvParts AS decimal(12, 2)) AS varchar(20)))
               AS varchar(max)), ' | ') WITHIN GROUP (ORDER BY JobCode, JobType, InvLabor + InvParts DESC) AS JobDetail
    FROM lines
    GROUP BY Branch, WorkOrder
)
SELECT
    wo.WorkOrder,
    wo.Branch,
    CAST(wo.CreatedOn AS date) AS OpenedDate,
    CAST(wo.ClosedDate AS date) AS ClosedDate,
    wo.AccountNumber AS CustomerAccount,
    c.DisplayName AS CustomerName,
    wo.MachinePIN,
    CAST(ROUND(t.LaborInvoiced, 2) AS decimal(12, 2)) AS LaborInvoiced,
    CAST(ROUND(t.PartsInvoiced, 2) AS decimal(12, 2)) AS PartsInvoiced,
    CAST(ROUND(t.MiscInvoiced, 2) AS decimal(12, 2)) AS MiscInvoiced,
    CAST(ROUND(t.WorkOrderTotal, 2) AS decimal(12, 2)) AS WorkOrderTotal,
    CAST(ROUND(t.CustomerPayTotal, 2) AS decimal(12, 2)) AS CustomerPayTotal,
    CAST(ROUND(t.WarrantyTotal, 2) AS decimal(12, 2)) AS WarrantyTotal,
    cd.JobCodes,
    ty.JobTypes,
    dt.JobDetail
FROM wo
LEFT JOIN totals t ON t.Branch = wo.Branch AND t.WorkOrder = wo.WorkOrder
LEFT JOIN codes cd ON cd.Branch = wo.Branch AND cd.WorkOrder = wo.WorkOrder
LEFT JOIN types ty ON ty.Branch = wo.Branch AND ty.WorkOrder = wo.WorkOrder
LEFT JOIN detail dt ON dt.Branch = wo.Branch AND dt.WorkOrder = wo.WorkOrder
LEFT JOIN dbo.CustomerLookup c ON c.MatchKey = UPPER(TRIM(CAST(wo.AccountNumber AS varchar(20))))
ORDER BY wo.ClosedDate DESC, wo.Branch, wo.WorkOrder;
