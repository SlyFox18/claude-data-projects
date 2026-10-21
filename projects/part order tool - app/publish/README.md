# Non-JD Parts Order Tool - data publish

Reads DP Gold (`Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory`, `Fact_OutstandingTransfers`, `dim_BranchLocation`)
after the morning DP run and uploads the web app's data files to the SharePoint library **NonJD Order Data**
on https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite.

- Plan: `docs/superpowers/plans/2026-10-20-non-jd-parts-order-tool-data-feed.md`
- Spec: `docs/superpowers/specs/2026-10-20-non-jd-parts-order-tool-redesign-design.md`
- Where the business rules live: the Gold notebook (fabric-workspace-docs
  `workspaces/DP - Presentation - Dev/Fact Tables/Parts Order Tool/Build_Gold_NonJD_Reorder.Notebook`) and its
  independent check, `tools/dp-migration/nonjd_reorder_check.py`.
- Runs on the Gateway PC (SPI00T4022W11), Task Scheduler `\SPI\Non-JD Order Tool Publish`, "run whether user is
  logged on or not", as the Parts Availability task's account.
- `NONJD_SOURCE` in `.env` picks the DP tier (`dev` or `prod`).

## Setup

1. `python -m venv .venv`
2. `.venv\Scripts\pip install -r requirements.txt`
3. Copy `.env.example` to `.env` and fill `TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `SITE_ID`, `DRIVE_ID` and
   `NONJD_SOURCE` (default `dev`). `NONJD_ENV_FILE` points at a different settings file.
4. With no `CLIENT_SECRET`, reads of OneLake use your `az` CLI login but uploads fail (they need the service principal).

## Running it

By hand: `python run_publish.py`. Tests: `python -m pytest -q` (run from this folder; it has its own conftest.py).

What decides whether to publish:
- It looks back 14 days in `dp_refresh_log` for the latest `Build_Gold_NonJD_Reorder` item row. Skipped rows are
  ignored. It publishes only if that latest run succeeded and hasn't been published yet.
- It refuses (exit 1) if `Fact_NonJD_Reorder.BuiltAtUtc` is outside that run, or if the table changes during extraction.

What gets uploaded:
- The reorder, surplus, transfers and rules files are re-uploaded on every new DP run (they embed `dataAsOf`, so their
  content always changes). History files are uploaded only when their content changed. `_meta.json` goes last.
- If `NONJD_SOURCE` changes, every file is re-sent.
- Files over 4 MB fail the upload (there is no chunked upload yet).

Other behavior:
- `--force` re-publishes the latest run, if it succeeded, and re-sends every file (use it to repair a file damaged
  or deleted in SharePoint). If the latest run failed it does nothing (exit 0).
- State is in `publish_state.json` (written atomically). Deleting it has the same effect as `--force` on the next run.
- A single-instance lock (`publish.lock`) stops overlapping runs; a second copy prints a message and exits 0.
- Exit code 0 = published or nothing to do; 1 = error (Task Scheduler shows last result 0x1).

Task Scheduler setup:
- Action: `cmd.exe /c ".venv\Scripts\python.exe run_publish.py >> publish.log 2>&1"`, Start in = this `publish` folder.
- Trigger: weekdays 07:15, repeat every 30 minutes for 3 hours.
- Settings: "Do not start a new instance"; stop the task if it runs longer than 25 minutes.

## For the app (Plan B)

- Fetch only the branches listed in `_meta.json`. Files of branches that dropped out stay in the library.
- A crash mid-upload can briefly leave some branch files newer than `_meta.json` until the next run heals it. If
  `reorder_<b>.dataAsOf` differs from `_meta.dataAsOf`, show the file's own date.
- History files have no `dataAsOf`, so a stale history file after a mid-upload crash can't be detected from the file
  itself (it heals on the next run).
- Show `dataAsOf` and flag data older than one business day.

## File contract (schemaVersion 1)

schemaVersion 1 = this rules-list contract (2026-10-20); the earlier matrix-era shape was never consumed.

All files sit flat in the library (no sub-folders). They are UTF-8 JSON with sorted keys (the examples below are
unsorted for reading); `.json.gz` files are gzip-compressed, `_meta.json` is plain.

- Numbers are plain JSON numbers (whole values are integers). `NaN` / `Infinity` never appear (they become `null`;
  the writer refuses to emit them).
- Nulls: the `sales` / `requests` arrays never contain null (they use 0). In a reorder part, only these fields can be
  null: `description`, `productGroup`, `minimumQty`, `maximumQty`, `reorderCode`, `activityCode`, `minOverride` and
  `maskExpires`. Every other reorder field is never null: blank text arrives as `""` (`bin`, `superTo`, `superFrom`,
  `dealerGroupCode`), quantities and prices are 0 when missing, and `target`, `minimumIgnored`, `ruleName` and the other rule fields are
  always filled (Gold fills the built-in default rule when no rule matches). In the other files, any field may be null.
- Dates are ISO strings (`2026-10-20`). Datetimes are ISO UTC with `+00:00` and may include fractional seconds.
- Branch codes are Equip's text codes (e.g. `"1"`, `"92"`), **trimmed**. The `branch` value inside every file is that
  trimmed key, and it is the key in the file names. A code must match `^[A-Za-z0-9_-]+$`, and two raw codes that trim
  to the same key (a trailing-space duplicate) are an error; either makes the publish fail rather than write bad files.
- Part numbers are raw as stored in Gold (a trailing space is significant). Match on `franchise` + `partNumber`.

### `_meta.json` (uploaded last)
```json
{"schemaVersion": 1, "dataAsOf": "2026-10-20T11:41:07+00:00", "publishedAt": "2026-10-20T12:20:03.482915+00:00",
 "source": "prod",
 "branches": [{"branch": "1", "name": "Lubbock", "parts": 18234}],
 "counts": {"parts": 412345, "historyRows": 3456789, "transferLines": 210}}
