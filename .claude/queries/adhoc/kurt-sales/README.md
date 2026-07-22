# Kurt Sales - Parts & Service Activity (Ad Hoc)

**Requested by:** Kurt (Sales) via Brian, 2026-07-22
**Purpose:** Kurt supplied a territory account list and wanted to know which of
those customers bought parts and/or service in roughly the last 2 years, with
sales totals and a part-level detail view. One-off analysis, delivered as an
Excel workbook (not a Power BI report).

## Inputs

- `account-list.xlsx` - 1,080 accounts from Kurt (Account #, Name, City, State,
  Type). This is the source of truth.
- `account-list.csv` - same data, kept as a plain-text convenience copy. (An
  earlier CSV export had an encoding issue that silently dropped ~26 rows if
  parsed without `ignore_errors`; this copy was regenerated straight from the
  xlsx with proper UTF-8 encoding, so it's clean.)

## Method

`build_report.py` queries the `LH_Master_Data` lakehouse directly via DuckDB
over OneLake (`delta_scan`, Azure CLI credential chain) - no dataflow or
notebook needed for a one-off pull like this.

- **Window:** InvoiceDate / TransDatetime >= 2025-01-01 (through whenever the
  script is run)
- **Scope:** All branches company-wide (a customer can transact at more than
  one location)
- **Revenue only** - no cost/margin columns
- **Match key:** Kurt's Account # matched directly to `BillToAccount` on
  `Fact_Parts_Invoices` / `Fact_Service_Invoices` / `Fact_Parts_Detail`. Not
  routed through `dim_CustomerList` - verified during development that a
  direct match finds every account that has real activity (`dim_CustomerList`
  uses inner joins upstream and drops some accounts, but none with actual
  purchase history in the fact tables), so skipping it removes a dependency
  without losing coverage.
- **Part descriptions:** joined from `dim_Parts.Description`, not
  `Fact_Parts_Detail.Description` - that column holds the customer name by
  design (how the source system records the invoice line), already handled
  the same way in the Customer Anatomy report.
- **Only accounts with activity are included** - Kurt wants buyers, not the
  full list with zero rows.

## Output

`Kurt Sales - Parts and Service Activity (2025-01-01 to Present).xlsx`

- **Summary** tab: Account #, Name, City, State, Parts Sales $, Service Sales
  $, Total $, Last Parts Purchase Date, Last Service Date - one row per
  account with activity. Date columns are blank when that account has no
  activity of that type in the window (e.g. parts-only accounts have no
  Last Service Date).
- **Parts Detail** tab: Account #, Name, City, State, Part #, Description,
  Qty Sold, Parts Sales $ - one row per account x part number.

## Results (as of 2026-07-22 run)

- 333 of 1,080 accounts had parts and/or service activity since 2025-01-01
  (190 parts-only, 30 service-only, 112 both)
- ~$3.17M parts + ~$1.03M service = ~$4.19M total across those 333 accounts
- 18,146 customer x part detail rows

Re-run `build_report.py` from this folder any time for a refreshed pull
(requires `fab auth login` and `az login` to be active).
