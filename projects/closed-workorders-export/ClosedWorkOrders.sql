-- ClosedWorkOrders.sql
-- Purpose:  Daily CSV feed for Casey's tractor-alert dashboard, which matches alert tickets to
--           work orders (by WO number, or by MachinePIN within 30 days of OpenedDate) and puts
--           dollar figures on them.
-- Grain:    one row per work order closed since 2024-08-01 (Andrea's alert history starts Aug 2024),
--           ~41k rows in Oct 2026. Overwrites ClosedWorkOrders.csv daily; the flow skips the write
--           (and fails) if fewer than 30,000 rows come back, so a bad run never replaces a good file.
--           WO numbers are effectively unique company-wide (4 reuses in 720k WOs of history).
-- Filters:  John Deere machines only, machine PIN present. Work orders carry no 'D' franchise
--           (theirs are AG/CP/OT/CW), so "John Deere" is the machine's Make, matched loosely because
--           Make is free text ('JOHN DEER', 'JD', 'DEERE'), plus HAGIE (a Deere brand). The REG join
--           falls back to a case/space-insensitive match. Stock units are INCLUDED and flagged
--           (IsStockUnit) since 2026-10-16: 11 of Andrea's Yes tickets were on stock units.
-- Source:   DP_Presentation SQL endpoint (Prod):
--             Silver_WkRoFile                 (WO header: dates, account, REG, stock flag)
--             Silver_WkVehFl                  (REG -> machine PIN/VIN, make; REG is unique)
--             Silver_WkInvReg                 (invoice register: labor/parts/other/sublet/total, ROType)
--             Silver_WkOthSub                 (job lines: job code, job type, invoiced labor + parts)
--             Silver_TechnicianPunchedDetail  (tech time punches; key ROBranch+WO+Tech+Seq+Start)
--             dim_Technician_Code_Names       (tech code -> "T1505 - Name")
--             CustomerLookup                  (account -> display name, as the Gold service facts use)
-- Notes:    Pay type (ROType/JobType): R = customer pay, W = warranty, I = internal, S = other.
--           MiscInvoiced = other charges + sublet. WorkOrderTotal = labor + parts + misc, no tax.
--           JobDetail: every job as "JobCode (JobType): L labor + P parts = total", joined by " | ".
--           Job dollars are labor + parts only (misc is per invoice), so jobs add up to
--           LaborInvoiced + PartsInvoiced.
--           PunchDetail: every punch as "yyyy-mm-dd hh:mm-hh:mm, TechCode, JobCode, hours", joined
--           by " | ", in time order. Punch times are shop-local (as Equip stores them). Commas in
--           job codes are replaced with ';' inside PunchDetail. Punches are matched on the RO
--           branch (2% of punches are by a tech from another branch).
--           Run by the Power Automate flow "Closed Work Orders Export - Daily".

WITH veh_ci AS (
    -- Case/space-insensitive REG fallback (a WO can carry '410r' when the machine is '410R').
    -- Only keys that are unique after UPPER/TRIM, so no arbitrary survivor (1 collision in 270k).
    SELECT UPPER(TRIM(Registration)) AS RegKey, MIN(VIN) AS VIN, MIN(Make) AS Make
    FROM dbo.Silver_WkVehFl
    GROUP BY UPPER(TRIM(Registration))
    HAVING COUNT(*) = 1
),
wo_veh AS (
    SELECT r.Branch, r.WorkOrder, r.CreatedOn, r.ClosedDate, r.AccountNumber, r.CustomerVehicleFlag,
           TRIM(COALESCE(ve.VIN, vc.VIN)) AS MachinePIN,
           UPPER(TRIM(COALESCE(ve.Make, vc.Make))) AS Make
    FROM dbo.Silver_WkRoFile r
    LEFT JOIN dbo.Silver_WkVehFl ve ON ve.Registration = r.Registration
    LEFT JOIN veh_ci vc ON ve.Registration IS NULL AND vc.RegKey = UPPER(TRIM(r.Registration))
    WHERE r.IsClosed = 'Y'
      AND r.ClosedDate >= '2024-08-01'
),
wo AS (
    -- Hagie (1FA... PINs) is a John Deere brand, so it counts as Deere.
    SELECT Branch, WorkOrder, CreatedOn, ClosedDate, AccountNumber, MachinePIN,
           CASE WHEN CustomerVehicleFlag = 'S' THEN 'Y' ELSE 'N' END AS IsStockUnit
    FROM wo_veh
    WHERE COALESCE(MachinePIN, '') <> ''
      AND (Make LIKE '%DEER%' OR Make IN ('JD', 'HAGIE'))
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
),
punches AS (
    SELECT p.ROBranch AS Branch, p.WorkOrder, TRIM(p.TechCode) AS TechCode, p.SequenceID,
           TRIM(p.JobCode) AS JobCode, p.StartTime, p.EndTime,
           COALESCE(p.HoursWorked, 0) AS HoursWorked, COALESCE(p.HoursSold, 0) AS HoursSold
    FROM dbo.Silver_TechnicianPunchedDetail p
    JOIN wo ON wo.Branch = p.ROBranch AND wo.WorkOrder = p.WorkOrder
),
punch_sum AS (
    SELECT Branch, WorkOrder,
           COUNT(*) AS PunchCount,
           SUM(HoursWorked) AS LaborHoursPunched,
           SUM(HoursSold) AS LaborHoursSold,
           MIN(StartTime) AS FirstPunch,
           MAX(EndTime) AS LastPunch
    FROM punches GROUP BY Branch, WorkOrder
),
techs AS (
    SELECT Branch, WorkOrder,
           STRING_AGG(CAST(TechName AS varchar(max)), '; ') WITHIN GROUP (ORDER BY TechName) AS Technicians
    FROM (SELECT DISTINCT p.Branch, p.WorkOrder, COALESCE(t.TechnicianDisplayName, p.TechCode) AS TechName
          FROM punches p LEFT JOIN dbo.dim_Technician_Code_Names t ON t.TechnicianCode = p.TechCode) x
    GROUP BY Branch, WorkOrder
),
punch_detail AS (
    SELECT Branch, WorkOrder,
           STRING_AGG(CAST(
               CONCAT(CONVERT(varchar(16), StartTime, 120), '-', CONVERT(varchar(5), EndTime, 108), ', ',
                      TechCode, ', ', REPLACE(JobCode, ',', ';'), ', ',
                      CAST(CAST(HoursWorked AS decimal(8, 2)) AS varchar(12)), 'h')
               AS varchar(max)), ' | ') WITHIN GROUP (ORDER BY StartTime, TechCode, SequenceID, JobCode) AS PunchDetail
    FROM punches
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
    dt.JobDetail,
    -- Added 2026-10-16 (appended so existing column positions don't move):
    wo.IsStockUnit,
    COALESCE(ps.PunchCount, 0) AS PunchCount,
    CAST(ROUND(COALESCE(ps.LaborHoursPunched, 0), 2) AS decimal(10, 2)) AS LaborHoursPunched,
    CAST(ROUND(COALESCE(ps.LaborHoursSold, 0), 2) AS decimal(10, 2)) AS LaborHoursSold,
    CONVERT(varchar(16), ps.FirstPunch, 120) AS FirstPunch,
    CONVERT(varchar(16), ps.LastPunch, 120) AS LastPunch,
    tc.Technicians,
    pd.PunchDetail
FROM wo
LEFT JOIN totals t ON t.Branch = wo.Branch AND t.WorkOrder = wo.WorkOrder
LEFT JOIN codes cd ON cd.Branch = wo.Branch AND cd.WorkOrder = wo.WorkOrder
LEFT JOIN types ty ON ty.Branch = wo.Branch AND ty.WorkOrder = wo.WorkOrder
LEFT JOIN detail dt ON dt.Branch = wo.Branch AND dt.WorkOrder = wo.WorkOrder
LEFT JOIN punch_sum ps ON ps.Branch = wo.Branch AND ps.WorkOrder = wo.WorkOrder
LEFT JOIN techs tc ON tc.Branch = wo.Branch AND tc.WorkOrder = wo.WorkOrder
LEFT JOIN punch_detail pd ON pd.Branch = wo.Branch AND pd.WorkOrder = wo.WorkOrder
LEFT JOIN dbo.CustomerLookup c ON c.MatchKey = UPPER(TRIM(CAST(wo.AccountNumber AS varchar(20))))
ORDER BY wo.ClosedDate DESC, wo.Branch, wo.WorkOrder;
