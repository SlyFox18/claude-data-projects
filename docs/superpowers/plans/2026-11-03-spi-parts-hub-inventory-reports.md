# SPI Parts Hub: Inventory reports, MLPF Gaps first (Plan L, app 0.12.0)

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development, one task at a time with a
> review after each (Brian's standing choice). Steps use checkbox (`- [ ]`) syntax.

> **Progress:** plan written 2026-11-03 (Claude, for Brian). Spec approved 2026-11-03.
> - **L4 done 2026-11-03** (data-projects `16e6ed85`; publish tests 338 pass): contract 6, `build_jd` (all JD
>   branches, no D6; twins kept; 4 MB check), `_meta.jdBranches`, `counts.jdParts`; publish refuses an older Gold
>   without Fact_CorpParts_JD and checks its BuiltAtUtc like Fact_NonJD_Reorder's. Local `--out` build on Dev: 72
>   files, 27 `jd_` files, largest `jd_2` 482 KB, jdParts 254,213. JD branches include tiny ones (5: 2 rows, 97: 1,
>   15I, 4B, 4I, 4S, 8I). **Don't publish v6 until L12.**
> - **L2b (Silver franchise-case fix) approved by Brian 2026-11-03:** in progress.
> - **L3 + L3b analysis done 2026-11-03** (data-projects `f2a809a9`; 31 new tests, nonjd tests still pass):
>   `corp_parts_check.py --tier dev` **PASS**, 0 differences (254,213 rows, 752,100 demands; MLPF 10,048 at run 2's
>   as-of). **Excel comparison** (Brian's 09:41 refresh, 10,065 rows) against Prod Silver (`--tier prod --groups-tier
>   dev --as-of '2026-11-03 09:40:30'`; Prod InTrans ends 11-02 18:42): 10,046 match on every column; 19 only in
>   Excel, 13 only in ours, 1 value difference. **Every row is explained, and none points to the Gold rule:** 6 = a
>   **Silver bug** (below); 11 at branch 4 = stock received against back orders and invoiced this morning; 7 = sold or
>   transferred 11-02, then reordered before 09:41; 9 = live Equip on hand / on order moved today with no InTrans
>   yet (unverified); 0 twins; 0 from the workbook's franchise-less join. The workbook's GETDATE() was 09:40:00–09:40:50
>   (two invoices on the 10-27 edge). **Silver bug:** `Build_Silver_PartInformation` joins InManuf / InManuf_Locale on
>   `FRANCHISE == FR` (case-sensitive in Spark; Equip isn't), so InMaster rows stored with franchise `'d'` (321 in
>   Prod) get the defaults: PackageQty '0', Returnable '', CommodityCode '', weight 0. Files in the scratchpad `mlpf/`.
> - **L2 done 2026-11-03** (fabric-workspace-docs `6e7e7dc4`; dag_check OK, hygiene 0, 364 tests): Part 5 of
>   Build_Gold_NonJD_Reorder writes `Fact_CorpParts_JD` (guards: unique key, unique commodity codes, no stocking-rule
>   fan-out). Bounds passed as text cast in the UTC session (Silver keeps Equip's Central wall clock); DemandAsOf =
>   BuiltAtUtc as Central. Dev runs `23af3a3b` and `c69314c3` Completed: 254,213 rows at 27 branches both times;
>   CorpDemands 752,132 → 752,100 = exactly the 32 invoices in the 17-minute slice the 18-month start moved over.
>   MLPF Gaps (L-D19) **10,049** on Dev (Dev InTrans ends 2026-10-26). Fact_NonJD_* fingerprints unchanged.
>   CommodityGroup "Other" on 67% of rows (19k blank codes; the rest codes not in Ben's 244-code CSV: same as the
>   workbook; raise with Ben). Source never NULL among MLPF candidates. **Don't start Pipeline_DP_Refresh with
>   `run_item.py`** (typed params → "Unable to convert mode to string", Dev run `51cb9afb`); send plain strings.
>   Brian refreshed MLPF Gaps.xlsx at 09:41 (10,065 rows) for the Excel comparison.
> - **L1 done 2026-11-03** (fabric-workspace-docs `278c4fbe`; dag_check OK, 364 tests): `df_CommodityCodeGroups_Raw`
>   (DP - Staging - Dev, item `4497e578…`) → DP_Staging `CommodityCodeGroups`, daily, no de-dup (Gold checks codes are
>   unique); DP_Presentation shortcut via Git sync (the usual DP_Presentation "changed on both sides" conflict, resolved
>   by Accept incoming; workspace-only changes untouched). Direct refresh and Dev pipeline `b81647f7` (items mode)
>   Completed. DuckDB: 244 codes, 17 groups, unique, trimmed, identical to the reference CSV (staging and shortcut).
>   Prod: run the dataflow, then `sync_shortcuts.py --apply` (dry run: would create CommodityCodeGroups).
> - **L0 done 2026-11-03:** NonJD_InventoryReports `bc73e59b-29c5-43d9-93ed-92849e0986bc` created by Brian and checked
>   (Description, Conditions plain multi-line; Active default Yes; Archived default No). `.env` line
>   `VITE_LIST_INVENTORY_REPORTS` given to Brian.

**Goal:** a live **Inventory** area: the Corp Parts reports over the active JD (franchise D) parts, starting with a
built-in **MLPF Gaps** that matches the workbook row for row, plus **Copy as my own** (editable saved copies).

**Architecture:** a new SharePoint dataflow brings Ben's CommodityCodeGroups.csv into DP_Staging; the Gold notebook
`Build_Gold_NonJD_Reorder` adds `Fact_CorpParts_JD` (one row per branch + JD part, with the Corp demand count); a
DuckDB reference check recomputes it and writes the MLPF list for the Excel comparison; the publish adds per-branch
`jd_<branch>.json.gz` files in contract v6. The app makes the Cleanup checks engine work over any field catalogue,
adds a JD catalogue with **starts with / doesn't start with**, a saved-reports list and three Inventory pages.

**Tech stack:** Fabric Dataflow Gen2 and notebook (PySpark) in fabric-workspace-docs; DuckDB reference check and the
Python publish in data-projects; nonjd-order-app (React 19, TypeScript, Vite, Tailwind 4, react-router 7, Vitest).

**Spec:** `docs/superpowers/specs/2026-11-03-spi-parts-hub-inventory-reports-design.md`.

---

## What Prod shows today (2026-11-03, Silver_PartInformation, franchise D)

- 893,688 JD rows. **Active** (on hand ≠ 0, on order > 0 or 24-month sales ≠ 0): **230,464 rows at 27 branches**
  (largest: 11 with 20,359, 1 with 19,858, 4 with 17,225).
- The largest branch as JSON is 6.6 MB, **465 KB gzipped**: far under the 4 MB upload limit, so no file splitting.
- `Returnable` (the workbook's Return Indicator): R 601,218 · N 246,212 · blank 45,196 · D 1,221.
- `PackageQty` is **text** (`'1.00'`, `'2.00'`, `'0'`, …): Gold casts it to a number.
- `SuperTo` is never NULL; 80,154 rows hold a part number.
- **2** trailing-space twin keys (Branch + trimmed PartNumber appears twice).
- InTrans `REF_NO` is Silver's `RONumber`; `ORIGINAL_INVOICE_NO` is `OriginalInvoiceNo`.
- `dim_CommodityCode` has no group (its planned CommodityGroup column was never built), so the group needs its own
  source (L-D9).

## How we run this plan

- Same as Plans I–K: one task at a time, a review after each, fixes, push. Stage named files only; `.env*` never read
  or committed. App tests in two halves (`npx vitest run --exclude "src/pages/__tests__/**"`, then
  `npx vitest run src/pages/__tests__`), `npm run lint`, `npx tsc -b`. `npm run build` only in L11. Commits end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Fabric: work on `dev` in fabric-workspace-docs; `python deploy/dag_check.py`, `python deploy/hygiene_audit.py`,
  `python -m pytest deploy -q`; git sync Dev; never `fab import`. Claude may run Dev pipelines; Brian merges and runs
  the deploys and Prod pipelines.
- **Order matters:** app 0.12.0 (reads v5 and v6) on Fedora before the Gateway PC publishes v6; Prod Gold with
  `Fact_CorpParts_JD` before the Gateway PC pulls the v6 publish code.
- **The Excel gate:** Ben doesn't see Inventory until the MLPF Gaps comparison (L3b on Dev, again in L12 on Prod) has
  every difference explained.

## Decisions made in this plan (Brian can overrule any of them)

| # | Decision | Why |
|---|---|---|
| L-D9 | **Commodity group from a new dataflow** `df_CommodityCodeGroups_Raw` (DP - Staging, SharePoint connector, the existing tenant-wide SharePoint connection) reading `CommodityCodeGroups.csv` from the Report Site into DP_Staging table `CommodityCodeGroups` (CommodityCode, CommodityGroup), daily in the DP run; a DP_Presentation shortcut; Gold maps unmapped codes to **"Other"** as the workbook does. | Ben keeps editing one CSV; DP's standard way in for a SharePoint file (NEW-DATA-SOURCE). |
| L-D10 | **Corp demand window from the build time in Central:** invoices with `TransDatetime` in [now − 18 months, now − 7 days], credits in [now − 18 months, now] (as the workbook: no 7-day cutoff on credits). `now` = the build's UTC time as Central wall clock (Equip stores Central wall clock). Gold keeps it as `DemandAsOf`. | The workbook uses GETDATE() on the Equip server (Central). The reference check reuses `DemandAsOf`, so it compares like with like. |
| L-D11 | **Invoice grouping exactly as the workbook:** per Branch + trimmed PartNumber + invoice key, where the key is trimmed `RONumber` for TYPE 'I' and trimmed `OriginalInvoiceNo` for TYPE 'C'; Branch and Franchise trimmed, upper-case; only InTrans franchise D. An invoice counts when its net qty > 0 and it has an 'I' line in the window. | The built-in must match Excel; the workbook's own grouping already counts one invoice once. |
| L-D12 | **Grain = Silver's** (Branch + Franchise + PartNumber as stored), franchise D only; the two trailing-space twins stay two rows, each with the demand of the trimmed part number. The publish trims `partNumber` and doesn't require it unique; the app keys rows by position. | No arbitrary survivor (notebook rules). The Excel comparison will show the twins (workbook: one row). |
| L-D13 | **Gold columns:** Branch, Franchise, PartNumber, Description, Cost, OnHand, OnOrder, PackageQty (decimal; non-numeric text → NULL), ReturnIndicator (`Returnable`, trimmed), Source, SLC, SuperTo, CommodityCode, CommodityGroup, DealerGroupCode, MinimumQty, MaximumQty (Silver_PartStockingRules; no row → NULL), Sales12, SalesPrev12 (`Current12MoSales`, `Previous12MoSales`), CorpDemands (int, 0 when none), DemandAsOf, BuiltAtUtc. Text as stored (trimmed in the publish). | What MLPF needs, plus min/max and sales for the next reports (Corporate Stocking). |
| L-D14 | **Active** = OnHand ≠ 0 or OnOrder > 0 or Sales12 + SalesPrev12 ≠ 0 or CorpDemands > 0. | Spec section 1. |
| L-D15 | **Contract v6:** `jd_<branch>.json.gz` per branch with JD rows; `_meta.json` gains `jdBranches: MetaBranch[]` (every JD branch with rows, **no** D6 exclusions, names from dim_BranchLocation) and `counts.jdParts`. Older apps ignore both. The app accepts 3–6; on v3–v5 Inventory says "JD parts aren't in today's data yet". | Additive; L-D5. |
| L-D16 | **One engine, many catalogues:** `src/cleanup/conditions.ts` works over a `Catalogue` (fields, comparisons, in-data check). Cleanup keeps its catalogue; Inventory gets a JD one. Stored JSON is unchanged. | Spec: "the Cleanup checks engine". |
| L-D17 | **starts with / doesn't start with** (`startsWith`, `notStartsWith`, list values, trimmed, case-insensitive) for **every text field in both catalogues**. Blank never starts with anything (so "doesn't start with" matches a blank, as "is not" does). | MLPF needs it; harmless and useful in Cleanup (SLC families). |
| L-D18 | **JD fields** (label · type): Branch · text; Part number · text; Corp demands · number; On hand · number; On order · number; Cost · money; Package qty · number (blank = not a number); Return indicator · text; Source · text; SLC · text; Super To · text; Commodity code · text; Commodity group · text; Dealer group · text ("(none)" = blank); Equip minimum · number (blank); Equip maximum · number (blank); Sales 12 months · number; Sales 24 months · number. | Spec section 2. |
| L-D19 | **Built-in MLPF Gaps** = Branch is not 12 · Corp demands = 2 · On hand < 1 · On order = 0 · Package qty = 1 · Return indicator is R · Source is not AN · SLC doesn't start with 21, 90, 91, 99 · Super To is blank. Columns (`MLPF_COLUMNS`): Branch, Part number, Description, Cost, Source, SLC, Commodity code, Commodity group, Dealer group, On order, On hand, Corp demands. Sorted by part number, then branch (the workbook's sort). | The workbook's WHERE and output. |
| L-D20 | **Saved copies** in `NonJD_InventoryReports` (same columns as NonJD_CleanupChecks), `VITE_LIST_INVENTORY_REPORTS`. A copy's columns = `MLPF_COLUMNS` plus any other field its conditions read. | Spec L-D6; one column set people already know. |
| L-D21 | **Routes:** `/inventory` (list), `/inventory/mlpf-gaps` (built-in results), `/inventory/report/:id` (copy results), `/inventory/new?from=<mlpf-gaps\|id>` and `/inventory/report/:id/edit` (editor). Area `inventory` goes live: rail "Reports"; launch card with no count. | Mirrors Cleanup. |
| L-D22 | **CSV:** `Inventory-<report name>-<yyyymmdd>[-partial].csv`, the table's columns in order, `neutraliseFormula` on text, numbers unformatted (pastes beside the workbook). | As Cleanup. |

## SharePoint list (L0, Brian)

**NonJD_InventoryReports** (same as NonJD_CleanupChecks)
| Column | Type | Notes |
|---|---|---|
| Title | (built in) | the report's name |
| Description | Multiple lines of text (plain) | optional |
| Conditions | Multiple lines of text (plain) | JSON, written by the app |
| Active | Yes/No | default Yes |
| Archived | Yes/No | default No |

Then `VITE_LIST_INVENTORY_REPORTS=<id>` in `.env.production` and `.env.example`.

## File map

| Repo | File | Change |
|---|---|---|
| fabric-workspace-docs | `workspaces/DP - Staging - Dev/Raw Data - Dataflows/df_CommodityCodeGroups_Raw.Dataflow/` (new: `.platform`, `mashup.pq`, `queryMetadata.json`) | CSV → `CommodityCodeGroups` |
| fabric-workspace-docs | `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook/notebook-content.py` | Part 5: `Fact_CorpParts_JD` |
| fabric-workspace-docs | `deploy/dp_refresh_dag.json`, the shortcut config `sync_shortcuts.py` reads, `docs/TABLE-LINEAGE.md` (generated) | new item, produces, dependsOn, shortcut |
| data-projects | `tools/dp-migration/corp_parts_check.py` + `test_corp_parts_check.py` (new) | reference check, `--mlpf-out`, `--compare-xlsx` |
| data-projects | `projects/part order tool - app/publish/` extract, build_files, publish_logic, run_publish, README, tests | v6 JD files |
| app | `src/data/contract.ts`, `types.ts`, `files.ts`, `source.ts`, mock | v6, `JdFile`, `loadJd` |
| app | `src/state/jdBranches.ts` (new) | `useJdBranches()` (cache per dataAsOf) |
| app | `src/cleanup/catalogue.ts` (new), `fields.ts`, `conditions.ts` | generic engine, starts with |
| app | `src/inventory/fields.ts`, `src/inventory/builtIns.ts` (new) | JD catalogue, MLPF Gaps |
| app | `src/config.ts`, `src/data/lists.ts`, `source.ts`, mock | `NonJD_InventoryReports` |
| app | `src/pages/inventory/` (new): `InventoryReportsPage.tsx`, `ReportResultsPage.tsx`, `ReportEditorPage.tsx`, `JdPartPanel.tsx`; `src/pages/cleanup/ConditionRowEditor.tsx`; `src/App.tsx`; `src/ui/areas.ts` | pages, routes, area live |

---

## Tasks

### Task L0: List and ID (Brian, with Claude)

- [ ] **Step 1:** Brian creates `NonJD_InventoryReports` (above) on the parts tool site.
- [ ] **Step 2:** Claude reads its ID and checks the columns through Graph; gives Brian the `.env` line.

### Task L1: Commodity groups dataflow (fabric-workspace-docs, Dev)

- [ ] **Step 1:** copy `df_NonJD_OrderRules_Raw.Dataflow` as `df_CommodityCodeGroups_Raw.Dataflow` with a fresh
  `.platform` `logicalId` (no trailing newline) and new query IDs. `mashup.pq`: header comment (purpose, grain = one
  row per CommodityCode, source, business use); `SharePoint.Files("https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite", [ApiVersion = 15])`,
  the file `CommodityCodeGroups.csv`, `Csv.Document(..., [Delimiter = ",", Columns = 2, Encoding = 65001])`, promote
  headers, rename `Group` → `CommodityGroup`, trim both, drop blank codes, both `type text`; destination DP_Staging
  table `CommodityCodeGroups`, Replace. Same SharePoint connection (`path` `https://spitractor.sharepoint.com`).
- [ ] **Step 2:** `dp_refresh_dag.json` item (dataflow, staging tier, daily, `produces: ["CommodityCodeGroups"]`, as
  the NonJD dataflows) and a DP_Presentation shortcut `CommodityCodeGroups` in the shortcut config. `dag_check`,
  pytest. Commit, push, `wait_ci.py`, git sync DP - Staging - Dev and DP - Presentation - Dev; run the Dev pipeline
  `mode=items items=df_CommodityCodeGroups_Raw`. If the dataflow fails on credentials, Brian opens it once in the Dev
  UI and picks the existing SharePoint connection, then rerun. Check with DuckDB: ≈ 244 rows, codes unique, no blank
  groups. `sync_shortcuts.py` (dry run, then `--apply` for Dev if it covers Dev).

### Task L2: Gold `Fact_CorpParts_JD` (fabric-workspace-docs, Dev)

- [ ] **Step 1:** in `Build_Gold_NonJD_Reorder`, a new **Part 5** after the purchases write (header note "Plan L:
  Fact_CorpParts_JD, the Corp Parts reports' JD parts"; GRAIN and SOURCES lines updated, add
  `CommodityCodeGroups`):

```python
# ---- Part 5 (Plan L): Fact_CorpParts_JD, every active JD (franchise D) part with the Corp demand count ----
# The Corp demand rule (shared by the Corp Parts workbooks, MLPF Gaps.pq): one demand = one invoice for the
# Branch + part, net of its credits. Invoices (TYPE 'I', Qty > 0) dated now-18 months .. now-7 days; credits
# (TYPE 'C', Qty < 0) dated now-18 months .. now, matched to their invoice by OriginalInvoiceNo. An invoice whose
# net qty is <= 0, or that has no 'I' line in the window, doesn't count. Transfers never count. "now" is the build
# time as Central wall clock, the way Equip stores TransDatetime (L-D10).
from zoneinfo import ZoneInfo
demand_as_of = datetime.now(ZoneInfo("America/Chicago")).replace(tzinfo=None, microsecond=0)
win_start = add_months_dt(demand_as_of, -18)          # same day and time, clamped to the month's end
inv_end = demand_as_of - timedelta(days=7)

jd_tx = (spark.sql("""SELECT Branch, Franchise, PartNumber, Type, Qty, TransDatetime, RONumber, OriginalInvoiceNo
                      FROM Silver_InTrans""")
         .where(F.upper(ztrim(c("Franchise"))) == "D")
         .withColumn("_t", F.upper(ztrim(c("Type"))))
         .withColumn("_ts", F.to_timestamp(c("TransDatetime")))
         .where(((c("_t") == "I") & (c("Qty") > 0) & (c("_ts") >= F.lit(win_start)) & (c("_ts") <= F.lit(inv_end)))
                | ((c("_t") == "C") & (c("Qty") < 0) & (c("_ts") >= F.lit(win_start))
                   & (c("_ts") <= F.lit(demand_as_of))))
         .select(F.upper(ztrim(c("Branch"))).alias("_b"), ztrim(c("PartNumber")).alias("_p"),
                 F.when(c("_t") == "I", ztrim(c("RONumber"))).otherwise(ztrim(c("OriginalInvoiceNo"))).alias("_inv"),
                 c("Qty"), (c("_t") == "I").cast("int").alias("_isInv")))
corp_demands = (jd_tx.groupBy("_b", "_p", "_inv")
                .agg(F.sum("Qty").alias("_net"), F.max("_isInv").alias("_hasInv"))
                .where((c("_net") > 0) & (c("_hasInv") == 1))
                .groupBy("_b", "_p").agg(F.count(F.lit(1)).cast("int").alias("CorpDemands")))
```

  Then the part rows: Silver_PartInformation where `upper(ztrim(Franchise)) == 'D'`, left-join `corp_demands` on
  (`upper(ztrim(Branch))`, `ztrim(PartNumber)`), left-join Silver_PartStockingRules (full key, franchise D) for
  Minimum/Maximum, left-join `CommodityCodeGroups` on `upper(ztrim(CommodityCode))` (group → "Other" when no match),
  `PackageQty` = `F.expr("try_cast(trim(PackageQty) AS DECIMAL(12,2))")`, `CorpDemands` coalesced to 0, the L-D14
  active filter, the L-D13 columns, `DemandAsOf` = `F.lit(demand_as_of).cast("timestamp")`, `BuiltAtUtc` as the other
  tables. Assert the key (Branch, Franchise, PartNumber as stored) is unique before writing (raise with the first
  duplicates); check `CommodityCodeGroups` codes are unique after trim/upper (raise otherwise, never pick one).
  Literal `.save("Tables/Fact_CorpParts_JD")`, overwrite + overwriteSchema, VACUUM RETAIN 0 HOURS, print row count,
  rows with CorpDemands > 0, and the MLPF count (the L-D19 filter in Spark, for the log only).
  `add_months_dt` is a small helper beside `add_months` (same clamping, keeps the time).
- [ ] **Step 2:** `dp_refresh_dag.json`: `Fact_CorpParts_JD` in the item's `produces`; `CommodityCodeGroups` and
  `df_CommodityCodeGroups_Raw` in `dependsOn` as the scanner wants. `dag_check`, `hygiene_audit`, pytest. Commit,
  push, git sync, Dev run `mode=items items=Build_Gold_NonJD_Reorder` → Completed. **Run it twice**; the second run's
  row count and CorpDemands total equal the first (minutes apart: a difference must be explained by an invoice crossing
  the window edge).

### Task L3: Reference check `corp_parts_check.py` (data-projects)

- [ ] **Step 1 (tests first):** `test_corp_parts_check.py` on in-memory DuckDB tables: an invoice with 2 lines = 1
  demand; an invoice fully credited = 0; partially credited = 1; a credit whose invoice is outside the window = 0; an
  invoice 6 days old = 0, 8 days old = 1; a transfer = 0; a non-D InTrans line = 0; trailing-space part numbers and
  invoice numbers group together; an inactive part is dropped; an unmapped commodity code → "Other"; `PackageQty`
  `'1.00'` → 1, `'abc'` → NULL; the MLPF filter keeps exactly the one passing fixture part.
- [ ] **Step 2:** the script (same shape as `nonjd_reorder_check.py`: `_connect`, `TIERS`, `--tier dev|prod`):
  read Gold's `DemandAsOf` (one value; fail if not one), build the expected table in SQL from Silver_PartInformation,
  Silver_InTrans, Silver_PartStockingRules and CommodityCodeGroups with that `now`, compare row by row with
  `Fact_CorpParts_JD` on the key (numbers within 0.005, text exact), print PASS/FAIL with the first 20 differences.
  `--mlpf-out <csv>`: write Gold's MLPF Gaps list with the workbook's columns and sort (Branch, PartNumber,
  Description, Cost, Source, SLC, CommodityCode, CommodityGroup, DealerGroupCode, OnOrder, OnHandQty, Demands).
  `--compare-xlsx <MLPF Gaps.xlsx> [--sheet <name>]`: read the workbook's table (openpyxl), match on trimmed Branch +
  PartNumber and print: only in Excel, only in Gold, and value differences per column, each with the part's Gold
  CorpDemands, OnHand, OnOrder and last InTrans date so a difference can be explained (window edge, a sale or receipt
  since the build, the twins).
- [ ] **Step 3:** `--tier dev` → PASS, 0 differences. Commit, push.

### Task L3b: Excel comparison on Dev (Brian, then Claude)

- [ ] **Step 1:** Brian refreshes **MLPF Gaps.xlsx** as close as possible to a Dev Gold run (Claude runs the Dev
  item first and says when it finished), saves a copy locally and gives Claude the path.
- [ ] **Step 2:** `corp_parts_check.py --tier dev --compare-xlsx <path>`; Claude explains every difference by part
  in a short note in this plan's Progress. Anything that isn't timing, the twins or Dev's data age is a bug: fix L2/L3
  and repeat. **Gate:** no unexplained differences.

### Task L4: Publish contract v6 (data-projects)

- [ ] **Step 1 (tests first):** `test_extract.py` (`JD_COLUMNS` read from `Fact_CorpParts_JD`; a missing column fails
  `check_columns` naming it), `test_build_files.py`: `jd_<branch>.json.gz` = `{"branch", "dataAsOf", "parts": [...]}`
  with the L-D18 fields (`partNumber`, `description`, `cost`, `onHand`, `onOrder`, `packageQty`, `returnIndicator`,
  `source`, `slc`, `superTo`, `commodityCode`, `commodityGroup`, `dealerGroupCode`, `minimumQty`, `maximumQty`,
  `sales12`, `salesPrev12`, `corpDemands`); text trimmed, blank → `""` (description, packageQty, min, max may be
  null); money rounded to cents, quantities to 2 dp; branch 12 **is** written (no D6 check on JD rows); duplicate
  trimmed part numbers allowed; rows sorted by partNumber then the raw value; `_meta.json` has `jdBranches` (sorted as
  `branches`) and `counts.jdParts`, `contractVersion == 6`; a branch file over 4 MB fails the build naming it.
- [ ] **Step 2:** `extract.JD_COLUMNS` and `jd_parts(con)`; `build_files.build_jd(rows, names, data_as_of)` →
  `(hashes, jd_branches)`; `run_publish` calls it and passes `jdBranches` / `jdParts` to `write_meta`;
  `publish_logic.CONTRACT_VERSION = 6` and `jd_*.json.gz` re-uploaded every run (they carry `dataAsOf`); README:
  contract history ("6 = Plan L: jd_<branch>.json.gz, `_meta.jdBranches`, `counts.jdParts`; deploy app 0.12.0
  first"), the JD file's fields and nulls, the branch rule.
- [ ] **Step 3:** tests pass; local `--out` build against Dev: report file count, the largest `jd_` file size and
  `counts.jdParts`. **Don't publish v6 until L12.** Commit, push.

### Task L5: App data: v6 and the JD files

- [ ] **Step 1:** `contract.ts`: `SUPPORTED_CONTRACT_VERSIONS = [3, 4, 5, 6]`, `CONTRACT_VERSION = 6`,
  `hasJdParts(meta) = contractVersion >= 6`. `types.ts`: `Meta.jdBranches?: MetaBranch[]`, `counts.jdParts?: number`;

```ts
/** One JD (franchise D) part in jd_<branch>.json.gz (contractVersion 6, Plan L). Blank text arrives as "". */
export interface JdPart {
  partNumber: string;
  description: string | null;
  cost: number;
  onHand: number;
  onOrder: number;
  /** null = Equip's value isn't a number. */
  packageQty: number | null;
  returnIndicator: string;
  source: string;
  slc: string;
  superTo: string;
  commodityCode: string;
  /** "Other" when the code isn't in CommodityCodeGroups.csv. */
  commodityGroup: string;
  dealerGroupCode: string;
  minimumQty: number | null;
  maximumQty: number | null;
  sales12: number;
  salesPrev12: number;
  /** The Corp demand count (invoices net of credits, 7 days to 18 months). */
  corpDemands: number;
}
export interface JdFile { branch: string; dataAsOf: string; parts: JdPart[] }
```

  `DataSource.loadJd(branch): Promise<JdFile>` (`files.loadJd`, `jd_<branch>.json.gz`, same fetch / gunzip / error
  handling as `loadReorder`).
- [ ] **Step 2:** mock: `contractVersion` default 6 with `jdBranches` 1, 2 and 12, and the JD fixtures (`JD_FIXTURES`
  in `src/data/mock/jdFixtures.ts`): at branch 1 **JD-MLPF-OK** (passes every MLPF condition: demands 2, on hand 0,
  on order 0, package 1, R, source "JD", SLC "40", super to blank, commodity "07A" / "Tillage"), then one part per
  condition that fails only that one (`JD-MLPF-DEM3` demands 3, `-ONHAND` on hand 1, `-ONORDER` 1, `-PKG2` package 2,
  `-RETN` N, `-SRCAN` AN, `-SLC21` "2105", `-SUPER` super to "R123456"), at branch 12 `JD-MLPF-B12` (passes all but
  the branch), at branch 2 a few ordinary parts; `asV5` drops `jdBranches`. Tests for `loadJd` and the mock.
- [ ] **Step 3:** `src/state/jdBranches.ts`: `useJdBranches()` → `{ status, branches: Map<string, JdPart[]>,
  missing: string[], dataAsOf }`, loading `meta.jdBranches` in parallel (as `useAllBranches`, same cache rules: one
  per DataSource, dropped when `dataAsOf` changes, a file whose `dataAsOf` differs isn't cached, failures not cached).
  `notInData` when `!hasJdParts(meta)`. Tests. Commit "L5: v6 data and the JD files".

### Task L6: The engine over any catalogue (refactor, no behaviour change)

- [ ] **Step 1:** `src/cleanup/catalogue.ts`:

```ts
export interface FieldDefOf<P, F extends string> {
  id: F; label: string; type: FieldType; blankable: boolean;
  read(p: P): FieldValue;
}
export interface Catalogue<P, F extends string> {
  fields: readonly FieldDefOf<P, F>[];
  isFieldId(id: unknown): id is F;
  fieldDef(id: F): FieldDefOf<P, F>;
  comparisonsFor(id: F): Comparison[];
  fieldInData(id: F, meta: Pick<Meta, 'contractVersion'>): boolean;
  /** Text stored for a condition value (vendor digits, dealer group "(none)"); default: trimmed. */
  storedText?(field: F, s: string): string;
  /** What's wrong with one stored text value, or null. */
  textProblem?(field: F, s: string): string | null;
}
export function makeCatalogue<P, F extends string>(
  fields: readonly FieldDefOf<P, F>[],
  opts?: Pick<Catalogue<P, F>, 'storedText' | 'textProblem'> & { fieldInData?: Catalogue<P, F>['fieldInData'] },
): Catalogue<P, F>; // comparisonsFor from BY_TYPE + blank/notBlank when blankable; fieldInData defaults to () => true
```

  `FieldType`, `FieldValue`, `Comparison` move here (re-exported from `fields.ts`). `fields.ts` exports
  `CLEANUP_CATALOGUE: Catalogue<SlimPart, FieldId>` built from today's FIELDS, keeping `fieldDef`, `isFieldId`,
  `comparisonsFor`, `fieldInData` as thin wrappers so existing imports compile.
- [ ] **Step 2:** `conditions.ts`: every exported function gains a `catalogue` parameter **last, defaulting to
  `CLEANUP_CATALOGUE`** (`parseConditions`, `conditionProblem`, `compileConditions`/`matches`, `conditionText`,
  `checkColumns`, …), and `Condition<F extends string = FieldId>`, `CleanupCheck<F = FieldId>`. The vendor and
  dealer-group special cases move into the cleanup catalogue's `storedText` / `textProblem`. `ConditionRowEditor`
  takes an optional `catalogue` prop (default cleanup).
- [ ] **Step 3:** no test changes needed: full suites, lint, tsc green with the existing tests untouched (that's the
  proof of no behaviour change). Commit "L6: condition engine over a catalogue".

### Task L7: JD catalogue, starts with, MLPF Gaps (pure)

- [ ] **Step 1 (tests first):** `startsWith` / `notStartsWith` in `BY_TYPE.text` (both catalogues): value kind
  `list`; `conditionProblem` "Pick at least one."; match on trimmed, upper-cased value vs each trimmed, upper-cased
  prefix; blank → `startsWith` false, `notStartsWith` true; `conditionText` "SLC doesn't start with 21, 90, 91 or 99"
  / "Source starts with A". Editor: chips as "one of" (free text, no suggestions list needed).
- [ ] **Step 2:** `src/inventory/fields.ts`: `JdRow = JdPart & { branch: string }`; `JdFieldId` and
  `JD_CATALOGUE` per L-D18 (text via `textValue`; dealer group "(none)" = blank as Cleanup; `packageQty` null =
  blank, blankable; `sales24` = sales12 + salesPrev12; `fieldInData` always true: the whole data set is v6).
- [ ] **Step 3:** `src/inventory/builtIns.ts`:

```ts
export const MLPF_GAPS_ID = 'mlpf-gaps';
export const MLPF_GAPS_NAME = 'MLPF Gaps';
export const MLPF_GAPS_DESCRIPTION =
  'JD parts with exactly 2 Corp demands and nothing on hand or on order, returnable, package qty 1, not superseded ' +
  '(the MLPF Gaps workbook).';
export const MLPF_GAPS: readonly Condition<JdFieldId>[] = [
  { field: 'branch', op: 'isNot', value: { kind: 'text', value: '12' } },
  { field: 'corpDemands', op: 'eq', value: { kind: 'number', value: 2 } },
  { field: 'onHand', op: 'lt', value: { kind: 'number', value: 1 } },
  { field: 'onOrder', op: 'eq', value: { kind: 'number', value: 0 } },
  { field: 'packageQty', op: 'eq', value: { kind: 'number', value: 1 } },
  { field: 'returnIndicator', op: 'is', value: { kind: 'text', value: 'R' } },
  { field: 'source', op: 'isNot', value: { kind: 'text', value: 'AN' } },
  { field: 'slc', op: 'notStartsWith', value: { kind: 'list', values: ['21', '90', '91', '99'] } },
  { field: 'superTo', op: 'blank', value: { kind: 'none' } },
];
export const MLPF_COLUMNS: readonly JdFieldId[] = ['branch', 'partNumber', 'description', 'cost', 'source', 'slc',
  'commodityCode', 'commodityGroup', 'dealerGroup', 'onOrder', 'onHand', 'corpDemands'];
export function reportColumns(conditions: readonly Condition<JdFieldId>[]): JdFieldId[]; // MLPF_COLUMNS + others used
```

  Tests on `JD_FIXTURES`: exactly `JD-MLPF-OK` matches; each `JD-MLPF-*` fails; `JD-MLPF-B12` fails only on the
  branch; `parseConditions(JSON.parse(JSON.stringify(MLPF_GAPS)), JD_CATALOGUE)` round-trips; a stored Cleanup field
  id (`'vendor'`) doesn't parse in the JD catalogue. Full suites, lint, tsc. Commit "L7: JD catalogue and MLPF Gaps".

### Task L8: Saved reports list

- [ ] `config.lists.inventoryReports` (`VITE_LIST_INVENTORY_REPORTS`, required, in the required-list table);
  DataSource `loadInventoryReports()`, `saveInventoryReport()`, `patchInventoryReport()`, sharing the cleanup checks'
  Graph mappers with the list name and `JD_CATALOGUE` as parameters (no copy of the mapper code); rows that fail to
  parse are "unreadable" as in Cleanup. Mock seeds one active copy "MLPF Gaps – 2 or 3 demands" (Corp demands ≥ 2, Corp
  demands ≤ 3, plus the other eight MLPF conditions; author "Ben Hill") and one archived. Tests.
  Commit "L8: inventory reports list".

### Task L9: Pages

- [ ] **Step 1:** `areas.ts`: `inventory` live, `home: '/inventory'`, screens `[{ path: '/inventory', label:
  'Reports', icon: 'orders' }]`, description "The Corp Parts reports, in the app."; launch card (no count). Routes per
  L-D21 in `App.tsx`.
- [ ] **Step 2:** `InventoryReportsPage` (`/inventory`), modelled on `CleanupChecksPage`: "Inventory reports",
  built-in MLPF Gaps first with a "Built in" tag and its description, then saved copies (name, description,
  conditions text, author, changed, Off); each with its count over the loaded JD branches and progress; **Copy as my
  own** on every report; Edit / Switch off / Archive (ask first, re-read first, name clash refused) on copies only;
  Show archived (N); "Data as of …". On v3–v5 data: "JD parts aren't in today's data yet. They arrive with the next
  publish." and nothing else.
- [ ] **Step 3:** `ReportResultsPage` (`/inventory/mlpf-gaps`, `/inventory/report/:id`), modelled on
  `CheckResultsPage`: H1 the report's name, its conditions text, "Data as of …"; branch filter (all branches by
  default, the JD branch names), search box (part number or description, trimmed, case-insensitive, contains);
  sortable table with the report's columns (default sort part number, then branch), row count and **Total cost (1 each)**
  = the sum of Cost over the shown rows (MLPF parts have nothing on hand, so this is what stocking one of each would
  cost); Export CSV (L-D22); missing branches named ("Branches 4 and 7
  didn't load; the count covers the rest."), CSV marked `-partial` then. Clicking a row opens `JdPartPanel`: every
  L-D18 field with its label, Escape / close button returns focus to the row.
- [ ] **Step 4:** `ReportEditorPage` (`/inventory/new?from=…`, `/inventory/report/:id/edit`), modelled on
  `CheckEditorPage` with `catalogue={JD_CATALOGUE}`: from a built-in or copy, pre-filled conditions and name "Copy of
  <name>"; live Try it over the loaded JD branches; Save report ("Report saved." / "Report updated."), name clash with
  the built-in and active copies refused; leave guard; "← Inventory reports". Share code with the cleanup pages where
  it would otherwise be copied (e.g. the try-it hook, the sort/CSV helpers), not by making the cleanup pages generic.
- [ ] **Step 5:** tests for each page on the mock (the built-in shows 1 part, JD-MLPF-OK; the branch filter; search;
  sort; CSV content and name; the panel; copy → editor pre-filled → save → listed; v5 data message; a branch that fails
  to load). Full suites, lint, tsc. Commit "L9: inventory pages".

### Task L10: Click-through and try-it notes

- [ ] `src/__tests__/clickThrough0120.test.tsx`: launch → Inventory → MLPF Gaps (1 part, CSV) → row panel → Copy as
  my own → change Corp demands to ≥ 2 → Try it count 2 (JD-MLPF-OK, JD-MLPF-DEM3) → Save → listed with a count →
  Edit → Switch off → Archive.
- [ ] `for-users/0.12.0-try-it.md`: three short jobs ("Open MLPF Gaps", "Make your own version", "Tidy the list"),
  each with "Look for".

### Task L11: Review and 0.12.0 build

- [ ] typescript-reviewer over L5–L10; fixes; full suites, lint, tsc; `package.json` 0.12.0 and README row;
  `npm run build`; check dist (the new list ID plus the existing lists and site, no mock strings, "Version 0.12.0 ·
  commit …"). Push.

### Task L12: Release (Brian's steps, one at a time)

1. fabric-workspace-docs PR dev → main (`merge_preview.py`); Brian merges (merge commit), runs **Deploy DP backend**,
   then `python deploy/claim_prod_pipeline.py` (the new dataflow runs as the pipeline's last modifier); Claude
   fast-forwards dev; `sync_shortcuts.py --apply` after the Prod staging run creates `CommodityCodeGroups`.
2. Brian deploys app 0.12.0 to Fedora (reads v5 now, v6 later).
3. Brian runs Prod `mode=items items=df_CommodityCodeGroups_Raw`, then shortcuts (step 1), then
   `mode=items items=Build_Gold_NonJD_Reorder`; Claude runs `corp_parts_check.py --tier prod` → PASS and
   `nonjd_reorder_check.py --tier prod` → PASS (no change to the Non-JD tables).
4. Brian pulls `C:\data-projects` on the Gateway PC and runs `.venv\Scripts\python.exe run_publish.py`; Claude
   confirms `_meta.json` `contractVersion: 6`, `jdBranches` and `counts.jdParts`.
5. Brian refreshes MLPF Gaps.xlsx; `corp_parts_check.py --tier prod --compare-xlsx` → every difference explained.
6. Real test on Fedora: MLPF Gaps count ≈ the workbook's; Brian copies it, saves, switches off and archives; Claude
   checks the row through Graph and deletes it.

### Task L13: Documents and progress

- [ ] Guide section "Inventory reports (0.12.0)" (task-shaped), walkthrough "Version 0.12.0", regenerate both .docx,
  `projects/part order tool - app/INVENTORY-REPORTS.md` for Ben (what MLPF Gaps checks, the Corp demand rule in plain
  words, the JD fields, data as of the morning, how a copy works, the Excel comparison result), FUTURE-IDEAS F4 →
  MLPF Gaps done in 0.12.0 with the next reports listed; `projects/corp parts excel reports/CLAUDE.md` note that MLPF
  Gaps is also in the app; plan and spec Progress; memory.

---

## Self-review against the spec

- Built-in matching the workbook + Copy as my own (L-D1): L7 (MLPF_GAPS from the .pq's WHERE), L9 Steps 2 and 4,
  L3b / L12 step 5 (Excel gate).
- Everyone sees it (L-D2): area live, no roles (L9 Step 1).
- Once-a-day data with "Data as of" (L-D3): L9 Steps 2–3.
- Option 1, browser engine over shipped JD parts (L-D4): L4, L5, L6.
- Every JD branch incl. 12 (L-D5): L4 (no D6 check), L5 mock branch 12, MLPF's "Branch is not 12".
- InventoryReports list (L-D6): L0, L8. No Part page link; details panel (L-D7): L9 Step 3.
- Gold table with the listed columns and the Corp demand rule computed once, trimmed: L2, L-D10–L-D14; commodity
  group from the same CSV: L1, L-D9.
- Contract v6, lazy load, 4 MB check: L4, L5 (loaded only by Inventory pages).
- New fields and starts with / doesn't start with: L7, L-D17, L-D18.
- Errors (not yet in data, missing branches, unknown field): L5 Step 3, L9 Steps 2–3, engine's `unknown` kept by L6.
- Testing: Gold run twice (L2), reference check (L3), Excel comparison (L3b, L12), publish pytest (L4), Vitest incl.
  one-fail-each fixtures (L5, L7, L9, L10). Release pattern: L12. Later reports: out of scope (spec "Later").
