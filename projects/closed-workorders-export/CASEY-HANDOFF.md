# Service Data Exports: file guide for the alert dashboard

Updated 2026-10-16. This describes the two CSV files that land in the **Service Data Exports**
SharePoint library, synced to
`C:\Users\cashurst\spitractor\South Plains Implement - Report Site - Service Data Exports`.

## What changed on 2026-10-16

1. **New file: `OpenWorkOrders.csv`**, in the same folder.
   - **Same-folder warning:** if the dashboard reads *every* CSV in the folder, it must now tell the two files apart by file name. Their columns differ, and an open work order should not be counted as closed.
2. **`ClosedWorkOrders.csv` now includes stock units.**
   - They're flagged in a new `IsStockUnit` column (Y/N).
   - 11 of Andrea's Yes tickets were on stock units (demo, rental or recently sold machines), so they no longer get filtered out. That's about 5,200 extra rows.
   - Filter on `IsStockUnit = 'N'` if you only want customer-owned machines.
3. **Both files now have time-punch columns** (listed below). In the closed file they're **appended after `JobDetail`**, so no existing column moved. Still, read columns by header name, not position.
4. **Closed file filter fixes from 2026-10-15** (already live):
   - A work order's unit is now matched to its machine even when capitals or spaces differ (`410r` vs `410R`).
   - Hagie sprayers (a John Deere brand, `1FA...` PINs) now count as John Deere.

## Common rules (both files)

- **Schedule:** both files are overwritten every morning at about 7:30 AM Central, after the 6:15 AM data refresh.
- **Row-count check:** a file is only replaced if the export returns a sensible number of rows. Otherwise yesterday's file stays.
- **Rows:**
  - One row per work order.
  - `WorkOrder` is unique company-wide in practice; match on it alone.
  - `MachinePIN` is never blank.
  - John Deere machines only.
- **Serial matching:** `MachinePIN` repeats across work orders, because one machine has many work orders. When matching by serial, expect several candidates and take the closest by date.
- **Encoding:** standard comma CSV with a header row. Text fields containing commas or quotes are quoted.
- **Alert job link:** a Service Center alert sent to DBS adds a job named `SC` + ticket number. Match it with the regex `^SC\d{6,}$`, not "starts with SC", because `SCH5026` and `SCH-5026` are unrelated codes. No SC number appears on more than one work order, but a work order can carry more than one SC job.
- **`JobDetail`:** every job on the work order, joined by ` | `, each as
  `JobCode (JobType): L <labor> + P <parts> = <labor+parts>`.
  - **JobType:** R = customer pay, W = warranty, I = internal, S = sundry/other.
  - **Misc not included:** job dollars are labor + parts only. Misc (sublet + other charges) is billed per invoice, not per job.
- **`PunchDetail`:** every technician time punch, in time order, joined by ` | `, each as
  `yyyy-mm-dd hh:mm-hh:mm, TechCode, JobCode, <hours>h`.
  - **Example:** `2026-10-12 07:56-10:05, T1505, Diag 2.0, 2.15h`.
  - **Times:** shop-local (Central), as Equip stores them.
  - **Commas:** any comma inside a job code is replaced with `;`, so splitting a punch on `, ` is safe.
  - **Alert-job hours:** to get the hours spent on the alert job, sum the punches whose JobCode is the SC job.

### Punch columns (both files)

| Column | Meaning |
|---|---|
| PunchCount | Number of time punches on the WO (0 = no labor clocked yet) |
| LaborHoursPunched | Actual clock hours, summed |
| LaborHoursSold | Hours sold/billed on those punches |
| FirstPunch / LastPunch | First clock-in and last clock-out, `yyyy-mm-dd hh:mm` (shop-local) |
| Technicians | Distinct techs who punched, as `T1505 - Name; ...` |
| PunchDetail | Every punch (format above) |

## ClosedWorkOrders.csv

- **Rows:** all John Deere work orders closed since 2024-08-01, about 41,000 rows (~25 MB).
- **Ordering:** newest close date first.

| Column | Meaning |
|---|---|
| WorkOrder, Branch | Work order number and store |
| OpenedDate, ClosedDate | yyyy-mm-dd |
| CustomerAccount, CustomerName | Bill-to account and name (blank name = account not found) |
| MachinePIN | Machine serial (17-char JD PIN for most units; older units have shorter serials) |
| LaborInvoiced, PartsInvoiced, MiscInvoiced | Invoiced dollars; Misc = sublet + other charges |
| WorkOrderTotal | Labor + parts + misc, before tax |
| CustomerPayTotal, WarrantyTotal | Split of WorkOrderTotal by pay type (internal/other make up the rest) |
| JobCodes, JobTypes | Distinct job codes / pay types on the WO, joined by `; ` |
| JobDetail | Per-job dollars (format above) |
| IsStockUnit | Y = SPI-owned stock unit at the time of the WO (new) |
| PunchCount ... PunchDetail | Time punches (new; see table above) |

## OpenWorkOrders.csv

- **Rows:** all currently open John Deere work orders, about 800–900 rows. "Open" uses the same definition as the Open Work Orders report: not invoiced, quotes excluded.
- **Finished but not invoiced:** these rows are included on purpose. `Status` says which ones they are.
- **Freshness:**
  - Open/closed status and dollars-to-date are as of the 6:15 AM refresh.
  - Machine, jobs and punches are as of midnight.
  - So a work order opened early this morning may be missing until tomorrow.
- **Ordering:** oldest first.

| Column | Meaning |
|---|---|
| WorkOrder, Branch | Work order number and store |
| OpenedDate | yyyy-mm-dd |
| Status, StatusCode | DBS progress status, e.g. `Booked In` (BI), `T-Complete` (WP), `Complete Priced` (CP), `In Delay - Part` (DP), `Warranty Complete` (WC), `WIP Finished Not Invoiced` (WF) |
| CustomerAccount, CustomerName | As in the closed file |
| MachinePIN | As in the closed file |
| IsStockUnit | Y = stock unit |
| ServiceWriter | Service writer's name (falls back to their code) |
| LastTechnician | Tech on the most recent punch, as `T1505 - Name` (blank = no labor yet) |
| LaborToDate, PartsToDate, MiscToDate, TotalToDate | Dollars on the WO so far (not invoiced yet, so they can still change) |
| JobCodes, JobTypes, JobDetail | Same formats as the closed file, using to-date dollars |
| PunchCount ... PunchDetail | Time punches (same as the closed file) |

**Not available:** a promised/due date. DBS's "expected" date is just the creation time, and the estimated start/finish fields are empty.

**Using the two files together:**
- **Alert already being worked:** a ticket whose SC job, or whose machine within your 30-day window, appears in `OpenWorkOrders.csv` is already in the shop.
- **Open to closed:** when that work order closes, it drops out of the open file and appears in the closed file with final invoiced dollars, usually the next morning.
