# Non-JD Parts Order Tool: redesign on the DP backend

> **Progress:** design agreed with Brian 2026-10-20 (options discussion in the same session). No plan yet; next step is `writing-plans`.
>
> Supersedes the platform choice in `2026-05-28-non-jd-parts-order-tool-design.md` (Power Apps V1, then a React web app as V2) and the LH_Master_Data backend in `2026-05-28-non-jd-parts-order-tool-fabric-foundation.md`. The ROP calculation, franchise scope and screen list from those documents still apply unless this spec says otherwise.

## 1. Goal

Give the parts ordering team a working prototype of a reorder tool for non-John Deere parts, built on the DP backend, that they can use on real data and react to. Ordering for non-JD franchises is a manual, spreadsheet-driven process today. John Deere parts are ordered through JD's PRISM system, which has no equivalent for other franchises.

The prototype's main job is discovery. Brian doesn't work in the ordering process day to day, so the rules (stale-part cutoffs, demand windows, spiking, masking, export layouts) will be settled by watching the users work with something real. The design therefore favours fast iteration and cheap change over completeness.

## 2. Users

| Person | Role | Uses the tool for |
|---|---|---|
| Ben | Corporate parts manager, over the whole parts department | Oversight, settings, rule decisions |
| Shannon | Parts manager, all non-JD ordering for all 19 stores | Primary daily user |
| Barry | Parts manager, JD ordering for about half the stores | Occasional; possible future JD scope |
| Curt | Parts manager, JD ordering for the other stores | Occasional; possible future JD scope |

- All four get the same full access, including editing part settings. No role split.
- Desktop and laptop browsers only. No tablet or phone layout is required.
- None of them have Power Apps licences today.

## 3. Platform decision

**A React single-page web app, reading pre-built data files from SharePoint, saving its own data to SharePoint lists.** This is the same pattern as the Parts Availability app (`parts-lookup-app` repo), which moved off Fabric Apps for capacity reasons.

| Option | Verdict | Reason |
|---|---|---|
| **React web app + SharePoint files and lists** | **Chosen** | No new licences; no Fabric cost while people use it; the design handoff is already React; proven by Parts Availability |
| Fabric App (Rayfin) | Rejected for now | Still preview (checked 2026-10-20). Every Fabric App owns a SQL database in Fabric, and that database's minimum "kept online" billing was the real cost driver in the Parts Availability capacity incidents (`2026-08-14-parts-lookup-static-file-prototype-design.md`). The new read connectors only remove the copy step, not the database. |
| Power Apps canvas app | Rejected | Needs Power Apps Premium for all four users (the SQL connector to Fabric is premium); layout limits make the mockups hard to reproduce |
| Power BI report with write-back (translytical task flows, GA March 2026) | Rejected | Fine for review and annotation, poor for a select-and-export order workflow and a two-step wizard |
| Custom web app with its own API on Azure | Rejected | Same result as the chosen option with hosting, security and an API to maintain alone |

## 4. Architecture

```
JD Bronze (InMaster, INHIST_MONTH_4_PI / InHistMQT, transfer tables)
  -> DP_Staging Silver (existing Silver_InMaster etc. + new part-history Silver)
  -> DP_Presentation Gold (new Build_Gold_NonJD_* notebooks, in Pipeline_DP_Refresh)
  -> Publish script on the Gateway PC (DuckDB over OneLake, SPN), after the morning DP run
  -> SharePoint document library: per-branch JSON files + manifest + meta
  -> React SPA (MSAL sign-in) reads files via Microsoft Graph with the user's own token
  -> App writes part settings and orders to SharePoint lists via Graph
  -> Staging dataflow reads the settings list back into DP each morning (feeds the Gold calc)
```

User activity touches only SharePoint. Fabric is used once a day, by the DP refresh and one small read by the publish script.

## 5. Backend on DP

### 5.1 What exists and what's new

