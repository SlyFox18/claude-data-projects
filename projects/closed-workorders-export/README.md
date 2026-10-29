# Closed / Open Work Orders Exports (for Casey's alert dashboard)

> **2026-10-27: all parts sales** (Casey's parts-vs-inspections analysis). Everything lands in `Service Data Exports/Parts/`; the field guide is [CASEY-HANDOFF.md](CASEY-HANDOFF.md) → "Parts sales files".
> - **Frozen years:** `PartsSales_2024.csv` (Aug–Dec 2024) and `PartsSales_2025.csv` were built locally by [build_parts_sales_history.py](build_parts_sales_history.py), a DuckDB port of the line query. Brian uploads them to SharePoint by hand. Never rebuild them unless the columns change.
> - **Live files:** flow "Parts Sales Export - Biweekly" (`2cd9fdb6-d469-4a69-9635-187d44fffc7e`) runs every other Monday at 08:00 from 2026-11-02. It writes:
>   - `PartsSales_yyyy-MM.csv` for every month of the current year, from [PartsSalesLines.sql](PartsSalesLines.sql), one query per month. In January it starts from last January, so December gets finished.
>   - `PartsSalesSummary.csv` ([PartsSalesSummary.sql](PartsSalesSummary.sql)).
>   - `PartsCustomers.csv` ([PartsCustomers.sql](PartsCustomers.sql)).
>
>   Floors: 20,000 lines for a finished month, more than 0 for the current month, 100,000 summary rows, 10,000 customers. A file below its floor isn't written, and the run ends Failed with a list of what was skipped.
> - **Why monthly files:** a whole year as one CSV string is ~70+ MB, against Power Automate's 100 MB message limit and the 2-minute query limit. A month is 5–8 MB and takes about 5 s.
> - **Matching:** the header is the Silver_Invoice row with the same number, type I/C/S and the same date (exactly one per line). Invoice numbers alone repeat, because type E records reuse them. The channel comes from the header's ModuleType (W service, I counter, S equipment). The work order comes from WkInvReg by invoice number.
> - **Flow copy of the SQL:** the queries in the flow have their header comments stripped. The `.sql` files are the documented source. To change a query, edit the file and regenerate the flow definition.
> - **Port check (2026-10-27):** the DuckDB port matched the flow's Jan–May 2026 files line for line (282k lines), apart from two things:
>   - **UnitPrice rounding:** DuckDB divides decimals in floating point. Fixed by rounding in integer cents.
>   - **SQL endpoint ghost rows:** 0–2 lines a month. For a few recently renumbered gauge parts (`PG2-1/2-300LFR` / `PG212-300LFR`), the endpoint returned both the old and new part-number rows, plus old part-master descriptions. `delta_scan` showed only the current rows. Refreshing the SQL endpoint metadata should clear it (TROUBLESHOOTING.md, "orphaned Parquet files" row).

> **2026-10-27: parts file.**
> - **What it is:** `Parts/ClosedWorkOrderParts.csv` ([ClosedWorkOrderParts.sql](ClosedWorkOrderParts.sql)), one row per part line on the closed file's work orders (~358k rows, 31 MB).
> - **Flow:** "Closed Work Order Parts Export - Biweekly" (`d356cd5e-7799-4e8f-9f52-0bf91c6b36ff`), every other Monday at 07:45 starting 2026-11-02. It writes only if there are at least 300,000 lines.
> - **Subfolder on purpose:** the file sits in a `Parts` subfolder so Casey's dashboard, which reads every CSV at the top level, doesn't pick it up.
> - **CSV built in SQL:** the query builds the CSV text itself and returns one row (`LineCount`, `Csv`). As JSON rows it would be ~70 MB, close to Power Automate's 100 MB message limit. The query took 37–60 s in testing, inside the connector's 2-minute limit, but it grows with history.
> - **Matching:**
>   - Part lines are matched on invoice number alone (WkInvReg → InTrans.RONumber). Some shops draw stock from another store (91 → 8, 6 → 92), so a branch match would drop them.
>   - Lines must be dated on or after the work order's open date, as a guard against reused invoice numbers.
>   - All 41,070 work orders tie to PartsInvoiced to the penny.
> - **Description:** comes from dim_Parts, because InTrans.Description is a transaction note.

> **2026-10-16:**
> - **Open file:** added `OpenWorkOrders.csv` ([OpenWorkOrders.sql](OpenWorkOrders.sql)), via flow "Open Work Orders Export - Daily" (`f3077a5b-65a3-4624-b3f0-9366fda25c54`). It runs daily at 07:30 and writes only if there are at least 300 rows (~880 open JD WOs).
> - **Closed file:** now includes stock units (`IsStockUnit`).
> - **Both files:** gained time-punch columns from Silver_TechnicianPunchedDetail, and its hours match WkMechWk within 0.2%. Closed is now ~41k rows / 25 MB.
> - **Field guide:** [CASEY-HANDOFF.md](CASEY-HANDOFF.md) is the guide for Casey's side. Update it whenever columns change.
> - **Open file sources:** "open" = RepairOrderDetail.StatusDisplay <> 'Invoiced', quotes excluded (same as the Open Work Orders report). Job $ and status come from RepairOrderDetail (06:15 ODBC pull); machine, jobs and punches come from midnight Bronze.

Daily CSV of closed service work orders, used by Casey's tractor-alert dashboard (a program on
his PC) to match alert tickets to work orders by WO number and put dollar figures on them.

