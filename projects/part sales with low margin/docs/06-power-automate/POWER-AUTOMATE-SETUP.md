# Power Automate Setup — Low Margin Pricing Alerts

## Overview

Two independent flows alert parts staff when current inventory is priced
below 20% margin. Built by hand-authoring flow JSON via the Power Automate
flowagent MCP tools (not cloned from Parts Action Summary — `copy_flow` was
broken in this environment; see Known Issues), reusing the same
distribution mechanism (SPI-PARTS Azure AD group + PartsBranchMapping
SharePoint list + "Parts Action Dashboard Email" app registration) but with
distinct purple/red visual styling so recipients never confuse them with
the Parts Action email.

Design rationale: `docs/superpowers/specs/2026-07-22-parts-low-margin-alerts-design.md`
Implementation plan: `docs/superpowers/plans/2026-07-22-parts-low-margin-alerts.md`

## Flow Overview

| Setting | Weekly Digest | Daily New-Item Alert |
|---|---|---|
| Orchestrator flow ID | `dad7ae83-e6d8-4f63-af15-7c33c734b025` | `66e29bef-7838-4b01-9e6b-c4a8562fb51d` |
| Test/manual flow ID | `134dadf0-0ad8-4d0c-ae44-45206184ccc2` | `f6c9fd72-9279-424b-898a-8bc7a8eaf802` |
| Trigger | Recurrence — weekly Monday 8:30 AM CST | Recurrence — every weekday 8:30 AM CST (see Known Issues re: schedule syntax) |
| Content | Every part+branch currently below 20% margin | Only newly-crossed part+branch combos since last run |
| Orchestrator state as of 2026-07-23 | **Stopped** — awaiting go-live approval | **Stopped** — awaiting go-live approval |
| Environment | Brian Fox's Environment, `2cf47cce-a195-ed3a-94e1-287c38adb011` (the one **without** Dataverse — see Known Issues) | same |

## Data & Threshold

- Dataset: "Part Sales with Low Margin" — workspace (groupid)
  `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7`, dataset (datasetid)
  `412c8395-7a2f-480c-996b-53af35a3ec02`.
- Threshold: `Actual Margin % (INV) < 0.20`, computed per part+branch+franchise
  row from `dim_Parts_LowMargin`, filtered to `OnHandQty > 0 && InventoryCost > 0`
  (both filters confirmed to match the live Page 2 report table's own applied
  filters — see design spec).
- `Actual Margin % (INV)` = `DIVIDE(SellValue - InventoryCost, SellValue, 0)`
  where `SellValue = SellPrice1 * OnHandQty`.
- Full validated detail-query DAX and aggregate-query DAX are embedded
  verbatim in both flows' `Run_Detail_Query`/`Run_Aggregate_Query` actions —
  see the plan doc for the exact text if rebuilding from scratch.
- `PartBranchKey` (existing column on `dim_Parts_LowMargin`,
  `PartNumber|Branch|Franchise`) is the tracking key for the daily alert's
  diff logic. It's excluded from the weekly digest CSV (not useful to a
  human reader) but currently still present in the daily alert's CSV — a
  deliberate simplification to reduce flow complexity, since that CSV is
  usually 0-2 rows.

## SharePoint Tracking List (daily alert only)

**Site:** South Plains Implement - Report Site (same site as `PartsBranchMapping`)
**List:** `LowMarginPartsTracking`, GUID `c69ed96e-03d5-485a-a763-b6a46a9a75a5`

| Column | Type |
|---|---|
| PartBranchKey | Single line text |
| PartNumber | Single line text |
| Branch | Single line text (BranchFilter format, e.g. `"2 - Tornillo"`) |
| Franchise | Single line text |
| FirstFlaggedDate | Date and Time |

**Sync logic (daily alert flow only):** each run queries the current
below-threshold set, diffs against this list's `PartBranchKey` values via
`Filter Array` + `contains()`/`not()` (see Known Issues — there is no native
`difference()` function), creates a new list item for every newly-crossed
key, and deletes the list item for any key that's no longer below threshold
(i.e. the part got re-priced). This makes the list self-correcting — no
manual cleanup needed.

## Shared Infrastructure (reused as-is)

- SPI-PARTS Azure AD group + officeLocation → PartsBranchMapping lookup:
  identical to the Parts Action Summary Orchestrator's recipient pipeline.
- "Parts Action Dashboard Email" Entra app registration (Mail.Send,
  GroupMember.Read.All) — same `clientId`/`tenant`/`secret` reused inline in
  every HTTP action's `authentication` block, matching how the existing
  production flow already does it (not a new pattern introduced here).
- Sender mailbox: `bfox@spitractor.com` (matches Parts Action's sendMail
  pattern — Graph API `POST /v1.0/users/bfox@spitractor.com/sendMail`).