| Need | Source today | Plan |
|---|---|---|
| Part master, on hand, on order, cost, bin | `Silver_InMaster`, `Silver_PartInformation` | Reuse |
| 60-month sales and demand history | Not in DP. `Silver_PartInformation` deliberately carries only 33 of the source view's ~200 columns (`2026-09-18-jdis-part-information-rebuild-design.md`) | New Silver table from the Bronze shortcuts already in DP_Staging: `INHIST_MONTH_4_PI` (wide, "month for PI") and/or `InHistMQT` (one row per part per month). **First build task: confirm which columns hold monthly sales units and demand counts, and that they match the old `pi_sales_history_*` / requests columns.** Prefer the long monthly shape if it matches. |
| Inbound / outbound transfers | `Fact_OutstandingTransfers` (one row per outstanding transfer line: supplying branch, requesting branch, ordered / shipped / in-transit qty, age) | Reuse |
| ROP parameter matrix (1,993 rows) | CSV, loaded into LH by `df_Param_ROP_Matrix` | Move the CSV to SharePoint; small staging dataflow into DP_Staging |
| Franchise scope | `param_FranchiseScope` CSV in LH | Same treatment as the matrix. Exclusions stay D, ZP, S, T*, U*, 95; DA is included. |
| Part settings (user overrides) | SharePoint list `config_PartSettings` (Report Site) | New list (section 7), read back by a staging dataflow into DP_Staging |

### 5.2 New Gold outputs

- **`Fact_NonJD_Reorder`**: one row per Branch + Franchise + PartNumber. Port of the LH notebook's ROP logic (`nb_Fact_NonJD_Parts_Order`, part 2): month count capped at 19, average monthly demand and sales over active months, matrix lookup, `StockingTarget = MAX(WarehouseMin, EffectiveMin, CEIL(CalcROP))`, `RecommendedOrderQty = MAX(0, StockingTarget - OnHand - OnOrder)`, `EstOrderValue`. Adds `InboundTransferQty` (display only, see 8.3) and `SurplusQty = MAX(0, OnHand - StockingTarget)` for the transfer suggestions.
- **`Fact_NonJD_SalesHistory`**: one row per Branch + Franchise + PartNumber + month, 60 months.

### 5.3 Rules that apply

- Follow `docs/architecture/dp-notebook-rules.md`.
- **Key correction:** the LH fact was described as one row per Branch + PartNumber. The real InMaster key is Branch + Franchise + PartNumber. Use the full key everywhere, including the published files and the settings list.
- Trailing-space twin part numbers are real separate rows. Trim only where porting SQL `=` comparisons.
- Path-based `.save("Tables/...")`, VACUUM after overwrite, UTC session time zone, outputs declared in `dp_refresh_dag.json`, run twice and compare.
- Add both notebooks to the DAG as daily items. They're cheap next to the rest of the run, but measure the added minutes and CU in Dev.

### 5.4 Which tier the prototype reads

DP Dev has no refresh schedule. Users testing on stale on-hand numbers would give misleading feedback. So:

1. Build and validate the Silver and Gold items in Dev as usual.
2. Promote the backend items to Prod through the normal release (they have no report consumers, so the risk is low).
3. Point the publish script at **Prod** Gold. The app itself stays a dev prototype.

Brian decides when step 2 happens. Until then the publish script can read Dev after a manual Dev run.

## 6. Publish script and files

- Lives in this repo at `projects/part order tool - app/publish/`. Runs on the Gateway PC (which already runs a clone of `dev` for Parts Availability) from Task Scheduler, weekdays after the DP run.
- Before publishing, checks that today's DP run succeeded for the NonJD items (`dp_refresh_log`). If not, it doesn't publish, and the app's freshness banner shows the data's real age.
- Reads Gold with DuckDB `delta_scan` over OneLake using the existing refresh SPN. Writes to a SharePoint document library through Graph, the same way the Parts Availability upload works.
- Files (gzipped JSON; exact shapes settled in the plan):

