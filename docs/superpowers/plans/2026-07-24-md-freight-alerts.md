# MD Freight Alerts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build two new Power Automate flows — a weekly full-list digest and a daily new-item alert — that notify parts/branch staff per-branch about open MD (Machine Down) invoices missing freight or significantly under-charging it, reusing the Low Margin flows' recipient/distribution plumbing but with turquoise (weekly) / amber (daily) styling distinct from both Parts Action (navy) and Low Margin (purple/red).

**Architecture:** Two independent flows, built by reading an existing Low Margin flow's JSON (`get_flow`) as a structural template and hand-authoring the new flow via `create_flow` — **not** `copy_flow`/`edit_flow`, which are confirmed broken in this environment (see Low Margin's `POWER-AUTOMATE-SETUP.md` Known Issues #1). Flow A queries `Fact_MDInvoices_NoFreight` for every open invoice currently in "No Freight" or "Partial Freight ≥ 10%" and sends weekly. Flow B runs daily, diffs the current qualifying invoice set against a new SharePoint tracking list to isolate newly-crossed invoices, and only emails branches with something new.

**Tech Stack:** Power Automate (cloud flows), Power BI REST API (`executeQueries` via HTTP action, DAX), SharePoint Online (tracking list), Microsoft Graph API (mail send, reusing the existing "Parts Action Dashboard Email" app registration), Fabric semantic model "MD Invoices With No Freight".

**Domain note for the executor:** This is a low-code build, not a traditional codebase — there is no unit test suite. "Test" steps in this plan mean: running DAX queries live via `pbi dax execute` against Power BI Desktop, and running flows live via the `mcp__plugin_power-automate_flowagent` tools (`run_flow`, `get_run_history`, `diagnose_run`) and checking the actual output (query results, run status, received email). Treat every DAX/HTML/JSON block below as exact content to use, not a sketch. **All test emails go to `bfox@spitractor.com` only — never to any real parts-department recipient** — and both Orchestrators must be left in a **Stopped/disabled** state at the end of this plan; nothing here goes live.

---

## Known IDs and Reused Infrastructure

Confirmed via `fab get` against the live workspace and the Low Margin flows' own setup doc — use these exactly, do not re-derive:

| Item | Value |
|---|---|
| Workspace ("RP - Parts Reports") Group ID | `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7` |
| "MD Invoices With No Freight" Dataset ID | `88bcada9-ceeb-42e5-99f9-9b6cd06a9f0d` |
| Power Platform environment (no Dataverse — the correct one) | `2cf47cce-a195-ed3a-94e1-287c38adb011` — call `set_current_env` to this before any flow operation; the tenant has a second, unrelated environment with the identical display name "Brian Fox's Environment" |
| SPI-PARTS Azure AD group + officeLocation recipient pipeline | Reused as-is — read the exact group ID from the `HTTP - Get Users` action inside the reference flow via `get_flow`, do not hand-type it |
| PartsBranchMapping SharePoint list (site: South Plains Implement - Report Site, GUID `19da5d2c-18b8-4359-8c0b-9a4e2711210d`) | Reused as-is — `OfficeLocation` → `BranchFilter` (e.g. `"11 - Brownfield"`) |
| "Parts Action Dashboard Email" Entra app registration (Mail.Send, GroupMember.Read.All, User.Read.All) | Reused as-is for both new flows' HTTP Get Users and sendMail actions |
| Power BI connection reference | `shared_powerbi` (`shared-powerbi-04fe5718-dd42-4f4b-8e94-555dfbfdc0c1`) |
| SharePoint connection reference | `shared_sharepointonline-1` on Orchestrators, bare `shared_sharepointonline` on manual/test flows (the auto-discovered `shared-sharepointonl-8446ffb5-...` connection is broken — do not use it) |
| Reference flow to read for Flow A structure | "Low Margin Weekly Digest - Orchestrator" (flow ID `dad7ae83-e6d8-4f63-af15-7c33c734b025`) |
| Reference flow to read for Flow B structure | "Low Margin New Item Alert - Orchestrator" (flow ID `66e29bef-7838-4b01-9e6b-c4a8562fb51d`) |
| Reference flow to read for Flow A test child | "Low Margin Weekly Digest - Branch Email" (flow ID `134dadf0-0ad8-4d0c-ae44-45206184ccc2`) |
| Reference flow to read for Flow B test child | "Low Margin New Item Alert - Branch Email" (flow ID `f6c9fd72-9279-424b-898a-8bc7a8eaf802`) |

---

## Confirmed Model Fields (from `Fact_MDInvoices_NoFreight.tmdl` and `_Measures.tmdl`)

`Fact_MDInvoices_NoFreight` raw columns used: `FileNumber`, `RONumber`, `OrderDate`, `Branch`, `PartNumber`, `OrderQty`, `TotalLineWeight`, `TotalFreightCharged`, `FreightStatus`, plus calculated columns `MissedFreightAmount`, `PctFreightDifference` (raw decimal, e.g. `0.411` = 41.1%), `FreightBucket` (`"No Freight"` / `"Partial Freight"` / `"Adequate Freight"`).

