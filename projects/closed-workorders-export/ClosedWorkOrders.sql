-- ClosedWorkOrders.sql
-- Purpose:  Daily CSV feed for Casey's tractor-alert program, so he can match alerts to the
--           service work that followed and put dollar figures on it.
-- Grain:    one row per closed work order (Branch + WorkOrder), closed in the last 90 days.
--           Written daily as a new file wo-YYYY-MM-DD.csv (Casey's dashboard reads every file
--           and keeps the newest row per WO). WO numbers are effectively unique company-wide
--           (4 reuses in 720k WOs of history; none within any 90-day window).
-- Source:   DP_Presentation SQL endpoint (Prod), Silver shortcuts:
--             Silver_WkRoFile  (WO header: dates, account, REG, pay method)
--             Silver_WkVehFl   (REG -> machine PIN/VIN, make, model, year; REG is unique)
--             Silver_WkInvReg  (invoice register: labor/parts/other/sublet/total per invoice, ROType)
--             Silver_WkOthSub  (job lines: job codes, job types, actual cost)
--             CustomerLookup   (account -> display name; same lookup the Gold service facts use)
-- Notes:    Pay type (ROType/JobType): R = customer pay, W = warranty, I = internal, S/other.
--           MiscInvoiced = OtherChargesInvoiced + SubletInvoiced. WorkOrderTotal excludes tax.
--           ClaimNumber is blank in Silver, so warranty comes from the pay type.
--           MachinePIN is the full 17-char JD PIN for most Deere units; older and non-Deere
--           machines carry shorter serials. EquipRegistration is Equip's own unit key.
--           Run by the Power Automate flow "Closed Work Orders Export - Daily".

