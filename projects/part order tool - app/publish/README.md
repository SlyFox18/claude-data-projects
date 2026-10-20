# Non-JD Parts Order Tool - data publish

Reads DP Gold (`Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory`, `Fact_OutstandingTransfers`, `dim_BranchLocation`)
after the morning DP run and uploads the web app's data files to the SharePoint library **NonJD Order Data**
on https://spitractor.sharepoint.com/sites/PartsOrderTool.

- Plan: `docs/superpowers/plans/2026-10-20-non-jd-parts-order-tool-data-feed.md`
- Runs on the Gateway PC, Task Scheduler `\SPI\Non-JD Order Tool Publish`.
- Publishes only when `Build_Gold_NonJD_Reorder` succeeded in `dp_refresh_log` (latest run) and that run hasn't been published yet.
- `NONJD_SOURCE` in `.env` picks the DP tier (`dev` or `prod`).

## Running it

By hand: `python run_publish.py`. Tests: `python -m pytest -q` (run from this folder; it has its own conftest.py).

- `--force` re-publishes the latest successful run and re-sends every file (use it to repair a file damaged or
  deleted in SharePoint). It never publishes a failed run.
- Normal run: the reorder, surplus and transfers files are re-uploaded on every new DP run (they embed `dataAsOf`,
  so their content always changes). History files are uploaded only when their content changed. `_meta.json` goes last.
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
- Show `dataAsOf` and flag data older than one business day.

## File contract (schemaVersion 1)

All files sit flat in the library (no sub-folders). They are UTF-8 JSON with sorted keys; `.json.gz` files are
gzip-compressed, `_meta.json` is plain.

- Numbers are plain JSON numbers (whole values are integers). `NaN` / `Infinity` never appear (they become `null`;
  the writer refuses to emit them). Any field can be `null`.
- Dates are ISO strings (`2026-10-20`); datetimes are ISO UTC with `+00:00`.
- Branch codes are Equip's text codes (e.g. `"1"`, `"92"`), **trimmed**. The `branch` value inside every file is that
  trimmed key, and it is the key in the file names. A code must match `^[A-Za-z0-9_-]+$`, and two raw codes that trim
  to the same key (a trailing-space duplicate) are an error; either makes the publish fail rather than write bad files.
- Part numbers are raw as stored in Gold (a trailing space is significant). Match on `franchise` + `partNumber`.

### `_meta.json` (uploaded last)
```json
{"schemaVersion": 1, "dataAsOf": "2026-10-20T11:41:07+00:00", "publishedAt": "2026-10-20T12:20:03+00:00",
 "source": "prod",
 "branches": [{"branch": "1", "name": "Lubbock", "parts": 18234}],
 "counts": {"parts": 412345, "historyRows": 3456789, "transferLines": 210}}
```
`dataAsOf` is when the DP run finished (not the publish time). `branches` is sorted numerically, then
alphabetically; `name` falls back to the code if the branch is not in `dim_BranchLocation`. `counts.parts` is the
total reorder rows, `historyRows` the rows read from the history table.

### `reorder_<branch>.json.gz`
`{"branch", "dataAsOf", "parts": [ ... ]}`, one object per part in scope at that branch. Each part has these fields
(every Gold column except `branch`):

| Field | Meaning |
|---|---|
| franchise, partNumber, description, bin, vendorCode, productGroup, superTo, superFrom | Part identity |
| onHand, onOrder, backOrder | Equip quantities |
| cost, sellPrice, listPrice | Prices |
| minimumQty, maximumQty, reorderCode, activityCode | Equip stocking fields |
| minOverride, isMasked, maskExpires | From the app's settings list (as of the DP run) |
| isLowMargin | InMaster user_field_3 = LOW |
| sales12, salesPrev12, lastRequested | 12-month totals and last request date |
| monthCount, avgDemand, avgSales | Activity in the 12-month window |
| target | Stocking target; null when no recent activity |
| recommendedQty, estValue | Suggested order quantity and its value at cost |
| surplusQty | Stock above target (all on-hand stock when no recent activity) |
| inboundQty | Open quantity on outstanding transfers into this branch |
| status | `Reorder`, `OutOfStock`, `OK`, `NoRecentActivity`, `Masked` |

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
"openQty", "status", "subType", "ageDays", "date"}]}`. Outstanding transfer lines for part numbers in scope.
`partNumber` here comes from `Fact_OutstandingTransfers` (expected upper-case and trimmed); match it with
`partNumber.trim().toUpperCase()` on the app side. `toBranch` / `fromBranch` are not trimmed by the publish, so trim
them before comparing to a branch key.
