# Power Automate Setup — Low Margin Invoice Alert

## Overview

**This design was reworked on 2026-07-27 after stakeholder (Ben) feedback and
supersedes the original Page-2/inventory-snapshot design.** The original
weekly-digest + daily-new-item pair (built 2026-07-22, based on
`dim_Parts_LowMargin`) is documented in the "Superseded Design" section at
the bottom of this file. Those flows still exist and are left **Stopped and
unused** — not deleted — in case they're useful later.

**Current design:** a single alert flow on **invoiced parts sales**
(`Fact_InTrans`, Page 1), not the inventory pricing snapshot. Rationale
(from Ben): price changes are handled by parts managers at the corp office,
not store-level parts staff, and the actionable signal is what's actually
being sold below margin — not what's sitting in inventory mispriced. There
is no weekly digest — invoiced data doesn't "fall off" a list the way a
current-inventory snapshot does, so a single recurring alert on new invoice
activity is sufficient. There is no dollar floor — every qualifying line
alerts, per Ben's explicit direction.

Built by hand-authoring/patching flow JSON via the Power Automate flowagent
MCP tools (not cloned from Parts Action Summary — `copy_flow` is broken in
this environment; see Known Issues), reusing the same distribution
mechanism (SPI-PARTS Azure AD group + PartsBranchMapping SharePoint list +
"Parts Action Dashboard Email" app registration) but with distinct
red-themed visual styling (copied from the MD Freight alert's column
styling) so recipients never confuse it with the Parts Action or MD Freight
emails.

Design rationale: `docs/superpowers/specs/2026-07-27-parts-low-margin-invoiced-sales-alert-design.md`
Implementation plan: `docs/superpowers/plans/2026-07-27-parts-low-margin-invoiced-sales-alert.md`

## Flow Overview