`_Measures` used for display values, called exactly as the live report's own Open Orders matrix calls them — **do not "fix" `Sell Price 1`**, it is defined as `SUM(Fact_MDInvoices_NoFreight[UnitCost])` in production (a pre-existing naming quirk, not a bug to correct here):

```
'Sell Price 1'   = SUM(Fact_MDInvoices_NoFreight[UnitCost])
'Unit Price'     = SUM(Fact_MDInvoices_NoFreight[UnitPrice])
'Order Qty'      = SUM(Fact_MDInvoices_NoFreight[OrderQty])
'Total Weight'   = SUM(Fact_MDInvoices_NoFreight[TotalLineWeight])
'Actual Freight' = SUMX(VALUES(FileNumber), CALCULATE(MAX(TotalFreightCharged)))
'Calculated Freight' = SUMX(VALUES(FileNumber), <bracket lookup against FreightCalculator on total order weight>)
'Missed Freight' = [Calculated Freight] - [Actual Freight]
'% Freight Difference' = DIVIDE([Calculated Freight] - [Actual Freight], ([Calculated Freight] + [Actual Freight]) / 2, BLANK())
```

**Row-context gotcha found while writing this plan (verify in Task 1, do not skip):** `'Total Weight'`, `'Actual Freight'`, `'Calculated Freight'`, `'Missed Freight'`, and `'% Freight Difference'` all internally dedupe via `SUMX(VALUES(Fact_MDInvoices_NoFreight[FileNumber]), ...)` with **no `ALLEXCEPT`**. Called from inside a `SELECTCOLUMNS`/`ADDCOLUMNS` row iteration over the line-grain fact table (one row per part line), the implicit context-transition filters on *every* column of the current row (not just `FileNumber`) — so instead of returning the true invoice-level total, the measure would silently return just that single line's own value, which is wrong for any invoice with more than one part line. `MissedFreightAmount`/`PctFreightDifference` (the calculated *columns*) already solve this correctly with an explicit `ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])`. The DAX in Task 1 below applies the same fix by wrapping each of those five measures in `CALCULATE([Measure], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber]))` wherever they're read per line — this restores full-invoice context before the measure's own `SUMX(VALUES(FileNumber), ...)` runs, so multi-line invoices show the correct repeated invoice-level total on every one of their part-line rows (matching what the live matrix shows when a row is expanded). `Total Weight` belongs in this wrapped group because the freight bracket lookup keys on the **order's total weight**, not any single line's weight — it is not a per-line figure despite the name similarity to `TotalLineWeight`. `Order Qty`, `Sell Price 1`, `Unit Price` are the genuinely per-line values and must **not** be wrapped this way — each part line's own quantity/price is exactly what should show, no dedup needed there.

**Confirmed live (2026-07-24, via independent double DAX validation against Branch `11 - Brownfield`):** invoice `1508170` (3 part lines) — with the `ALLEXCEPT` wrap, all three lines correctly return the identical invoice-level `Weight=85.7693`, `Actual Freight=154.86`, `Calculated Freight=234.930862`, `% Freight Difference=0.41084`, `Missed Freight=80.07086`. Without the wrap, the same three lines return wrong, inconsistent per-line values for `Missed Freight` (`-116.04`, `-52.15`, `+6.25` instead of `+80.07` on all three) — proving the fix is necessary, not cosmetic. Also found and worked around during validation: `pbi-cli`'s `pbi dax execute` command silently drops DAX row results (`EmbeddedResource` content blocks aren't read by its `_parse_content()`, only `TextContent` blocks are) — it always reports `{"success": true}` with no data, for every query. Use a direct `mcp` client script against the `pbi-cli-tool`-bundled `powerbi-modeling-mcp.exe` server instead when running DAX validation until this is fixed upstream.

**Second bug found live (2026-07-24, during Task 4's flow test run) — `FileNumber`/`RONumber` JSON type mismatch:** `FileNumber` and `RONumber` are `int64` columns in the model (confirmed via `Fact_MDInvoices_NoFreight.tmdl`), so Power BI's `executeQueries` REST API serializes `"Invoice #"`/`"RO #"` as JSON **integers**. The flow's `Parse JSON` action schema declares both as `"type": "string"` (correct — they're used downstream as SharePoint tracking-list keys, "Single line text" columns, and as diff/lookup keys, so they must be text end-to-end), which caused a hard schema-validation failure on the first live test run (`Invalid type. Expected String but got Integer.`). **Fix: wrap both in `FORMAT(..., "0")` in the DAX itself**, forcing them to serialize as JSON strings unconditionally — this is now baked into the query text below (do not remove it). No other columns needed this (`OrderDate` and `Branch` are already string/dateTime-as-string at the source; the numeric measures like `Order Qty`/`Weight`/`Actual Freight`/etc. are intentionally left as JSON numbers).

**Qualification filter (Ben's rule, hardcoded, independent of the report's own adjustable slider):**
```
Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"
    || (Fact_MDInvoices_NoFreight[FreightBucket] = "Partial Freight"
        && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
```
Filter directly on `Fact_MDInvoices_NoFreight` columns, not `dim_BranchLocation` — but branch selection still goes through `dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"` in a separate `CALCULATETABLE` filter argument, matching every other flow's DAX in this repo (relationship-based branch filtering, not a direct column filter on the fact table).

