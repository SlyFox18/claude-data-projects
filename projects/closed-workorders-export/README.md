# Closed Work Orders Export (for Casey's alert dashboard)

Daily CSV of closed service work orders, used by Casey's tractor-alert dashboard (a program on
his PC) to match alert tickets to work orders by WO number and put dollar figures on them.

| | |
|---|---|
| **Flow** | Power Automate "Closed Work Orders Export - Daily" (`76128aa1-c93c-48d1-b703-74371fe09774`, env `2cf47cce-…`), owner Brian, daily 07:30 Central (after the 06:15 DP refresh) |
| **Query** | [ClosedWorkOrders.sql](ClosedWorkOrders.sql), run with the SQL Server connector ("PA-DataLoad", Entra auth) against the **Prod** DP_Presentation SQL endpoint |
| **Output** | `wo-YYYY-MM-DD.csv` in SharePoint: South Plains Implement - Report Site → **Service Data Exports** library. A new dated file each day (Casey's request); his dashboard reads every file and keeps the newest row per WO |
| **Grain** | One row per closed WO, closed in the last 90 days (~5,000 rows, ~1.3 MB) |
| **Consumer** | Casey: OneDrive-syncs the library to his PC; the dashboard refreshes at 5:35 PM |

## Columns

- **IDs:** Branch, WorkOrder, OpenedDate, ClosedDate.
- **Customer:** CustomerAccount, CustomerName.
- **Machine:** MachinePIN, Make, Model, ModelYear, EquipRegistration, Hours.
- **Flags:** IsStockUnit, IsFieldService, PaymentMethod.
- **Jobs:** JobCount, JobCodes, JobTypes, WorkCategories, AnyMachineDown.
- **Dollars:**
  - LaborInvoiced, PartsInvoiced, MiscInvoiced (= SubletInvoiced + OtherChargesInvoiced), WorkOrderTotal.
  - By pay type: CustomerPayTotal, WarrantyTotal, InternalTotal, OtherPayTypeTotal.
  - Cost: LaborCost, PartsCost.
- **Other:** InvoiceNumbers, ExtractedAtUtc.

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
