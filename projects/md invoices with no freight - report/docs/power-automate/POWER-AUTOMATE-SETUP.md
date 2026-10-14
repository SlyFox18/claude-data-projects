# Power Automate Setup — MD Freight Alerts

## ⚠️ Architecture change (2026-07-27) — read this first

The **weekly digest is no longer a standalone flow.** Ben (stakeholder)
asked, after seeing the standalone weekly digest working, to fold it into
the existing **"Parts Action Summary - Orchestrator"** flow instead — one
consolidated weekly action-items email per branch manager rather than yet
another separate email, to avoid email fatigue. The weekly MD Freight KPI
section (Invoices Flagged + Freight Opportunity $) and `MD_Freight_Missed.csv`
attachment now ship as part of that flow's Wednesday 8:00 AM run.

**Full detail on the merged weekly flow lives in
`projects/parts action dashboard - report/documentation/power-automate-setup.md`**
(its "MD Freight" DAX/attachment/HTML sections) — that is now the
authoritative doc for the weekly send. This doc's DAX/gotchas below are
still accurate and were reused as-is in that merge; only the *delivery
mechanism* for the weekly cadence changed.

The **standalone "MD Freight Weekly Digest" Orchestrator and test flow
(`9de57c5b-547d-4a89-a368-c46ac141b215` / `35f9ea68-361f-478b-9371-2ef35298212d`)
still exist**, fully built and tested, but are now redundant — left
**Stopped** intentionally as a fallback/reference rather than deleted.
Candidates for cleanup later; not urgent since Stopped flows have zero
effect.

The **daily "MD Freight New Item Alert" is unaffected** — it remains its
own standalone flow (see below), since Ben only asked to consolidate the
weekly cadence, not the daily one.

## Overview

One flow (the daily alert) alerts parts/branch staff when an open MD
(Machine Down) invoice newly becomes missing freight or significantly
under-charged; the weekly view is now delivered via Parts Action Summary
(see above). Built by hand-authoring flow JSON via the Power Automate
flowagent MCP tools (`get_flow` on an existing sibling flow as a structural
template, then `create_flow`/`update_flow` — `copy_flow`/`edit_flow` are
broken in this environment), reusing the same distribution mechanism as the
Parts Action Summary and Low Margin flows (SPI-PARTS Azure AD group +
PartsBranchMapping SharePoint list + "Parts Action Dashboard Email" app
registration) but with distinct amber visual styling so recipients never
confuse the email families.

Design rationale: `docs/superpowers/specs/2026-07-24-md-freight-alerts-design.md`
Implementation plan: `docs/superpowers/plans/2026-07-24-md-freight-alerts.md`
(both predate the 2026-07-27 architecture change above — describe the
original two-flow design, which was superseded for the weekly cadence only)

## Flow Overview

| Setting | Weekly Digest (superseded — see above) | Daily New-Item Alert (active design) |
|---|---|---|
| Orchestrator flow ID | `9de57c5b-547d-4a89-a368-c46ac141b215` (Stopped, unused) | `8f49bdfb-c777-4bcf-a83f-b4422f8d0f1d` |
| Test/manual flow ID | `35f9ea68-361f-478b-9371-2ef35298212d` (Stopped, unused) | `54e48914-c8f5-4127-9dd1-4f1048dadf1d` |
| Trigger | n/a — weekly content now rides Parts Action Summary's Wed 8:00 AM run | Recurrence — placeholder weekdays 9:00 AM CST |
| Content | n/a | Only invoices newly qualifying since the last run |
| Orchestrator state as of 2026-07-27 | **Stopped** — kept as fallback, not deleted | **Stopped** — awaiting Ben's go-ahead to enable |
| Environment | Brian Fox's Environment, `2cf47cce-a195-ed3a-94e1-287c38adb011` (the one **without** Dataverse — see Known Issues) | same |

9:00 AM is later than the Low Margin flows' 8:30 AM because this report is
**Tier 2** (can finish refreshing after 8 AM), not Tier 1. Not yet
finalized — no schedule has gone live yet; waiting on Ben's approval.

## Data & Threshold

- Dataset: "MD Invoices With No Freight" — workspace (groupid)
  `4f2d10c6-11e1-4d3a-959d-a461ef9a4cd7` ("RP - Parts Reports"), dataset
  (datasetid) `88bcada9-ceeb-42e5-99f9-9b6cd06a9f0d`.
- Threshold: `Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"` OR
  (`FreightBucket = "Partial Freight"` AND
  `Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10`) — hardcoded
  10%, independent of the report's own adjustable "Alert Threshold %"
  slider (which stays a separate what-if tool on the report, defaulting to
  15%).
