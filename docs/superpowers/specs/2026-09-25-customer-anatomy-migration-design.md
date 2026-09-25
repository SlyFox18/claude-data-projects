# Customer Anatomy Report Migration — Design

**Date:** 2026-09-25
**Status:** Design approved by Brian. Awaiting spec review.
**Report:** `fabric-workspace-docs/workspaces/RP - Dev/Customer Anatomy.{Report,SemanticModel}` ("V2" dropped). It is the flagship, most-used report, and the last report still on LH_Master_Data. There is no `.pbip` yet.
**Target:** DP_Presentation (`DP - Presentation - Dev`)
**Precedent:** the Inspections migration (`2026-09-25-inspections-migration-design.md`, plan and catalog entry). The same single-writer Git-sync flow and tools (`tools/dp-migration/`) apply.

## Ground truth (verified 2026-09-25)

- **Model:** 13 LH_Master_Data tables, all plain reads with no filters, transforms or incremental-refresh policies. 200 measures, 25 relationships. dim_CustomerList has 5 calculated columns: CSM, Route Day, EngagementLevel, UniqueCustomerGroup, IsUniqueCustomer.
- **Column usage** (six methods): every column the report uses exists in DP. The columns missing from DP are all unused: `AccountClass`/`Account_Class`, `ContactClass`, the dim_BranchLocation extras, 53 dim_DateTable columns (including `IsRolling12Months`) and `dim_Parts.VendorCode`. **No DAX restores are needed.**
- **Sources:** every raw source (Invoice, InTrans, WkOthSub, WkRoFile, WkInvReg, VhStock, ArMaster_Customer) is a directly mirrored base table, not a SQL Anywhere view.
- **Registration:** all 10 Customer Anatomy producers are unregistered, so their data has been frozen since 09-14. None has the UTC pin or VACUUM. Five Silver inputs are unscheduled: Invoice, WkOthSub, WkRoFile, WkInvReg and VhStock.

## Decisions (Brian, 2026-09-25)

1. **Keep the Fact_Service_Detail fix.** Production joins wkothsub to Invoice on `InvoiceNumber` alone (`df_Fact_Service_Detail` lines 95–98), so every job row appears twice for 2023 onward. In 2025, production has 103,783 rows but only 52,979 jobs, for $111.0M against DP's $54.6M. DP joins on InvoiceNumber and Branch, giving one row per job. The fix affects 16 measures: Service Jobs, Service Labor/Parts Revenue/Cost/Margin, Service Job Total Revenue/Margin, Customer Pay Jobs/Revenue, Warranty Jobs/Revenue, Parts Cost Ex Sundry and the Service Invoice Header Card, with GP% indirect. **This is documented as a production bug fixed.**
2. **Include 2022.** Production's code filters to 2022 onward, but its raw inputs are pre-filtered to 2023 onward. As a result, production's 2022 has parts and service invoices but $0 equipment (Total Sales $131.8M) and almost no service-job detail. DP delivers the intended 2022: $382.6M equipment, $514.6M total. **This is documented as a production gap fixed.**
3. **Unique-customer lookup matches production's window: 2022 onward.** Production pattern-matches only 2022+ invoices; DP currently looks back to 1998, which adds 176 customers and moves 7 to a different group. The lookup is shared with Unique Parts Customers.
4. **Trim the Gold facts** to the used columns plus any column a downstream notebook reads, as for Inspections.

## Build chain

```
Silver (manual refresh): Invoice, InTrans, WkOthSub, WkRoFile, WkInvReg, VhStock, ArMasterCustomer
Shared dims (registered; run first): dim_CustomerList, dim_Parts, dim_DateTable, dim_BranchLocation
Wave 1: CustomerLookup (reads dim_CustomerList), EngagedAcres (CSV in Files), UniqueCustomersInvoiceLookup,
        Equipment_Sales, Parts_Detail, Service_Parts_Details
Wave 2: Parts_Invoices, Service_Invoices, Service_Detail        (read CustomerLookup)
Wave 3: CustomerPerformance   (aggregates Parts_Invoices, Service_Invoices, Equipment_Sales; reads dim_CustomerList)
```

All 10 notebooks are registered in `deploy/dp_backend_scope.json` with a `wave` field (daily cadence). Code reaches Dev only through this flow: push → `wait_ci.py` → `git_sync.py` → `run_item.py`. **No `fab import`.** New `.platform` files have no trailing newline. The chain runs manually because schedules are paused.

## Notebook changes

Every one of the 10 notebooks gets the same hygiene: `spark.sql.session.timeZone = UTC`, and after each overwrite, the retention check disabled followed by `VACUUM ... RETAIN 0 HOURS`.

