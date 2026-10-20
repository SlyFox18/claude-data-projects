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
- The reorder, surplus and transfers files are re-uploaded on every new DP run (they embed `dataAsOf`, so their
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

All files sit flat in the library (no sub-folders). They are UTF-8 JSON with sorted keys (the examples below are
unsorted for reading); `.json.gz` files are gzip-compressed, `_meta.json` is plain.

- Numbers are plain JSON numbers (whole values are integers). `NaN` / `Infinity` never appear (they become `null`;
  the writer refuses to emit them).
- Nulls: the `sales` / `requests` arrays never contain null (they use 0). `isMasked`, `status`, `inboundQty`, `activeMonths`,
  `ruleName`, `demandBasis`, `historyMonths`, `minActiveMonths`, `weeksOfCover`, `windowDemand`, `monthlyRate`,
  `calcTarget` and `effectiveMin` are never null (Gold fills the built-in default rule when no rule matches). Any other field may be null.
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
`{"branch", "dataAsOf", "parts": [ ... ]}`, one object per part in scope at that branch. Each part has the 42 fields
below: `extract.REORDER_SQL` selects 43 columns, and `branch` is the file-level key rather than a per-part field. They
are renamed as shown. Gold's `RuleId` and `BuiltAtUtc` are not published (users see the rule name, not its list id).

| Field | Meaning |
|---|---|
| franchise, partNumber, description, bin, vendorCode, productGroup, superTo, superFrom | Part identity |
| onHand, onOrder, backOrder | Equip quantities |
| cost, sellPrice, listPrice | Prices |
| minimumQty, maximumQty, reorderCode, activityCode | Equip stocking fields |
| minOverride | From the app's settings list (as of the DP run) |
| isMasked | Non-null boolean that already accounts for expiry: Masked AND (maskExpires null OR maskExpires >= the Central date of the build) |
| maskExpires | Date string. Can be set while `isMasked` is false (the mask expired) |
| isLowMargin | InMaster user_field_3 = LOW |
| sales12, salesPrev12 | Quantities (units, not dollars) for the current and previous 12 months |
| lastRequested | Equip last-demand date as a datetime string at 00:00+00:00. Use the date part only; don't convert time zones. `1900-01-01` means never requested |
| dealerGroupCode | Equip dealer group code for this part at this branch (what the rules match on); may be null |
| ruleName | Name of the rule that set this part's settings (`Built-in default` when no rule matched) |
| demandBasis | `UnitsSold` or `Requests`: what `windowDemand` counts |
| historyMonths | Full months of history measured (the current partial month is left out) |
| minActiveMonths | Months with demand needed before the part is stocked at all |
| weeksOfCover | Weeks of demand to keep on hand |
| windowDemand | Total units sold (or requests) in the window; 0 if negative |
| activeMonths | Months in the window with demand > 0 |
| monthlyRate | windowDemand / historyMonths (calendar months, not active months) |
| calcTarget | ceil(monthlyRate x weeksOfCover x 12 / 52) when activeMonths >= minActiveMonths, else 0 |
| effectiveMin | The app's min override, else Equip's minimum, else 0 |
| target | Stocking target = max(calcTarget, ceil(effectiveMin)); null when no recent activity |
| recommendedQty | max(0, target - onHand - onOrder); back orders are not subtracted. 0 when masked or no recent activity |
| estValue | recommendedQty at cost, rounded to 2 decimals |
| surplusQty | Stock above target (all on-hand stock when no recent activity) |
| inboundQty | Open quantity on outstanding transfers into this branch; 0 (not null) when none |
| status | `Masked`, `NoRecentActivity` (target 0 and no demand in the window), `NotStocked` (had demand in the window but the target came out 0, usually below `minActiveMonths`), `OutOfStock` (recommendedQty > 0 and onHand <= 0), `Reorder`, `OK`. Checked in that order |

### Explaining a suggestion (for the app)

Every input to the target is in the part object, so the app can build the sentence without guessing. Rules guide for
Ben: `projects/part order tool - app/REORDER-RULES.md` (written in Task 21).

Template (status `Reorder` / `OutOfStock` / `OK`, basis `UnitsSold`):

> `<ruleName>`: sold `<windowDemand>` in `<historyMonths>` months (`<monthlyRate>` a month) x `<weeksOfCover>` weeks of
> cover gives a target of `<calcTarget>`. On hand `<onHand>`, on order `<onOrder>`, so order `<recommendedQty>`.

Worked example: "Cotton - in season: sold 18 in 12 months (1.5 a month) x 10 weeks of cover gives a target of 4. On
hand 1, on order 0, so order 3."

Variants:
- `demandBasis` = `Requests`: say "requested `<windowDemand>` times" instead of "sold `<windowDemand>`".
- `NotStocked`: "`<ruleName>`: only `<activeMonths>` of `<historyMonths>` months had demand; this rule stocks parts with
  at least `<minActiveMonths>`." (If `activeMonths` >= `minActiveMonths`, the cause is `weeksOfCover` 0 or net demand <= 0.)
- `NoRecentActivity`: "No demand in the last `<historyMonths>` months, so nothing is stocked." (A min still applies if
  `effectiveMin` > 0, in which case the status is not `NoRecentActivity`.)
- A minimum wins (`effectiveMin` rounded up > `calcTarget`): "Minimum `<effectiveMin>` sets the target (the rule's
  `<calcTarget>` is lower)." Then the on hand / on order / order tail as above.
- `Masked`: "Masked, so no order is suggested" (add "until `<maskExpires>`" when set). The target and rule still show.

Show `<monthlyRate>` rounded to 2 decimals.

### `history_<branch>.json.gz`
`{"branch", "months": [60 labels like "2026-10", "2026-09", ...], "parts": [{"franchise", "partNumber",
"sales": [60 numbers], "requests": [60 numbers]}]}`. Labels are newest first; index 0 is the current (partial)
month, using the Central-time month of the DP build. Index `i` in `sales` / `requests` lines up with `months[i]`;
months with no activity are `0`. Only parts that have history rows appear; parts are sorted by franchise, then part number.

### `surplus.json.gz`
`{"dataAsOf", "parts": [{"branch", "franchise", "partNumber", "onHand", "target", "surplusQty", "status"}]}`, every
branch, only parts with surplusQty > 0. Used for "store N has extra" hints.

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