---

## Task 1: Validate the DAX queries against the live model

**Files:** none (live validation only)

- [ ] **Step 1: Open the report in Power BI Desktop**

Open `projects/md invoices with no freight - report/reports/current/MD Invoices With No Freight.pbip` in Power BI Desktop and let it fully load. (It may already be open — if so, just confirm it's the current file.)

- [ ] **Step 2: Connect via the `pbi` CLI**

```bash
pbi connect
```
Expected: detects the open Desktop instance and reports a connection name like `PBIDesktop-MD Invoices With No Freight-XXXXX`.

- [ ] **Step 3: Run the detail (Invoice+Part row) query for one known branch**

```bash
pbi dax execute "EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = \"No Freight\"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = \"Partial Freight\"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        \"Invoice #\", FORMAT(Fact_MDInvoices_NoFreight[FileNumber], \"0\"),
        \"RO #\", FORMAT(Fact_MDInvoices_NoFreight[RONumber], \"0\"),
        \"Order Date\", Fact_MDInvoices_NoFreight[OrderDate],
        \"Branch\", Fact_MDInvoices_NoFreight[Branch],
        \"Part Number\", Fact_MDInvoices_NoFreight[PartNumber],
        \"Order Qty\", [Order Qty],
        \"Sell Price 1\", [Sell Price 1],
        \"Unit Price\", [Unit Price],
        \"Weight\", CALCULATE([Total Weight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        \"Actual Freight\", CALCULATE([Actual Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        \"Calculated Freight\", CALCULATE([Calculated Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        \"% Freight Difference\", CALCULATE([% Freight Difference], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        \"Missed Freight\", CALCULATE([Missed Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber]))
    ),
    dim_BranchLocation[Branch] = \"11 - Brownfield\"
)"
```

Expected: a table of rows, every `FreightBucket` behind the scenes is either No Freight or Partial Freight ≥ 10% (spot-check by cross-referencing a couple of `Invoice #` values against the live Open Orders matrix). Pick a branch with at least one multi-part-line MD invoice for this test — Brownfield is a good candidate given its order volume.

- [ ] **Step 4: Confirm the multi-line invoice fix is actually needed and actually works**

In Power BI Desktop, open the Open Orders page, expand one multi-part-line invoice in the matrix (so `Part Number` rows are visible under it), and note its `Weight`, `Actual Freight`, `Calculated Freight`, `% Freight Difference`, `Missed Freight` values — these should be **identical across every part-line row** for that invoice (they're invoice-level, not line-level, figures).

Then re-run Step 3's query filtered to just that invoice:
```bash
pbi dax execute "EVALUATE FILTER(<Step 3 query table>, [Invoice #] = <that FileNumber>)"
```
(Simplest: temporarily change Step 3's `FILTER(...)` condition to `Fact_MDInvoices_NoFreight[FileNumber] = <that FileNumber>` and drop the branch filter, then re-run.)

Expected: every returned row for that invoice shows the same `Weight`/`Actual Freight`/`Calculated Freight`/`% Freight Difference`/`Missed Freight`, matching the Desktop matrix. **If they don't match** (e.g. `Weight` is much smaller than the matrix total, or varies row to row), the `ALLEXCEPT` wrap isn't working as expected — stop and re-diagnose before proceeding; every later task's CSV/email content depends on this being correct.

- [ ] **Step 5: Run the aggregate KPI query for the same branch**

```bash
pbi dax execute "EVALUATE
ROW(
    \"InvoicesFlagged\", COALESCE(CALCULATE(
        DISTINCTCOUNT(Fact_MDInvoices_NoFreight[FileNumber]),
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = \"No Freight\"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = \"Partial Freight\"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        dim_BranchLocation[Branch] = \"11 - Brownfield\"), 0),
    \"OpportunityDollars\", COALESCE(CALCULATE(
        SUMX(
            VALUES(Fact_MDInvoices_NoFreight[FileNumber]),
            CALCULATE([Missed Freight])
        ),
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = \"No Freight\"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = \"Partial Freight\"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        dim_BranchLocation[Branch] = \"11 - Brownfield\"), 0)
)"
```

Expected: `InvoicesFlagged` matches the count of distinct `Invoice #` values from Step 3's output, `OpportunityDollars` is a positive dollar figure. Sanity-check `OpportunityDollars` by hand: sum `Missed Freight` from Step 3's output after de-duplicating to one row per `Invoice #` (since it repeats per part line) — the two totals should match.

- [ ] **Step 6: Run the distinct-invoice-keys query (used by Flow B's diff logic)**

```bash
pbi dax execute "EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        SUMMARIZE(
            FILTER(
                Fact_MDInvoices_NoFreight,
                Fact_MDInvoices_NoFreight[FreightBucket] = \"No Freight\"
                    || (Fact_MDInvoices_NoFreight[FreightBucket] = \"Partial Freight\"
                        && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
            ),
            Fact_MDInvoices_NoFreight[FileNumber]
        ),
        \"Invoice #\", FORMAT(Fact_MDInvoices_NoFreight[FileNumber], \"0\")
    ),
    dim_BranchLocation[Branch] = \"11 - Brownfield\"
)"
```

Expected: one row per distinct qualifying `Invoice #`, row count equals `InvoicesFlagged` from Step 5. `Invoice #` must come back as a JSON string here too (same `FORMAT()` reasoning as Step 3) — this query's output feeds Flow B's `CurrentKeys` array, which gets diffed against the SharePoint tracking list's text-typed `FileNumber` column.

- [ ] **Step 7: Confirm all three counts agree**

`InvoicesFlagged` (Step 5) = distinct `Invoice #` count from Step 3 = row count from Step 6. If they don't match, stop and re-check the filter logic before proceeding to Task 2 — every later task depends on these three queries being correct and consistent.

---

## Task 2: Create the SharePoint tracking list

**Files:** none (SharePoint UI — no repo artifact)

- [ ] **Step 1: Create the list**

In the "South Plains Implement - Report Site" SharePoint site (same site as `PartsBranchMapping` and `LowMarginPartsTracking`), create a new list named `MDFreightTracking` with these columns:

| Column | Type | Notes |
|---|---|---|
| Title | Single line text | Default column, unused |
| FileNumber | Single line text | The MD invoice number — matches `Fact_MDInvoices_NoFreight[FileNumber]` exactly (store as text even though the source is numeric, matching how `PartBranchKey` is stored as text on `LowMarginPartsTracking`) |
| Branch | Single line text | Store in `BranchFilter` format (e.g. `"11 - Brownfield"`) to match `PartsBranchMapping` and simplify per-branch `Get_items` filtering |
| FirstFlaggedDate | Date and Time | Set when the item is created (the date it was first detected qualifying) |

- [ ] **Step 2: Record the list GUID**

Note the list's GUID (visible in List Settings → General Settings, or in the URL) — it will be needed for the `Get_items`/`Create item`/`Delete item` actions in Task 5.

---

## Task 3: Build Flow A — MD Freight Weekly Digest

**Files:** none (Power Automate cloud flow, built via MCP tool calls)

- [ ] **Step 1: Set the correct environment**

```
mcp__plugin_power-automate_flowagent__set_current_env(environment: "2cf47cce-a195-ed3a-94e1-287c38adb011")
```

- [ ] **Step 2: Read the Low Margin Weekly Digest Orchestrator as a structural template**

```
mcp__plugin_power-automate_flowagent__get_flow(flow_name: "Low Margin Weekly Digest - Orchestrator")
```
Note its recipient-pipeline actions (HTTP - Get Users incl. the SPI-PARTS group ID, `Apply to each`, SKIP condition, PartsBranchMapping `Get_items` + `Condition_1`, the variable-set actions for `RecipientName`/`RecipientBranchName`/`RecipientBranchFilter`/`RecipientEmail`) and the final `HTTP: Graph API sendMail` action shape (auth block, connection refs, attachment structure) — these get carried over unchanged into the new flow.

- [ ] **Step 3: Create the new flow**

```
mcp__plugin_power-automate_flowagent__create_flow(
  flow_name: "MD Freight Weekly Digest - Orchestrator"
)
```
Build its definition using `get_current_flow`/`update_flow` iteratively (per the connection-reference gotcha noted below), assembling:
- Recurrence trigger: `frequency: "Week"`, `interval: 1`, `schedule: { weekDays: ["Monday"] }`, `startTime` set for 9:00 AM, `timeZone: "Central Standard Time"` (placeholder schedule — not going live yet, see plan header).
- The same `HTTP - Get Users`, `Apply to each`, SKIP condition, PartsBranchMapping lookup, and variable-set actions read in Step 2, unchanged (same SPI-PARTS group ID and PartsBranchMapping list GUID `19da5d2c-18b8-4359-8c0b-9a4e2711210d`).
- **Connection-reference gotcha:** `update_flow` rejects an explicit `authentication` property in `OpenApiConnection` action `inputs` and requires `host.connectionReferenceName` in addition to `host.connectionName`. Any connector action (Power BI HTTP, SharePoint `Get_items`) must have a matching entry in the top-level `connectionRefs` at creation time — entries not referenced by an action at creation time get silently pruned, and a later `update_flow` referencing them by name will fail with "connection reference could not be found."

- [ ] **Step 4: Add the detail query action**

Add an HTTP action `Run_Detail_Query` (POST to the Power BI REST API `executeQueries` endpoint, dataset `88bcada9-ceeb-42e5-99f9-9b6cd06a9f0d`, workspace `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7`, connection reference `shared_powerbi`). Query text — the exact DAX validated in Task 1 Step 3, with `dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"` in place of the hardcoded `"11 - Brownfield"`.
Follow with `Parse JSON` on the response (same schema pattern as the Low Margin flow's detail-query `Parse JSON` step — 10-column table: `Invoice #`, `RO #`, `Order Date`, `Branch`, `Part Number`, `Order Qty`, `Sell Price 1`, `Unit Price`, `Weight`, `Actual Freight`, `Calculated Freight`, `% Freight Difference`, `Missed Freight`).

- [ ] **Step 5: Add the aggregate query action**

Add a second HTTP action `Run_Aggregate_Query`, same connection, using the exact DAX validated in Task 1 Step 5 (again with `@{variables('RecipientBranchFilter')}` substituted in). Follow with `Parse JSON`, then `Compose: InvoicesFlagged` = `body('Parse_JSON_Aggregate')?['results'][0]['tables'][0]['rows'][0]['[InvoicesFlagged]']` and `Compose: OpportunityDollars` = the equivalent for `[OpportunityDollars]`.

- [ ] **Step 6: Add the CSV attachment**

Add `Create CSV table` (Data Operations connector), input: `body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows']`, columns: Custom, mapping each of the 13 header names to its corresponding `item()?['<ColName>']` expression: `Invoice #`, `RO #`, `Order Date`, `Branch`, `Part Number`, `Order Qty`, `Sell Price 1`, `Unit Price`, `Weight`, `Actual Freight`, `Calculated Freight`, `% Freight Difference`, `Missed Freight`.

- [ ] **Step 7: Compose the HTML body**

Add `Compose: HTML Body`:

```html
<div style="font-family:Segoe UI,Arial,sans-serif; font-size:13px; max-width:600px;">
  <div style="background:#0e8a9c; color:#fff; padding:14px 16px; border-left:6px solid #6fd0dc;">
    <div style="font-size:16px; font-weight:600;">MD Freight Weekly Digest</div>
    <div style="font-size:12px; opacity:.85;">@{variables('RecipientBranchName')} — Week of @{formatDateTime(utcNow(),'MMMM d, yyyy')}</div>
  </div>
  <div style="display:flex; gap:8px; padding:14px 16px;">
    <div style="flex:1; background:#e9f7f9; border-radius:6px; padding:10px; text-align:center; border:1px solid #c3e8ec;">
      <div style="font-size:20px; font-weight:700; color:#0e8a9c;">@{outputs('Compose_InvoicesFlagged')}</div>
      <div style="font-size:11px; color:#555;">Invoices Flagged</div>
    </div>
    <div style="flex:1; background:#e9f7f9; border-radius:6px; padding:10px; text-align:center; border:1px solid #c3e8ec;">
      <div style="font-size:20px; font-weight:700; color:#c98a1c;">@{formatNumber(outputs('Compose_OpportunityDollars'),'C')}</div>
      <div style="font-size:11px; color:#555;">Opportunity</div>
    </div>
  </div>
  <div style="padding:0 16px 16px;">
    <div style="font-size:12px; color:#888;">Full detail attached: MD_Freight_Missed.csv</div>
  </div>
</div>
```

- [ ] **Step 8: Repoint the sendMail action**

Update the `HTTP: Graph API sendMail` body: subject = `"MD Freight Weekly Digest — @{variables('RecipientBranchName')}"`, body content = `outputs('Compose_HTML_Body')`, attachment = single item built from `outputs('Create_CSV_table')` base64-encoded, filename `MD_Freight_Missed.csv`. To recipient = `variables('RecipientEmail')`, using the same Graph API auth block read in Step 2.

- [ ] **Step 9: Save and validate**

```
mcp__plugin_power-automate_flowagent__preflight_flow(flow_name: "MD Freight Weekly Digest - Orchestrator")
mcp__plugin_power-automate_flowagent__validate_flow(flow_name: "MD Freight Weekly Digest - Orchestrator")
```
Expected: no errors. Fix any reported issues before continuing.

- [ ] **Step 10: Ensure the flow is stopped**

```
mcp__plugin_power-automate_flowagent__disable_flow(flow_name: "MD Freight Weekly Digest - Orchestrator")
```
Expected: flow state is Stopped/Off. This flow must not run on a schedule until Brian explicitly approves go-live.

---

## Task 4: Build the Flow A manual test child flow

**Files:** none (Power Automate cloud flow)

- [ ] **Step 1: Read the Low Margin test flow as a structural template**

```
mcp__plugin_power-automate_flowagent__get_flow(flow_name: "Low Margin Weekly Digest - Branch Email")
```
Note its Button trigger with 4 manual inputs (`RecipientName`, `RecipientBranchName`, `RecipientBranchFilter`, `RecipientEmail`) — same shape, no loop/SharePoint lookup needed.

- [ ] **Step 2: Create the new test flow**

```
mcp__plugin_power-automate_flowagent__create_flow(
  flow_name: "MD Freight Weekly Digest - Branch Email"
)
```
Build it with the same Button trigger and 4 inputs, then apply the same step content as Task 3 Steps 4-8 (detail/aggregate query, CSV, HTML, sendMail — identical DAX and HTML, just reading the 4 manual inputs instead of loop variables). Use connection reference `shared_sharepointonline` (bare, no `-1` suffix) for any SharePoint action, matching the Low Margin test flow's pattern.

- [ ] **Step 3: Validate**

```
mcp__plugin_power-automate_flowagent__preflight_flow(flow_name: "MD Freight Weekly Digest - Branch Email")
mcp__plugin_power-automate_flowagent__validate_flow(flow_name: "MD Freight Weekly Digest - Branch Email")
```
Expected: no errors.

- [ ] **Step 4: Run it manually against a real branch, sending to yourself only**

Button-triggered flows cannot be invoked via the flowagent `run_flow` tool (`ListCallbackUrlOperationBlocked` — confirmed in the Low Margin build). Run it manually from make.powerautomate.com → flow → **Run**, with inputs:
```
RecipientName: Test
RecipientBranchName: Brownfield
RecipientBranchFilter: 11 - Brownfield
RecipientEmail: bfox@spitractor.com
```

- [ ] **Step 5: Verify the run**

```
mcp__plugin_power-automate_flowagent__get_run_history(flow_name: "MD Freight Weekly Digest - Branch Email")
```
Expected: latest run status `Succeeded`. Open the received test email (at `bfox@spitractor.com`) and confirm: turquoise-accented layout matches the approved mockup, KPI numbers match Task 1 Step 5's output for Brownfield, and `MD_Freight_Missed.csv` is attached with all 13 columns and the same row count as Task 1 Step 3 — including confirming that a multi-part-line invoice shows identical `Weight`/`Actual Freight`/`Calculated Freight`/`% Freight Difference`/`Missed Freight` across its part-line rows.

---

## Task 5: Build Flow B — MD Freight New Item Alert

**Files:** none (Power Automate cloud flow)

- [ ] **Step 1: Read the Low Margin New Item Alert Orchestrator as a structural template**

```
mcp__plugin_power-automate_flowagent__get_flow(flow_name: "Low Margin New Item Alert - Orchestrator")
```
Note its diff logic shape (`Compose: CurrentKeys`, `Get_items` on the tracking list, `Compose: PreviousKeys`, `Compose: ToAdd`/`Compose: ToRemove` via `difference()`, the `Apply_to_each_ToAdd`/`Apply_to_each_ToRemove` sync loops, and the `Condition: Should Send Alert` gate).

- [ ] **Step 2: Create the new flow with a daily weekday trigger**

```
mcp__plugin_power-automate_flowagent__create_flow(
  flow_name: "MD Freight New Item Alert - Orchestrator"
)
```
Recurrence trigger: `frequency: "Week"`, `interval: 1`, `schedule: { weekDays: ["Monday","Tuesday","Wednesday","Thursday","Friday"] }` (per the known `weekDays` requires `frequency: "Week"` gotcha — `"Day"` frequency does not support `weekDays`), `startTime` at 9:00 AM, `timeZone: "Central Standard Time"`.
Same recipient pipeline (`HTTP - Get Users`, `Apply to each`, SKIP condition, PartsBranchMapping lookup, variable sets) as Task 3 Step 3.

- [ ] **Step 3: Add the detail query action**

Same as Task 3 Step 4 — add `Run_Detail_Query` with the identical validated DAX from Task 1 Step 3, `dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"`. Follow with `Parse JSON`.

- [ ] **Step 4: Add the current-keys query action**

Add a third HTTP action `Run_Current_Keys_Query`, same connection, using the DAX validated in Task 1 Step 6 (again with `@{variables('RecipientBranchFilter')}` substituted in). Follow with `Parse JSON`, then `Compose: CurrentKeys` = `select(body('Parse_JSON_CurrentKeys')?['results'][0]['tables'][0]['rows'], item()?['[Invoice #]'])`.

- [ ] **Step 5: Get previously-tracked keys for this branch**

Add `Get_items (SharePoint)` on the `MDFreightTracking` list, filter: `Branch eq '@{variables('RecipientBranchFilter')}'`. Follow with `Compose: PreviousKeys` = `select(body('Get_items_Tracking')?['value'], item()?['FileNumber'])`.

- [ ] **Step 6: Compute newly-crossed and resolved keys**

Add `Compose: ToAdd` = `difference(outputs('Compose_CurrentKeys'), outputs('Compose_PreviousKeys'))`.
Add `Compose: ToRemove` = `difference(outputs('Compose_PreviousKeys'), outputs('Compose_CurrentKeys'))`.

- [ ] **Step 7: Sync the tracking list**

Add `Apply_to_each_ToAdd` over `outputs('Compose_ToAdd')`: inside, `Create item` (SharePoint, `MDFreightTracking`) using `FileNumber` = the current loop item, `Branch` = `variables('RecipientBranchFilter')`, `FirstFlaggedDate` = `utcNow()`.
Add `Apply_to_each_ToRemove` over `outputs('Compose_ToRemove')`: inside, `Filter_array` on `body('Get_items_Tracking')?['value']` where `FileNumber` equals the current loop item, then `Delete item` (SharePoint) using the matched item's `ID`.

- [ ] **Step 8: Add the send condition**

Add `Condition: Should Send Alert` = `length(outputs('Compose_ToAdd'))` greater than `0`.

- [ ] **Step 9: (TRUE branch) Filter detail rows to the new invoices only**

Add `Filter_array: NewItemRows` on `body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows']` where `contains(outputs('Compose_ToAdd'), item()?['[Invoice #]'])`. This keeps every part-line row belonging to a newly-crossed invoice.

- [ ] **Step 10: Build the CSV attachment**

Add `Create CSV table`, input: `body('Filter_array_NewItemRows')`, same 13-column mapping as Task 3 Step 6.

- [ ] **Step 11: Build the alert table**

Add `Create HTML table: NewItemsTable`, input: `body('Filter_array_NewItemRows')`, columns: Custom — `Invoice #` = `item()?['[Invoice #]']`, `Branch` = `item()?['[Branch]']`, `% Freight Difference` = `formatNumber(item()?['[% Freight Difference]'], 'P1')`.

- [ ] **Step 12: Compose the HTML body**

Add `Compose: HTML Body`:

```html
<div style="font-family:Segoe UI,Arial,sans-serif; font-size:13px; max-width:600px;">
  <div style="background:linear-gradient(135deg,#d97a1f,#b8590f); color:#fff; padding:14px 16px;">
    <div style="font-size:12px; letter-spacing:1px; text-transform:uppercase; opacity:.9;">⚠ New Freight Alert</div>
    <div style="font-size:16px; font-weight:600; margin-top:2px;">@{length(outputs('Compose_ToAdd'))} invoice(s) just crossed threshold</div>
    <div style="font-size:12px; opacity:.85;">@{variables('RecipientBranchName')} — @{formatDateTime(utcNow(),'MMMM d, yyyy')}</div>
  </div>
  <div style="margin-top:10px;">
    @{body('Create_HTML_table_NewItemsTable')}
  </div>
  <div style="padding:12px 16px 0;">
    <div style="font-size:12px; color:#888;">Full detail attached: New_MD_Freight_Missed.csv</div>
  </div>
</div>
```

- [ ] **Step 13: Repoint the sendMail action**

Same as Task 3 Step 8: subject = `"New Freight Alert — @{variables('RecipientBranchName')}"`, body = `outputs('Compose_HTML_Body')`, attachment from `outputs('Create_CSV_table')`, filename `New_MD_Freight_Missed.csv`. Move this action, and Steps 9-12, inside the `Condition: Should Send Alert` TRUE branch — nothing sends on the FALSE branch.

- [ ] **Step 14: Save and validate**

```
mcp__plugin_power-automate_flowagent__preflight_flow(flow_name: "MD Freight New Item Alert - Orchestrator")
mcp__plugin_power-automate_flowagent__validate_flow(flow_name: "MD Freight New Item Alert - Orchestrator")
```
Expected: no errors.

- [ ] **Step 15: Ensure the flow is stopped**

```
mcp__plugin_power-automate_flowagent__disable_flow(flow_name: "MD Freight New Item Alert - Orchestrator")
```
Expected: flow state is Stopped/Off.

---

## Task 6: Build the Flow B manual test child flow

**Files:** none (Power Automate cloud flow)

- [ ] **Step 1: Read the Low Margin test flow as a structural template**

```
mcp__plugin_power-automate_flowagent__get_flow(flow_name: "Low Margin New Item Alert - Branch Email")
```

- [ ] **Step 2: Create the new test flow**

```
mcp__plugin_power-automate_flowagent__create_flow(
  flow_name: "MD Freight New Item Alert - Branch Email"
)
```
Same Button trigger with 4 manual inputs, then apply the same step content as Task 5 Steps 3-13, using the 4 manual inputs in place of the loop variables. Connection reference `shared_sharepointonline` (bare) for SharePoint actions.

- [ ] **Step 3: Validate**

```
mcp__plugin_power-automate_flowagent__preflight_flow(flow_name: "MD Freight New Item Alert - Branch Email")
mcp__plugin_power-automate_flowagent__validate_flow(flow_name: "MD Freight New Item Alert - Branch Email")
```
Expected: no errors.

- [ ] **Step 4: First test run — establish baseline**

Run manually from make.powerautomate.com → flow → **Run**, with inputs:
```
RecipientName: Test
RecipientBranchName: Brownfield
RecipientBranchFilter: 11 - Brownfield
RecipientEmail: bfox@spitractor.com
```
Expected: since `MDFreightTracking` starts empty for this branch, every currently-qualifying invoice is "new" — confirm `get_run_history` shows `Succeeded` and the test email (at `bfox@spitractor.com`) lists the full current qualifying invoice set for Brownfield (matching Task 1 Step 5's `InvoicesFlagged` count), and confirm in SharePoint that `MDFreightTracking` now has one row per invoice for Branch `"11 - Brownfield"`.

- [ ] **Step 5: Second test run — confirm no false alerts**

Run it again immediately with the same inputs.
Expected: `ToAdd` and `ToRemove` are both empty (nothing changed since Step 4), the `Should Send Alert` condition evaluates false, no email is sent, and `get_run_history` still shows `Succeeded` (a no-op run, not a failure).

- [ ] **Step 6: Third test run — confirm resolution removes tracking**

In SharePoint, manually delete one row from `MDFreightTracking` for Branch `"11 - Brownfield"` (simulating that invoice having been resolved — freight added or corrected — since the last run; this is the one case `ToRemove` fires on, since the live data hasn't actually changed).
Run the flow again.
Expected: that one key appears in `ToRemove` and its SharePoint row gets recreated (since the underlying data still shows it qualifying) — confirming the add/remove sync logic runs both directions correctly, even though in production `ToRemove` will only be non-empty when an invoice actually gets resolved or closed.

---

## Task 7: Write project documentation

**Files:**
- Create: `projects/md invoices with no freight - report/docs/power-automate/POWER-AUTOMATE-SETUP.md`
- Modify: `projects/md invoices with no freight - report/CLAUDE.md`

- [ ] **Step 1: Write the setup doc**

Create `projects/md invoices with no freight - report/docs/power-automate/POWER-AUTOMATE-SETUP.md`, mirroring the structure of `projects/part sales with low margin/docs/06-power-automate/POWER-AUTOMATE-SETUP.md`: Flow Overview table (both flows, including flow IDs once known post-creation), Architecture (the two-flow structure + shared infrastructure reuse), the confirmed IDs table from this plan's header, the full validated DAX queries from Task 1 (detail, aggregate, current-keys), the row-context/`ALLEXCEPT` gotcha called out in this plan's "Confirmed Model Fields" section, the SharePoint tracking-list schema from Task 2, the add/remove sync logic from Task 5 Steps 4-7, and a Troubleshooting table covering: no email received (check `MDFreightTracking` — did anything actually change?), wrong branch data (verify `PartsBranchMapping` `BranchFilter` matches `dim_BranchLocation[Branch]` exactly), CSV missing columns (check the `Create CSV table` column mapping against the 13-column list), multi-line invoice showing wrong freight totals (check the `ALLEXCEPT` wrap on the four repeated-value measures), sendMail 401 (same app registration secret as Parts Action/Low Margin — see those flows' troubleshooting entries).

- [ ] **Step 2: Update the project CLAUDE.md**

Add a section to `projects/md invoices with no freight - report/CLAUDE.md` (after the "Documentation Status" section) pointing to the new doc:

```markdown
## Power Automate Alerts
Two flows alert on open MD invoices in `Fact_MDInvoices_NoFreight` where
`FreightBucket = "No Freight"` or (`FreightBucket = "Partial Freight"` and
`PctFreightDifference >= 10%`):
- **MD Freight Weekly Digest** — full current list, weekly (placeholder Monday 9:00 AM CST)
- **MD Freight New Item Alert** — only newly-crossed invoices, daily (placeholder Mon-Fri 9:00 AM CST)

Both reuse the Parts Action Summary / Low Margin distribution pipeline (SPI-PARTS
group + PartsBranchMapping) but with distinct turquoise/amber styling so they're
never confused with the Parts Action or Low Margin emails. Both Orchestrators are
built and fully tested but left **Stopped** — no schedule has gone live yet. See
`docs/power-automate/POWER-AUTOMATE-SETUP.md` for full detail, flow IDs, and the
row-context gotcha found while replicating the report's own freight measures at
line grain.
```

- [ ] **Step 3: Commit the documentation**

```bash
git add "projects/md invoices with no freight - report/docs/power-automate/POWER-AUTOMATE-SETUP.md" "projects/md invoices with no freight - report/CLAUDE.md"
git commit -m "Document Power Automate MD Freight alert flows"
```
Expected: commit succeeds, `git status` shows a clean working tree for these two paths.

---

## Self-Review Notes

- **Spec coverage:** Every section of `docs/superpowers/specs/2026-07-24-md-freight-alerts-design.md` maps to a task — data/threshold + row-context correctness (Task 1), tracking list (Task 2), Flow A weekly digest with HTML+CSV (Tasks 3-4), Flow B daily alert with HTML+CSV and state tracking (Tasks 5-6), shared infrastructure reuse (noted throughout, no separate task needed since nothing new is created besides the tracking list), documentation (Task 7). Both Orchestrators explicitly left Stopped (Task 3 Step 10, Task 5 Step 15) and all test sends restricted to `bfox@spitractor.com` (Tasks 4 and 6), matching the spec's Rollout/Testing section.
- **New finding beyond the original spec:** the `SUMX(VALUES(FileNumber), ...)` row-context gap in `Actual Freight`/`Calculated Freight`/`Missed Freight`/`% Freight Difference` when called per part-line row (not from the matrix's own invoice-level grouping context) wasn't discussed during brainstorming — surfaced here rather than silently baked in, with an explicit live-validation step (Task 1 Step 4) before anything is built on top of it.
- **Naming consistency:** `Invoice #` (mapped from `FileNumber`) is used identically across the DAX (Task 1), the SharePoint tracking schema's `FileNumber` column (Task 2), the CSV column mapping (Tasks 3, 5), and the diff logic (Task 5) — verified no drift between tasks. `MDFreightTracking` list name and its three columns (`FileNumber`, `Branch`, `FirstFlaggedDate`) are used identically in Task 2's creation and Task 5's `Get_items`/`Create item`/`Delete item` actions.
