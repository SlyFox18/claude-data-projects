# Non-JD Parts Order Tool - data publish

Reads DP Gold (`Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory`, `Fact_NonJD_TransferSuggestion`,
`Fact_OutstandingTransfers`, `dim_BranchLocation`) and the list tables Gold read (`NonJD_OrderRules`,
`NonJD_TransferRules`, `NonJD_Transfers`) after the morning DP run and uploads the web app's data files to the SharePoint library **NonJD Order Data**
on https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite.

- Plan: `docs/superpowers/plans/2026-10-20-non-jd-parts-order-tool-data-feed.md`; round 1 (contractVersion 2):
  `docs/superpowers/plans/2026-10-26-non-jd-parts-order-tool-round-1.md`; round 2 (contractVersion 3):
  `docs/superpowers/plans/2026-10-27-non-jd-parts-order-tool-round-2-phase-2.md` (task E6)
- Spec: `docs/superpowers/specs/2026-10-20-non-jd-parts-order-tool-redesign-design.md`; round 2 (transfers,
  phase-in): `docs/superpowers/specs/2026-10-27-non-jd-parts-order-tool-round-2-design.md` ("The contract (v3)")
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

Local build, no upload: `python run_publish.py --out <dir>` builds every file plus `_meta.json` into `<dir>` and
stops. It uploads nothing, writes no `publish_state.json` and takes no lock, so it can run beside the scheduled
publish. The run checks below still apply (a failed latest run builds nothing); `publish_state.json` is ignored, so
it builds even when the run was already published. Only earlier output files (`*.json.gz`, `_meta.json`) in `<dir>`
are replaced. The app's parity checks and `make_engine_fixture.py --output <dir>` read such a build. With no
`CLIENT_SECRET` in the settings file, OneLake is read with your `az` login, and no other secret is needed:
`TENANT_ID`, `CLIENT_ID`, `SITE_ID` and `DRIVE_ID` must be set but aren't used (any placeholder will do).

What decides whether to publish:
- It looks back 14 days in `dp_refresh_log` for the latest `Build_Gold_NonJD_Reorder` item row. Skipped rows are
  ignored. It publishes only if that latest run succeeded and hasn't been published yet.
- It refuses (exit 1) if `Fact_NonJD_Reorder.BuiltAtUtc` is outside that run, or if the table changes during extraction.
- It refuses (exit 1) before extracting anything if a table (`Fact_NonJD_Reorder`, `Fact_NonJD_SalesHistory`,
  `Fact_OutstandingTransfers`, `Fact_NonJD_TransferSuggestion`, `NonJD_OrderRules`, `NonJD_TransferRules` or
  `NonJD_Transfers`) lacks a column the contract needs, naming the missing columns (`extract.check_columns`); a
  missing list or suggestion table is named with what to deploy. Gold and the publish code must be deployed together
  (round 2 Gold with contractVersion 3 publish code).
- It refuses (exit 1) if a rule in `NonJD_OrderRules` or `NonJD_TransferRules` has a NaN or infinite number, naming
  the rule and the field, or if Gold left a never-null round 2 reorder field null (see "Nulls").

What gets uploaded:
- The reorder, surplus, transfers, rules, transfer rules and transfer suggestions files are re-uploaded on every new
  DP run (they embed `dataAsOf`, so their content always changes); `transfer_suggestions.json.gz` is sent on every
  upload even if its hash is unchanged (`publish_logic.ALWAYS_UPLOAD`). History files are uploaded only when their
  content changed. `_meta.json` goes last.
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
- Check `_meta.json`'s `contractVersion` first (missing = 1) and load nothing unless it is the version the app knows
  (messages under "File contract").

## File contract (schemaVersion 1, contractVersion 3)

- `schemaVersion` 1 = the rules-list file layout (2026-10-20); the earlier matrix-era shape was never consumed. It
  is unchanged in round 1.
- `contractVersion` = the fields inside the files. 1 = Plan A/B (`_meta.json` had no `contractVersion`; treat a
  missing one as 1). **2 = round 1** (Plan C, 2026-10-26): demand counts, weeks or months of supply, line value
  limits, Manual Order, masks that end at a request, the new statuses and the excluded branches. **3 = round 2**
  (Plan E, 2026-10-27): `target` includes an active phase-in (step 8), `recommendedQty` subtracts committed app
  transfers (step 9), order rules match on five more criteria, 28 new reorder fields, two new files
  (`transfer_rules.json.gz`, `transfer_suggestions.json.gz`) and `counts.transferSuggestions`. Deploy the v3 app
  first, then publish v3 (a v2 app refuses v3 data).
