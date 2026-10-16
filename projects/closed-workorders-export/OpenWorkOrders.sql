-- OpenWorkOrders.sql
-- Purpose:  Daily CSV of currently open John Deere work orders for Casey's tractor-alert dashboard,
--           so he can see whether a machine with an alert is already in the shop, and whether the
--           alert's job (SC + ticket number) is already on the work order.
-- Grain:    one row per open work order. Overwrites OpenWorkOrders.csv each morning (07:30, after the
--           06:15 DP refresh). The flow skips the write (and fails) if too few rows come back.
-- "Open":   same definition as the Open Work Orders report: RepairOrderDetail.StatusDisplay is not
--           'Invoiced', quotes excluded. This includes work that is finished but not yet invoiced
--           (e.g. Complete Priced, Warranty Complete, WIP Finished Not Invoiced); Status says which.
-- Filters:  John Deere machines only (Make like DEER, 'JD', or 'HAGIE'), machine PIN present.
--           Stock units included and flagged (IsStockUnit).
-- Freshness: RepairOrderDetail (open list, status, to-date $) is pulled from Equip during the 06:15
--           DP refresh. Everything else (machine, jobs, punches) comes from JD's midnight copy of
--           Equip, so a WO opened after midnight can be missing its PIN and drop out until tomorrow.
-- Source:   DP_Presentation SQL endpoint (Prod):
--             RepairOrderDetail               (open WOs, one row per job: status, $ to date, writer)
--             Silver_WkRoFile                 (account, REG, stock flag)
--             Silver_WkVehFl                  (REG -> machine PIN/VIN, make)
--             Silver_TechnicianPunchedDetail  (tech time punches)
--             dim_Technician_Code_Names, dim_Salesperson, CustomerLookup (names)
-- Notes:    Column names and formats match ClosedWorkOrders.csv where they overlap. JobDetail uses
--           the to-date labor/parts on each job ("JobCode (JobType): L labor + P parts = total").
--           JobType letters: R = customer pay (Retail), W = warranty, I = internal, S = sundry.
--           Run by the Power Automate flow "Open Work Orders Export - Daily".