| Setting | Value |
|---|---|
| Orchestrator flow name | `Low Margin New Item Alert - Orchestrator` |
| Orchestrator flow ID | `6427c9b7-b74c-455a-afbe-b0ce417a18b0` (recreated 2026-07-27 — the original `66e29bef-7838-4b01-9e6b-c4a8562fb51d` was deleted during the rework; an export of it is kept at `flow-exports/LowMarginWeeklyDigest-Orchestrator_20260727205130/` and was the base used to rebuild this flow, see Known Issues #7) |
| Test/manual flow ID | `f6c9fd72-9279-424b-898a-8bc7a8eaf802` (reused from the original build, rebuilt with new logic) |
| Trigger | Recurrence — every weekday 8:30 AM CST |
| Content | Every invoiced parts sale line below 20% margin, no dollar floor |
| Orchestrator state as of 2026-07-27 | **Stopped** — Brian testing changes live in-session; awaiting Ben's decision on go-live timing / further changes |
| Environment | Brian Fox's Environment, `2cf47cce-a195-ed3a-94e1-287c38adb011` (the one **without** Dataverse — see Known Issues) |

## Data & Threshold

- Dataset: "Part Sales with Low Margin" — workspace (groupid)
  `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7`, dataset (datasetid)
  `412c8395-7a2f-480c-996b-53af35a3ec02`.
- Source table: **`Fact_InTrans`** (Page 1 — invoiced transaction history),
  not `dim_Parts_LowMargin`.
- Threshold: `Actual Margin % = ActualMarginDollars / SaleValue < 0.20`,
  computed per invoice line, filtered to `Qty > 0 && SaleValue > 0` (these
  filters mirror the report's own filters, which were separately restored
  on Page 1 after being found missing).
- **No dollar floor** — every line below 20% margin alerts, regardless of
  size.
- **Description column gotcha:** `Fact_InTrans[Description]` is an
  **invoice-level** description, not a part description — do not use it
  directly. The alert's DAX uses
  `LOOKUPVALUE(dim_Parts[Description], dim_Parts[PartNumber], [PartNumber])`
  to get the actual part description.
- **Date window (replaces the old tracking-list diff):** since Fact_InTrans
  is append-only invoice history (not a snapshot), there's no need to diff
  against a previous run to find "new" items — a stateless weekday-aware
  lookback window does the job:
  ```
  VAR Today = TODAY()
  VAR DOW = WEEKDAY(Today, 2)          -- Monday = 1
  VAR LookbackDays = IF(DOW = 1, 3, 1)  -- Monday looks back through the weekend
  VAR WindowStart = Today - LookbackDays
  ```
  This means Tuesday–Friday runs see the prior 1 day, and Monday's run sees
  back through Friday (3 days), so nothing invoiced over a weekend is
  missed. This fully replaces the SharePoint tracking-list sync mechanism
  used by the old design — no tracking list, no diff logic, no stale-item
  cleanup.
- Full validated DAX is embedded verbatim in the `Run_Detail_Query` action
  on both the Orchestrator and the test flow — see the design spec for the
  exact text if rebuilding from scratch.

## Email Content

**CSV attachment columns** (`Low_Margin_Invoices.csv`): Branch, Franchise,
Part Number, Description, Qty, Date, Ref No, Salesman, Cost $, Sale $,
Margin $, Margin Value %, Customer No.

**Inline HTML table columns** (subset, for at-a-glance scanning): Part
Number, Description, Ref No, Cost $, Actual Margin %. Ref No was added
after initial testing per Brian's follow-up request. Styling copied from
the MD Freight alert: red banner (`#8a1c1c`), header background
(`#fdecea`), header text (`#7f1d1d`), border (`#f3b3b3`).

**Trigger explanation line:** per Ben's request that the email be explicit
about what's causing it to fire, the HTML body includes a line stating the
filter criteria in plain language: *"Trigger: Invoiced parts sales with Qty
> 0, Sale $ > 0, and Actual Margin % below 20%."*

## Shared Infrastructure (reused as-is)

- SPI-PARTS Azure AD group + officeLocation → PartsBranchMapping lookup:
  identical to the Parts Action Summary Orchestrator's recipient pipeline.
  Recipients are unchanged from the original design.
- "Parts Action Dashboard Email" Entra app registration (Mail.Send,
  GroupMember.Read.All) — same `clientId`/`tenant`/`secret` reused inline in
  every HTTP action's `authentication` block, matching how the existing
  production flow already does it.
- Sender mailbox: `bfox@spitractor.com` (matches Parts Action's sendMail
  pattern — Graph API `POST /v1.0/users/bfox@spitractor.com/sendMail`).
- Power BI connection: `shared-powerbi-04fe5718-dd42-4f4b-8e94-555dfbfdc0c1`
  (connection reference key `shared_powerbi`).
- SharePoint connection: `shared-sharepointonl-91a46c53-a2ad-426d-af54-cd3d21665ce7`
  (connection reference key `shared_sharepointonline-1`) — still used for
  the PartsBranchMapping recipient lookup, just not for a tracking list
  anymore.

## Known Issues / Gotchas (discovered while building)

1. **`copy_flow` and `edit_flow` are broken** in this flowagent MCP
   environment (`ctx.getClient(...).copyFlow/editFlow is not a function`).
   Use `get_flow` to read a source flow's JSON, then `create_flow`/`update_flow`
   to build/patch the new one by hand.
2. **`select()` and `difference()` are not real expression functions** —
   despite being tempting names, Power Automate's workflow expression
   language has no such functions. Use a `Select` **action** (type
   `"Select"`) to extract/transform an array, and `Filter Array` (type
   `"Query"`) with `not(contains(...))` if a set difference is ever needed.
3. **A `Table` action's actual content is `body('ActionName')`, not
   `outputs('ActionName')`** — using `outputs()` on a Create CSV/HTML table
   action dumps the whole action envelope instead of just the table
   content.
4. **`update_flow` enforces stricter schema validation than `create_flow`**
   for `OpenApiConnection` actions in some cases — it can reject an
   explicit `authentication` property in `inputs` and require
   `host.connectionReferenceName` in addition to `host.connectionName`.
   However, note gotcha #7 below — the proven-working exported flow uses
   plain `"authentication": "@parameters('$authentication')"` with **no**
   `connectionReferenceName`, and that saved successfully via `update_flow`
   during the rebuild. Treat this validation behavior as inconsistent
   rather than a fixed rule. When adding new connector actions to an
   existing flow, also add a matching entry to the top-level
   `connectionRefs` — connection references not referenced by any action at
   creation time get silently pruned.
5. **Recurrence trigger validation:** `weekDays` is only valid with
   `frequency: "Week"`, not `"Day"`. The correct way to express "every
   weekday" is `frequency: "Week", interval: 1, schedule.weekDays: [Mon..Fri]`.
6. **Two environments share the exact display name** "Brian Fox's
   Environment" in this tenant (one with Dataverse, one without). All flows
   in this project live in the one **without** Dataverse:
   `2cf47cce-a195-ed3a-94e1-287c38adb011`. See
   `reference_power_platform_known_issues` in Claude's memory for more.
7. **Mysterious, non-deterministic `InvalidRequestContent` / "Invalid JSON
   at path..." errors on `create_flow`/`update_flow`** — encountered
   repeatedly while rebuilding the Orchestrator after it was deleted and
   recreated, at many different byte offsets, across many retries, despite
   every submitted payload validating cleanly with a local JSON parser.
   Reducing payload size didn't fix it. The failures were NOT a payload
   size limit — a proven-working exported flow definition (14,298 chars)
   was measurably larger than every failing attempt (6,000–12,000 chars).
   **Working fix:** instead of hand-authoring the JSON payload in the tool
   call, load a known-good exported flow definition as a Python dict,
   programmatically patch only the specific fields that need to change
   (query text, schema, action content), re-serialize, and submit that. This
   succeeded on the first try. Working theory: something about generating a
   large JSON blob inline as part of a long tool-call response is fragile in
   this environment — patching a file-backed known-good structure sidesteps
   whatever that is. If this recurs, export the current flow first
   (portal → flow → Export → Package (.zip) → unzip →
   `Microsoft.Flow/flows/<id>/definition.json`) and patch from that rather
   than typing JSON by hand.
8. **`update_flow`'s ID parameter is named `flow`, not `flowId`** — passing
   `flowId` throws a Zod validation error (`Required` on path `["flow"]`).
9. **`create_flow` refuses to create a flow with a duplicate display name**
   (`DuplicateFlowName`) if one already exists in the environment — use
   `update_flow` against the existing flow ID instead once the skeleton
   flow has been created.
10. **2026-07-23 Microsoft-side outage** (Power Platform "Known Issues" ID
    6576887, "Power Automate and Environment Loading Issues") caused the
    Flow API to return empty flow lists and `AzureResourceManagerServerError`/
    `ServerTimeout` for roughly the length of one work session. Resolved on
    its own; no data was lost. If flows seem to vanish, check Admin Center →
    Support → Known Issues before assuming anything was deleted.

## Testing

The test/manual flow (`f6c9fd72-...`) accepts 4 manual inputs (Name,
Branch, BranchFilter, Email) via a Button trigger, matching the existing
"Parts Action Summary - Weekly Branch Email" test-flow pattern.
Button-triggered flows cannot be invoked via the flowagent `run_flow` tool
(`ListCallbackUrlOperationBlocked`) — run them manually from
make.powerautomate.com → flow → **Run**.

Confirmed working end-to-end against Tornillo (`2 - Tornillo`) test data,
including a Fact_InTrans data-discrepancy investigation (a CE51 part
appeared in the raw DAX result but not the report's filtered view — root
cause was the report's own Page 1 `Measure Filter` slicer set to a −50%
to 15% range, silently hiding rows between 15–20% margin; the alert's DAX
was correct all along). Orchestrator rebuilt with the same validated logic
and re-verified via `get_flow` after the JSON-parsing issue (#7 above) was
resolved — full action tree (Run_Detail_Query → Parse_JSON_Detail →
Condition_Should_Send_Alert → Create_CSV_table/Compose_Rows/Compose_HTML_Body/HTTP_sendMail)
confirmed present and correctly wired.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Email not received | Recipient's officeLocation has no PartsBranchMapping row, or is skipped (blank/"Support Center") | Same troubleshooting as Parts Action Summary — check PartsBranchMapping list |
| CSV shows `{"body":"..."}` as literal content | `outputs()` used instead of `body()` on a Table action | Fix the action's expression to use `body('Create_CSV_table')` |
| Description column blank or wrong | Query used `Fact_InTrans[Description]` directly instead of the `dim_Parts` LOOKUPVALUE | Fix the DAX to use `LOOKUPVALUE(dim_Parts[Description], dim_Parts[PartNumber], [PartNumber])` |
| A row expected in the report doesn't appear in the alert | Report-side slicer (e.g. Page 1 Measure Filter) may be hiding it — this is a report display filter, not an alert bug | Verify against the raw DAX query directly, filtered only by Ref No/RONumber, before assuming the alert query is wrong |
| sendMail 401/403 | Same app registration as Parts Action — see that flow's troubleshooting entry (secret expiry April 2028) |
| Flow save fails with a connection-reference error after edits | Missing `connectionRefs` entry for a newly-added connector action | Add the connection reference explicitly in the `update_flow` call, not just in the action's `host` |
| `create_flow`/`update_flow` fails with `InvalidRequestContent`/"Invalid JSON" despite valid JSON | Likely the inline-large-payload fragility described in Known Issues #7 | Export a known-good flow, patch it programmatically (Python), submit the patched file's content instead of hand-typed JSON |

---

## Superseded Design (2026-07-22, replaced 2026-07-27)

The original design alerted on **current inventory pricing** (Page 2,
`dim_Parts_LowMargin`) with two flows: a weekly full-list digest and a
daily new-item alert using a SharePoint tracking-list diff. Both
Orchestrators are **Stopped and left in place, unused** — not deleted —
per Brian's instruction, in case this direction is revisited.

| Setting | Weekly Digest | Daily New-Item Alert (original) |
|---|---|---|
| Orchestrator flow ID | `dad7ae83-e6d8-4f63-af15-7c33c734b025` | `66e29bef-7838-4b01-9e6b-c4a8562fb51d` (deleted 2026-07-27; export retained at `flow-exports/`) |
| Test/manual flow ID | `134dadf0-0ad8-4d0c-ae44-45206184ccc2` | `f6c9fd72-9279-424b-898a-8bc7a8eaf802` (reused/rebuilt for the new design — see above) |
| Trigger | Recurrence — weekly Monday 8:30 AM CST | Recurrence — every weekday 8:30 AM CST |
| Content | Every part+branch currently below 20% margin | Only newly-crossed part+branch combos since last run |

- Threshold was `Actual Margin % (INV) < 0.20` from `dim_Parts_LowMargin`,
  filtered to `OnHandQty > 0 && InventoryCost > 0`.
- `Actual Margin % (INV)` = `DIVIDE(SellValue - InventoryCost, SellValue, 0)`
  where `SellValue = SellPrice1 * OnHandQty`.
- Used a `LowMarginPartsTracking` SharePoint list (site: South Plains
  Implement - Report Site, GUID `c69ed96e-03d5-485a-a763-b6a46a9a75a5`,
  columns: PartBranchKey, PartNumber, Branch, Franchise, FirstFlaggedDate)
  to diff each run's below-threshold set against the prior run, adding
  newly-crossed keys and removing keys that got re-priced.
- Design rationale: `docs/superpowers/specs/2026-07-22-parts-low-margin-alerts-design.md`
- Implementation plan: `docs/superpowers/plans/2026-07-22-parts-low-margin-alerts.md`

This design was abandoned because Ben clarified that store-level parts
staff don't own price changes — corp-office parts managers do — and that
the actionable signal should be actual sales activity below margin, not a
snapshot of mispriced inventory.
