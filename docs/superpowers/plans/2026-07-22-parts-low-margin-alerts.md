# Parts Low Margin Alerts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build two new Power Automate flows — a weekly full-list digest and a daily new-item alert — that notify parts staff per-branch when inventory is priced below 20% margin, reusing the Parts Action Summary's recipient/distribution plumbing but with a visually distinct email design.

**Architecture:** Two independent flows, each built by cloning the existing "Parts Action Summary - Orchestrator" flow (via the Power Automate `copy_flow` tool) and replacing its per-branch data/query/email steps with new ones. Flow A queries `dim_Parts_LowMargin` for everything currently below 20% margin and sends weekly. Flow B runs daily, diffs the current below-threshold set against a new SharePoint tracking list to isolate newly-crossed parts, and only emails branches with something new.

**Tech Stack:** Power Automate (cloud flows), Power BI REST API (`executeQueries` via HTTP action, DAX), SharePoint Online (tracking list), Microsoft Graph API (mail send, reusing the existing "Parts Action Dashboard Email" app registration), Fabric semantic model "Part Sales with Low Margin".

**Domain note for the executor:** This is a low-code build, not a traditional codebase — there is no unit test suite. "Test" steps in this plan mean: running the DAX query live via `pbi dax execute` against Power BI Desktop, and running the flow live via the `mcp__plugin_power-automate_flowagent` tools (`run_flow`, `smoke_test`, `get_run_history`, `diagnose_run`) and checking the actual output (query results, run status, received email). Treat every DAX/HTML/JSON block below as exact content to use, not a sketch.

---

## Known IDs and Reused Infrastructure

Confirmed via `fab get` against the live workspace — use these exactly, do not re-derive:

| Item | Value |
|---|---|
| Workspace ("RP - Parts Reports") Group ID | `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7` |
| "Part Sales with Low Margin" Dataset ID | `412c8395-7a2f-480c-996b-53af35a3ec02` |
| SPI-PARTS Azure AD group + officeLocation recipient pipeline | Reused as-is from the Orchestrator — do not recreate |
| PartsBranchMapping SharePoint list (site: South Plains Implement - Report Site, GUID `19da5d2c-18b8-4359-8c0b-9a4e2711210d`) | Reused as-is — `OfficeLocation` → `BranchFilter` (e.g. `"2 - Tornillo"`) |
| "Parts Action Dashboard Email" Entra app registration (Mail.Send, GroupMember.Read.All, User.Read.All) | Reused as-is for both new flows' HTTP Get Users and sendMail actions |
| Reference flow to clone | "Parts Action Summary - Orchestrator" (see `projects/parts action dashboard - report/documentation/power-automate-setup.md` for its full existing structure) |

---

## Confirmed Model Fields (from `dim_Parts_LowMargin.tmdl` and `_Measures.tmdl`)

`dim_Parts_LowMargin` columns: `PartNumber`, `Franchise`, `Branch`, `LowMarginFlag`, `StockOrderPrice`, `ListPrice`, `IsLowMarginFlagged`, `SellPrice1`, `QuantityOnHand`, `BulkBinQty`, `InventoryCost`, `OnHandQty`, `PartBranchKey` (already `PartNumber|Branch|Franchise`, reuse this as the tracking key), `Cost`.

`Description` is **not** on `dim_Parts_LowMargin` — it's pulled via `LOOKUPVALUE(dim_Parts[Description], dim_Parts[PartNumber], [PartNumber])`, matching the model's own `'Part Description'` measure.

Confirmed measure logic to replicate at row level:
- `Actual Margin % (INV)` = `DIVIDE(SellValue - InventoryCost, SellValue, 0)` where `SellValue = SellPrice1 * OnHandQty`
- `Desired Margin %` = `DIVIDE(SellValue - (Cost * OnHandQty), SellValue, 0)` (uses `Cost`, not `StockOrderPrice` — confirmed via the `'Desired Margin $'` and `'Test Manual Sum Positive'` measures)
- `New Sell Price` = `DIVIDE(ABS(MarginDiscrepancy), OnHandQty, 0) + ListPrice`
- Relationship: `dim_Parts_LowMargin[Branch] → dim_BranchLocation[BranchID]` exists (bidirectional) — filter branch via `dim_BranchLocation[Branch]`, consistent with every other query in the reference flow.