- **Bump `contractVersion`** on any removed or renamed field, any change in a field's meaning, or any new `status`
  value. Don't bump for a new optional field: the app ignores fields it doesn't know.
- **The app must refuse a `contractVersion` it doesn't know** and load nothing, rather than reading fields that have
  changed meaning:
  - newer than the app knows: "The app needs updating: the data was published in a newer format."
  - older than the app knows: "The data was published in an older format; it will update after the next publish."
- The publish fails before extracting anything, naming the columns, if a Gold table or `NonJD_OrderRules` lacks a
  column this contract needs, so a half-deployed Gold never reaches the app.

All files sit flat in the library (no sub-folders). They are UTF-8 JSON with sorted keys (the examples below are
unsorted for reading); `.json.gz` files are gzip-compressed, `_meta.json` is plain.

- Numbers are plain JSON numbers (whole values are integers). `NaN` / `Infinity` never appear (they become `null`;
  the writer refuses to emit them).
- Nulls: the `sales` / `requests` arrays never contain null (they use 0). In a reorder part, only these fields can be
  null: `description`, `productGroup`, `minimumQty`, `maximumQty`, `reorderCode`, `activityCode`, `minOverride`,
  `maskExpires`, `maskedOn`, `minLineValue` and `maxLineValue`. Every other reorder field is never null: blank text
  arrives as `""` (`bin`, `superTo`, `superFrom`, `dealerGroupCode`), quantities and prices are 0 when missing, and
  `target`, `minimumNoDemand`, `manualOrder`, `ruleName`, `supplyUnit` and the other rule fields are always filled
  (Gold fills the built-in default rule when no rule matches). Of the round 2 fields (contractVersion 3), only
  `slc`, `source`, `commodityCode`, `phaseInQty`, `phaseInEnds`, `phaseInOn`, `phaseInEndReason` and
  `transferRuleId` can be null (`transferRuleId` is null exactly when the built-in default transfer rule applied).
  The others are never null: blank `transferRuleName` / `excessUnit` / `redistUnit` would arrive as `""` (Gold
  always fills them), a null `pendingQty` arrives as 0 (Part 2 counts it as 0), and any other null fails the publish.
  In the other files, any field may be null.
- Dates are ISO strings (`2026-10-20`). Datetimes are ISO UTC with `+00:00` and may include fractional seconds.
- Branch codes are Equip's text codes (e.g. `"1"`, `"92"`), **trimmed**. The `branch` value inside every file is that
  trimmed key, and it is the key in the file names. A code must match `^[A-Za-z0-9_-]+$`, and two raw codes that trim
  to the same key (a trailing-space duplicate) are an error; either makes the publish fail rather than write bad files.
- **Excluded branches (D6): 12, 5, 97, 4B and 93C** (compared trimmed, case-insensitive) appear in no file: no
  reorder, history or surplus rows, no `_meta.json` entry, and no transfer line to or from them. Gold leaves them out
  of the reorder and history tables; a reorder row at one fails the publish (Gold and the publish are out of step).
  Transfer lines are filtered in the publish, because `Fact_OutstandingTransfers` still holds them.
- Part numbers are raw as stored in Gold (a trailing space is significant). Match on `franchise` + `partNumber`.

### `_meta.json` (uploaded last)
```json
{"schemaVersion": 1, "contractVersion": 3, "dataAsOf": "2026-10-20T11:41:07+00:00",
 "publishedAt": "2026-10-20T12:20:03.482915+00:00", "source": "prod",
 "branches": [{"branch": "1", "name": "Lubbock", "parts": 18234}],
 "counts": {"parts": 412345, "historyRows": 3456789, "transferLines": 210, "transferSuggestions": 2312}}
```
`dataAsOf` is when `Build_Gold_NonJD_Reorder` finished in the DP run (its `end_utc` in `dp_refresh_log`), not the
publish time. `branches` is sorted numerically, then alphabetically; `name` falls back to the code if the branch is
not in `dim_BranchLocation`. `counts.parts` is the total reorder rows, `historyRows` the rows read from the history
table, `transferLines` the Equip outstanding transfer lines read, `transferSuggestions` the lines in
`transfer_suggestions.json.gz`. `contractVersion` is described above (missing = 1).

