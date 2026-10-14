# Parts Low Margin Invoiced Sales Alert Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the existing "Low Margin New Item Alert" flows (built for
the now-abandoned Page 2/inventory design) to alert on invoiced parts sales
(`Fact_InTrans`, Page 1) below 20% margin, using a weekday-aware date window
instead of the SharePoint tracking-list diff, with a styled HTML table
matching the MD Freight alert's construction.

**Architecture:** Same two flows, same flow IDs, same recipient/CSV/sendMail
mechanics — only the DAX query, the "what counts as new" logic (date window
replaces tracking-list diff, which is dropped entirely), and the HTML body
construction change.

**Tech Stack:** Power Automate (`mcp__plugin_power-automate_flowagent__*`
tools), Power BI REST API (DAX via `ExecuteDatasetQuery`), `pbi` CLI for
live DAX validation.

**Domain note for the executor:** This is a live cloud rework, not a
traditional codebase — there is no unit test suite. "Test" steps mean
running the DAX live via `pbi dax execute` and running the flow live via
`run_flow`/manual portal runs, then inspecting real output (query row
counts, the actual email received). See
`projects/part sales with low margin/docs/06-power-automate/POWER-AUTOMATE-SETUP.md`
Known Issues section for platform gotchas already discovered this project
(no native `select()`/`difference()` functions, `body()` vs `outputs()` on
Table actions, `update_flow`'s stricter connection-reference validation
requiring `host.connectionReferenceName` — read that section before writing
any new flow JSON, do not rediscover these the hard way).

---

## Known IDs (reused, not recreated)

| Item | Value |
|---|---|
| Daily alert test/manual flow | `f6c9fd72-9279-424b-898a-8bc7a8eaf802` ("Low Margin New Item Alert - Branch Email") |
| Daily alert Orchestrator | `66e29bef-7838-4b01-9e6b-c4a8562fb51d` ("Low Margin New Item Alert - Orchestrator") |
| Dataset (groupid/datasetid) | `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7` / `412c8395-7a2f-480c-996b-53af35a3ec02` |
| Test branch | Tornillo, `BranchFilter = "2 - Tornillo"` |

**Dropped in this rework:** the `LowMarginPartsTracking` SharePoint list
(GUID `c69ed96e-03d5-485a-a763-b6a46a9a75a5`) and all its diff plumbing
(`Get_items_Tracking`, `Compose_CurrentKeys`/`PreviousKeys`,
`Filter_ToAdd`/`ToRemove`, `Apply_to_each_ToAdd`/`ToRemove`,
`Create_item`/`Delete_item`) — invoiced transactions never need to be
"resolved," so a date-window filter fully replaces this. Do not port this
logic into the rebuilt flows. The SharePoint list itself is left in place
(harmless, just unused) — do not delete it as part of this plan.

---

## Task 1: Validate the new detail DAX query against the live model

**Files:** none (live validation only, via `pbi` CLI against Power BI
Desktop with "Part Sales with Low Margin" open)

- [ ] **Step 1: Write the query to a scratch file and run it for Tornillo**

```dax
EVALUATE
VAR Today = TODAY()
VAR DOW = WEEKDAY(Today, 2)
VAR LookbackDays = IF(DOW = 1, 3, 1)
VAR WindowStart = Today - LookbackDays
RETURN
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER(
            ADDCOLUMNS(
                Fact_InTrans,
                "_MarginPct", DIVIDE([ActualMarginDollars], [SaleValue], 0)
            ),
            [Qty] > 0 && [SaleValue] > 0 && [_MarginPct] < 0.20 && [TransDatetime] >= WindowStart
        ),
        "Branch", [Branch],
        "Franchise", [Franchise],
        "Part Number", [PartNumber],
        "Description", LOOKUPVALUE(dim_Parts[Description], dim_Parts[PartNumber], [PartNumber]),
        "Qty", [Qty],
        "Date", [TransDatetime],
        "Ref No", [RONumber],
        "Salesman", [Salesman],
        "Cost $", [CostValue],
        "Sale $", [SaleValue],
        "Margin $", [ActualMarginDollars],
        "Margin Value %", [_MarginPct],
        "Customer No", [CustomerNo]
    ),
    dim_BranchLocation[Branch] = "2 - Tornillo"
)
```

```bash
pbi dax execute --file <scratch-path>/invoiced-detail-query.dax --max-rows 5
```

Expected: `success: True`, a non-negative `RowCount` reported in the CLI's
logs. Sanity-check a handful of returned rows against the live Page 1
report filtered to Tornillo + the last few days — every `Margin Value %`
should be < 20%, every `Qty`/`Sale $` > 0.

