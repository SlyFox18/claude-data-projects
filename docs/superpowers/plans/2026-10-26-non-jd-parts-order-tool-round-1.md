# Non-JD Parts Order Tool: Round 1 changes from Ben's feedback (Plan C)

> **For agentic workers:** use superpowers:subagent-driven-development, one task at a time with a review after each (Brian's standing choice). SharePoint, Entra, Gateway PC and Fabric UI steps are Brian's, one at a time, verified.

> **Progress:**
> - C0 DONE 2026-10-26 (Brian, verified via Graph):
>   - **NonJD_OrderRules:** MinDemands (Number, 0 dp), SupplyUnit (Choice Weeks/Months, default Weeks), MinLineValue / MaxLineValue (Number, 2 dp) and Archived (Yes/No, default No) are added. MinDemands is set on the existing rows: Default 3, Cotton in 2, Cotton off 3, Test 3. On existing rows SupplyUnit and Archived are blank, read as Weeks / No.
>   - **NonJD_PartSettings:** ManualOrder (Yes/No, default No) and MaskedOn (date only) are added. The test row is unchanged.
> - C1 DONE (`93fbd8f4`, `df45ccfe`, 273 tests): reference on the round 1 calculation incl. D13/D14; impact report `feedback/2026-10-26-round1-impact.md` (checks: step 1 = Dev Gold part by part, step 6 = reference part by part).
> - C3 DONE (fabric-workspace-docs `25bb5fc9`): Gold on round 1, synced to Dev with no conflict (the commit didn't touch the lakehouse).
>   - Compare: PASS, 0 differences on 199,473 rows.
>   - Determinism: identical fingerprint on two runs.
>   - Live list (Default 3 demands / 6 weeks) = impact step 5 exactly: 5,309 lines, $4.86M.
>   - **Until C4 lands and the Gateway PC pulls it,** the scheduled publish fails at extract (old columns gone) and uploads nothing, so the app stays on the Oct 23 files.
> - C5 DONE (app `6c27884`, `d26a255`, 803 tests):
>   - The engine and data layer are on round 1 and contract v2 (`src/data/contract.ts` refuses unknown versions).
>   - Full parity: 0 mismatches over 199,473 parts and 25 fields.
>   - Fuzz against the reference: 24,189 parts, 0 mismatches (two planted bugs were caught).
>   - The validation messages are identical.
>   - The live-only cases (manual, masked, value limits, months, mask ended) have hand-made tests ported from the reference.
>   - No separate review: parity and fuzz are the check; the save logic is reviewed with C6–C9.
> - C6–C9 DONE (app `c0bcab5`, `f585e44`, `72152a8`, `49a89ef`; review fixes `5794c93`; 894 tests): rules (MinDemands, supply unit, line values, archive with "Show archived"), wording (supply, Excess), D12 tag and switch (Home matches Reorder via `view.ts`), quick Mask / Manual order actions, the Special statuses page, One-Time exclusions and line limits, and Other branches (all branches auto-loaded, this branch included, totals). Updates PATCH only the changed columns (no lost updates).
> - C10 in progress: switch-over to minimise downtime. Refresh Dev first, while the old app keeps working; then deploy the app and publish straight after.
> - C4 DONE (`68fcf9b2`, `96d2e613`, 137 tests; review approved, then fixed: explanation wording, a contractVersion bump rule with newer/older messages, the rules column check before extract, non-finite rule numbers fail the publish): contract v2 (`contractVersion` 2 in `_meta.json`), 53 reorder fields, column check before extract, transfers exclude the excluded branches. The dry build from Dev matches Gold: 42 files, Branch 1 has 164 lines / $39,746.33.
>   - **Do NOT `git pull` on the Gateway PC until the app (C5–C9) is deployed to Fedora (C10).** A v2 publish would break the old app.
>   - Prod Gold is still old, so the Prod release must deploy round 1 Gold and this publish together.
> - C2 DONE (fabric-workspace-docs `e37cbf3e`, `fd351114`): both dataflows read the new columns, synced to DP - Staging - Dev and run.
>   - MinDemands, MinLineValue and MaxLineValue are `number` (DOUBLE), so a bad value reaches validation and isn't silently rounded. C3 casts them after validating.
>   - Blank SupplyUnit is null (SharePoint sends ""). Archived and ManualOrder are null when blank.
>   - MaskedOn is typed like MaskExpires (the date shown in SharePoint).

**Goal:** apply round 1 of Ben's answers (`projects/part order tool - app/feedback/2026-10-23-ben-answers.md`). That means demand-count stocking, weeks/months of supply, Equip minimums always applying, a target of 0 meaning order 0, branch exclusions, line value limits, masking and Manual Order, a special-status page, archived rules, and the wording Ben asked for.

**Architecture:** unchanged. Gold (`Build_Gold_NonJD_Reorder`), the DuckDB reference (`tools/dp-migration/nonjd_reorder_check.py`) and the app engine (`nonjd-order-app/src/engine`) implement the same rules and must agree with 0 differences. The publish contract (`projects/part order tool - app/publish/README.md`) carries the new fields.

**Out of scope (round 2 / later):** transfers (Q3), several branches at once (Q2), phase-in (Q8), spiking (Q6), EOQ / pre-approved (Q7), JD parts, and the Prod release (Plan A Task 15, scheduled separately).

---

## Decisions made with Brian (2026-10-26, Ben out)

| # | Ben's item | Decision |
|---|---|---|
| D1 | C1 | Stocking uses **demands**: the number of transactions (`RequestCount`) in the window. New rule setting **MinDemands** replaces MinActiveMonths (that column is left in the list, unused). Default 3 demands in 12 months. |
| D2 | C1 | "Weeks of cover" is called **weeks of supply** everywhere. Default rule: 12 weeks. |
| D3 | C4 | Supply can be set in **weeks or months**: new setting **SupplyUnit** (Weeks / Months; blank = Weeks). The amount stays in the WeeksOfCover column, shown as "Supply". Weeks 0–104, months 0–24. |
| D4 | Q5 | The **Equip minimum always applies**, even with no demand. Cleanup stays as the list of minimums on parts with no demand in the window. |
| D5 | C7 | **A target of 0 means order 0**, whatever negative stock or on-order shows. |
| D6 | Q1 | Branches **12, 5, 97, 4B, 93C** are left out of every output. |
| D7 | Q10 | Per-line limits in rules and One-Time Order: **MinLineValue** (a line below it isn't suggested) and **MaxLineValue** (the quantity is cut back to stay at or under it). |
| D8 | C3 | A mask also ends at the part's **first demand after it was masked** (`DateLastRequested` > MaskedOn). **Manual Order** (new setting) is never suggested until changed. Mask and Manual Order can be set from the Reorder list. New **Special statuses** page. |
| D9 | C6 | One-Time Order leaves masked and Manual Order parts off. |
| D10 | Q4 | Rules can be **archived** (new setting Archived). Archived rules are ignored and hidden unless "Show archived" is on. |
| D12 | Q5 (after C1 impact) | Equip minimums apply exactly as Ben asked. In the app, lines with MinimumNoDemand get a "Min, no demand" tag. Recommended Reorder gets a "Show minimums with no demand" switch, **off by default**, so those lines are visible on request but never added to an order unless chosen. The Home banner and the selection counts follow the switch. Brian emailed Ben the impact and the six largest suspect Equip minimums (2026-10-26). |
| D13 | C1 review | A line the value cap cuts to 0 gets status **AboveMaxValue** ("Above max value"), right after BelowMinValue. A partial cap keeps OutOfStock / Reorder with ValueCapped set. |
| D14 | C1 review | **UnitsSoldWindow** = max(0, round9(sum SalesQty)) over the window, whatever the basis. "No activity" = DemandCount 0 **and** UnitsSoldWindow 0. NoRecentActivity and MinimumNoDemand use no activity; stocking still uses DemandCount. (973 parts sold units with 0 recorded demands; question for Ben: why Equip records sales with no request.) |
| D11 | Q12 | "Surplus" is shown as **Excess**. Other branches loads every branch by default with a totals line. The contract field stays `surplusQty`. |

## The calculation (must match in Gold, reference and app)

For each part at each included branch (D6):

1. **Rule:** as today (highest Priority, then most criteria, then lowest Id), considering only rules that are **Active and not Archived** and in season. Archived rules are not validated or reported. Built-in default: 12 months, MinDemands 3, supply 12 Weeks, UnitsSold, no line limits.
2. **Window:** the last HistoryMonths full months (current month excluded), as today.
3. **WindowDemand** = max(0, round9(sum of the basis)), as today. **DemandCount** = max(0, sum of RequestCount) over the window (integer). ActiveMonths is still computed for display only.
4. **MonthlyRate** = WindowDemand / HistoryMonths.
5. **SupplyMonths** = Supply × 12/52 when SupplyUnit is Weeks (or blank), Supply when Months.
6. **CalcTarget** = ceil(round9(MonthlyRate × SupplyMonths)) when DemandCount ≥ MinDemands, else 0.
7. **EffectiveMin** = MinOverride if set, else the Equip minimum (D4). **MinimumNoDemand** = no MinOverride, Equip minimum > 0 and DemandCount = 0 (it replaces MinimumIgnored, and Cleanup reads it).
8. **Target** = max(CalcTarget, ceil(EffectiveMin)).
9. **Base qty** = 0 if Target = 0 (D5), else max(0, Target − trunc(on hand) − trunc(on order)).
10. **Line value** (only when base qty > 0 and cost > 0):
    - If MaxLineValue is set and qty × cost > MaxLineValue, then qty = floor(round9(MaxLineValue / cost)) and **ValueCapped** = true.
    - Then, if MinLineValue is set and qty × cost < MinLineValue, then qty = 0 and **BelowMinValue** = true.
11. **Live mask:** IsMasked = Masked and (MaskExpires blank or ≥ Central today) and not (MaskedOn set and DateLastRequested > MaskedOn). Comparison is at date level; a blank MaskedOn (older rows) never falls off on demand.
12. **Order** = 0 if ManualOrder or IsMasked, else the qty from step 10.
13. **Surplus** = max(0, trunc(on hand) − Target), as today.
14. **Status,** first match: ManualOrder · Masked · Target = 0 → NoRecentActivity (DemandCount = 0) or NotStocked · BelowMinValue · OutOfStock (order > 0 and on hand ≤ 0) · Reorder (order > 0) · OK.

**Validation (invalid rule → skipped with a WARN, as today):**
- MinDemands is a whole number from 0 to 9999.
- SupplyUnit is blank, Weeks or Months.
- Supply is in range for its unit.
- MinLineValue and MaxLineValue are blank or ≥ 0.
- When both are set, MinLineValue ≤ MaxLineValue.
- Messages follow today's style ("MinDemands is missing", "MinDemands must be a whole number 0-9999", "Supply must be 0-104 weeks" / "0-24 months", …).

---

## Tasks

### Task C0 (Brian, SharePoint): new list columns

On the Report Site, verified through Graph after each list:
- **NonJD_OrderRules:**
  - MinDemands (Number, 0 decimals)
  - SupplyUnit (Choice: Weeks, Months; default Weeks)
  - MinLineValue (Number, 2 decimals)
  - MaxLineValue (Number, 2 decimals)
  - Archived (Yes/No, default No)
- **Existing rule rows:** set MinDemands (Default 3, Cotton - in season 2, Cotton - off season 3, Test - UI/UX 3) so no rule is skipped when the new Gold runs. Leave Supply at its current values; 12 weeks for Default happens in C10.
- **NonJD_PartSettings:**
  - ManualOrder (Yes/No, default No)
  - MaskedOn (Date only)

### Task C1: Reference check and impact report

- `nonjd_reorder_check.py`: implement the calculation and validation above in RULE_CHECK_CTE / EXPECTED_SQL / INVALID_RULES_SQL. Update the tests first; every new branch of the rules needs a case, and the existing 125 tests are adapted.
- New `tools/dp-migration/nonjd_round1_impact.py` (read-only, Dev data): suggested lines and $ for every included branch under, cumulatively:
  1. today's logic;
  2. branch exclusions;
  3. MinDemands 3 instead of 3 active months;
  4. target 0 → order 0;
  5. Equip minimum always applies;
  6. Default at 12 weeks.

  Also give per-branch totals for 1, 8 and 92. The rule values are parameters, so it doesn't depend on C0. Output goes to a short markdown table for Ben.

### Task C2: Dataflows read the new columns

`df_NonJD_OrderRules_Raw` and `df_NonJD_PartSettings_Raw` (fabric-workspace-docs, Dev): add the new columns, typed (SupplyUnit text, MaskedOn date as the Central date). Git-sync Dev, run both, and check the staging tables with DuckDB.

### Task C3: Gold notebook

`Build_Gold_NonJD_Reorder`: implement the calculation; add EXCLUDED_BRANCHES (trimmed, case-insensitive) to the scope, the history output and the transfers it reads; and add the new columns.
- New columns: DemandCount, MinDemands, SupplyUnit, Supply, SupplyMonths, MinLineValue, MaxLineValue, ValueCapped, BelowMinValue, ManualOrder, MaskedOn, MinimumNoDemand.
- Remove MinimumIgnored and MinActiveMonths from the output.
- Follow `dp-notebook-rules.md`, and update `dp_refresh_dag.json` if outputs change.
- Done when: run twice; the reference compare gives PASS with 0 differences; `dag_check.py` and pytest pass.

### Task C4: Publish contract and build

- Contract README and `build_files.py`/`extract.py`:
  - New reorder fields (camelCase of the above).
  - `minimumIgnored` → `minimumNoDemand`.
  - `minActiveMonths` → `minDemands`.
  - `weeksOfCover` → `supply` + `supplyUnit`.
  - rules.json gets the new rule fields plus `archived`.
  - Settings fields the app reads live: manualOrder, maskedOn.
- Bump the contract version in `_meta.json`. The app refuses a contract version it doesn't know, showing "The app needs updating".
- `make_engine_fixture.py`: update the strata (demand counts, value caps, manual order, mask fall-off, months unit).

### Task C5: App engine

`src/engine`: the same calculation, validation and statuses. `explain()` gets sentences for:
- demands below the minimum;
- months vs weeks of supply;
- value capped / below the minimum value;
- manual order;
- a mask that ended because the part was requested.

Tests first. Then:
- Regenerate the fixture from C3's Dev output.
- `scripts/parity-full.ts` gives 0 mismatches on the full Dev data, with the new fields added to compareToGold.
- Repeat the differential fuzz against the C1 reference: 0 mismatches.

### Task C6: App rules and wording

**Rules page:**
- MinDemands replaces Min active months.
- Supply amount + unit (Weeks/Months).
- Min/Max line value.
- An Archive action and a "Show archived" toggle (archived rows greyed and read-only until unarchived).
- Try it covers all of these.

**Wording everywhere:**
- "weeks of supply" / "months of supply".
- "Excess" instead of "Surplus", with "Excess = on hand above that branch's target".
- Status labels: Manual order, Below min value.

### Task C7: Masking, Manual Order, Special statuses

- **Reorder row detail and the Create order review:** Mask (with optional expiry) and Manual order actions, using the same save as the Settings tab. Saving a mask writes MaskedOn = Central today. Unmask clears it.
- **Settings tab:** Manual Order toggle.
- **Live mask in the app:** follows step 11 (needs `dateLastRequested` from the reorder file).
- **New menu page Special statuses:**
  - Every NonJD_PartSettings row that is Masked (still live), Manual Order, or has a Min override.
  - Shows branch, part, description (from the all-branches slim cache), status, set by and on (Editor/Modified), expiry, and a link to the part.
  - Filters by status and branch; CSV export.
  - Phase-in joins it in round 2.

### Task C8: One-Time Order

- Masked and Manual Order parts are left off (D9). Remove the masked-unticked handling and its Select-all rule.
- Setup gets optional Min line value / Max line value, with the same per-line meaning as D7 applied to the one-time quantity.
- The inputs are recorded in Parameters.

### Task C9: Other branches

- The Part page's Other branches loads every branch automatically, from the slim cache with progress.
- Columns: on hand, target, excess, sold 12 mo (add `current12MoSales` to the slim projection).
- A totals row at the bottom.

### Task C10 (Brian + Claude): switch over in Dev

1. Git-sync Dev (C2, C3). Both are already done.
2. **Build and deploy the app to Fedora first.** The new app shows "The data was published in an older format; it will update after the next publish" until step 4. The old app has no version check, so the publish must never run ahead of the app.
3. Brian sets Default to Supply 12, SupplyUnit Weeks, MinDemands 3, in the app.
4. Dev refresh (mode all), then the publish: Gateway PC `git pull` + `run_publish.py --force`.
5. Retest list:
   - parity banner absent;
   - a mask set then requested;
   - manual order;
   - line value limits;
   - archived rule;
   - Special statuses;
   - One-Time leaves masked parts off;
   - Other branches totals.

### Task C11: Documents

- Update the user guide (`for-users/guide.js` → .docx), REORDER-RULES.md and the questions doc with the new calculation and wording.
- Add the impact table (C1) and a short "What changed from your answers" page for Ben.