WITH rod AS (
    SELECT Branch, TRY_CAST(RONumber AS int) AS WorkOrder, TRIM(JobCode) AS JobCode,
           CASE TRIM(JobType) WHEN 'Retail' THEN 'R' WHEN 'Warranty' THEN 'W' WHEN 'Internal' THEN 'I'
                              WHEN 'Sundry' THEN 'S' ELSE LEFT(TRIM(JobType), 1) END AS JobType,
           COALESCE(LaborSale, 0) AS LaborSale, COALESCE(PartSale, 0) AS PartSale,
           COALESCE(SubletSale, 0) + COALESCE(OtherSale, 0) AS MiscSale, COALESCE(TotalSale, 0) AS TotalSale,
           TRIM(StatusDisplay) AS StatusDisplay, TRIM(ROProgressStatus) AS ROProgressStatus,
           CreationDate, TRIM(SalespersonCode) AS SalespersonCode
    FROM dbo.RepairOrderDetail
    WHERE TRIM(StatusDisplay) <> 'Invoiced'
      AND COALESCE(QuotationIndicator, 'N') <> 'Y'
),
hdr AS (
    SELECT Branch, WorkOrder,
           MIN(CreationDate) AS CreationDate,
           MAX(StatusDisplay) AS StatusDisplay,
           MAX(ROProgressStatus) AS ROProgressStatus,
           MAX(SalespersonCode) AS SalespersonCode,
           SUM(LaborSale) AS LaborToDate, SUM(PartSale) AS PartsToDate,
           SUM(MiscSale) AS MiscToDate, SUM(TotalSale) AS TotalToDate
    FROM rod GROUP BY Branch, WorkOrder
),
veh_ci AS (
    SELECT UPPER(TRIM(Registration)) AS RegKey, MIN(VIN) AS VIN, MIN(Make) AS Make
    FROM dbo.Silver_WkVehFl
    GROUP BY UPPER(TRIM(Registration))
    HAVING COUNT(*) = 1
),
wo AS (
    SELECT h.*, r.AccountNumber,
           CASE WHEN r.CustomerVehicleFlag = 'S' THEN 'Y' ELSE 'N' END AS IsStockUnit,
           TRIM(COALESCE(ve.VIN, vc.VIN)) AS MachinePIN
    FROM hdr h
    JOIN dbo.Silver_WkRoFile r ON r.Branch = h.Branch AND r.WorkOrder = h.WorkOrder
    LEFT JOIN dbo.Silver_WkVehFl ve ON ve.Registration = r.Registration
    LEFT JOIN veh_ci vc ON ve.Registration IS NULL AND vc.RegKey = UPPER(TRIM(r.Registration))
    WHERE COALESCE(TRIM(COALESCE(ve.VIN, vc.VIN)), '') <> ''
      AND (UPPER(TRIM(COALESCE(ve.Make, vc.Make))) LIKE '%DEER%'
           OR UPPER(TRIM(COALESCE(ve.Make, vc.Make))) IN ('JD', 'HAGIE'))
),
lines AS (
    SELECT rod.* FROM rod JOIN wo ON wo.Branch = rod.Branch AND wo.WorkOrder = rod.WorkOrder
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
               CONCAT(JobCode, ' (', JobType, '): L ', CAST(CAST(LaborSale AS decimal(12, 2)) AS varchar(20)),
                      ' + P ', CAST(CAST(PartSale AS decimal(12, 2)) AS varchar(20)),
                      ' = ', CAST(CAST(LaborSale + PartSale AS decimal(12, 2)) AS varchar(20)))
               AS varchar(max)), ' | ') WITHIN GROUP (ORDER BY JobCode, JobType, LaborSale + PartSale DESC) AS JobDetail
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
last_tech AS (
    SELECT Branch, WorkOrder, TechCode
    FROM (SELECT Branch, WorkOrder, TechCode,
                 ROW_NUMBER() OVER (PARTITION BY Branch, WorkOrder
                                    ORDER BY StartTime DESC, TechCode, SequenceID DESC, JobCode) AS rn
          FROM punches) x
    WHERE rn = 1
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
    CAST(wo.CreationDate AS date) AS OpenedDate,
    CASE wo.ROProgressStatus
        WHEN 'BI' THEN 'Booked In'            WHEN 'BY' THEN 'Booked in on Yard'
        WHEN 'CA' THEN 'Customer Advised'     WHEN 'CO' THEN 'Collection'
        WHEN 'CP' THEN 'Complete Priced'      WHEN 'CS' THEN 'Complete Service Manager'
        WHEN 'CW' THEN 'Customer Waiting'     WHEN 'DA' THEN 'Warranty JAD'
        WHEN 'DP' THEN 'In Delay - Part'      WHEN 'MI' THEN 'More Info Needed'
        WHEN 'SC' THEN 'Sundry WO - Complete' WHEN 'WC' THEN 'Warranty Complete'
        WHEN 'WF' THEN 'WIP Finished Not Invoiced'
        WHEN 'WJ' THEN 'Warranty JAD'         WHEN 'WO' THEN 'Worked'
        WHEN 'WP' THEN 'T-Complete'
        ELSE COALESCE(wo.ROProgressStatus, wo.StatusDisplay)
    END AS Status,
    wo.ROProgressStatus AS StatusCode,
    wo.AccountNumber AS CustomerAccount,
    c.DisplayName AS CustomerName,
    wo.MachinePIN,
    wo.IsStockUnit,
    COALESCE(sp.FullName, wo.SalespersonCode) AS ServiceWriter,
    COALESCE(lt_name.TechnicianDisplayName, lt.TechCode) AS LastTechnician,
    CAST(ROUND(wo.LaborToDate, 2) AS decimal(12, 2)) AS LaborToDate,
    CAST(ROUND(wo.PartsToDate, 2) AS decimal(12, 2)) AS PartsToDate,
    CAST(ROUND(wo.MiscToDate, 2) AS decimal(12, 2)) AS MiscToDate,
    CAST(ROUND(wo.TotalToDate, 2) AS decimal(12, 2)) AS TotalToDate,
    cd.JobCodes,
    ty.JobTypes,
    dt.JobDetail,
    COALESCE(ps.PunchCount, 0) AS PunchCount,
    CAST(ROUND(COALESCE(ps.LaborHoursPunched, 0), 2) AS decimal(10, 2)) AS LaborHoursPunched,
    CAST(ROUND(COALESCE(ps.LaborHoursSold, 0), 2) AS decimal(10, 2)) AS LaborHoursSold,
    CONVERT(varchar(16), ps.FirstPunch, 120) AS FirstPunch,
    CONVERT(varchar(16), ps.LastPunch, 120) AS LastPunch,
    tc.Technicians,
    pd.PunchDetail
FROM wo
LEFT JOIN codes cd ON cd.Branch = wo.Branch AND cd.WorkOrder = wo.WorkOrder
LEFT JOIN types ty ON ty.Branch = wo.Branch AND ty.WorkOrder = wo.WorkOrder
LEFT JOIN detail dt ON dt.Branch = wo.Branch AND dt.WorkOrder = wo.WorkOrder
LEFT JOIN punch_sum ps ON ps.Branch = wo.Branch AND ps.WorkOrder = wo.WorkOrder
LEFT JOIN last_tech lt ON lt.Branch = wo.Branch AND lt.WorkOrder = wo.WorkOrder
LEFT JOIN dbo.dim_Technician_Code_Names lt_name ON lt_name.TechnicianCode = lt.TechCode
LEFT JOIN techs tc ON tc.Branch = wo.Branch AND tc.WorkOrder = wo.WorkOrder
LEFT JOIN punch_detail pd ON pd.Branch = wo.Branch AND pd.WorkOrder = wo.WorkOrder
LEFT JOIN dbo.dim_Salesperson sp ON sp.SalespersonCode = wo.SalespersonCode
LEFT JOIN dbo.CustomerLookup c ON c.MatchKey = UPPER(TRIM(CAST(wo.AccountNumber AS varchar(20))))
ORDER BY wo.CreationDate, wo.Branch, wo.WorkOrder;