```
`dataAsOf` is when `Build_Gold_NonJD_Reorder` finished in the DP run (its `end_utc` in `dp_refresh_log`), not the
publish time. `branches` is sorted numerically, then alphabetically; `name` falls back to the code if the branch is
not in `dim_BranchLocation`. `counts.parts` is the total reorder rows, `historyRows` the rows read from the history table.

### `reorder_<branch>.json.gz`
`{"branch", "dataAsOf", "parts": [ ... ]}`, one object per part in scope at that branch. Each part has the 43 fields
below: `extract.REORDER_SQL` selects 44 columns, and `branch` is the file-level key rather than a per-part field. They
are renamed as shown. Gold's `RuleId` and `BuiltAtUtc` are not published (users see the rule name, not its list id).

| Field | Meaning |
|---|---|
| franchise, partNumber, description, bin, productGroup, superTo, superFrom | Part identity (text) |
| vendorCode | Equip vendor number (integer; 0 when missing) |
| onHand, onOrder, backOrder | Equip quantities |
| cost, sellPrice, listPrice | Prices |
| minimumQty, maximumQty, reorderCode, activityCode | Equip stocking fields |
| minOverride | From the app's settings list (as of the DP run) |
| isMasked | Non-null boolean that already accounts for expiry: Masked AND (maskExpires null OR maskExpires >= the Central date of the build) |
| maskExpires | Date string. Can be set while `isMasked` is false (the mask expired) |
| isLowMargin | InMaster user_field_3 = LOW |
| sales12, salesPrev12 | Quantities (units, not dollars) for the current and previous 12 months |
| lastRequested | Equip last-demand date as a datetime string at 00:00+00:00. Use the date part only; don't convert time zones. `1900-01-01` means never requested |
| dealerGroupCode | Equip dealer group code for this part at this branch (what the rules match on); `""` when blank (matches only rules with a blank DealerGroupCode) |
| ruleName | Name of the rule that set this part's settings: `Rule <Id>` for a rule saved without a name, `Built-in default` when no rule matched (also when the matching rule was invalid and skipped; the DP run's WARN names those) |
| demandBasis | `UnitsSold` or `Requests`: what `windowDemand` counts |
| historyMonths | Full months of history measured (the current partial month is left out) |
| minActiveMonths | Months with demand needed before the rule's calculation stocks the part (a minimum still applies) |
| weeksOfCover | Weeks of demand to keep on hand; a number from 0 to 104, can be fractional |
| windowDemand | Total units sold (or requests) in the window; 0 if negative |
| activeMonths | Months in the window with demand > 0 |
| monthlyRate | windowDemand / historyMonths (calendar months, not active months) |
| calcTarget | ceil(round(monthlyRate x weeksOfCover x 12 / 52, 9)) when activeMonths >= minActiveMonths, else 0; the rounding only removes floating-point noise. Display it; don't recompute it in the app |
| effectiveMin | The app's min override (always applies); else Equip's minimum only when activeMonths > 0; else 0 |
| minimumIgnored | Boolean, never null: true when there is no min override, Equip's minimum is > 0 and activeMonths = 0 (a stale minimum that no longer drives an order) |
| target | Stocking target = max(calcTarget, effectiveMin rounded up). Never null; 0 when the part isn't stocked |
| recommendedQty | 0 when masked; otherwise max(0, target - onHand - onOrder) with onHand and onOrder truncated toward zero; back orders are not subtracted. Can be > 0 with status `NoRecentActivity` / `NotStocked` when onHand + onOrder is negative (it orders back up to 0) |
| estValue | recommendedQty at cost, rounded to 2 decimals |
| surplusQty | max(0, truncated onHand - target) (all on-hand stock when the target is 0) |
| inboundQty | Open quantity on outstanding transfers into this branch; 0 (not null) when none |
| status | `Masked`, `NoRecentActivity` (target 0 and no demand in the window), `NotStocked` (had demand in the window but the target came out 0, usually below `minActiveMonths`), `OutOfStock` (recommendedQty > 0 and onHand <= 0), `Reorder`, `OK`. Checked in that order |

### Explaining a suggestion (for the app)

Every input to the target is in the part object, so the app can build the sentence without guessing. Rules guide for
Ben: `projects/part order tool - app/REORDER-RULES.md` (written in Task 21).

Decide in this order, first match wins:

1. `status` = `Masked`: "Masked, so no order is suggested" (add "until `<maskExpires>`" when set).
2. `status` = `NoRecentActivity`: "No demand in the last `<historyMonths>` months, so nothing is stocked." If
   `minimumIgnored` is true, add "Equip minimum `<minimumQty>` ignored: no demand in the last `<historyMonths>`
   months." Then the negative-stock sentence below, if it applies. The app can also list every part with
   `minimumIgnored` true as a cleanup list for Ben (stale Equip minimums).
3. `status` = `NotStocked` (demand in the window, target 0):
   - `activeMonths` < `minActiveMonths`: "`<ruleName>`: only `<activeMonths>` of `<historyMonths>` months had demand; this rule needs `<minActiveMonths>`, so nothing is stocked."
   - else `weeksOfCover` = 0: "`<ruleName>` keeps 0 weeks of cover, so nothing is stocked."
   - else `windowDemand` = 0: "Returns cancelled out sales in the last `<historyMonths>` months, so nothing is stocked."
   - Then the negative-stock sentence below, if it applies.

   Negative-stock sentence (under both `NoRecentActivity` and `NotStocked`), if `recommendedQty` > 0 (on hand + on
   order is negative): "On hand `<onHand>`, on order `<onOrder>`, so order `<recommendedQty>` to bring it back to 0."
4. Otherwise (`Reorder`, `OutOfStock`, `OK`) the sentence is first clause + minimum clause + tail:
   - First clause: if `activeMonths` < `minActiveMonths`: "Only `<activeMonths>` of `<historyMonths>` months had demand (this rule needs `<minActiveMonths>`), so the rule gives 0". Otherwise "`<ruleName>`: sold `<windowDemand>` in `<historyMonths>` months (`<monthlyRate>` a month) x `<weeksOfCover>` weeks of cover gives a target of `<calcTarget>`". For `demandBasis` = `Requests`, say "requested `<windowDemand>` times" instead of "sold `<windowDemand>`".
   - Minimum clause, only if `target` > `calcTarget`: "; a minimum of `<target>` sets the target" (use `target`, not `effectiveMin`, so a fractional minimum reads right).
   - Tail: "On hand `<onHand>`, on order `<onOrder>`, so order `<recommendedQty>`." For `OK`: "On hand `<onHand>`, on order `<onOrder>`, which covers the target; nothing to order."

Worked examples (arithmetic: calcTarget = ceil(monthlyRate x weeksOfCover x 12 / 52)):
- Units: "Cotton - in season: sold 18 in 12 months (1.5 a month) x 10 weeks of cover gives a target of 4. On hand 1, on
  order 0, so order 3." (1.5 x 10 x 12 / 52 = 3.46, rounds up to 4; 4 - 1 - 0 = 3.)
- Requests (a made-up rule needing 3 active months, with `activeMonths` 4): "Stripper belts: requested 6 times in 12
  months (0.5 a month) x 6 weeks of cover gives a target of 1. On hand 0, on order 0, so order 1." (0.5 x 6 x 12 / 52
  = 0.69, rounds up to 1.)
- Minimum wins, rule gives a target (a minimum applies because the part had demand; `activeMonths` 4, rule needs 3): "Default: sold 4 in 12 months (0.33 a month) x 6
  weeks of cover gives a target of 1; a minimum of 3 sets the target. On hand 1, on order 0, so order 2." (0.33 x 6 x
  12 / 52 = 0.46, rounds up to 1; target 3; 3 - 1 = 2.)
- Minimum wins, rule gives 0 (`activeMonths` 2, so the part had demand and the minimum applies, rule needs 3): "Only 2 of 12 months had demand (this rule needs 3), so
  the rule gives 0; a minimum of 3 sets the target. On hand 1, on order 0, so order 2."
- NotStocked: "Default: only 2 of 12 months had demand; this rule needs 3, so nothing is stocked."

Number display:
- `monthlyRate`: at most 2 decimals, trailing zeros dropped; above 0 and below 0.005 shows "< 0.01"; 0 shows 0.
- `weeksOfCover` and `windowDemand`: up to 1 decimal, dropping ".0".
- Whole values arrive as JSON integers.
- Handle plurals: "1 month", "requested 1 time".

### `history_<branch>.json.gz`
`{"branch", "months": [60 labels like "2026-10", "2026-09", ...], "parts": [{"franchise", "partNumber",
"sales": [60 numbers], "requests": [60 numbers]}]}`. Labels are newest first; index 0 is the current (partial)
month, using the Central-time month of the DP build. Index `i` in `sales` / `requests` lines up with `months[i]`;
months with no activity are `0`. Only parts that have history rows appear; parts are sorted by franchise, then part number.

### `surplus.json.gz`
`{"dataAsOf", "parts": [{"branch", "franchise", "partNumber", "onHand", "target", "surplusQty", "status"}]}`, every
branch, only parts with surplusQty > 0. Used for "store N has extra" hints.

### `rules.json.gz`
`{"dataAsOf", "rules": [{"id", "ruleName", "priority", "active", "franchise", "dealerGroupCode", "branch",
"startMonth", "endMonth", "historyMonths", "minActiveMonths", "weeksOfCover", "demandBasis"}]}`, ordered by `id`
(`Modified` is left out). This is the rules list as the DP run read it at publish time; the app uses it only to check
its own engine against Gold. If the rules dataflow is re-run between Gold and the publish, it can differ from what
Gold used, so the app reports rather than blocks. An empty list is written as `"rules": []`. Each publish uploads
it (it embeds `dataAsOf`), before `_meta.json`, like the other per-run files.

### `transfers.json.gz`
`{"dataAsOf", "lines": [{"toBranch", "fromBranch", "partNumber", "ticket", "line", "orderQty", "shippedQty",
"openQty", "status", "subType", "ageDays", "date"}]}`. Outstanding transfer lines for part numbers in scope
(branch-12 transfers are excluded in Gold).

- `partNumber` is upper-cased and trimmed in Gold. Compare `part.partNumber.trim().toUpperCase()` to it.
- Transfer lines carry no franchise, so trailing-space twin parts and same-number parts in two franchises share the
  same lines (Gold's `inboundQty` matches the same way).
- `toBranch` / `fromBranch` are untrimmed in Gold and in the publish, and may be `""`. Trim before comparing to a branch key.
- `status`: `Pending`, `Partial` or `Shipped`.
- `subType`: `Stock`, `Work Order`, `Counter` or `Unknown`.
- `openQty` = shipped - supplied (always > 0).
- `ageDays` = days since the order date (Central), taking the max per ticket.
- `date` = line creation date, `YYYY-MM-DD`.