| | |
|---|---|
| **Flow** | Power Automate "Closed Work Orders Export - Daily" (`76128aa1-c93c-48d1-b703-74371fe09774`, env `2cf47cce-…`), owner Brian, daily 07:30 Central (after the 06:15 DP refresh) |
| **Query** | [ClosedWorkOrders.sql](ClosedWorkOrders.sql), run with the SQL Server connector ("PA-DataLoad", Entra auth) against the **Prod** DP_Presentation SQL endpoint |
| **Output** | `ClosedWorkOrders.csv` in SharePoint: South Plains Implement - Report Site → **Service Data Exports** library, overwritten daily. SharePoint version history keeps earlier copies |
| **Safety check** | The file is written only if the query returns at least 30,000 rows. Otherwise the run fails (failure email to Brian) and yesterday's file stays. Raise the threshold over time if needed; the count only grows (35k in Oct 2026) |
| **Grain** | One row per WO closed since 2024-08-01 (Andrea's alert history starts Aug 2024), on a John Deere machine with a PIN, not a stock unit (~35k rows, ~10 MB) |
| **Consumer** | Casey's dashboard reads every CSV in the synced folder `C:\Users\cashurst\spitractor\South Plains Implement - Report Site - Service Data Exports` at 5:35 PM. **Don't rename the file, folder or columns without telling Casey** |

## Columns

Trimmed to Casey's keep-list on 2026-10-15.

- **IDs and dates:** WorkOrder, Branch, OpenedDate, ClosedDate.
- **Customer:** CustomerAccount, CustomerName.
- **Machine:** MachinePIN.
- **Dollars:**
  - LaborInvoiced, PartsInvoiced, MiscInvoiced (other + sublet), WorkOrderTotal.
  - By pay type: CustomerPayTotal, WarrantyTotal.
- **Jobs:**
  - JobCodes, JobTypes.
  - JobDetail: every job as `JobCode (JobType): L labor + P parts = total`, joined by ` | `. Casey's side computes the alert-segment total from it. Job dollars are labor + parts only, because misc is billed per invoice, not per job.

**How Casey links tickets to WOs (2026-10-15):** when a Service Center alert is sent to DBS, a job named `SC` + ticket number (e.g. `SC1595680`) is added to the WO. That job's dollars in JobDetail are the "alert segment $". Facts checked 2026-10-15:
- **Format:** always `^SC\d{6,}$`. Don't loosen it to "starts with SC", because `SCH5026` / `SCH-5026` are unrelated codes.
- **Volume:** only 52 SC jobs since 2024-08, the first in Oct 2025.
- **Uniqueness:** no SC number appears on more than one WO, but 2 WOs carry two SC jobs.
- **Fallbacks:** WO number, then serial within 30 days.

**Row filters (Casey):**
- John Deere machines only. Work orders have no 'D' franchise (their franchises are AG/CP/OT/CW), so the filter is the machine Make, matched loosely as `%DEER%` or `JD`, since Make is free text.
- PIN present.
- Not a stock unit.

## Data notes (verified 2026-10-15)

- **WO number uniqueness:** effectively unique company-wide (4 reuses in 720k WOs of history; none in any 90-day window), so matching on WO number alone is safe.
- **Machine identity:**
  - `MachinePIN` comes from Silver_WkVehFl via the WO's REG; REG is unique there.
  - 89% of WOs have one, and ~55% are full 17-character JD PINs; older and non-Deere units carry shorter serials.
- **Dollar totals:**
  - Taken from the invoice register (Silver_WkInvReg).
  - InvoiceTotal = labor + parts + other + sublet, with no tax.
  - Labor and parts tie to the WkOthSub job lines to the penny.
- **Warranty:** `ClaimNumber` is blank in Silver, so warranty comes from the pay type (ROType W). The same blank column means `Fact_Service_Detail.IsWarrantyJob` (Customer Anatomy) is always FALSE. That is a known gap, not fixed here.

## Changing it

1. Edit the SQL here.
2. Paste it into the flow's "Execute SQL query" action.
3. Run the flow once and check the file.

The query runs in about 4 s, well inside the connector's 2-minute limit.
