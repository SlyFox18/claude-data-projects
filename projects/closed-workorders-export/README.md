# Closed Work Orders Export (for Casey's alert dashboard)

Daily CSV of closed service work orders, used by Casey's tractor-alert dashboard (a program on
his PC) to match alert tickets to work orders by WO number and put dollar figures on them.

| | |
|---|---|
| **Flow** | Power Automate "Closed Work Orders Export - Daily" (`76128aa1-c93c-48d1-b703-74371fe09774`, env `2cf47cce-…`), owner Brian, daily 07:30 Central (after the 06:15 DP refresh) |
| **Query** | [ClosedWorkOrders.sql](ClosedWorkOrders.sql), run with the SQL Server connector ("PA-DataLoad", Entra auth) against the **Prod** DP_Presentation SQL endpoint |
| **Output** | `wo-YYYY-MM-DD.csv` in SharePoint: South Plains Implement - Report Site → **Service Data Exports** library. A new dated file each day (Casey's request); his dashboard reads every file and keeps the newest row per WO |
| **Grain** | One row per closed WO, closed in the last 90 days, on a John Deere machine with a PIN, not a stock unit (~3,500 rows, ~1 MB) |
| **Consumer** | Casey: OneDrive-syncs the library to his PC; the dashboard refreshes at 5:35 PM |

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
