# Open Work Orders Labor Last 10 Days Alert — Power Automate

Daily email to Branch 91 (Lorenzo) parts staff listing every open work order
that has had labor punched in the last 10 days (any age). Same build pattern as the
Low Margin / MD Freight alerts: a manual-button test flow plus a scheduled Orchestrator.

## History

- 2026-09-28: built as "Open Work Orders 1-7 Days Alert" (WOs in the report's 1 - 7 Days aging bucket).
- 2026-09-29: users asked for labor recency instead of creation age. The criteria became
  `DaysSinceLastLabor <= 10`, a Last Labor column was added, the sort is now newest labor first,
  and both flows were renamed.

## Flows (env `2cf47cce-a195-ed3a-94e1-287c38adb011`)

| Flow | ID | Trigger |
|---|---|---|
| Open Work Orders Labor Last 10 Days Alert - Branch Email | `14c01bc1-f6ed-449d-81d3-e167f40644be` | Manual button (Name, Email) — test only |
| Open Work Orders Labor Last 10 Days Alert - Orchestrator | `df03a591-465d-4c5c-a341-3191e5d54874` | Recurrence Mon–Fri 7:00 AM Central |

## Data

- Model: `Open Work Orders` in `RP - Service Reports`
  (workspace `fa9b2eef-d507-48ad-bbeb-242037941987`, dataset `cdb3ffdb-a3d4-4d98-aeba-2e711c360fed`)
- Filter: `dim_BranchLocation[Branch] = "91 - Lorenzo"` (includes both `91` and `91I` internal WOs),
  `NOT ISBLANK(DaysSinceLastLabor)` and `Fact_OpenWorkOrders[DaysSinceLastLabor] <= 10`.
  "Not Started" WOs (no labor punch, DaysSinceLastLabor ≈ 46,000) drop out naturally.
- `DaysSinceLastLabor` is computed at model refresh (~6:30 AM), before the 7:00 AM send.
- Grain: the fact table has one row per job code, so the query `SUMMARIZE`s to one row
  per Branch + WorkOrder.
- Columns: Work Order #, Creation Date, Last Labor (`LastLaborPunch`), Customer Name
  (`CustomerNamePunch`; `(Internal)` when blank on 91I), Tech (`dim_Technician_Code_Names[TechnicianDisplayName]`).
- Sort: Last Labor descending, then Work Order #.
- Known source quirk: a few WOs show Last Labor earlier than Creation Date (e.g. 698746). The report shows
  the same values, so this comes from the source data, not the flow.

## Email

- Sender: `parts-notifications@spitractor.com` via Graph `sendMail` ("Parts Action Dashboard Email" app registration).
- Theme: green (`#1b5e20` header, `#e8f5e9` table header) — distinct from Low Margin (red),
  MD Freight (amber/turquoise) and Parts Action (navy).
- Attachment: `Open_Work_Orders_Labor_Last_10_Days.csv`.
- No email is sent when no WOs qualify.

## Recipients (Orchestrator)

Hard-coded list in the `Compose_Recipient_List` action (changed 2026-09-29, because some
Lorenzo parts staff have no company email). Each address gets its own email; no CC:

- lmcham@spitractor.com
- ngparnell@yahoo.com
- christianshane868@icloud.com
- jsalazar@spitractor.com
- oellis@spitractor.com
- dhagler@spitractor.com

The SPI-PARTS group lookup was removed, so changes to the group no longer affect this
flow. To add or remove someone, edit `Compose_Recipient_List`; this doesn't touch the secrets.
The query runs once per run, not per recipient. Failure alert goes to bfox@spitractor.com.

## Client secret

The flowagent `edit_flow` tool is broken, so every change is a full `update_flow`, and Claude
can't write the Graph client secret into a flow. After each update, every HTTP action's
authentication **Secret** field is reset to `PASTE_CLIENT_SECRET_HERE` (1 in the test flow,
2 in the Orchestrator). Paste the same secret the Low Margin flows use, and turn the
Orchestrator back on if the update left it Stopped.