**Filters carried into the DAX below, confirmed against the Page 2 report table itself:** rows are excluded unless `Total SOH Qty (OnHandQty) > 0` and `Inventory Cost > 0` — this matches the filters already applied to the live report table (not just a judgment call). Without the `OnHandQty > 0` filter, `SellValue` = 0, `DIVIDE(..., 0)` returns the fallback `0`, and every zero-inventory row would incorrectly read as "0% margin" and falsely qualify as below 20%. The report's `Measure Filter 2` (a `'Percentage Filter'[Value]` min/max slicer over `Actual Margin % (INV)`) is a user-adjustable range control on the report page, not a fixed business rule — our flow's fixed `< 0.20` cutoff replaces that slicer's function for the automated alert rather than needing to replicate the slicer mechanism itself.

---

## Task 1: Validate the row-level DAX query against the live model

**Files:** none (live validation only)

- [ ] **Step 1: Open the report in Power BI Desktop**

Open `projects/part sales with low margin/reports/current/Part Sales with Low Margin.pbip` in Power BI Desktop and let it fully load.

- [ ] **Step 2: Connect via the `pbi` CLI**

```bash
pbi connect
```
Expected: detects the open Desktop instance and reports a connection name like `PBIDesktop-Part Sales with Low Margin-XXXXX`.

- [ ] **Step 3: Run the detail query for one known branch**

```bash
pbi dax execute "EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER(
            ADDCOLUMNS(
                dim_Parts_LowMargin,
                \"_SellValue\", [SellPrice1] * [OnHandQty],
                \"_DesiredMarginDollars\", ([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]),
                \"_ActualMarginDollarsINV\", ([SellPrice1] * [OnHandQty]) - [InventoryCost],
                \"_ActualMarginPctINV\", DIVIDE(([SellPrice1] * [OnHandQty]) - [InventoryCost], [SellPrice1] * [OnHandQty], 0),
                \"_DesiredMarginPct\", DIVIDE(([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]), [SellPrice1] * [OnHandQty], 0),
                \"_MarginDiscrepancy\", (([SellPrice1] * [OnHandQty]) - [InventoryCost]) - (([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty])),
                \"_MDPValue\", [Cost] * [OnHandQty],
                \"_NewSellPrice\", DIVIDE(ABS((([SellPrice1] * [OnHandQty]) - [InventoryCost]) - (([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]))), [OnHandQty], 0) + [ListPrice]
            ),
            [OnHandQty] > 0 && [InventoryCost] > 0 && [_ActualMarginPctINV] < 0.20
        ),
        \"PartBranchKey\", [PartBranchKey],
        \"Branch\", [Branch],
        \"Franchise\", [Franchise],
        \"Part Number\", [PartNumber],
        \"Description\", LOOKUPVALUE(dim_Parts[Description], dim_Parts[PartNumber], [PartNumber]),
        \"Total SOH Qty\", [OnHandQty],
        \"Inventory Cost\", [InventoryCost],
        \"MDP Value\", [_MDPValue],
        \"Sell Value\", [_SellValue],
        \"Desired Margin %\", [_DesiredMarginPct],
        \"Actual Margin % (INV)\", [_ActualMarginPctINV],
        \"Desired Margin $\", [_DesiredMarginDollars],
        \"Actual Margin $ (INV)\", [_ActualMarginDollarsINV],
        \"Margin $ Discrepancy\", [_MarginDiscrepancy],
        \"Low\", [LowMarginFlag],
        \"New Sell Price\", [_NewSellPrice]
    ),
    dim_BranchLocation[Branch] = \"2 - Tornillo\"
)"
```

Expected: a table of rows, every `Actual Margin % (INV)` value under 0.20, every `Total SOH Qty` > 0. Sanity-check 2-3 rows by hand against the Page 2 report table filtered to Tornillo.

- [ ] **Step 4: Run the aggregate KPI query for the same branch**