### `reorder_<branch>.json.gz`
`{"branch", "dataAsOf", "parts": [ ... ]}`, one object per part in scope at that branch. Each part has the 81 fields
below (53 + 28 round 2 fields): `extract.REORDER_COLUMNS` selects 82 columns, and `branch` is the file-level key
rather than a per-part field. They are renamed as shown (the camelCase of the Gold column unless noted). Gold's
`RuleId` and `BuiltAtUtc` are not published (users see the rule name, not its list id); `TransferRuleId` is (plan E
decision X6), for showing which transfer rule applied and for the parity check.

Changed in contractVersion 3: `target` includes an active phase-in (step 8) and `recommendedQty` subtracts
`appInboundQty` (step 9). `surplusQty` is unchanged (shown as "Above target"). The 28 new fields are in the second
table below.

Changed in contractVersion 2: `minimumIgnored` is replaced by `minimumNoDemand`, `minActiveMonths` by `minDemands`,
and `weeksOfCover` by `supply` + `supplyUnit` + `supplyMonths`. New: `demandCount`, `unitsSoldWindow`,
`minLineValue`, `maxLineValue`, `valueCapped`, `belowMinValue`, `manualOrder` and `maskedOn`.

| Field | Meaning |
|---|---|
| franchise, partNumber, description, bin, productGroup, superTo, superFrom | Part identity (text) |
| vendorCode | Equip vendor number (integer; 0 when missing) |
| onHand, onOrder, backOrder | Equip quantities |
| cost, sellPrice, listPrice | Prices |
| minimumQty, maximumQty, reorderCode, activityCode | Equip stocking fields |
| minOverride | From the app's settings list (as of the DP run) |
| manualOrder | Non-null boolean, from the settings list (as of the DP run): the part is never suggested until the setting is turned off |
| isMasked | Non-null boolean, the live mask as of the build: Masked AND (maskExpires null OR maskExpires >= the Central date of the build) AND NOT (maskedOn set AND the date of lastRequested > maskedOn) |
| maskExpires | Date string. Can be set while `isMasked` is false (the mask expired, or ended at a request) |
| maskedOn | Date string: the Central date the mask was saved. Null on older rows (such a mask never ends at a request). Can be set while `isMasked` is false |
| isLowMargin | InMaster user_field_3 = LOW |
| sales12, salesPrev12 | Quantities (units, not dollars) for the current and previous 12 months |
| lastRequested | Equip last-demand date as a datetime string at 00:00+00:00. Use the date part only; don't convert time zones. `1900-01-01` means never requested |
| dealerGroupCode | Equip dealer group code for this part at this branch (what the rules match on); `""` when blank (matches only rules with a blank DealerGroupCode) |
| ruleName | Name of the rule that set this part's settings: `Rule <Id>` for a rule saved without a name, `Built-in default` when no rule matched (also when the matching rule was invalid and skipped; the DP run's WARN names those). Archived and inactive rules are never used |
| demandBasis | `UnitsSold` or `Requests`: what `windowDemand` counts |
| historyMonths | Full months of history measured (the current partial month is left out) |
| minDemands | Demands (transactions) in the window needed before the rule's calculation stocks the part (a minimum still applies). Integer 0-9999 |
| supplyUnit | `Weeks` or `Months` (a blank unit in the rules list arrives as `Weeks`) |
| supply | Amount of supply to keep, in `supplyUnit`: 0-104 weeks or 0-24 months, can be fractional (the rules list's WeeksOfCover column) |
| supplyMonths | `supply` in months: supply x 12 / 52 for Weeks, supply for Months. Display it; don't recompute it |
| minLineValue | Rule's minimum line value in dollars; a line worth less isn't suggested. Null = no limit |
| maxLineValue | Rule's maximum line value in dollars; the quantity is cut back to stay at or under it. Null = no limit |
| windowDemand | Total units sold (or requests) in the window, on the rule's basis; 0 if negative |
| unitsSoldWindow | Units sold in the window whatever the basis: max(0, round(sum, 9)) |
| demandCount | Demands (transactions, the sum of RequestCount) in the window; integer, 0 if negative. Stocking uses this |
| activeMonths | Months in the window with demand > 0 on the rule's basis (display only since round 1) |
| monthlyRate | windowDemand / historyMonths (calendar months, not active months) |
| calcTarget | ceil(round(monthlyRate x supplyMonths, 9)) when demandCount >= minDemands, else 0; the rounding only removes floating-point noise. Display it; don't recompute it in the app |
| effectiveMin | The app's min override if set, else Equip's minimum (it always applies, even with no demand), else 0 |
| minimumNoDemand | Boolean, never null: true when there is no min override, Equip's minimum is > 0 and the part had no activity in the window (demandCount 0 and unitsSoldWindow 0). The minimum still sets the target; this flags it for the "Min, no demand" tag and Ben's cleanup list |
| target | Stocking target = max(calcTarget, effectiveMin rounded up). Never null; 0 when the part isn't stocked |
| valueCapped | Boolean, never null: the maximum line value cut the quantity back (to floor(maxLineValue / cost)). With status `AboveMaxValue` it was cut to 0. Computed before the Manual Order / mask step, so it can be true on a `ManualOrder` or `Masked` part, and together with `belowMinValue` (the cut line fell below the minimum). Show the cap badge only when the status is `Reorder`, `OutOfStock` or `AboveMaxValue` |
| belowMinValue | Boolean, never null: the line (after any cap) was above 0 but worth less than minLineValue, so it is not suggested. Computed before the Manual Order / mask step, so it can be true on a `ManualOrder` or `Masked` part. Show the min badge only when the status is `BelowMinValue` |
| recommendedQty | In this order: base qty = 0 if target = 0 (a target of 0 orders 0 whatever negative stock shows), else max(0, target - onHand - onOrder) with onHand and onOrder truncated toward zero (back orders not subtracted); then, only when base qty > 0 and cost > 0, cut back to floor(maxLineValue / cost) if over maxLineValue (`valueCapped`), then 0 if the line is still above 0 but under minLineValue (`belowMinValue`); finally 0 when manualOrder or isMasked |
| estValue | recommendedQty at cost, rounded to 2 decimals |
| surplusQty | max(0, truncated onHand - target) (all on-hand stock when the target is 0). Shown as "Excess" |
| inboundQty | Open quantity on outstanding transfers into this branch; 0 (not null) when none |
| status | First match: `ManualOrder`, `Masked`, `NoRecentActivity` (target 0 and no activity in the window: no demands and no units sold), `NotStocked` (some activity, but the target came out 0: below `minDemands`, 0 supply, or net demand <= 0), `BelowMinValue`, `AboveMaxValue` (the maximum line value cut the line to 0: one unit costs more than it), `OutOfStock` (recommendedQty > 0 and onHand <= 0), `Reorder` (recommendedQty > 0), `OK`. A partial cap keeps `OutOfStock` / `Reorder` with `valueCapped` true |

Round 2 fields (contractVersion 3; the round 2 spec's "The calculation" defines each one, and its clarifications
sections settle the edge cases). Display them; don't recompute them, except where the app's live engine recalculates
the whole part.

| Field | Meaning |
|---|---|
| pendingQty | Silver_PartInformation PendingQty as stored (stock committed to tickets); Part 2 uses max(0, trunc(pendingQty)). Never null (0 when Gold has none) |
| slc, source, commodityCode | Part criteria from Silver_PartInformation, as stored; nullable. Order and transfer rules match on them (with `vendorCode`, `productGroup`) |
| phaseInQty | The part setting's PhaseInQty (whole number 1-99999); null when blank or invalid |
| phaseInEnds | Date string; null = no end date |
| phaseInOn | Date string the phase-in was saved (display only); nullable |
| phaseInActive | Boolean: phaseInQty > 0, phaseInEnds blank or >= the Central date of the build, and demandCount < max(minDemands, 1). Can be true on a Masked / ManualOrder part |
| phaseInEndReason | `Expired`, `MetCriteria` or null (display only) |
| appInboundQty, appOutboundQty | Units on committed app transfer lines into / out of this branch + franchise + part (step 8b); the lines are in `transfer_suggestions.json.gz` `committed` |
| transferRuleId | `NonJD_TransferRules` Id of the transfer rule that applied; null = the built-in default |
| transferRuleName | That rule's name (`Rule <Id>` when unnamed), or `Built-in default` |
| excessSupply, excessUnit | The rule's excess threshold and its unit (`Weeks` / `Months`) |
| allowSend, allowReceive | Booleans: whether this branch may send / receive this part |
| redistMax, redistUnit | Redistribution cap and its unit (a blank RedistMax arrives as 6 Months) |
| redistMinValue | Smallest redistribution line value the sender ships (blank = 0) |
| excessKeep | max(target, ceil9(monthlyRate x months(excessSupply, excessUnit))): what the branch keeps before calling stock excess |
| freeExcess | Units this branch can send: allowSend ? max(0, trunc(onHand) - pend - excessKeep - appOutboundQty) : 0 |
| convNeed | Conventional need: the step 9 base qty, 0 when it can't receive, is ManualOrder / masked / a minimum with no demand (unless phasing in) or has free excess |
| redistCap | min(ceil9(monthlyRate x months(redistMax, redistUnit)), excessKeep) |
| redistEligible | Boolean: may take redistribution (allowReceive, target > 0, rate > 0, not ManualOrder / masked, no free excess) |
| suggestedInQty, suggestedConvInQty, suggestedOutQty | Units suggested into this part (all kinds / conventional only) and out of it, from Gold's allocation; 0 when none |

### Settings the app reads live (`NonJD_PartSettings`)

The reorder file carries the settings as of the DP run. The app re-reads the list and recalculates with these
fields live: `MinOverride`, `Masked`, `MaskExpires`, **`MaskedOn`** and **`ManualOrder`** (new in contractVersion 2),
and **`PhaseInQty`**, **`PhaseInEnds`** and **`PhaseInOn`** (new in contractVersion 3). It also reads
`NonJD_Transfers` + `NonJD_TransferLines` live (open and recently placed) for step 8b, and `NonJD_TransferRules`.
- Live mask = Masked AND (MaskExpires blank or >= the Central date today) AND NOT (MaskedOn set AND the date of the
  part's `lastRequested` > MaskedOn). `lastRequested` comes from the reorder file (as of the DP run), so a request
  made today ends the mask from the next DP run.
- ManualOrder true: status `ManualOrder`, order 0.
- Saving a mask writes MaskedOn = the Central date today; unmasking clears it. Blank ManualOrder = No.

### Explaining a suggestion (for the app)

Every input to the target is in the part object, so the app can build the sentence without guessing. Rules guide for
Ben: `projects/part order tool - app/REORDER-RULES.md`. `<supply unit>` below is "weeks" or "months" from
`supplyUnit` ("week" / "month" for 1), always followed by "of supply". "No activity" = `demandCount` 0 and
`unitsSoldWindow` 0.

Mask ended by a request (a prefix, before any sentence below except `Masked` / `ManualOrder`): when the setting is
Masked, `maskedOn` is set, `isMasked` is false, `maskExpires` is blank or not yet passed, and the date of
`lastRequested` is after `maskedOn`: "The mask set on `<maskedOn>` ended when the part was requested on
`<lastRequested date>`."

Decide in this order, first match wins:

1. `status` = `ManualOrder`: "Manual order, so no order is suggested; it is ordered by hand until Manual order is turned off."
2. `status` = `Masked`: "Masked, so no order is suggested" (add "until `<maskExpires>`" when set; add "or until it is
   next requested" when `maskedOn` is set).
3. `status` = `NoRecentActivity`: "No demand in the last `<historyMonths>` months, so nothing is stocked." (A target
   of 0 orders 0, so there is no negative-stock sentence any more.)
4. `status` = `NotStocked` (some activity in the window, target 0):
   - `demandCount` < `minDemands`:
     - `demandCount` = 0 (so `unitsSoldWindow` > 0): "`<ruleName>`: sold `<unitsSoldWindow>` in `<historyMonths>` months but no demands were recorded; this rule needs `<minDemands>` demands, so nothing is stocked."
     - else: "`<ruleName>`: only `<demandCount>` demands in `<historyMonths>` months; this rule needs `<minDemands>`, so nothing is stocked."
   - else `supply` = 0: "`<ruleName>` keeps 0 `<supply unit>` of supply, so nothing is stocked."
   - else `windowDemand` = 0:
     - `demandBasis` = `Requests`: "No requests on this rule's basis in the last `<historyMonths>` months, so nothing is stocked." (Only with `minDemands` 0: demandCount is then 0 and the activity is units sold.)
     - else `activeMonths` > 0: "Returns cancelled out sales in the last `<historyMonths>` months, so nothing is stocked."
     - else: "`<demandCount>` demands but no units sold in the last `<historyMonths>` months, so nothing is stocked."
   - else (only with near-zero demand or supply, where the target rounds to 0): "`<ruleName>` gives a target of 0, so nothing is stocked."
5. Otherwise the sentence is first clause + minimum clause + tail:
   - First clause:
     - no activity: "No demand in the last `<historyMonths>` months, so the rule gives 0".
     - else `demandCount` < `minDemands` and `demandCount` = 0 (units sold, no demands): "No demands recorded (sold `<unitsSoldWindow>`; this rule needs `<minDemands>`), so the rule gives 0".
     - else `demandCount` < `minDemands`: "Only `<demandCount>` demands in `<historyMonths>` months (this rule needs `<minDemands>`), so the rule gives 0".
     - else "`<ruleName>`: sold `<windowDemand>` in `<historyMonths>` months (`<monthlyRate>` a month) x `<supply>` `<supply unit>` of supply gives a target of `<calcTarget>`". For `demandBasis` = `Requests`, say "requested `<windowDemand>` times" instead of "sold `<windowDemand>`".
   - Minimum clause, only if `target` > `calcTarget` (use `target`, not `effectiveMin`, so a fractional minimum reads right):
     - `minOverride` set: "; your min override of `<target>` sets the target".
     - else `minimumNoDemand` true: "; the Equip minimum of `<target>` applies even with no demand and sets the target".
     - else: "; the Equip minimum of `<target>` sets the target".
   - Tail, by status. "Base qty" = max(0, `target` - trunc(`onHand`) - trunc(`onOrder`)), the quantity before the line value limits.
     - `BelowMinValue`: "On hand `<onHand>`, on order `<onOrder>`, so the line would be `<base qty, after any cap>` at `<value>`, below this rule's minimum line value of `<minLineValue>`; nothing is suggested." (value = qty x cost.)
     - `AboveMaxValue`: "On hand `<onHand>`, on order `<onOrder>`; one costs `<cost>`, more than this rule's maximum line value of `<maxLineValue>`, so nothing is suggested."
     - `Reorder` / `OutOfStock` with `valueCapped`: "On hand `<onHand>`, on order `<onOrder>`, so order `<recommendedQty>`, cut back from `<base qty>` to stay at or under this rule's maximum line value of `<maxLineValue>`."
     - `Reorder` / `OutOfStock`: "On hand `<onHand>`, on order `<onOrder>`, so order `<recommendedQty>`."
     - `OK`: "On hand `<onHand>`, on order `<onOrder>`, which covers the target; nothing to order."

Worked examples (arithmetic: calcTarget = ceil(monthlyRate x supplyMonths); supplyMonths = weeks x 12 / 52):
- Units: "Cotton - in season: sold 18 in 12 months (1.5 a month) x 10 weeks of supply gives a target of 4. On hand 1,
  on order 0, so order 3." (1.5 x 10 x 12 / 52 = 3.46, rounds up to 4; 4 - 1 - 0 = 3.)
- Months (a made-up rule with Supply 2, SupplyUnit Months): "Hydraulics: sold 30 in 12 months (2.5 a month) x 2 months
  of supply gives a target of 5. On hand 2, on order 0, so order 3."
- Requests (a made-up rule needing 3 demands, with `demandCount` 6): "Stripper belts: requested 6 times in 12 months
  (0.5 a month) x 6 weeks of supply gives a target of 1. On hand 0, on order 0, so order 1." (0.5 x 6 x 12 / 52 =
  0.69, rounds up to 1.)
- Minimum wins, rule gives a target (`demandCount` 4, rule needs 3): "Default: sold 4 in 12 months (0.33 a month) x 6
  weeks of supply gives a target of 1; the Equip minimum of 3 sets the target. On hand 1, on order 0, so order 2."
- Minimum wins, rule gives 0 (`demandCount` 2, rule needs 3): "Only 2 demands in 12 months (this rule needs 3), so
  the rule gives 0; your min override of 3 sets the target. On hand 1, on order 0, so order 2." (with a min
  override of 3)
- Minimum with no demand (`minimumNoDemand` true): "No demand in the last 12 months, so the rule gives 0; the Equip
  minimum of 2 applies even with no demand and sets the target. On hand 0, on order 0, so order 2."
- Units but no demands, minimum wins: "No demands recorded (sold 4; this rule needs 3), so the rule gives 0; the Equip
  minimum of 2 sets the target. On hand 1, on order 0, so order 1."
- Value capped (cost $25, MaxLineValue 500): "Default: sold 120 in 12 months (10 a month) x 12 weeks of supply gives a
  target of 28. On hand 0, on order 0, so order 20, cut back from 28 to stay at or under this rule's maximum line
  value of $500." (28 x 25 = 700 > 500; floor(500 / 25) = 20.)
- Below min value (cost $4.50, MinLineValue 10): "Default: sold 5 in 12 months (0.42 a month) x 12 weeks of supply
  gives a target of 2. On hand 1, on order 0, so the line would be 1 at $4.50, below this rule's minimum line value of
  $10; nothing is suggested."
- Above max value (cost $650, MaxLineValue 500): "Default: sold 6 in 12 months (0.5 a month) x 12 weeks of supply
  gives a target of 2. On hand 0, on order 0; one costs $650, more than this rule's maximum line value of $500, so
  nothing is suggested."
- NotStocked: "Default: only 2 demands in 12 months; this rule needs 3, so nothing is stocked."
- NotStocked, units with no demands (D14): "Default: sold 4 in 12 months but no demands were recorded; this rule
  needs 3 demands, so nothing is stocked."

Number display:
- `monthlyRate`: at most 2 decimals, trailing zeros dropped; above 0 and below 0.005 shows "< 0.01"; 0 shows 0.
- `supply`, `windowDemand` and `unitsSoldWindow`: up to 1 decimal, dropping ".0".
- Money (`cost`, line values, `minLineValue`, `maxLineValue`): "$" with 2 decimals, dropping ".00" for whole dollars.
- Whole values arrive as JSON integers.
- Handle plurals: "1 month", "1 demand", "requested 1 time", "1 week of supply".

### `history_<branch>.json.gz`
`{"branch", "months": [60 labels like "2026-10", "2026-09", ...], "parts": [{"franchise", "partNumber",
"sales": [60 numbers], "requests": [60 numbers]}]}`. Labels are newest first; index 0 is the current (partial)
month, using the Central-time month of the DP build. Index `i` in `sales` / `requests` lines up with `months[i]`;
months with no activity are `0`. Only parts that have history rows appear; parts are sorted by franchise, then part number.

### `surplus.json.gz`
`{"dataAsOf", "parts": [{"branch", "franchise", "partNumber", "onHand", "target", "surplusQty", "status"}]}`, every
included branch, only parts with surplusQty > 0. Used for "store N has extra" hints (shown as "Excess").

### `rules.json.gz`
`{"dataAsOf", "rules": [{"id", "ruleName", "priority", "active", "archived", "franchise", "dealerGroupCode",
"branch", "slc", "source", "vendorCode", "productGroup", "commodityCode", "startMonth", "endMonth", "historyMonths",
"minDemands", "weeksOfCover", "supplyUnit", "minLineValue", "maxLineValue", "demandBasis"}]}`, ordered by `id`. These are exactly the `NonJD_OrderRules` columns Gold reads, raw
as the staging table holds them (Gold and the app's engine validate and normalise them the same way): numbers are
JSON numbers (whole values as integers); a blank `supplyUnit` is `null` and means `Weeks`; a blank `archived` or
`active` is `null` and means No; blank text may be `""` or `null`. `weeksOfCover` is the Supply amount, in
`supplyUnit` (the column kept its name). `MinActiveMonths` is still in the list but unused (D1) and `Modified` is left
out; neither is published.

Changed in contractVersion 3: the five criteria `slc`, `source`, `vendorCode`, `productGroup` and `commodityCode`
(text; blank = any) are new. Changed in contractVersion 2: `minActiveMonths` is gone; `minDemands`, `supplyUnit`,
`minLineValue`, `maxLineValue` and `archived` are new. Archived rules are in the file (the Rules page shows them under "Show archived"); like
inactive rules, the engine ignores them: they are neither matched nor validated.

This is the rules list as the DP run read it at publish time; the app uses it to check its own engine against Gold.
If the rules dataflow is re-run between Gold and the publish, it can differ from what Gold used, so the app reports
rather than blocks. An empty list is written as `"rules": []`. Each publish uploads it (it embeds `dataAsOf`),
before `_meta.json`, like the other per-run files.

### `transfer_rules.json.gz` (new in contractVersion 3)
`{"dataAsOf", "rules": [{"id", "ruleName", "priority", "active", "archived", "franchise", "dealerGroupCode",
"branch", "slc", "source", "vendorCode", "productGroup", "commodityCode", "startMonth", "endMonth", "excessSupply",
"excessUnit", "allowSend", "allowReceive", "redistMax", "redistUnit", "redistMinValue"}]}`, ordered by `id`: every
`NonJD_TransferRules` column Gold reads, raw, handled like `rules.json.gz` (a NaN or infinite number fails the
publish; `Modified` and `Notes` are not published). Blank values are `null` and Gold and the engine read them as
the spec says (units Months, AllowSend / AllowReceive Yes, RedistMax 6 Months, RedistMinValue 0; a null `active`
means inactive). An empty list (Ben starts with none) is `"rules": []`, and the built-in default applies everywhere.

### `transfer_suggestions.json.gz` (new in contractVersion 3)
`{"dataAsOf", "lines": [{"kind", "franchise", "partNumber", "fromBranch", "toBranch", "seq", "qty", "fromCost",
"toCost", "value", "description", "fromBin", "toBin"}], "committed": [{"transferId", "lineId", "status",
"placedAt", "fromBranch", "toBranch", "franchise", "partNumber", "qty"}]}`. All branches in one file (about 2-3K
lines a day, well under the 4 MB upload limit). Uploaded every run, before `_meta.json`.

- `lines`: `Fact_NonJD_TransferSuggestion`, one per Kind + Franchise + PartNumber + FromBranch + ToBranch, sorted by
  franchise, part number (nulls last), then `seq`. `kind` is `Conventional` or `Redistribution`; `seq` is the
  emission order within the group (conventional first). `qty` is whole; `value` = qty x toCost to the cent.
  `fromBranch` / `toBranch` are the stored branch values (not trimmed); trim before comparing to a branch key.
  `description`, `fromBin` and `toBin` are for the screens and the CSV and may be null. The analysis columns
  (FromFreeExcess, ToNeed and so on) stay in Gold.
- `committed`: the `NonJD_Transfers` lines Gold counted in step 8b (the app's per-group parity needs exactly these),
  sorted by `transferId`, `lineId`: Status Draft or Exported, or Placed with the Central date of `placedAt` on or
  after the Central date of the build; both branches non-blank and not excluded. Values are raw: `placedAt` an ISO
  UTC datetime or null, `qty` as stored (Gold counts max(0, trunc(qty))), `fromBranch` / `toBranch` untrimmed.

### `transfers.json.gz`
`{"dataAsOf", "lines": [{"toBranch", "fromBranch", "partNumber", "ticket", "line", "orderQty", "shippedQty",
"openQty", "status", "subType", "ageDays", "date"}]}`. Outstanding transfer lines for part numbers in scope.
No line to or from an excluded branch (12, 5, 97, 4B, 93C) is published; the publish filters them (trimmed,
case-insensitive), since `Fact_OutstandingTransfers` still has them.

- `partNumber` is upper-cased and trimmed in Gold. Compare `part.partNumber.trim().toUpperCase()` to it.
- Transfer lines carry no franchise, so trailing-space twin parts and same-number parts in two franchises share the
  same lines (Gold's `inboundQty` matches the same way).
- `toBranch` / `fromBranch` are untrimmed in Gold and in the publish, and may be `""`. Trim before comparing to a branch key.
- `status`: `Pending`, `Partial` or `Shipped`.
- `subType`: `Stock`, `Work Order`, `Counter` or `Unknown`.
- `openQty` = shipped - supplied (always > 0).
- `ageDays` = days since the order date (Central), taking the max per ticket.
- `date` = line creation date, `YYYY-MM-DD`.