- Power BI connection: `shared-powerbi-04fe5718-dd42-4f4b-8e94-555dfbfdc0c1`
  (connection reference key `shared_powerbi`).
- SharePoint connection: `shared-sharepointonl-91a46c53-a2ad-426d-af54-cd3d21665ce7`
  (connection reference key `shared_sharepointonline-1`, or bare
  `shared_sharepointonline` on the manual/test flows — see Known Issues,
  the auto-discovered connection `shared-sharepointonl-8446ffb5-...` is
  broken and must not be used).

## Known Issues / Gotchas (discovered while building)

1. **`copy_flow` and `edit_flow` are broken** in this flowagent MCP
   environment (`ctx.getClient(...).copyFlow/editFlow is not a function`).
   Use `get_flow` to read a source flow's JSON, then `create_flow`/`update_flow`
   to build/patch the new one by hand.
2. **`select()` and `difference()` are not real expression functions** —
   despite being tempting names, Power Automate's workflow expression
   language has no such functions (confirmed via the flowagent
   `get_expression_help` tool, which lists all valid functions). Use a
   `Select` **action** (type `"Select"`) to extract a column into a flat
   array, and `Filter Array` (type `"Query"`) with `not(contains(...))` to
   compute set differences.
3. **A `Table` action's actual content is `body('ActionName')`, not
   `outputs('ActionName')`** — using `outputs()` on a Create CSV/HTML table
   action dumps the whole action envelope (e.g. `{"body":"..."}`) into the
   output instead of just the table content. This caused a real bug in the
   first build of the weekly digest (garbled CSV) — fixed by switching to
   `body()`.
4. **`update_flow` enforces stricter schema validation than `create_flow`**
   for `OpenApiConnection` actions: it rejects an explicit `authentication`
   property in `inputs` (even though `create_flow` accepts it, and the
   existing production Parts Action flow already has it saved that way) and
   requires `host.connectionReferenceName` in addition to
   `host.connectionName`. When adding new connector actions to an existing
   flow via `update_flow`, also add a matching entry to the top-level
   `connectionRefs` — connection references not referenced by any action at
   creation time get silently pruned, and a later `update_flow` referencing
   them by name will fail with "connection reference could not be found."
5. **Recurrence trigger validation:** `weekDays` is only valid with
   `frequency: "Week"`, not `"Day"`. The correct way to express "every
   weekday" is `frequency: "Week", interval: 1, schedule.weekDays: [Mon..Fri]`.
6. **Two environments share the exact display name** "Brian Fox's
   Environment" in this tenant (one with Dataverse, one without). All flows
   in this project live in the one **without** Dataverse:
   `2cf47cce-a195-ed3a-94e1-287c38adb011`. See
   `reference_power_platform_known_issues` in Claude's memory for more.
7. **2026-07-23 Microsoft-side outage** (Power Platform "Known Issues" ID
   6576887, "Power Automate and Environment Loading Issues") caused the
   Flow API to return empty flow lists and `AzureResourceManagerServerError`/
   `ServerTimeout` for roughly the length of one work session. Resolved on
   its own; no data was lost. If flows seem to vanish, check Admin Center →
   Support → Known Issues before assuming anything was deleted.

## Testing

Both test/manual flows (`134dadf0...` and `f6c9fd72...`) accept 4 manual
inputs (Name, Branch, BranchFilter, Email) via a Button trigger, matching
the existing "Parts Action Summary - Weekly Branch Email" test-flow pattern.
Button-triggered flows cannot be invoked via the flowagent `run_flow` tool
(`ListCallbackUrlOperationBlocked`) — run them manually from
make.powerautomate.com → flow → **Run**.

Both confirmed working end-to-end against Tornillo (`2 - Tornillo`) test
data: weekly digest CSV/HTML verified correct; daily alert baseline run
(empty tracking list → 40 "new" items) and idempotency run (re-run with no
data change → zero items, no email sent) both confirmed correct.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Email not received | Recipient's officeLocation has no PartsBranchMapping row, or is skipped (blank/"Support Center") | Same troubleshooting as Parts Action Summary — check PartsBranchMapping list |
| CSV shows `{"body":"..."}` as literal content | `outputs()` used instead of `body()` on a Table action | Fix the action's expression to use `body('Create_CSV_table')` |
| Daily alert fires every day for the same part | Tracking list sync logic broken, or list manually edited | Check `LowMarginPartsTracking` — the flow should have removed the key when the part was last confirmed above threshold |
| sendMail 401/403 | Same app registration as Parts Action — see that flow's troubleshooting entry (secret expiry April 2028) |
| Flow save fails with a connection-reference error after edits | Missing `connectionRefs` entry for a newly-added connector action | Add the connection reference explicitly in the `update_flow` call, not just in the action's `host` |