```bash
pbi dax execute "EVALUATE
ROW(
    \"LowMarginCount\", COALESCE(CALCULATE(
        COUNTROWS(
            FILTER(
                ADDCOLUMNS(
                    dim_Parts_LowMargin,
                    \"_ActualMarginPctINV\", DIVIDE(([SellPrice1] * [OnHandQty]) - [InventoryCost], [SellPrice1] * [OnHandQty], 0)
                ),
                [OnHandQty] > 0 && [InventoryCost] > 0 && [_ActualMarginPctINV] < 0.20
            )
        ),
        dim_BranchLocation[Branch] = \"2 - Tornillo\"), 0),
    \"MarginGapDollars\", COALESCE(CALCULATE(
        SUMX(
            FILTER(
                ADDCOLUMNS(
                    dim_Parts_LowMargin,
                    \"_ActualMarginPctINV\", DIVIDE(([SellPrice1] * [OnHandQty]) - [InventoryCost], [SellPrice1] * [OnHandQty], 0),
                    \"_MarginDiscrepancy\", (([SellPrice1] * [OnHandQty]) - [InventoryCost]) - (([SellPrice1] * [OnHandQty]) - ([Cost] * [OnHandQty]))
                ),
                [OnHandQty] > 0 && [InventoryCost] > 0 && [_ActualMarginPctINV] < 0.20
            ),
            [_MarginDiscrepancy]
        ),
        dim_BranchLocation[Branch] = \"2 - Tornillo\"), 0)
)"
```

Expected: `LowMarginCount` matches the row count from Step 3, `MarginGapDollars` is a negative or small dollar figure representing the margin shortfall.

- [ ] **Step 5: Confirm row count matches Step 3's count**

If they don't match, stop and re-check the filter logic before proceeding to Task 2 — every later task depends on this query being correct.

---

## Task 2: Create the SharePoint tracking list

**Files:** none (SharePoint UI — no repo artifact)

- [ ] **Step 1: Create the list**

In the "South Plains Implement - Report Site" SharePoint site (same site as `PartsBranchMapping`), create a new list named `LowMarginPartsTracking` with these columns:

| Column | Type | Notes |
|---|---|---|
| Title | Single line text | Default column, unused |
| PartBranchKey | Single line text | `PartNumber\|Branch\|Franchise` — matches `dim_Parts_LowMargin[PartBranchKey]` exactly |
| PartNumber | Single line text | |
| Branch | Single line text | Store in `BranchFilter` format (e.g. `"2 - Tornillo"`) to match `PartsBranchMapping` and simplify per-branch `Get_items` filtering |
| Franchise | Single line text | |
| FirstFlaggedDate | Date and Time | Set when the item is created (the date it was first detected below threshold) |

- [ ] **Step 2: Record the list GUID**

Note the list's GUID (visible in List Settings → General Settings, or in the URL) — it will be needed for the `Get_items`/`Create item`/`Delete item` actions in Task 4.

---

## Task 3: Build Flow A — Low Margin Weekly Digest

**Files:** none (Power Automate cloud flow, built via MCP tool calls)

- [ ] **Step 1: Clone the Orchestrator as a starting point**

```
mcp__plugin_power-automate_flowagent__copy_flow(
  source_flow_name: "Parts Action Summary - Orchestrator",
  new_flow_name: "Low Margin Weekly Digest - Orchestrator"
)
```

- [ ] **Step 2: Change the trigger to weekly Monday 8:30 AM CST**

```
mcp__plugin_power-automate_flowagent__set_current_flow(flow_name: "Low Margin Weekly Digest - Orchestrator")
mcp__plugin_power-automate_flowagent__get_current_flow()
```
Then edit the Recurrence trigger: `frequency: Week`, `interval: 1`, `schedule: { weekDays: ["Monday"] }`, `startTime` set so it fires at 8:30 AM, `timeZone: "Central Standard Time"`.

- [ ] **Step 3: Remove Parts-Action-specific steps**

Inside the `Apply to each` (SPI-PARTS members) branch, after the existing SKIP condition and PartsBranchMapping lookup (`Get_items` + `Condition_1`, both kept as-is), delete every step specific to the old content: NegOH/NoBin/Aging aggregate + detail queries and their conditions, Transfers query, Parts Adjustments query, Bin Location query, Pin Capture query, Physical Inventory query and detail, and the old `Compose: HTML Body`. Keep: the SKIP condition, the PartsBranchMapping lookup and its variable sets (`RecipientName`, `RecipientBranchName`, `RecipientBranchFilter`, `RecipientEmail`), and the final `HTTP: Graph API sendMail` action (its body will be repointed in Step 6).