| File | Contents | Why |
|---|---|---|
| `reorder/{branch}.json` | All in-scope parts for one branch with recommendation, stock, cost, transfers | Recommended Reorder screen loads one branch |
| `history/{branch}.json` | 60 months of sales and demand per part, compact arrays | Part history and the One-Time Order calculation |
| `surplus.json` | Every Branch + Franchise + PartNumber with `SurplusQty > 0` | "Another store has extra" suggestions across all 19 stores |
| `transfers.json` | Outstanding transfer lines for in-scope parts | Inbound and outbound transfer detail |
| `_meta.json` | **Data date** (the DP run's completion time, not the publish time) and row counts | Freshness banner. Avoids the Parts Availability bug where publish time was stamped as data age. |

- Only re-uploads files whose content changed.
- Separate libraries for the prototype and any later production copy.

## 7. Saving data: SharePoint lists

Three lists on one SharePoint site (site to be chosen in the plan; a dedicated site keeps Dev and Prod apart):

| List | Key | Holds |
|---|---|---|
| `PartSettings` | Branch + Franchise + PartNumber | Minimum override, EOQ, force non-spiking, masking (with expiry), pre-approved rule, notes, last changed by and when |
| `Orders` | Order id | Branch, franchise, type (recommended or one-time), parameters used, created by and when, status (draft / exported), export count |
| `OrderLines` | Order id + Branch + Franchise + PartNumber | Recommended qty, ordered qty after edits, cost, value |

- Settings changes take effect at the next morning refresh. The app marks changed parts as "updates after tomorrow's refresh" so users aren't confused. The app doesn't duplicate the ROP calculation to preview overrides.
- Every save records who made it. SharePoint version history gives a free audit trail.
- Brian handles the Graph permission for writing to the lists.

## 8. App

### 8.1 Screens

The design handoff (`projects/part order tool - app/Non-JD Parts Order Tool/design_handoff_parts_order_tool/`) is the visual reference: left nav rail, breadcrumb, status pills, computed "Need" column. Its React prototype code can be reused directly.

1. **Home**: branch picker, data date, counts of parts needing reorder per franchise, recent orders.
2. **Recommended Reorder**: branch and franchise filters, "reorder needed only" toggle, search, sortable table (part, bin, cost, sales, demand, on hand, on order, **inbound transfers**, target, need, value, status). Select rows, adjust quantities, create an order.
3. **One-Time Order**: step 1 chooses branch, franchises and months of history; step 2 sets loading factor, minimum demands and sales, total or monthly average, then calculates in the browser from the history file. Same review and export as Recommended Reorder.
4. **Part Lookup**: search by part number. Detail, History (12-month chart plus 60-month table) and Settings tabs. Shows stock and surplus at other branches.
5. **Orders**: saved and exported orders, re-export, mark as placed.
6. **App Settings**: defaults such as starting branch.

The "Transfers" nav item in the mockup belongs to the separate driver Transfer App and is dropped here.

### 8.2 Export

- One CSV per franchise for the selected branch, because franchises map to the vendors that orders go to. **To confirm with Shannon** (section 11).
- Exporting saves the order and its lines, so a later phase can add vendor-specific layouts or direct submission without changing the data model.

### 8.3 Transfers

- Inbound transfers to the branch show beside each recommendation and on the part detail. They **don't** reduce the suggested quantity in the prototype; that may change after testing.
- When a part needs ordering at one branch and another branch has `SurplusQty > 0`, the row shows a "store N has X extra" hint, and the part detail lists those branches. Making the transfer itself stays in Equip.

### 8.4 Sign-in

- New Entra app registration (SPA), separate from Parts Availability's, with assignment required. Assigned to a group holding the four users plus Brian.
- Delegated Graph permissions: read the files library, read and write the three lists.

## 9. Hosting

| Stage | Where | Notes |
|---|---|---|
| Build | Brian's PC, `localhost` | Day-to-day development |
| Prototype testing | Fedora test server `spi10sr2041l` (`10.110.100.13`), a second Apache site next to the Parts Availability test copy | Already proven from the corporate office and a store; self-signed certificate, one browser warning. Fedora 41 is past end of life, which is acceptable for a prototype that hosts only static code. Setup notes: `parts-lookup-app/docs/FEDORA-SERVER-DEPLOYMENT.md`. |
| Production | Decided with IT once the prototype proves out | Candidates: the Windows Server 2016 IIS box (extended support ends 2027-01-12), a newer server, or Azure Static Web Apps on the existing Azure subscription |

No company data lives on the host. Moving hosts means copying the built files and adding the new address to the app registration's redirect URIs. Don't use a tunnel from Brian's PC this time.

## 10. Cost and capacity

- No new licences.
- Fabric: two extra notebooks in the daily DP run, plus one small DuckDB read. Measure both in Dev and record the numbers in the plan's progress notes.
- No Fabric SQL database, no GraphQL, no live queries from users.
- SharePoint and Graph usage is covered by existing Microsoft 365 licences.

## 11. Open questions for Ben and Shannon

The prototype starts on the current calculation and exposes these as settings where possible, so the answers can come from trying it. Rewritten from `projects/part order tool - app/CORP-PARTS-MANAGER-QUESTIONS.md` (June 2026), which neither has reviewed.

0. **What the ROP matrix's columns mean (most important; found 2026-10-20 on the first Dev run).** The tool reads JD's ROP matrix export (dealer 048757, 2023-09-22) the way the old LH notebook did: stocking target = average demand per active month × "Modifier". That can't be right: the Modifier reaches 48 for parts with steady demand, and parts requested once in 12 months get a target of 4 (one $42,000 axle drive). Across all branches the suggested orders total about $9.8M. We need JD's PRISM definition of Modifier, Trending Cap, Stocking Weeks and the Spiking columns (Ben may have it, or JD's PRISM documentation) before anyone acts on the numbers.
1. **Ordering unit.** Do you place orders by franchise, by vendor, or something else? What does each vendor's order form look like? (Please share two or three real examples.)
2. **Stale parts.** How long without any sales or requests before a part should stop being recommended?
3. **History window.** Should recommendations use 60 months, or a shorter window so old high-volume parts don't inflate them?
4. **Spiking.** How do you recognise a one-off spike, and what should happen to the recommendation when you see one?
5. **Masking.** Does masking hide a part from recommendations entirely, or just until an expiry date?
6. **Pre-approved rules.** What choices belong in this setting, and what does each one mean?
7. **One-time orders.** When do you use a monthly average instead of a total? What do "trending" and "phase-in" mean in PRISM, and do you need them here?
8. **Small orders.** Should lines under some dollar value be hidden?
9. **Transfers.** After using the tool, should inbound transfers reduce the suggested quantity?
10. **Low margin.** Should the low-margin flag matter for non-JD parts, and at what threshold?
11. **History scope.** Is it useful to see a part's history across all branches, not only the selected one?

## 12. Later phases (not in the prototype)

- **Intraday freshness.** DP's `intraday` mode exists but isn't scheduled. One JD incremental copy costs about 6,500 CU(s) (measured for Parts Availability, 2026-10), so more frequent data is a cost decision.
- Inbound transfers reducing the suggested quantity.
- Vendor-specific export layouts or direct submission.
- JD parts in the same tool, alongside PRISM.
- Production hosting and a proper certificate (section 9).

## 13. Out of scope

- Any change to the Parts Availability app or its feed.
- Deleting the LH_Master_Data NonJD items (`df_NonJD_Parts_Ordering_Raw`, `df_InMaster_Parts_Ordering_Raw`, the param dataflows, `nb_Fact_NonJD_Parts_Order`, `Pipeline_NonJD_Order_Tool`) or the old `config_PartSettings` list. All are unscheduled. Deletion needs Brian's explicit OK, as a separate step.
- The existing Power Apps canvas app. It's left as is.

## 14. Prototype success criteria

- Shannon can pick a branch, see recommendations with transfers and surplus hints, adjust quantities, and export per-franchise CSVs without help.
- Part settings saved in the app change the next morning's recommendations.
- The data date shown in the app is the DP run's completion time, and a failed run shows as stale.
- Gold outputs pass `dag_check.py`, the hygiene audit and a two-run comparison.
- Measured daily Fabric cost of the new items is recorded.
- The open questions in section 11 have answers, or at least concrete feedback, after a few weeks of use.
