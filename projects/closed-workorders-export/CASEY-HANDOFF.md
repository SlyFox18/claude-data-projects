# Service Data Exports: file guide for the alert dashboard

Updated 2026-10-27. This describes the CSV files that land in the **Service Data Exports**
SharePoint library, synced to
`C:\Users\cashurst\spitractor\South Plains Implement - Report Site - Service Data Exports`.

## What changed on 2026-10-27

1. **New file: `Parts\ClosedWorkOrderParts.csv`**, holding the part lines for the work orders in `ClosedWorkOrders.csv`. It's in a **`Parts` subfolder**, so it stays out of the top-level folder the dashboard reads. If the dashboard scans subfolders too, have it skip this one (or match it by name), because it's a different shape from the work-order files. Details are in [ClosedWorkOrderParts.csv](#closedworkorderpartscsv) below.
2. **New: all parts sales**, in the same `Parts` subfolder. This is every parts sale, at the counter, on work orders and on equipment deals, for every customer and brand, from Aug 1, 2024. It's for comparing parts buying against inspections. Details are in [Parts sales files](#parts-sales-files) below.

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

**Using the open and closed files together:**
- **Alert already being worked:** a ticket whose SC job, or whose machine within your 30-day window, appears in `OpenWorkOrders.csv` is already in the shop.
- **Open to closed:** when that work order closes, it drops out of the open file and appears in the closed file with final invoiced dollars, usually the next morning.

## ClosedWorkOrderParts.csv

- **Location:** `...\Service Data Exports\Parts\ClosedWorkOrderParts.csv`.
- **Rows:** one row per part line (a sale, or a credit/return) on every work order in `ClosedWorkOrders.csv`. That's the same work orders: closed since 2024-08-01, John Deere, PIN present, stock units included. About 358,000 rows (~31 MB).
- **Schedule:** overwritten **every other Monday at about 7:45 AM Central**, starting 2026-11-02. A first copy was written 2026-10-27. Because it's refreshed less often than the daily closed file, work orders closed since the last Monday run won't have parts yet.
- **Join:** join to `ClosedWorkOrders.csv` on `WorkOrder`. Summing `LineTotal` for a work order gives exactly its `PartsInvoiced` (checked to the penny on all 41,070 work orders, 2026-10-27).
- **Ordering:** newest close date first, then by work order and the time each part was posted.

| Column | Meaning |
|---|---|
| WorkOrder, Branch | Work order number and the work order's store (same as the closed file) |
| ClosedDate | yyyy-mm-dd, the work order's close date |
| PartBranch | Store whose stock the part came from. It's usually the same as Branch, but some shops draw from another store (e.g. branch 91 work orders use branch 8 parts) |
| JobCode | Job on the work order the part was charged to. Parts on the alert job have the `SC<ticket#>` code, so filtering on it gives the alert job's parts |
| PartNumber, Description | Part number and its part-master description |
| Quantity | Quantity; negative on a return/credit |
| UnitPrice | LineTotal ÷ Quantity, rounded to cents (blank when Quantity is 0) |
| LineTotal | Sale dollars for the line, before tax; negative on a credit |

**Not just parts:** a few lines are charges billed through the parts system: freight (`3750`), mileage/service-vehicle and battery-core fees, and discounts (`LEGACY`, `*10PROMO`, `ADV`, `4900`, negative). They're kept because they're part of `PartsInvoiced`. Filter them out by PartNumber if you only want physical parts.

## Parts sales files

Every parts sale and credit since **2024-08-01**: all customers, all brands, all channels (parts counter, work orders, equipment deals). It's built for questions like: did a customer buy fewer parts in a year they skipped an inspection, do inspections drive parts sales, and which customers buy parts somewhere other than where they get service. All files are in `...\Service Data Exports\Parts\`.

| File | What it is | Refreshed |
|---|---|---|
| `PartsSales_2024.csv` | Line detail, Aug 1 – Dec 31, 2024 (~280k lines, 36 MB) | Never (frozen) |
| `PartsSales_2025.csv` | Line detail, all of 2025 (~701k lines, 90 MB) | Never (frozen) |
| `PartsSales_2026-01.csv` … `PartsSales_2026-MM.csv` | Line detail, one file per month of the current year (35k–65k lines, 5–8 MB each) | Every other Monday, ~8:00 AM (all months of the year are rewritten; a new month's file appears automatically) |
| `PartsSalesSummary.csv` | Monthly totals per customer, store, channel and sale type, Aug 2024 to date (~127k rows, 16 MB) | Every other Monday, ~8:00 AM |
| `PartsCustomers.csv` | One row per account: name, kind, city/state/ZIP, home store, totals (~18k rows) | Every other Monday, ~8:00 AM |

**Reading them:**
- **Line files:** read all `PartsSales_*.csv` files together as one table. They have identical columns and never overlap. In January the flow also finishes off the previous December, and that year's monthly files stay in place.
- **Excel:** every file fits under Excel's 1,048,576-row limit, but the 2025 file is large. A script or Power Query is the better tool.
- **Totals:** dollars are sale value before tax. Credits and returns are negative, so summing `LineTotal` gives net sales.
- **Joins:**
  - Line files and the summary → `PartsCustomers.csv` on `CustomerAccount`, or on `WOCustomerAccount` (see below).
  - Line files → `ClosedWorkOrders.csv` on `WorkOrder`, for work-order part lines.
  - Customers ↔ `ClosedWorkOrders.csv` on `CustomerAccount`. That's the same Equip account number, which is how to tie a customer's inspection work orders to their parts buying.

### PartsSales_* (line detail)

| Column | Meaning |
|---|---|
| TransDate | yyyy-mm-dd the part was sold or credited |
| Branch, StoreName | Store that made the sale (e.g. `16`, `Morton`) |
| InvoiceNumber | Invoice the line is on (several lines per invoice) |
| Channel | `Counter` (parts counter), `Service` (on a work order), `Equipment` (on an equipment deal) |
| WorkOrder | Work order number, on Service lines only |
| CustomerAccount | Account billed for the line |
| AccountKind | `Customer`, or a generic account: `Cash` (walk-in), `Web` (online orders, ECOMMERCE01), `Warranty` (John Deere warranty claims), `Internal` (the dealership billing itself), `Sundry` |
| InvoiceName | Name typed on the invoice. **Only filled for Cash/Web/Sundry accounts**, where it's the only clue to who the buyer was (Sundry invoices carry no name) |
| WOCustomerAccount | On Service lines: the work order's own customer. Warranty and internal parts are billed to `WARRANTIES-<store>` / internal accounts, so use this column to credit them to the farm whose machine it was |
| SaleType | Equip's trade type code: `R` retail, `W` warranty, `I` internal, plus `C`, `T`, `D` (other Equip pricing classes; ask Brian if they matter) |
| JobCode | Work-order job the part was charged to (Service lines) |
| PartNumber, Description | Part number and part-master description |
| Franchise | Brand/franchise code: `D` = John Deere parts; others are other brands; `ZP` = fees, freight and discounts |
| Quantity, UnitPrice, LineTotal | Quantity (negative on credits), LineTotal ÷ Quantity rounded to cents, and the line's sale dollars |

### PartsSalesSummary.csv

One row per **Month + CustomerAccount + InvoiceName + Branch + Channel + SaleType**. `InvoiceName` is filled (upper-cased) only for Cash/Web/Sundry accounts, so walk-in buyers are split by the name on their invoices.

| Column | Meaning |
|---|---|
| Month | yyyy-mm |
| CustomerAccount, CustomerName, AccountKind, InvoiceName | As in the line files |
| CustomerCity, CustomerState, CustomerZip | Customer's address from their account (blank for ~10% of sales, mostly generic and newer accounts) |
| HomeBranch | The customer's **home store** in Equip |
| Branch, StoreName | Store that made the sale. Compare with HomeBranch to find customers who buy away from home (e.g. served in Lubbock, buying in Abernathy) |
| Channel, SaleType | As in the line files |
| Invoices, Lines | Distinct invoices and lines |
| NetSales | Sales minus credits |
| JDPartsSales, OtherSales | NetSales split into John Deere parts (franchise D) and everything else |

**Not attributed:** the summary groups warranty parts under the `WARRANTIES-<store>` accounts, not the farm. Use the line files' `WOCustomerAccount` if that matters.

### PartsCustomers.csv

| Column | Meaning |
|---|---|
| CustomerAccount, CustomerName, AccountKind | Account, name, kind (same rules as above) |
| CustomerCity, CustomerState, CustomerZip | From the account's address (blank where Equip has none) |
| HomeBranch, HomeStore | Customer's home store number and name |
| FirstPartsSale, LastPartsSale | First and last parts purchase billed to the account since 2024-08-01 |
| PartsInvoices, PartsNetSales | Number of parts invoices and net parts sales billed to the account since 2024-08-01 |

Accounts that only show up as a work order's customer (never billed for parts themselves) are included with the purchase columns blank.