| Notebook | Changes |
|---|---|
| Build_Gold_UniqueCustomersInvoiceLookup | Decision 3: filter Silver_Invoice to `InvoiceDate >= 2022-01-01` for the pattern matches, and Silver_InTrans to `TransDatetime >= 2022-01-01` for the Tornillo/Dell City branch-majority count. **The plan first reads production's `df_UniqueCustomer_Lookup` in full to confirm exactly which inputs are windowed.** The goal is exactly production's 542 customers and groups. |
| The 7 facts | Trim the output to the used columns plus downstream reads (Decision 4). The logic is otherwise unchanged. |
| CustomerLookup, EngagedAcres | Hygiene and registration only. |

**Keep-list rule:** the columns the report uses (from the audit) plus the columns CustomerPerformance reads from Parts_Invoices, Service_Invoices and Equipment_Sales. The plan recomputes each list from the notebooks and the model before trimming. It also fixes the audit's one known false-positive class: `sortByColumn` matches weren't table-qualified, so `Fact_CustomerPerformance.Month` showed as "used" only because dim_DateTable sorts by its own Month column.

**Unchanged by design:**
- The CustomerVehicleFlag Stock/Unknown customer-assignment logic (the proven fix that took Unknown from $19M to $2.3M).
- The InvoiceNumber + Branch join fix across the Customer Anatomy notebooks.
- EngagedAcres stays sourced from the CSV in Files.

## Report layer

Claude makes these edits only while the report is closed in Desktop, and confirms that before editing and again before pushing.

1. Create `workspaces/RP - Dev/Customer Anatomy.pbip` and commit it first.
2. Repoint all 13 partitions to `Sql.Database("…inkp24yoeqfedgiktcbh6mwaq4…", "DP_Presentation")`.
3. **Facts:** remove the columns trimmed in Gold from the TMDL.
4. **Dims:** add `Table.SelectColumns` and remove the other columns.
   - `dim_CustomerList` keeps 24 source columns, and its 5 calculated columns are untouched: CustomerKey, AccountNumber, CustomerNumber, DisplayName, CompanyName, TradeType, AccountStatus, Territory, CreditLimit, AccountBalance, CreditTerm, City, State, PrimaryPhone, BusinessPhone, MobilePhone, Aging30, Aging60, Aging90, IsKeyCustomer, CreditUtilization, FinancialRiskLevel, HasOverdueBalance, CustomerTier.
   - `dim_DateTable`: DateKey, Date, Year, Month, SortableMonthYear.
   - `dim_BranchLocation`: Branch, BranchID, LocationID.
   - `dim_Parts`: PartNumber, Description, Franchise.
   - `dim_EngagedAcres` and `lookup_UniqueCustomers_Invoice` are fully used and stay unchanged.
5. The edit script checks each table's exact expected removal count and confirms there are no `//` lines, no BOM, and 0 `LH_Master_Data` references. If a table fails, it writes nothing.

**Brian's publish steps** (lessons from Inspections):
1. Update RP - Dev from Git **before** opening Desktop.
2. Pull, open the `.pbip`, refresh, check the pages, and publish.
3. Claude checks that the DP_Presentation credentials are set, then triggers the **service refresh** and confirms it completes.
4. Commit from RP - Dev.

## Validation

**Parity before Desktop** (`tools/dp-migration/customer_anatomy_parity.py`): every table compared month by month against production for complete months through 2026-08. These differences are expected and named in advance:

| Area | Expected difference |
|---|---|
| Fact_Service_Detail | Production ≈ 2× DP for 2023+ (Decision 1); DP adds 2022 |
| Fact_Equipment_Sales | DP adds 2022; 2023–2025 identical to the dollar |
| Fact_CustomerPerformance | 2022 gains equipment; service is slightly different where Service_Invoices differs |
| Fact_Service_Invoices | Small differences from the reused-invoice-number fix, verified key by key |
| Fact_Parts_Detail | DP higher in Aug 2026 (production's InTrans gap: about 7,101 Aug-2026 transactions missing from production's `InTrans_Incremental`; see the Inspections entry in `report-migration-catalog.md`). The small 2022–2025 row differences must be explained key by key, not assumed. |
| lookup_UniqueCustomers_Invoice | Exactly production's customers and groups |
| Everything else | Identical for complete months |

**Anything unexplained stops the work and goes to Brian before any change is made.**

**After publish:**
- A DAX `executeQueries` check against the refreshed model: Total, Parts, Service and Equipment sales by year, and unique-customer counts, matched against the parity figures.
- 0 `LH_Master_Data` references left.
- A whole-project `git status` and a bookmark check.
- The catalog and memory updated.

**Before production (Brian):** a deeper page-by-page validation against production with timing controlled for. That gate applies to this report as well.

## Out of scope

- The DP pipeline redesign and bulk registration (see `dp-refresh-pipeline-assessment.md`)
- Production's InTrans gap (logged; to be checked after this migration)
- Widening the unique-customer window (a possible future change, agreed with the owners)