- Qualification is at **invoice grain** (`FileNumber`), not part-line
  grain — an invoice with 3 part lines is one qualifying (or non-qualifying)
  unit, matching how `MissedFreightAmount`/`PctFreightDifference`/
  `FreightBucket` are computed on the fact table itself (`ALLEXCEPT` on
  `FileNumber`).

## Confirmed Live DAX (validated 2026-07-24/27 against Branch `11 - Brownfield`)

### Detail query (Invoice+Part row grain — used for the CSV attachment)

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = "Partial Freight"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        "Invoice #", FORMAT(Fact_MDInvoices_NoFreight[FileNumber], "0"),
        "RO #", FORMAT(Fact_MDInvoices_NoFreight[RONumber], "0"),
        "Order Date", Fact_MDInvoices_NoFreight[OrderDate],
        "Branch", Fact_MDInvoices_NoFreight[Branch],
        "Part Number", Fact_MDInvoices_NoFreight[PartNumber],
        "Order Qty", [Order Qty],
        "Sell Price 1", [Sell Price 1],
        "Unit Price", [Unit Price],
        "Weight", CALCULATE([Total Weight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "Actual Freight", CALCULATE([Actual Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "Calculated Freight", CALCULATE([Calculated Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "% Freight Difference", CALCULATE([% Freight Difference], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "Missed Freight", CALCULATE([Missed Freight], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber]))
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

### Aggregate query (weekly digest KPI cards only)

```dax
EVALUATE
ROW(
    "InvoicesFlagged", COALESCE(CALCULATE(
        DISTINCTCOUNT(Fact_MDInvoices_NoFreight[FileNumber]),
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = "Partial Freight"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0),
    "OpportunityDollars", COALESCE(CALCULATE(
        SUMX(
            VALUES(Fact_MDInvoices_NoFreight[FileNumber]),
            CALCULATE([Missed Freight])
        ),
        FILTER(
            Fact_MDInvoices_NoFreight,
            Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"
                || (Fact_MDInvoices_NoFreight[FreightBucket] = "Partial Freight"
                    && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
        ),
        dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"), 0)
)
```

### Per-invoice summary query (daily alert only — diff keys + dedup'd display)

```dax
EVALUATE
CALCULATETABLE(
    SELECTCOLUMNS(
        SUMMARIZE(
            FILTER(
                Fact_MDInvoices_NoFreight,
                Fact_MDInvoices_NoFreight[FreightBucket] = "No Freight"
                    || (Fact_MDInvoices_NoFreight[FreightBucket] = "Partial Freight"
                        && Fact_MDInvoices_NoFreight[PctFreightDifference] >= 0.10)
            ),
            Fact_MDInvoices_NoFreight[FileNumber]
        ),
        "Invoice #", FORMAT(Fact_MDInvoices_NoFreight[FileNumber], "0"),
        "Branch", CALCULATE(MAX(Fact_MDInvoices_NoFreight[Branch]), ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "% Freight Difference", CALCULATE([% Freight Difference], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])),
        "Status", IF(
            CALCULATE(MAX(Fact_MDInvoices_NoFreight[FreightBucket]), ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber])) = "No Freight",
            "Missed",
            "Partial"
        )
    ),
    dim_BranchLocation[Branch] = "@{variables('RecipientBranchFilter')}"
)
```

Produces exactly one row per qualifying invoice (via `SUMMARIZE` on
`FileNumber`), used two ways in the daily alert flow: `Compose_CurrentKeys`
extracts just `[Invoice #]` for the add/remove diff against the tracking
list, and `Filter_NewItemSummary` (filtered to the newly-crossed subset)
feeds the email's on-screen table — giving a clean one-row-per-invoice
summary with a `Missed`/`Partial` label, instead of repeating a row per part
line. The CSV attachment still uses the full detail query (line grain), so
part-level detail isn't lost — it's just not repeated in the email body.

## SharePoint Tracking List (daily alert only)

**Site:** South Plains Implement - Report Site (same site as
`PartsBranchMapping` and `LowMarginPartsTracking`)
**List:** `MDFreightTracking`, GUID `1dee91c8-9181-4737-befa-304ae4ec9a5f`

| Column | Type |
|---|---|
| FileNumber | Single line text |
| Branch | Single line text (BranchFilter format, e.g. `"11 - Brownfield"`) |
| FirstFlaggedDate | Date and Time |

**Sync logic (daily alert flow only):** each run queries the current
per-invoice summary (above), diffs its `[Invoice #]` values against this
list's `FileNumber` values via `Select` + `Query` (`not(contains(...))`),
creates a new list item for every newly-crossed invoice, and deletes the
list item for any invoice no longer qualifying (freight added/corrected, or
the order closed). Self-correcting — no manual cleanup needed. Confirmed
live (2026-07-27): baseline run flags every currently-qualifying invoice as
new; an immediate re-run is a silent no-op; manually deleting one tracking
row and re-running correctly re-flags just that one invoice.

## Shared Infrastructure (reused as-is)

- SPI-PARTS Azure AD group + officeLocation → PartsBranchMapping lookup:
  identical to Parts Action Summary / Low Margin's recipient pipeline.
  PartsBranchMapping list GUID `19da5d2c-18b8-4359-8c0b-9a4e2711210d`.
- "Parts Action Dashboard Email" Entra app registration (Mail.Send,
  GroupMember.Read.All) — same `clientId`/`tenant`/`secret` reused inline in
  every HTTP action's `authentication` block, matching the existing
  production flows' established pattern (not a new pattern introduced
  here).
- Sender mailbox: `bfox@spitractor.com` (Graph API
  `POST /v1.0/users/bfox@spitractor.com/sendMail`).
- Power BI connection: `shared_powerbi`
  (`shared-powerbi-04fe5718-dd42-4f4b-8e94-555dfbfdc0c1`).
- SharePoint connection: `shared_sharepointonline`
  (`shared-sharepointonl-91a46c53-a2ad-426d-af54-cd3d21665ce7`) — bare name
  (no `-1` suffix) on both new Orchestrators, unlike the Low Margin
  Orchestrators which use `shared_sharepointonline-1`; both point at the
  same underlying connection. The auto-discovered "PA-DataLoad" SharePoint
  connection is broken for these lists (502/UserName parsing error) — do
  not use it, always reuse this proven connection GUID.

## Email Design

Both emails use the same rich HTML template family as Parts Action / Low
Margin — 800px centered table layout, South Plains Implement logo in the
header, a footer with contact info — recolored per flow:

| Flow | Header color | Accent |
|---|---|---|
| Weekly Digest | `#0e8a9c` (turquoise) | KPI cards `#e9f7f9` bg / `#a9dee4` border; Invoices Flagged in turquoise, Opportunity $ in amber (`#c98a1c`) |
| Daily Alert | `#b8590f` (flat amber — no CSS gradient; Outlook's Word rendering engine doesn't support them reliably) | Summary table: Invoice # / Branch / Status (Missed or Partial) / % Freight Difference |

**Design iteration note:** the first build used a plain `<div>`-based HTML
body (no logo, no greeting, no footer) matching only the color scheme
approved during brainstorming — this under-shot the actual sibling flows,
which use a much richer table-based template. Fixed by pulling the exact
Low Margin HTML template live via `get_flow` and recoloring it, rather than
guessing. If building a third flow in this family, start from one of these
two flows' `Compose_HTML_Body` action content, not from scratch.

**CSV columns** (both flows, full detail/line grain): `Invoice #`, `RO #`,
`Order Date`, `Branch`, `Part Number`, `Order Qty`, `Sell Price 1`,
`Unit Price`, `Weight`, `Actual Freight`, `Calculated Freight`,
`% Freight Difference`, `Missed Freight`.

## Corp Manager CC + sendMail Body Rewrite (added 2026-08-18)

Ben Hill asked to receive every branch's daily alert, and to add Barry
Sheets (Corporate North) and Curt Summers (Corporate South) scoped to
their own branch groups — same ask, same implementation pattern, applied
identically to the Low Margin New Item Alert Orchestrator on the same
date; see that flow's setup doc
(`projects/part sales with low margin/docs/06-power-automate/POWER-AUTOMATE-SETUP.md`,
"Corp Manager CC" section) for the full rationale and the branch-group
table. Corp managers remain skipped from the per-recipient loop
(`officeLocation = "Support Center"`) — they're CC'd on the relevant
branch manager's own email instead, no new SharePoint columns or loop
changes.

**This flow's `HTTP_sendMail` body was also converted from the old
string-concatenated JSON pattern to a native JSON object body** (matching
the fix already applied to Low Margin on 2026-07-28 — see that flow's
Known Issues #12 / "sendMail Body" note) as part of adding the CC field,
rather than splicing another string fragment into the fragile concat
pattern. The `body` input is now:

```json
"body": {
  "message": {
    "subject": "@{concat('New Freight Alert - ', variables('RecipientBranchName'), ' - ', formatDateTime(utcNow(),'MMMM d, yyyy'))}",
    "body": { "contentType": "HTML", "content": "@{outputs('Compose_HTML_Body')}" },
    "toRecipients": [ { "emailAddress": { "address": "@{variables('RecipientEmail')}" } } ],
    "ccRecipients": "@if(contains(createArray('Lamesa','Littlefield','Levelland','Morton','Tahoka','Lorenzo','Slaton','Lubbock','Crosbyton','Abernathy'), variables('RecipientBranchName')), createArray(createObject('emailAddress', createObject('address', 'bhill@spitractor.com')), createObject('emailAddress', createObject('address', 'bsheets@spitractor.com'))), if(contains(createArray('Seminole','Tornillo','Denver City','Mesquite','San Angelo','Ballinger','Big Spring','Brownfield','Snyder'), variables('RecipientBranchName')), createArray(createObject('emailAddress', createObject('address', 'bhill@spitractor.com')), createObject('emailAddress', createObject('address', 'csummers@spitractor.com'))), createArray(createObject('emailAddress', createObject('address', 'bhill@spitractor.com')))))",
    "attachments": [ { "name": "New_MD_Freight_Missed.csv", "contentBytes": "@{base64(body('Create_CSV_table'))}", "@@odata.type": "#microsoft.graph.fileAttachment" } ]
  }
}
```

Note the `"@@odata.type"` double-@ escape (native-object form, required —
see Known Issues #12 in the Low Margin doc) versus the old pattern's
single `\"@odata.type\"` (fine inside a plain string).

Applied 2026-08-18 via `preview_update` → diff-verified (only the
`Apply_to_each` loop's nested actions changed, all 5 other top-level
actions byte-identical) → `update_flow` with the returned `previewToken`.
Expression syntax confirmed via `validate_flow`. This flow was Stopped
until earlier the same day (2026-08-18) when Brian turned it on per Ben's
go-ahead — first live run (weekdays 9:00 AM CST) will be the first real
confirmation of both the daily-alert logic itself and this CC addition.
**Not yet applied to the Parts Action Summary Orchestrator** — see the
Low Margin doc's Corp Manager CC section for why, and the exact manual
steps needed there instead.

---

## Known Issues / Gotchas (discovered while building)

1. **`copy_flow`/`edit_flow` are broken** in this flowagent MCP environment
   — same as the Low Margin build. Use `get_flow` on a sibling flow as a
   structural template, then `create_flow`/`update_flow` to build/patch by
   hand.
2. **Row-context gotcha on line-grain fact tables:** `'Actual Freight'`,
   `'Calculated Freight'`, `'Missed Freight'`, `'% Freight Difference'`, and
   `'Total Weight'` all internally dedupe via
   `SUMX(VALUES(Fact_MDInvoices_NoFreight[FileNumber]), ...)` with no
   `ALLEXCEPT`. Called naively from a `SELECTCOLUMNS` row iteration over the
   line-grain fact table (one row per part line), the implicit
   context-transition filters on *every* column of the current row, not
   just `FileNumber` — silently returning just that single line's own value
   instead of the true invoice-level total. Fixed by wrapping each measure
   call in `CALCULATE([Measure], ALLEXCEPT(Fact_MDInvoices_NoFreight,
   Fact_MDInvoices_NoFreight[FileNumber]))`. Confirmed live (invoice
   1508170, 3 part lines): without the wrap, `Missed Freight` returned
   `-116.04`/`-52.15`/`+6.25` per line instead of the correct `+80.07`
   repeated on all three.
3. **`FileNumber`/`RONumber` are `int64` in the model**, so Power BI's
   `executeQueries` REST API serializes them as JSON integers — but they
   need to be text end-to-end (SharePoint tracking-list keys, diff/`contains`
   logic). The `Parse JSON` schema correctly declares them as strings, which
   caused a hard schema-validation failure on first live test
   (`Invalid type. Expected String but got Integer.`). Fixed by wrapping
   both in `FORMAT(..., "0")` in the DAX.
4. **Line-grain duplication in the daily alert's on-screen table:** building
   the "new items" HTML table directly from the (line-grain) detail query
   showed the same invoice repeated once per part line, while the banner
   text ("N invoice(s) crossed threshold") correctly counted invoices. Fixed
   by adding a dedicated per-invoice summary query (`SUMMARIZE` on
   `FileNumber`) and building the on-screen table from that instead —  the
   CSV attachment still uses the full line-grain detail so part-level
   information isn't lost, just not shown redundantly in the email body.
5. **`pbi-cli`'s `pbi dax execute` command silently drops DAX row results.**
   The MCP server returns results as an `EmbeddedResource` content block
   (payload at `block.resource.text`), but `pbi-cli`'s `_parse_content()`
   only reads `TextContent` blocks — it always reports `{"success": true}`
   with no data, for every query. Confirmed via source inspection
   (`pbi_cli/core/mcp_client.py`, `_parse_content()`) and reproduced twice
   independently. Workaround: a standalone Python script using the `mcp`
   library bundled in the `pbi-cli-tool` venv, reading
   `EmbeddedResource.resource.text` directly — see
   `feedback_powerbi_mcp_dax_execute_blocked` in Claude's memory for the
   full pattern. Worth checking for an upstream fix before re-deriving this
   workaround in a future session.
6. **`host.connectionName` in `OpenApiConnection` actions must be the
   connection-reference logical key** (e.g. `"shared_powerbi"`), not the
   literal connection GUID — the GUID belongs only inside the top-level
   `connectionRefs[key].connectionName`. Putting the GUID directly in
   `host.connectionName` produces "The API connection reference '<GUID>'
   could not be found" even though the connection is genuinely `Connected`.
7. **`preflight_flow`/`validate_flow` flag `extra-authentication`** on both
   `HTTP_-_Get_Users` and the `OpenApiConnection` actions' inline
   `authentication` blocks — confirmed as a pre-existing lint false
   positive shared by the Low Margin flows too (same finding reproduced
   against `Low Margin Weekly Digest - Orchestrator`), not a regression.
   The real Flow API accepts and persists the pattern fine.

## Testing

Both test/manual flows accept 4 manual inputs (Name, Branch, BranchFilter,
Email) via a Button trigger. Button-triggered flows cannot be invoked via
the flowagent `run_flow` tool (`ListCallbackUrlOperationBlocked`) — run them
manually from make.powerautomate.com → flow → **Run**.

Both confirmed working end-to-end against Brownfield (`11 - Brownfield`)
test data (2026-07-27): weekly digest CSV/HTML verified correct against the
live DAX validation numbers; daily alert baseline run (empty tracking list
→ every qualifying invoice flagged as new), idempotency run (re-run with no
data change → zero items, no email sent), and resolution-simulation run
(one tracking row manually deleted → only that invoice re-flagged) all
confirmed correct.

**Since the 2026-07-27 architecture change:** to test the weekly MD Freight
content, use **"Parts Action Summary - Weekly Branch Email"** (see the
Parts Action Dashboard project's setup doc), not the standalone weekly test
flow above — the standalone flow still runs fine but its output no longer
reflects what real branch managers actually receive. The daily alert's test
flow here is still the correct one to use for daily-alert testing.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Email not received | Recipient's officeLocation has no PartsBranchMapping row, or is skipped (blank/"Support Center") | Same troubleshooting as Parts Action Summary / Low Margin — check PartsBranchMapping list |
| `Parse JSON Detail` fails with "Expected String but got Integer" | A raw identifier column (e.g. `FileNumber`, `RONumber`) isn't wrapped in `FORMAT(..., "0")` in the DAX | Add the `FORMAT()` wrap to the offending column in `Run_Detail_Query`/`Run_Current_Keys_Query` in both the Orchestrator and its test flow |
| Multi-line invoice shows wrong/varying freight totals across its part lines | Missing `ALLEXCEPT` wrap on `Weight`/`Actual Freight`/`Calculated Freight`/`% Freight Difference`/`Missed Freight` | Wrap the measure call in `CALCULATE([Measure], ALLEXCEPT(Fact_MDInvoices_NoFreight, Fact_MDInvoices_NoFreight[FileNumber]))` |
| Same invoice appears multiple times in the daily alert's on-screen table | The HTML table is built from the line-grain detail/`Filter_NewItemRows` instead of the per-invoice summary/`Filter_NewItemSummary` | Repoint `Create_HTML_table_NewItemsTable`'s `from` to `Filter_NewItemSummary` |
| Daily alert fires every day for the same invoice | Tracking list sync logic broken, or list manually edited | Check `MDFreightTracking` — the flow should have removed the key when the invoice was last confirmed resolved |
| CSV shows `{"body":"..."}` as literal content | `outputs()` used instead of `body()` on a Table action | Fix the action's expression to use `body('Create_CSV_table')` |
| sendMail 401/403 | Same app registration as Parts Action / Low Margin — see those flows' troubleshooting entries (secret expiry April 2028) |
| Flow save fails with a connection-reference error after edits | Missing `connectionRefs` entry for a newly-added connector action, or a literal GUID used in `host.connectionName` instead of the logical key | Add the connection reference explicitly in the `update_flow` call; use the logical key (e.g. `shared_powerbi`) in `host.connectionName` |