- [ ] **Step 4: Add the detail query action**

Add an HTTP action `Run Detail Query` — same shape as the existing DAX HTTP calls in the Orchestrator (POST to the Power BI REST API `executeQueries` endpoint, dataset `412c8395-7a2f-480c-996b-53af35a3ec02`, workspace `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7`, reusing the same Power BI connection/auth already configured on the cloned flow's other HTTP actions). Query text — the exact DAX validated in Task 1, Step 3, with `dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"` in place of the hardcoded `"2 - Tornillo"`.
Follow with `Parse JSON` on the response (same schema pattern as the existing detail-query Parse JSON steps in the Orchestrator).

- [ ] **Step 5: Add the aggregate query action**

Add a second HTTP action `Run Aggregate Query`, same connection, using the exact DAX validated in Task 1 Step 4 (again with `@{variables('RecipientBranchFilter')}` substituted in). Follow with `Parse JSON`, then `Compose: LowMarginCount` = `body('Parse_JSON_Aggregate')?['results'][0]['tables'][0]['rows'][0]['[LowMarginCount]']` and `Compose: MarginGapDollars` = the equivalent for `[MarginGapDollars]`.

- [ ] **Step 6: Add the CSV attachment**

Add `Create CSV table` (Data Operations connector), input: `body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows']`, columns: Custom, mapping each of the 14 header names (`PartBranchKey` excluded — it's an internal key, not user-facing) to its corresponding `item()?['<ColName>']` expression: `Branch`, `Franchise`, `Part Number`, `Description`, `Total SOH Qty`, `Inventory Cost`, `MDP Value`, `Sell Value`, `Desired Margin %`, `Actual Margin % (INV)`, `Desired Margin $`, `Actual Margin $ (INV)`, `Margin $ Discrepancy`, `Low`, `New Sell Price`.

- [ ] **Step 7: Compose the HTML body**

Add `Compose: HTML Body`:

```html
<div style="font-family:Segoe UI,Arial,sans-serif; font-size:13px; max-width:600px;">
  <div style="background:#3d2b56; color:#fff; padding:14px 16px; border-left:6px solid #a688d1;">
    <div style="font-size:16px; font-weight:600;">Low Margin Pricing Digest</div>
    <div style="font-size:12px; opacity:.85;">@{variables('RecipientBranchName')} — Week of @{formatDateTime(utcNow(),'MMMM d, yyyy')}</div>
  </div>
  <div style="display:flex; gap:8px; padding:14px 16px;">
    <div style="flex:1; background:#f6f2fa; border-radius:6px; padding:10px; text-align:center; border:1px solid #e0d3ee;">
      <div style="font-size:20px; font-weight:700; color:#3d2b56;">@{outputs('Compose_LowMarginCount')}</div>
      <div style="font-size:11px; color:#555;">Parts Below 20%</div>
    </div>
    <div style="flex:1; background:#f6f2fa; border-radius:6px; padding:10px; text-align:center; border:1px solid #e0d3ee;">
      <div style="font-size:20px; font-weight:700; color:#3d2b56;">@{formatNumber(outputs('Compose_MarginGapDollars'),'C')}</div>
      <div style="font-size:11px; color:#555;">Margin Gap</div>
    </div>
  </div>
  <div style="padding:0 16px 16px;">
    <div style="font-size:12px; color:#888;">Full detail attached: Low_Margin_Parts.csv</div>
  </div>
</div>
```

- [ ] **Step 8: Repoint the sendMail action**

Update the `HTTP: Graph API sendMail` body: subject = `"Low Margin Pricing Digest — @{variables('RecipientBranchName')}"`, body content = `outputs('Compose_HTML_Body')`, attachment = single item built from `outputs('Create_CSV_table')` base64-encoded, filename `Low_Margin_Parts.csv`. To recipient = `variables('RecipientEmail')`, unchanged from the original flow.

- [ ] **Step 9: Save and validate**

```
mcp__plugin_power-automate_flowagent__preflight_flow(flow_name: "Low Margin Weekly Digest - Orchestrator")
mcp__plugin_power-automate_flowagent__validate_flow(flow_name: "Low Margin Weekly Digest - Orchestrator")
```
Expected: no errors. Fix any reported issues before continuing.

---

## Task 4: Build the Flow A manual test child flow

**Files:** none (Power Automate cloud flow)

- [ ] **Step 1: Clone the existing test flow**

```
mcp__plugin_power-automate_flowagent__copy_flow(
  source_flow_name: "Parts Action Summary - Weekly Branch Email",
  new_flow_name: "Low Margin Weekly Digest - Branch Email"
)
```

- [ ] **Step 2: Apply the same step changes as Task 3**

Repeat Task 3 Steps 3-8 on this cloned flow (it has the same 4 manual inputs — `RecipientName`, `RecipientBranchName`, `RecipientBranchFilter`, `RecipientEmail` — instead of a loop, so the detail/aggregate query, CSV, HTML, and sendMail steps are identical).

- [ ] **Step 3: Run it manually against a real branch**

```
mcp__plugin_power-automate_flowagent__run_flow(
  flow_name: "Low Margin Weekly Digest - Branch Email",
  inputs: { RecipientName: "Test", RecipientBranchName: "Tornillo", RecipientBranchFilter: "2 - Tornillo", RecipientEmail: "<your test address>" }
)
```

- [ ] **Step 4: Verify the run**

```
mcp__plugin_power-automate_flowagent__get_run_history(flow_name: "Low Margin Weekly Digest - Branch Email")
```
Expected: latest run status `Succeeded`. Open the received test email and confirm: purple-accented layout matches the approved mockup, KPI numbers match the Task 1 Step 4 output for Tornillo, and `Low_Margin_Parts.csv` is attached with all 14 columns and the same row count as Task 1 Step 3.

---

## Task 5: Build Flow B — Low Margin New-Item Alert

**Files:** none (Power Automate cloud flow)

- [ ] **Step 1: Clone the Orchestrator**

```
mcp__plugin_power-automate_flowagent__copy_flow(
  source_flow_name: "Parts Action Summary - Orchestrator",
  new_flow_name: "Low Margin New Item Alert - Orchestrator"
)
```

- [ ] **Step 2: Set the trigger to daily Mon-Fri 8:30 AM CST**

Edit the Recurrence trigger: `frequency: Day`, `interval: 1`, `schedule: { weekDays: ["Monday","Tuesday","Wednesday","Thursday","Friday"] }`, `startTime` at 8:30 AM, `timeZone: "Central Standard Time"`.

- [ ] **Step 3: Remove Parts-Action-specific steps**

Same as Task 3 Step 3 — keep the SKIP condition, PartsBranchMapping lookup and variable sets, and the final sendMail action (repointed later); remove everything else.

- [ ] **Step 4: Add the detail query action**

Same as Task 3 Step 4 — add `Run Detail Query` with the identical validated DAX from Task 1 Step 3, `dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"`. Follow with `Parse JSON`.

- [ ] **Step 5: Build the current-keys array**

Add `Compose: CurrentKeys` = `select(body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows'], item()?['[PartBranchKey]'])`.

- [ ] **Step 6: Get previously-tracked keys for this branch**

Add `Get_items (SharePoint)` on the `LowMarginPartsTracking` list, filter: `Branch eq '@{variables('RecipientBranchFilter')}'`. Follow with `Compose: PreviousKeys` = `select(body('Get_items_Tracking')?['value'], item()?['PartBranchKey'])`.

- [ ] **Step 7: Compute newly-crossed and resolved keys**

Add `Compose: ToAdd` = `difference(outputs('Compose_CurrentKeys'), outputs('Compose_PreviousKeys'))`.
Add `Compose: ToRemove` = `difference(outputs('Compose_PreviousKeys'), outputs('Compose_CurrentKeys'))`.

- [ ] **Step 8: Sync the tracking list**

Add `Apply_to_each_ToAdd` over `outputs('Compose_ToAdd')`: inside, `Filter_array` on `body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows']` where `item()?['[PartBranchKey]']` equals the current loop item, then `Create item` (SharePoint, `LowMarginPartsTracking`) using the filtered row's `PartBranchKey`, `PartNumber`, `Branch` (= `variables('RecipientBranchFilter')`), `Franchise`, and `FirstFlaggedDate` = `utcNow()`.
Add `Apply_to_each_ToRemove` over `outputs('Compose_ToRemove')`: inside, `Filter_array` on `body('Get_items_Tracking')?['value']` where `PartBranchKey` equals the current loop item, then `Delete item` (SharePoint) using the matched item's `ID`.

- [ ] **Step 9: Add the send condition**

Add `Condition: Should Send Alert` = `length(outputs('Compose_ToAdd'))` greater than `0`.

- [ ] **Step 10: (TRUE branch) Filter detail rows to the new keys only**

Add `Filter_array: NewItemRows` on `body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows']` where `contains(outputs('Compose_ToAdd'), item()?['[PartBranchKey]'])`.

- [ ] **Step 11: Build the CSV attachment**

Add `Create CSV table`, input: `body('Filter_array_NewItemRows')`, same 14-column mapping as Task 3 Step 6.

- [ ] **Step 12: Build the alert table**

Add `Create HTML table: NewItemsTable`, input: `body('Filter_array_NewItemRows')`, columns: Custom — `Part Number` = `item()?['[Part Number]']`, `Description` = `item()?['[Description]']`, `Branch` = `item()?['[Branch]']`, `Actual Margin %` = `formatNumber(item()?['[Actual Margin % (INV)]'], 'P1')`.

- [ ] **Step 13: Compose the HTML body**

Add `Compose: HTML Body`:

```html
<div style="font-family:Segoe UI,Arial,sans-serif; font-size:13px; max-width:600px;">
  <div style="background:#8a1c1c; color:#fff; padding:14px 16px;">
    <div style="font-size:12px; letter-spacing:1px; text-transform:uppercase; opacity:.9;">⚠ New Low Margin Alert</div>
    <div style="font-size:16px; font-weight:600; margin-top:2px;">@{length(outputs('Compose_ToAdd'))} part(s) just crossed 20% margin</div>
    <div style="font-size:12px; opacity:.85;">@{variables('RecipientBranchName')} — @{formatDateTime(utcNow(),'MMMM d, yyyy')}</div>
  </div>
  <div style="margin-top:10px;">
    @{body('Create_HTML_table_NewItemsTable')}
  </div>
  <div style="padding:12px 16px 0;">
    <div style="font-size:12px; color:#888;">Full detail attached: New_Low_Margin_Parts.csv</div>
  </div>
</div>
```

- [ ] **Step 14: Repoint the sendMail action**

Same as Task 3 Step 8: subject = `"New Low Margin Alert — @{variables('RecipientBranchName')}"`, body = `outputs('Compose_HTML_Body')`, attachment from `outputs('Create_CSV_table')`, filename `New_Low_Margin_Parts.csv`. Move this action, and Steps 10-13, inside the `Condition: Should Send Alert` TRUE branch — nothing sends on the FALSE branch.

- [ ] **Step 15: Save and validate**

```
mcp__plugin_power-automate_flowagent__preflight_flow(flow_name: "Low Margin New Item Alert - Orchestrator")
mcp__plugin_power-automate_flowagent__validate_flow(flow_name: "Low Margin New Item Alert - Orchestrator")
```
Expected: no errors.

---

## Task 6: Build the Flow B manual test child flow

**Files:** none (Power Automate cloud flow)

- [ ] **Step 1: Clone the test flow**

```
mcp__plugin_power-automate_flowagent__copy_flow(
  source_flow_name: "Parts Action Summary - Weekly Branch Email",
  new_flow_name: "Low Margin New Item Alert - Branch Email"
)
```

- [ ] **Step 2: Apply the same step changes as Task 5**

Repeat Task 5 Steps 3-14 on this cloned flow, using its 4 manual inputs in place of the loop variables.

- [ ] **Step 3: First test run — establish baseline**

```
mcp__plugin_power-automate_flowagent__run_flow(
  flow_name: "Low Margin New Item Alert - Branch Email",
  inputs: { RecipientName: "Test", RecipientBranchName: "Tornillo", RecipientBranchFilter: "2 - Tornillo", RecipientEmail: "<your test address>" }
)
```
Expected: since `LowMarginPartsTracking` starts empty for this branch, every currently-below-threshold part is "new" — confirm `get_run_history` shows `Succeeded` and the test email lists the full current below-threshold set for Tornillo (matching Task 1 Step 3's row count), and confirm in SharePoint that `LowMarginPartsTracking` now has one row per part for Branch `"2 - Tornillo"`.

- [ ] **Step 4: Second test run — confirm no false alerts**

Run it again immediately with the same inputs.
Expected: `ToAdd` and `ToRemove` are both empty (nothing changed since Step 3), the `Should Send Alert` condition evaluates false, no email is sent, and `get_run_history` still shows `Succeeded` (a no-op run, not a failure).

- [ ] **Step 5: Third test run — confirm resolution removes tracking**

In SharePoint, manually delete one row from `LowMarginPartsTracking` for Branch `"2 - Tornillo"` (simulating that part having been re-priced above 20% since the last run — this is the one case `ToRemove` fires on, since the live data hasn't actually changed).
Run the flow again.
Expected: that one key appears in `ToRemove` and its SharePoint row gets recreated (since the underlying data still shows it below threshold) — confirming the add/remove sync logic runs both directions correctly, even though in production `ToRemove` will only be non-empty when a part actually gets re-priced.

---

## Task 7: Write project documentation

**Files:**
- Create: `projects/part sales with low margin/docs/06-power-automate/POWER-AUTOMATE-SETUP.md`
- Modify: `projects/part sales with low margin/CLAUDE.md`

- [ ] **Step 1: Write the setup doc**

Create `projects/part sales with low margin/docs/06-power-automate/POWER-AUTOMATE-SETUP.md`, mirroring the structure of `projects/parts action dashboard - report/documentation/power-automate-setup.md`: Flow Overview table (both flows), Architecture (the two-flow structure + shared infrastructure reuse), the confirmed IDs table from this plan's header, the full validated DAX queries from Task 1, the SharePoint tracking-list schema from Task 2, the add/remove sync logic from Task 5 Steps 5-8, and a Troubleshooting table covering: no email received (check `LowMarginPartsTracking` — did anything actually change?), wrong branch data (verify `PartsBranchMapping` `BranchFilter` matches `dim_BranchLocation[Branch]` exactly), CSV missing columns (check the `Create CSV table` column mapping against the 14-column list), sendMail 401 (same app registration secret as Parts Action — see that flow's troubleshooting entry).

- [ ] **Step 2: Update the project CLAUDE.md**

Add a section to `projects/part sales with low margin/CLAUDE.md` (after the "Documentation Status" section) pointing to the new doc:

```markdown
## Power Automate Alerts
Two flows alert on `Actual Margin % (INV) < 20%` from `dim_Parts_LowMargin`:
- **Low Margin Weekly Digest** — full current list, weekly (Monday 8:30 AM CST)
- **Low Margin New Item Alert** — only newly-crossed parts, daily (Mon-Fri 8:30 AM CST)

Both reuse the Parts Action Summary distribution pipeline (SPI-PARTS group +
PartsBranchMapping) but with distinct purple/red styling so they're never
confused with the Parts Action email. See
`docs/06-power-automate/POWER-AUTOMATE-SETUP.md` for full detail.
```

- [ ] **Step 3: Commit the documentation**

```bash
git add "projects/part sales with low margin/docs/06-power-automate/POWER-AUTOMATE-SETUP.md" "projects/part sales with low margin/CLAUDE.md"
git commit -m "Document Power Automate low margin alert flows"
```
Expected: commit succeeds, `git status` shows a clean working tree for these two paths.

---

## Self-Review Notes

- **Spec coverage:** Every section of `docs/superpowers/specs/2026-07-22-parts-low-margin-alerts-design.md` maps to a task — data/threshold (Task 1), Flow A weekly digest with HTML+CSV (Tasks 3-4), Flow B daily alert with HTML+CSV and state tracking (Tasks 5-6), shared infrastructure reuse (noted throughout, no separate task needed since nothing new is created), documentation (Task 7).
- **New addition beyond the original spec:** the zero-`OnHandQty` exclusion (called out explicitly above) wasn't discussed during brainstorming — surfaced here rather than silently baked in.
- **Naming consistency:** `PartBranchKey` is used identically in the DAX (Task 1), the SharePoint schema (Task 2), and the diff logic (Task 5) — verified no drift between tasks.