- [ ] **Step 2: Confirm the weekday-aware window on a Monday and a non-Monday**

Since `TODAY()` drives the window, this can't be forced to a different day
artificially — instead, manually compute what `WindowStart` should be for
today's actual weekday (Monday → today minus 3, else minus 1) and confirm
the returned rows' `Date` values don't fall earlier than that boundary. If
today is not Monday when this is run, note in the task that Monday behavior
should be spot-checked on the next Monday's live run (Task 2/3 test runs).

- [ ] **Step 3: Confirm the Description fix**

Pick 2-3 returned `Part Number` values and cross-check their `Description`
against `dim_Parts` directly (e.g. via the report's own part search) to
confirm it's the real part description, not the invoice-level text that
was in the old `Fact_InTrans[Description]` column.

---

## Task 2: Rebuild the daily alert test/manual flow

**Files:** none (Power Automate cloud flow — `update_flow` on
`f6c9fd72-9279-424b-898a-8bc7a8eaf802`)

- [ ] **Step 1: Fetch the current flow definition**

```
mcp__plugin_power-automate_flowagent__get_flow(flow: "f6c9fd72-9279-424b-898a-8bc7a8eaf802")
```

- [ ] **Step 2: Replace `Run_Detail_Query`'s DAX**

Swap `groupid`/`datasetid` stay the same (already point at the right
dataset). Replace `specification/query` with the exact query validated in
Task 1 Step 1, with `dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"`
in place of the hardcoded `"2 - Tornillo"`.

- [ ] **Step 3: Replace `Parse_JSON_Detail`'s schema**

Replace the `rows` item schema with the 13 columns from the new query:
`[Branch]` (string), `[Franchise]` (string), `[Part Number]` (string),
`[Description]` (string), `[Qty]` (number), `[Date]` (string), `[Ref No]`
(string), `[Salesman]` (string), `[Cost $]` (number), `[Sale $]` (number),
`[Margin $]` (number), `[Margin Value %]` (number), `[Customer No]`
(string).

- [ ] **Step 4: Delete all tracking-list/diff actions**

Remove entirely: `Compose_CurrentKeys`, `Get_items_Tracking`,
`Compose_PreviousKeys`, `Filter_ToAdd`, `Filter_ToRemove`,
`Apply_to_each_ToAdd`, `Apply_to_each_ToRemove`. `Condition_Should_Send_Alert`
stays, but its `runAfter` now points directly at `Parse_JSON_Detail`, and
its expression becomes:

```json
{"and": [{"greater": ["@length(body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows'])", 0]}]}
```

- [ ] **Step 5: Rewrite `Condition_Should_Send_Alert`'s actions**

Inside the condition's `actions`:

`Create_CSV_table` — `from`: `@body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows']`,
`format: "CSV"` (matches the Page 1 report's 13-column order — no custom
`columns` mapping needed, matches existing bracketed-header convention).

`Compose_Rows` (type `"Select"`) — builds one `<tr>` HTML string per row,
for the 4-column inline alert table (Part Number, Description, Cost $,
Actual Margin %):

```
@concat('<tr><td style="padding:10px 18px;border-bottom:1px solid #f1f5f9;font-size:13px;color:#333333;">', item()?['[Part Number]'], '</td><td style="padding:10px 18px;border-bottom:1px solid #f1f5f9;font-size:13px;color:#333333;">', item()?['[Description]'], '</td><td style="padding:10px 18px;border-bottom:1px solid #f1f5f9;font-size:13px;color:#333333;text-align:right;">', formatNumber(float(item()?['[Cost $]']), 'C'), '</td><td style="padding:10px 18px;border-bottom:1px solid #f1f5f9;font-size:13px;color:#333333;text-align:right;font-weight:600;">', formatNumber(float(item()?['[Margin Value %]']), 'P1'), '</td></tr>')
```

with `"from": "@body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows']"`.

`Compose_WindowStartLabel` (type `"Compose"`) — precomputes the display
label for the trigger line:

```
@formatDateTime(addDays(utcNow(), -if(equals(dayOfWeek(utcNow()),1), 3, 1)), 'MMMM d, yyyy')
```

`Compose_HTML_Body` (type `"Compose"`) — replaces the prior version.
`runAfter: Compose_WindowStartLabel`:

```html
<!DOCTYPE html><html><body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,sans-serif"><table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px 8px"><table width="800" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:8px;overflow:hidden"><tr><td style="background:#8a1c1c;padding:20px 28px"><table width="100%" cellpadding="0" cellspacing="0"><tr><td valign="middle"><p style="margin:0;color:#fbd5d5;font-size:11px;text-transform:uppercase;letter-spacing:.1em">Low Margin Invoice Alert</p><p style="margin:6px 0 0;color:#ffffff;font-size:20px;font-weight:bold">@{length(body('Parse_JSON_Detail')?['results'][0]['tables'][0]['rows'])} invoice line(s) below 20% margin</p><p style="margin:4px 0 0;color:#fbd5d5;font-size:12px">Trigger: Invoiced parts sales with Qty &gt; 0, Sale $ &gt; 0, and Actual Margin % below 20% &mdash; @{outputs('Compose_WindowStartLabel')} through @{formatDateTime(utcNow(),'MMMM d, yyyy')}</p><p style="margin:6px 0 0;color:#fbd5d5;font-size:13px">@{variables('RecipientBranchName')}</p></td><td align="right" valign="middle"><img src="https://2271149.fs1.hubspotusercontent-na2.net/hubfs/2271149/raw_assets/public/South-Plains-Website-Build/South%20Plains%20Website%20Template/images/south-plains-implement-logo.png" height="50" style="display:block"></td></tr></table></td></tr><tr><td style="padding:20px 28px"><table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;"><tr style="background:#fdecea;"><th style="padding:10px 18px;text-align:left;font-size:11px;color:#7f1d1d;text-transform:uppercase;letter-spacing:.05em;border-bottom:2px solid #f3b3b3;">Part Number</th><th style="padding:10px 18px;text-align:left;font-size:11px;color:#7f1d1d;text-transform:uppercase;letter-spacing:.05em;border-bottom:2px solid #f3b3b3;">Description</th><th style="padding:10px 18px;text-align:right;font-size:11px;color:#7f1d1d;text-transform:uppercase;letter-spacing:.05em;border-bottom:2px solid #f3b3b3;">Cost $</th><th style="padding:10px 18px;text-align:right;font-size:11px;color:#7f1d1d;text-transform:uppercase;letter-spacing:.05em;border-bottom:2px solid #f3b3b3;">Actual Margin %</th></tr>@{join(body('Compose_Rows'), '')}</table></td></tr><tr><td style="background:#f8fafc;padding:16px 28px;text-align:center;border-top:1px solid #e2e8f0"><p style="margin:0;font-size:11px;color:#94a3b8">Low Margin Invoice Alert &mdash; South Plains Implement</p><p style="margin:4px 0 0;font-size:11px;color:#94a3b8">Full detail attached: Low_Margin_Invoices.csv &nbsp;&middot;&nbsp; Questions? Contact bfox@spitractor.com</p></td></tr></table></td></tr></table></body></html>
```

`HTTP_sendMail` — unchanged action shape, just repoint the CSV filename and
subject:

```
@{concat('{"message":{"subject":"Low Margin Invoice Alert - ',variables('RecipientBranchName'),' - ',formatDateTime(utcNow(),'MMMM d, yyyy'),'","body":{"contentType":"HTML","content":"',replace(outputs('Compose_HTML_Body'),'"','\"'),'"},"toRecipients":[{"emailAddress":{"address":"',variables('RecipientEmail'),'"}}],"attachments":[{"@odata.type":"#microsoft.graph.fileAttachment","name":"Low_Margin_Invoices.csv","contentBytes":"',base64(body('Create_CSV_table')),'"}]}}')}
```

Update the `runAfter` chain: `Create_CSV_table` → `Compose_Rows` →
`Compose_WindowStartLabel` → `Compose_HTML_Body` → `HTTP_sendMail`.

- [ ] **Step 6: Apply via `update_flow`**

Send the full corrected definition (this flow uses the trigger-token auth
pattern — `"authentication": {"value": "@json(decodeBase64(triggerOutputs().headers['X-MS-APIM-Tokens']))['$ConnectionKey']", "type": "Raw"}`
on the Power BI `OpenApiConnection` action, matching how this flow was
originally built — do not use `@parameters('$authentication')` here, that
pattern is for the Orchestrator's recurrence trigger only, see Task 3).

- [ ] **Step 7: Run it manually against Tornillo and verify**

From make.powerautomate.com → the flow → **Run**, with Name=Test,
Branch=Tornillo, BranchFilter=`2 - Tornillo`, Email=`bfox@spitractor.com`.

Expected: an email titled "Low Margin Invoice Alert - Tornillo - <date>"
with the red banner, the "Trigger:" line showing the correct date window,
a styled 4-column table (Part Number/Description/Cost $/Actual Margin %)
with a tinted red header row, and `Low_Margin_Invoices.csv` attached with
all 13 columns. Cross-check the row count and a couple of values against
the Task 1 validation output for the same window.

---

## Task 3: Rebuild the daily alert Orchestrator

**Files:** none (Power Automate cloud flow — `update_flow` on
`66e29bef-7838-4b01-9e6b-c4a8562fb51d`)

- [ ] **Step 1: Fetch the current flow definition**

```
mcp__plugin_power-automate_flowagent__get_flow(flow: "66e29bef-7838-4b01-9e6b-c4a8562fb51d")
```

- [ ] **Step 2: Apply the same changes as Task 2, Steps 2-5**

Same DAX, same Parse_JSON schema, same removal of tracking-list actions,
same `Condition_Should_Send_Alert` rewrite (`Create_CSV_table`,
`Compose_Rows`, `Compose_WindowStartLabel`, `Compose_HTML_Body`,
`HTTP_sendMail` — identical content), applied inside `Condition_1`'s
actions (the branch-mapping-found branch, nested inside the `Apply_to_each`
loop) instead of at the top level. Use `@parameters('$authentication')`
for all `OpenApiConnection` actions (no explicit `authentication` property
in `inputs` — this flow's trigger is Recurrence, matching the pattern
already used for `Run_Detail_Query`/`Get_items` in this same flow), and
ensure `host.connectionReferenceName` is set alongside `host.connectionName`
on every `OpenApiConnection` action (required by `update_flow`'s stricter
validation — see POWER-AUTOMATE-SETUP.md Known Issues #4).

- [ ] **Step 3: Apply via `update_flow`**

The `connectionRefs` for this flow already include both `shared_powerbi`
and `shared_sharepointonline-1` from the original build — no new connector
is introduced by this rework (SharePoint's `Get_items` for
`PartsBranchMapping` is unaffected; only the `LowMarginPartsTracking`
SharePoint actions are being removed, and those used the same
`shared_sharepointonline-1` reference, so nothing needs to be added or
dropped from `connectionRefs`).

- [ ] **Step 4: Validate structurally**

Confirm `update_flow` returns success (state stays `Stopped` — do not
publish/start it as part of this task; going live requires Brian's
separate explicit approval, same as the original build).

---

## Task 4: Update project documentation

**Files:**
- Modify: `projects/part sales with low margin/docs/06-power-automate/POWER-AUTOMATE-SETUP.md`
- Modify: `projects/part sales with low margin/CLAUDE.md`

- [ ] **Step 1: Rewrite the affected sections of POWER-AUTOMATE-SETUP.md**

Update: remove references to the Weekly Digest being part of the active
design (note both Weekly Digest flows are stopped/unused, kept only in
case needed later); replace the "Data & Threshold" section with the
`Fact_InTrans` query/threshold/filters from the design spec; replace the
"SharePoint Tracking List" section with a note that it's no longer used by
this flow (kept in place, unused) and that the daily alert now uses a
weekday-aware date window computed directly in DAX instead; update the
"Flow Overview" table to remove the Weekly Digest row entirely; add the new
HTML styling section (matching MD Freight's construction) to Known Issues
or a new "Email Styling" section, referencing the design spec at
`docs/superpowers/specs/2026-07-27-parts-low-margin-invoiced-sales-alert-design.md`.

- [ ] **Step 2: Update CLAUDE.md's "Power Automate Alerts" section**

Replace the two-flow (digest + alert) description with a single-flow
description: invoiced sales below 20% margin, daily weekdays 8:30 AM CST,
date-window based (no tracking list), same per-branch distribution.

- [ ] **Step 3: Commit**

```bash
git add "projects/part sales with low margin/docs/06-power-automate/POWER-AUTOMATE-SETUP.md" "projects/part sales with low margin/CLAUDE.md"
git commit -m "Rework low margin alert to invoiced sales (Fact_InTrans), drop weekly digest"
```

---

## Self-Review Notes

- **Spec coverage:** Data source pivot (Task 1/2/3), Description fix (Task 1
  Step 3, baked into the query in Task 2/3), date window replacing tracking
  list (Task 1/2/3), no dollar floor (query has none), column sets for both
  CSV and HTML table (Task 2 Step 5), MD Freight-matched styling + Trigger
  line (Task 2 Step 5), disposition of old flows (explicitly left alone,
  called out in Known IDs section), documentation (Task 4).
- **Naming consistency:** `Compose_Rows`, `Compose_WindowStartLabel`,
  `Compose_HTML_Body`, `Create_CSV_table`, `HTTP_sendMail` are used
  identically across Task 2 and Task 3 — verified no drift.
- **No placeholders:** all DAX and HTML content is complete and verbatim;
  the only forward reference (Task 1 Step 2's "spot-check on the next
  Monday") is an explicit, justified deferral (can't force `TODAY()` to a
  different weekday), not a placeholder.