WITH wo AS (
    SELECT Branch, WorkOrder, CreatedOn, ClosedDate, AccountNumber, Registration, Odometer,
           CustomerVehicleFlag, IsFieldService, PaymentMethod
    FROM dbo.Silver_WkRoFile
    WHERE IsClosed = 'Y'
      AND ClosedDate >= DATEADD(day, -90, CAST(GETDATE() AS date))
),
lines AS (
    SELECT s.Branch, s.WorkOrder, TRIM(s.JobCode) AS JobCode, TRIM(s.JobType) AS JobType,
           TRIM(s.WorkCategory) AS WorkCategory, TRIM(s.InvoiceNumber) AS InvoiceNumber,
           s.IsMachineDown,
           COALESCE(s.InvLabor, 0) AS InvLabor, COALESCE(s.InvParts, 0) AS InvParts,
           COALESCE(s.ActLabor, 0) AS ActLabor, COALESCE(s.ActParts, 0) AS ActParts
    FROM dbo.Silver_WkOthSub s
    JOIN wo ON wo.Branch = s.Branch AND wo.WorkOrder = s.WorkOrder
),
jobs AS (
    SELECT Branch, WorkOrder,
        COUNT(*) AS JobCount,
        MAX(CASE WHEN IsMachineDown = 'Y' THEN 1 ELSE 0 END) AS AnyMachineDown,
        SUM(ActLabor) AS LaborCost,
        SUM(ActParts) AS PartsCost
    FROM lines GROUP BY Branch, WorkOrder
),
totals AS (
    -- Invoice register: one row per invoice; a WO can have several (one per pay type).
    -- InvoiceTotal = LabourCharged + PartsValue + OtherValue + SubletValue (no tax), and
    -- labor/parts tie to the WkOthSub job lines exactly (checked 2026-10-15).
    SELECT i.Branch, i.WorkOrder,
        SUM(COALESCE(i.LabourCharged, 0)) AS LaborInvoiced,
        SUM(COALESCE(i.PartsValue, 0)) AS PartsInvoiced,
        SUM(COALESCE(i.OtherValue, 0) + COALESCE(i.SubletValue, 0)) AS MiscInvoiced,
        SUM(COALESCE(i.SubletValue, 0)) AS SubletInvoiced,
        SUM(COALESCE(i.OtherValue, 0)) AS OtherChargesInvoiced,
        SUM(COALESCE(i.InvoiceTotal, 0)) AS WorkOrderTotal,
        SUM(CASE WHEN i.ROType = 'R' THEN COALESCE(i.InvoiceTotal, 0) ELSE 0 END) AS CustomerPayTotal,
        SUM(CASE WHEN i.ROType = 'W' THEN COALESCE(i.InvoiceTotal, 0) ELSE 0 END) AS WarrantyTotal,
        SUM(CASE WHEN i.ROType = 'I' THEN COALESCE(i.InvoiceTotal, 0) ELSE 0 END) AS InternalTotal,
        SUM(CASE WHEN i.ROType IN ('R', 'W', 'I') THEN 0 ELSE COALESCE(i.InvoiceTotal, 0) END) AS OtherPayTypeTotal
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
cats AS (
    SELECT Branch, WorkOrder,
           STRING_AGG(WorkCategory, '; ') WITHIN GROUP (ORDER BY WorkCategory) AS WorkCategories
    FROM (SELECT DISTINCT Branch, WorkOrder, WorkCategory FROM lines WHERE WorkCategory <> '') x
    GROUP BY Branch, WorkOrder
),
invs AS (
    SELECT Branch, WorkOrder,
           STRING_AGG(InvoiceNumber, '; ') WITHIN GROUP (ORDER BY InvoiceNumber) AS InvoiceNumbers
    FROM (SELECT DISTINCT Branch, WorkOrder, InvoiceNumber FROM lines WHERE InvoiceNumber <> '') x
    GROUP BY Branch, WorkOrder
)
SELECT
    wo.Branch,
    wo.WorkOrder,
    CAST(wo.CreatedOn AS date) AS OpenedDate,
    CAST(wo.ClosedDate AS date) AS ClosedDate,
    wo.AccountNumber AS CustomerAccount,
    c.DisplayName AS CustomerName,
    TRIM(v.VIN) AS MachinePIN,
    TRIM(v.Make) AS Make,
    TRIM(v.Model) AS Model,
    v.[Year] AS ModelYear,
    TRIM(wo.Registration) AS EquipRegistration,
    wo.Odometer AS Hours,
    CASE WHEN wo.CustomerVehicleFlag = 'S' THEN 'Y' ELSE 'N' END AS IsStockUnit,
    wo.IsFieldService,
    wo.PaymentMethod,
    j.JobCount,
    cd.JobCodes,
    ty.JobTypes,
    ct.WorkCategories,
    j.AnyMachineDown,
    CAST(ROUND(t.LaborInvoiced, 2) AS decimal(12, 2)) AS LaborInvoiced,
    CAST(ROUND(t.PartsInvoiced, 2) AS decimal(12, 2)) AS PartsInvoiced,
    CAST(ROUND(t.MiscInvoiced, 2) AS decimal(12, 2)) AS MiscInvoiced,
    CAST(ROUND(t.SubletInvoiced, 2) AS decimal(12, 2)) AS SubletInvoiced,
    CAST(ROUND(t.OtherChargesInvoiced, 2) AS decimal(12, 2)) AS OtherChargesInvoiced,
    CAST(ROUND(t.WorkOrderTotal, 2) AS decimal(12, 2)) AS WorkOrderTotal,
    CAST(ROUND(t.CustomerPayTotal, 2) AS decimal(12, 2)) AS CustomerPayTotal,
    CAST(ROUND(t.WarrantyTotal, 2) AS decimal(12, 2)) AS WarrantyTotal,
    CAST(ROUND(t.InternalTotal, 2) AS decimal(12, 2)) AS InternalTotal,
    CAST(ROUND(t.OtherPayTypeTotal, 2) AS decimal(12, 2)) AS OtherPayTypeTotal,
    CAST(ROUND(j.LaborCost, 2) AS decimal(12, 2)) AS LaborCost,
    CAST(ROUND(j.PartsCost, 2) AS decimal(12, 2)) AS PartsCost,
    iv.InvoiceNumbers,
    CONVERT(varchar(19), SYSUTCDATETIME(), 126) AS ExtractedAtUtc
FROM wo
LEFT JOIN dbo.Silver_WkVehFl v ON v.Registration = wo.Registration
LEFT JOIN jobs j ON j.Branch = wo.Branch AND j.WorkOrder = wo.WorkOrder
LEFT JOIN totals t ON t.Branch = wo.Branch AND t.WorkOrder = wo.WorkOrder
LEFT JOIN codes cd ON cd.Branch = wo.Branch AND cd.WorkOrder = wo.WorkOrder
LEFT JOIN types ty ON ty.Branch = wo.Branch AND ty.WorkOrder = wo.WorkOrder
LEFT JOIN cats ct ON ct.Branch = wo.Branch AND ct.WorkOrder = wo.WorkOrder
LEFT JOIN invs iv ON iv.Branch = wo.Branch AND iv.WorkOrder = wo.WorkOrder
LEFT JOIN dbo.CustomerLookup c ON c.MatchKey = UPPER(TRIM(CAST(wo.AccountNumber AS varchar(20))))
ORDER BY wo.ClosedDate DESC, wo.Branch, wo.WorkOrder;
