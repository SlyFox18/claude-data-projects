# Non-JD Parts Order Tool: round 2 design (transfers, several branches, phase-in)

> **Progress:** design written 2026-10-27 (Claude, for Brian), without waiting for Ben. Every assumption is in the table below so Ben can correct it. Nothing is built yet. No code, Fabric or SharePoint changes were made; the numbers come from read-only DuckDB queries on Prod Gold built 2026-10-26 20:59 UTC.
>
> Builds on: spec `2026-10-20-non-jd-parts-order-tool-redesign-design.md`, Plan A (data feed), Plan B (app), Plan C (round 1, decisions D1–D14 and "The calculation"), contract v2 (`projects/part order tool - app/publish/README.md`). Ben's answers: `projects/part order tool - app/feedback/2026-10-23-ben-answers.md` (Q2, Q3, Q8).

**Goal:** add the three things Ben asked for in round 2:
- **Transfers (Q3).** Transfer rules, conventional and redistribution transfers suggested daily, and a transfer step before the order in Recommended Reorder and the One-Time Order. Ticking a transfer recalculates the order.
- **Several branches at once on Recommended Reorder (Q2).**
- **Phase-in (Q8).**

The architecture doesn't change: Gold (`Build_Gold_NonJD_Reorder`), the DuckDB reference (`tools/dp-migration/nonjd_reorder_check.py`) and the app engine (`nonjd-order-app/src/engine`) implement the same rules and must agree with 0 differences.

---

## Assumptions for Ben

Each one is what we will build unless Ben says otherwise. "Alternative" is the other reasonable reading.

| # | Assumption | Why | Alternative |
|---|---|---|---|
| A1 | **Months of supply** for transfers = truncated on hand ÷ the part's monthly rate from its order rule (the same rate the order uses: the rule's window and demand basis). | One meaning of "months of supply" across the tool; the rate is already computed and shown. | A separate window or basis per transfer rule (e.g. always 12 months of units sold). |
| A2 | **Excess** at a sending branch = free stock above what it keeps. It keeps the larger of its own target and the excess supply (default **12 months**, rounded up to whole units). Free stock = on hand minus stock already committed to open tickets (Equip's PendingQty). | Ben's "greater than 12 months of supply", and a sender must never fall below its own target. We found that Equip's on hand includes pending stock (see "Data findings"). | Excess measured against 12 months alone, ignoring the target. In practice that only differs when an Equip minimum or override is above 12 months of supply. |
| A3 | **A part with no sales in the window (monthly rate 0):** everything above its target is excess. Its target still protects an Equip minimum, a min override or a phase-in. | Stock that doesn't sell is exactly what should move. It is 77% of all excess dollars ($2.69M of $3.47M). | Treat rate-0 stock as not transferable, or protect parts created in the last N months. |
| A4 | **Conventional receivers** are lines that would be ordered: target > 0, not Manual order, not masked, and the receiving branch's rule allows receiving. The **need** is the base quantity before the line value limits (target − on hand − on order − transfers already saved in the app). | A transfer replaces a purchase. Line value limits are about purchase lines, so a line too small to buy (Below min value) or cut back by the cap can still be filled by transfer. | Fill only the quantity that would actually be ordered (after the limits). |
| A5 | **Minimums with no demand (D12) are never conventional receivers.** | They are hidden from the order by default and are on Ben's cleanup list. Moving stock to satisfy a suspect minimum is the wrong default. | Treat them like any other need. |
| A6 | **Allocation:** each part (franchise + part number) is allocated on its own across all branches. Receivers go in this order: out of stock first, then the largest need, then branch order. Each receiver takes from the sender with the **most free excess** first (ties: branch order), then the next, until its need is filled or nothing is left. | Taking from the largest pile first gives the fewest transfer lines (90% of covered lines need one sender) and drains the most overstocked branch first. Everything is deterministic. | Branch priority, distance or truck route (we have no data for these), or sharing the excess in proportion to need. |
| A7 | **All branch pairs are equal.** No transfer cost, distance or route is used. | There is no such data in Equip or DP. | Ben supplies a list of preferred or blocked branch pairs; it slots into the sender order in A6. |
| A8 | **Redistribution** runs after conventional, on the excess that is left. A receiver must already stock the part (target > 0), have sales (monthly rate > 0), not be masked or on Manual order, and not itself have excess. It can take stock up to its rule's **receive maximum** (default **6 months of supply**), counting on hand, on order and transfers in. The emptiest receivers (fewest months of supply) go first. | This is Ben's description: started by the over-stocked sender, going to a branch that sells the part and has room above its normal supply. | Let branches that don't stock the part receive, or start from the receivers' side. |
| A9 | **Redistribution lines below a minimum value are not suggested;** the default is **$25** at the sender's cost. Conventional transfers have no minimum. | With no minimum there are 1,129 lines for $124K. At $25 there are 552 lines for $119K: half the work for 96% of the value. | No minimum, or a minimum quantity. |
| A10 | **Transfer rules use the same pick order as order rules** (highest priority, then most criteria, then lowest Id; seasons; Active; Archived). The sender's rule decides its excess and whether it may send. The receiver's rule decides whether it may receive and its receive maximum. | One way of thinking about rules for Ben. Each branch's own part record decides, because group code, SLC and source vary by branch. | One rule per branch pair, or rules that match the sender and receiver together. |
| A11 | **Rule criteria:** Franchise, Dealer group code, Branch, **SLC**, **Source**, **Vendor code**, **Product group** and **Commodity code**, on transfer rules **and on order rules**. | Ben asked for these on transfer rules and said rules should "still" have them. Adding them to both costs little once Gold reads the fields. Commodity code is empty for non-JD parts today (26 parts) but matters for JD parts later. | Transfer rules only; order rules keep Franchise / Group code / Branch. |
| A12 | **Conventional suggestions start ticked; redistribution suggestions start unticked.** | Conventional replaces buying. Redistribution is optional housekeeping. | Both unticked (opt in), or both ticked. |
| A13 | **A ticked transfer becomes a saved "transfer order"** (one per sending + receiving branch, all franchises together) with a CSV export. Someone keys it into Equip and marks it **Entered in Equip**. The app never writes to Equip. | Equip transfers are made by people today. One ticket per branch pair is how Equip groups a transfer (`InSalOrd` type T, lines can mix franchises). | One per branch pair and franchise, like orders. |
| A14 | **Saved transfers count straight away:** they reduce the sender's free excess and add to the receiver's inbound (so its order drops) while **Draft** or **Exported**, and after **Entered in Equip** until the next morning's data, which then carries them in Equip's own on order and pending. **Cancelled** never counts. | Without this, the next person or the next morning would be shown the same transfer again. | Count only until Exported, or never (rely on Equip only). |
| A15 | **Transfers already in Equip are not subtracted again.** Equip puts an open transfer into the receiving branch's on order (true for 531 of 534 open transfer lines), so the order already accounts for it. `inboundQty` stays display only. | Subtracting it again would count it twice. | — (it's a data fact, but Ben should know why "inbound" doesn't change the order). |
| A16 | **"Excess" changes meaning:** from round 2 it is the transfer meaning (free stock above the excess supply). Round 1's "Excess" (on hand above target, D11) is relabelled **Above target**. | Two different "Excess" numbers on one screen would confuse. Ben's Q3 uses Deere's meaning. | Call the transfer figure "Transferable" and keep round 1's label. |
| A17 | **Selecting a transfer never changes the sender's order.** A sender keeps at least its own target (A2), so its order stays 0. | It follows from A2. | — |
| A18 | **Phase-in:** while active, target = the larger of the normal target and the phase-in quantity. It ends at its end date (default 12 months from the day it is set) or once the part has as many demands in its rule's window as the rule needs (at least 1). It is worked out fresh every day, not remembered: if demands later fall below the minimum before the end date, the phase-in applies again. | Ben's Q8, worded as the rule's own stocking test. A permanent "fell off" would need state the lists don't have. Within a 12-month phase-in a part's demands rarely fall back. | Make the end permanent (needs a "PhaseInEnded" column written by the app, or a history scan). |
| A19 | **Masked and Manual order beat phase-in** (no order). A phase-in part in a One-Time Order uses the one-time calculation only. | Masks and Manual order are explicit "don't order" settings. One-Time is a different calculation. | Phase-in as a floor in One-Time too. |
| A20 | **Multi-branch Recommended Reorder** works like 0.3.0's One-Time: branch and franchise checkboxes, one list with a Branch column, one order per branch + franchise. **Home stays on the single default branch.** | Same pattern Shannon has already tried; Home is a quick glance. | Several default branches on Home. |
| A21 | **One-Time Order transfers are conventional only,** filling the one-time quantity from other branches' excess (worked out with their normal rules). | A one-time order is a single buy; redistribution belongs with the daily order. | Offer redistribution in One-Time too. |
| A22 | **No age protection for senders.** A brand-new part with no sales yet can be sent unless it has a phase-in or a minimum. | Phase-in is the tool for "we want this stocked here". | Protect parts created in the last 6 or 12 months (needs DateCreated). |
| A23 | **A Draft transfer never left open** keeps holding its stock until someone cancels it. The Transfers page flags drafts older than 7 days. | Deterministic and simple; nothing changes silently. | Drafts expire after N days. |

## Decisions for Brian

> **Answered 2026-10-26 by Brian:**
> - **1:** the order of work is approved, and phase 1 (app 0.4.0, multi-branch Reorder) is started.
> - **3:** PendingQty is confirmed as stock committed to open tickets that on hand still counts, so A2 stands.
> - **2 and 4:** due at phase 2.
> - **Phase 1 deviation (accepted):** Part Lookup keeps its own slim cache, not the engine loader, because it reads only the reorder files. One-Time and Reorder use `engineBranches.ts`. App 0.4.0 commits: `4d54ca9`, `d878da0`, `f60c7a9`.
> - **Phase 1 done 2026-10-27:** app 0.4.0 (`3ca2dec`, after review fixes `8940fa9`, `3ca2dec`) is deployed on Fedora. 984 tests pass. Brian's check on Prod data: all 19 branches load in about the 4 s target (was 10–12 s), and nothing looks or feels off. Prod Gold that morning: Barry's six Equip minimum fixes are in (all six show MinimumQty 0, no order); minimums with no demand now total 3,115 lines / $463,388 (were $4.27M on Dev 10-23), and the rest of the suggested order is 2,699 lines / $1,128,063.

Only these need Brian:
1. **Order of work** (see "Phasing"): multi-branch Reorder first (app only, no data change), then the data, phase-in and contract v3, then the live transfer step. The alternative is to wait for Ben's answers before phase 3, the expensive part. Recommendation: send Ben the assumption table now and build phases 1–2 while he reads it.
2. **SharePoint (Brian's steps, verified through Graph as in Plan C C0):** create `NonJD_TransferRules`, `NonJD_Transfers` and `NonJD_TransferLines`, and add columns to `NonJD_PartSettings` and `NonJD_OrderRules` (listed under "The lists").
3. **Check PendingQty in Equip** (SQL Anywhere or ask JDIS): is `jdis_Part_Information.PendingQty` the stock picked or committed to open tickets (counter, work order, transfer) and still counted in on hand? The data says on hand = bin + bulk bin + pending for 14,284 of 14,349 parts with pending, and every unshipped transfer line has pending at the sender. A2 depends on this.
4. **Two new dataflows in DP** (`df_NonJD_TransferRules_Raw`, `df_NonJD_Transfers_Raw`) in Pipeline_DP_Refresh. That means a Prod backend deploy and `claim_prod_pipeline.py` as usual.

## Opportunity (Prod Gold, 2026-10-26)

Default rules as in A1–A9: excess above 12 months, receive maximum 6 months, $25 redistribution minimum. Values at cost. "Default view" = Recommended Reorder's default (Reorder + Out of stock, minimums with no demand hidden).

| Measure | Value |
|---|---|
| Parts in scope | 199,524 at 19 branches |
| **Excess** (free stock above max(target, 12 months)), all branches | 1,192,644 units, **$3.47M**; $2.69M of it on parts with no sales in the window (A3) |
| Order lines, default view | **2,696 lines, $1.12M** (5,819 lines / $5.39M with the no-demand minimums) |
| **Conventional:** order lines another branch could fill | **1,055 lines (39%)**, 863 of them fully; 11,265 units, **$173K (15%) not bought** |
| Transfer lines for that | 1,199 (953 lines from one sender, 75 from two, 27 from three or more) |
| **Redistribution** after conventional | **552 lines, $119K** (19 sending, 19 receiving branches). No minimum: 1,129 lines / $124K. $100 minimum: 261 lines / $105K |

Sensitivity to the excess supply (conventional / redistribution at $25):

| Excess above | Conventional | Redistribution |
|---|---|---|
| 6 months | 1,185 lines, $233K | 736 lines, $163K |
| **12 months (default)** | **1,055 lines, $173K** | **552 lines, $119K** |
| 24 months | 909 lines, $147K | 401 lines, $89K |

For scale: non-JD **stock** transfers in Equip over the last 12 months were about 3,600 lines and $2.55M at cost (`Fact_Transfers`, type T, subtype Stock). So the suggestions are a modest daily list, not a flood.

**Caveats:**
- Values are at the receiving branch's cost. Cost is usually the same everywhere (glossary).
- A trailing-space or case difference in part numbers between branches would hide a match. We checked: no order line gains a sender under a trimmed, upper-cased key, so matching on the exact franchise + part number loses nothing.
- These are one morning's numbers. Seasonal parts (cotton) will swing them.
- The sizing script (scratch, not committed) is an approximation of the calculation below: the need was Gold's recommended qty (after the line value limits) and sender pending stock was not subtracted. Expect the real figures to be a little different.

## Data findings

**Descriptive fields for rules** (non-JD scope, 199,524 parts; "differ" = parts at 2+ branches whose value isn't the same at all of them, blank counted as a value):

| Field | Where | Filled | Distinct | Differs by branch | Notes |
|---|---|---|---|---|---|
| Dealer group code | `Silver_PartInformation.DealerGroupCode` (per branch) | 64% (74% of parts with stock) | 1,413 | 50% | Already used by order rules |
| **SLC** | `Silver_PartInformation.SLC` (per branch) | 13.5% (21% with stock) | 74 | 24% | `00` on 25,500 of 26,840 filled rows; then 50E, 20A, 15D … |
| **Source** | `Silver_PartInformation.Source` (per branch) | 14.2% (22% with stock) | 169 | 25% | `500` on 16,145; then AL, 503, 501, 504 … |
| **Commodity code** | `Silver_PartInformation.CommodityCode` (per branch) | **0.0%** (26 parts) | 4 | — | Empty for non-JD; matters for JD later |
| Vendor code | `Silver_PartInformation.VendorCode` (per branch, integer) | 100% | — | 40% | Already published as `vendorCode` |
| Product group | `Silver_InMaster.ProductGroup` (per branch) | 2.8% | 483 | 8% | Already published as `productGroup` |

- `Silver_InMaster` also has `Category` and `SalesClass`. They hold the same values as SLC and Source (same distinct values and counts). Use `Silver_PartInformation`, which Gold already reads.
- `dim_Parts` has SLC, Source and CommodityCode too, but it is company-wide (the most common value across branches), so it is wrong for per-branch rules. It is not used.
- **The Commodity Code Groups CSV** (`CommodityCodeGroups.csv`, 244 JD commodity codes in 17 groups) isn't relevant now: non-JD parts have no commodity code. Keep it in mind for JD parts, where a "Commodity group" criterion could read it.

**Transfers in Equip and DP:**
- A transfer is a parts ticket of type T: `InSalOrd.OrderType = 'T'`. The ticket's branch is the **sending** branch, and `TrfToBranch` is the receiving branch. Its lines are in `InSalPar`, which can mix franchises. `Silver_InSalOrd` appears to hold only open tickets (452; 389 of them from October).
- `Fact_OutstandingTransfers`: one row per open line (PartTicket + LineNumber) with Requesting / Supplying branch, Order / Shipped / Supplied quantity, OpenQty = shipped − supplied, status and subtype.
  - It keeps only tickets where the sender's InMaster in-transit qty is > 0, and only lines with shipped > supplied. So **unshipped transfer lines are left out** (87 lines today; 19 to non-JD parts).
  - Outbound is available (SupplyingBranch), but only for shipped lines.
  - 440 lines today. Gold's `InboundTransferQty` is > 0 on 70 non-JD parts (608 units).
- **How Equip's quantities carry a transfer** (checked across all 534 open lines):
  - The receiving branch's **OnOrder includes it**, shipped or not (531 of 534; only 627 of 199,524 non-JD parts have any on order at all).
  - While unshipped, the sending branch's **PendingQty** carries it (86 of 87), and on hand still includes it. On hand = bin + bulk bin + pending for 99.5% of parts with pending. Once shipped, pending clears and the sender's in-transit holds it.
  - Consequences: a transfer in Equip already lowers the receiver's order (A15), and a sender's free stock must subtract pending (A2). Both use data DP already has; `Fact_OutstandingTransfers` is not needed for the calculation.
- `Fact_Transfers` (InTrans, type T) is the history of completed transfers; used above for scale only.
- **No transfer cost, distance or route data exists** (A7).
- **The separate Transfer App project** (memory note `project_transfer_app_bin_data_source`) is about JD's barcode backend for picking and bin scans (`SPITractor-JDOPS`, `EquipTransfers` connector). It can't create transfers for us today (the connection isn't shared with Brian). It's not used in round 2. If that connection is ever shared, "create the Equip ticket from a saved transfer" becomes possible later.

---

## The calculation

This is the round 1 calculation (Plan C) with the changes below. Each new step has to be implemented three times (Gold, reference, app) and give the same results.

**Notation:**
- `oh` = trunc(QuantityOnHand)
- `oo` = trunc(OnOrder)
- `pend` = max(0, trunc(PendingQty))
- `rate` = MonthlyRate (step 4)
- `months(x, unit)` = x × 12 / 52 for Weeks, x for Months, evaluated in that order (as SupplyMonths)
- `ceil9(x)` = ceil(round9(x))
- **Branch order** = trimmed branch code; codes made only of digits come first in number order, then the others by ordinal string comparison (as `_meta.branches`).

All quantities are whole numbers.

### Part 1: per part at each branch (the order engine, changed)

Steps 1–7 are unchanged, except that step 1's rule matching knows the new criteria (A11, below).

- **Step 7b, phase-in:**
  - **PhaseInActive** = PhaseInQty is set and > 0, AND (PhaseInEnds is blank or ≥ the Central date of the build), AND DemandCount < max(MinDemands, 1).
  - **PhaseInEndReason** (display only) =
    - `Expired` when PhaseInQty > 0 and PhaseInEnds < the Central date;
    - else `MetCriteria` when PhaseInQty > 0 and DemandCount ≥ max(MinDemands, 1);
    - else null.
- **Step 8, target:** Target = max(CalcTarget, ceil(EffectiveMin), PhaseInActive ? ceil(PhaseInQty) : 0).
- **Step 8b, committed app transfers** (A14): **AppInboundQty** and **AppOutboundQty** = the sums of the committed transfer lines into and out of this exact Branch + Franchise + PartNumber.
  - A line is committed when its transfer's Status is Draft or Exported, OR Status is Placed and the Central date of PlacedAt ≥ the Central date of the build (for the app: of `dataAsOf`).
  - Branch codes are compared trimmed and case-insensitive. Franchise and part number are compared exactly, as stored in the line (copied from Gold).
- **Step 9, base qty:** 0 if Target = 0, else max(0, Target − oh − oo − AppInboundQty).
- Steps 10–14 are unchanged. Status values are unchanged; a line covered by a saved transfer simply comes out OK or with a smaller quantity.
- **SurplusQty** (step 13) is unchanged; it is shown as **Above target** (A16).

### Part 2: transfer inputs per part (new)

1. **Transfer rule:** pick one rule from `NonJD_TransferRules` exactly as step 1 picks an order rule:
   - Only Active, not Archived, valid and in-season rules count.
   - Order: highest Priority, then most non-blank criteria, then lowest Id.
   - Criteria are compared trimmed and upper-case. A blank criterion matches anything; a blank part value matches only a blank criterion. VendorCode is compared as its integer's text.
   - No match: the built-in default, `{RuleName "Built-in default", ExcessSupply 12, ExcessUnit Months, AllowSend true, AllowReceive true, RedistMax 6, RedistUnit Months, RedistMinValue 25}`.
2. **ExcessKeep** = max(Target, ceil9(rate × months(ExcessSupply, ExcessUnit))). With rate 0 this is Target (A3).
3. **FreeExcess** = AllowSend ? max(0, oh − pend − ExcessKeep − AppOutboundQty) : 0.
4. **ConvNeed** (A4, A5) = the step 9 base qty, but 0 when any of these holds: AllowReceive is false, ManualOrder, IsMasked, MinimumNoDemand, or FreeExcess > 0.
5. **RedistCap** = ceil9(rate × months(RedistMax, RedistUnit)).
   - **RedistEligible** = AllowReceive, Target > 0, rate > 0, not ManualOrder, not IsMasked, and FreeExcess = 0.

### Part 3: allocation (new; once per Franchise + PartNumber group, across all branches)

A group is allocated only when some branch has FreeExcess > 0 and some other branch has ConvNeed > 0 or is RedistEligible. Every other group has no suggestions.

**State:** `free[b]` = FreeExcess, `got[b]` = 0 (units suggested into b in this run).

**Conventional:**
1. Receivers = branches with ConvNeed > 0, sorted by:
   - QuantityOnHand ≤ 0 first (the raw value, as the OutOfStock status uses it);
   - then ConvNeed descending;
   - then branch order.
2. For each receiver r, in order, with `want = ConvNeed[r]`: while want > 0 and some sender s ≠ r has free[s] > 0:
   - Pick s = the largest free[s], ties by branch order. Re-pick on every iteration, because free changes.
   - q = min(want, free[s]). Emit a line (Conventional, s → r, q). Then free[s] −= q, want −= q, got[r] += q.

**Redistribution:**
1. Receivers = RedistEligible branches with room = RedistCap − oh − oo − AppInboundQty − got[r] > 0.
2. Sort them by:
   - cover = round9((oh + oo + AppInboundQty + got[r]) / rate), ascending;
   - then branch order.
3. For each receiver r, in order, with `room` as above: go through the senders s ≠ r with free[s] > 0, sorted by free[s] descending (ties by branch order) and re-sorted after each line:
   - q = min(room, free[s]).
   - If q × Cost[s] (rounded to 9 decimals) < the sender's RedistMinValue, skip this sender for this receiver and try the next.
   - Else emit (Redistribution, s → r, q), then free[s] −= q, room −= q.
   - Stop when room = 0 or no sender is left.

**Output:**
- One row per emitted line: Kind, Franchise, PartNumber, FromBranch, ToBranch, Qty, FromCost, ToCost, Value = Qty × ToCost (rounded to cents), Seq (emission order within the group, from 1).
- The key is Kind + Franchise + PartNumber + FromBranch + ToBranch. Each pair is emitted at most once per kind, because a receiver takes from a sender in one go.
- Per part: **SuggestedInQty** (conventional + redistribution into it), **SuggestedOutQty**, **SuggestedConvInQty**.

**Determinism:**
- Every sort has a total order (branch order is unique per branch within a group).
- Every comparison of money or rate is on round9 values; every quantity is an integer.
- The result depends only on the inputs, not on the order of rows or on which branches the user is viewing.

### Part 4: what ticking does (the app only)

- **Ticked, not yet saved:** the receiver's view recomputes steps 9–14 with AppInboundQty + the ticked quantity into that part (a preview). The allocation is **not** re-run when ticks change: unticking a suggestion doesn't offer that stock to anyone else in this session.
- **Saved:** the lines become committed (step 8b). After the lists are re-read, the whole calculation runs again with the new committed lines, so other users and other branches see the reduced excess.
- **The sender's order never changes** (A17).

### One-Time Order with transfers

- **One-Time rec qty** = max(0, ceil(anticipated) − oh − oo − AppInboundQty). The new term is the subtraction of AppInboundQty.
- The One-Time transfer step runs only the conventional half of Part 3:
  - Receivers: the listed one-time parts at the ticked branches, with need = rec qty before the line value limits, leaving out masked and Manual order parts as today.
  - Senders: FreeExcess from Part 2, from the live engine for every branch.
- It is live-only, like the rest of One-Time: there is no Gold version and no parity check.

### Validation (an invalid rule is skipped with a WARN, as order rules are)

**Transfer rules:**
- Priority is required.
- StartMonth / EndMonth: as for order rules.
- ExcessUnit and RedistUnit: blank, Weeks or Months (blank = Months).
- ExcessSupply is required and in range: "ExcessSupply must be 0-260 weeks" / "0-60 months".
- RedistMax: blank = the default 6 months; else "RedistMax must be 0-104 weeks" / "0-24 months". 0 = this branch takes no redistribution.
- RedistMinValue: blank (= 0) or "RedistMinValue must be 0 or more".
- AllowSend / AllowReceive: blank = Yes.

**Order rules:** the new criteria are text and need no validation.

**Part settings:** PhaseInQty is blank or a whole number 1–99999 ("PhaseInQty must be a whole number 1-99999"). An invalid setting is ignored and reported, like an invalid MinOverride today.

## Where it is calculated

**Decision: both.** Gold calculates every morning, and the app recalculates live across all branches with the same algorithm. Gold's result is published and is the parity reference.

| Option | Verdict |
|---|---|
| Gold only (morning) | Rejected. Ben wants ticking to recalculate the order, rules and settings are live in the app, and a transfer saved by one user must reduce what the next user sees the same day. |
| App only | Rejected. That breaks "Gold = reference = engine": nothing would check the app, Home couldn't show counts without loading every branch, and there'd be no reference for Try it. |
| **Both** | **Chosen.** Gold writes `Fact_NonJD_TransferSuggestion` and per-part transfer fields, and the publish ships `transfer_suggestions.json.gz`. The app loads every branch (as 0.3.0's One-Time already does for 19 branches in 10–12 s), runs the same engine and allocation, and checks parity **per group** (below). |

**Parity per group:** a Franchise + PartNumber group must equal Gold line for line when all of these hold:
- the live order rules equal `rules.json.gz`;
- the live transfer rules equal `transfer_rules.json.gz`;
- no live part setting of that franchise + part changed at any branch;
- the committed transfer lines touching that group equal the ones Gold used (listed in the suggestions file).

Otherwise the group is **Changed** (info), not a mismatch, which is the same idea as round 1's per-part check.

**Implementations:**
- **Gold:** Part 1 and Part 2 are Spark columns. Part 3 is `groupBy("Franchise", "PartNumber").applyInPandas(allocate)` over the candidate groups only (a few thousand). `allocate` is a plain Python function with the explicit sorts above. It must follow `dp-notebook-rules.md`: no `first` or `dropDuplicates`, unique ordering.
- **Reference:** Parts 1–2 in DuckDB SQL, and Part 3 as a separately written Python loop over the SQL result, not shared with the notebook. It compares `Fact_NonJD_TransferSuggestion` row by row and the new reorder columns by the existing compare.
- **App:** `src/engine/transfers.ts`, a pure `allocateGroup(rows, rules)` plus `transferInputs(part, result, rule)`. A fixture from Gold, `parity-full.ts` extended to suggestions, and a differential fuzz against the reference, as in C5.

## The data model

**Gold `Fact_NonJD_Reorder`, new columns:**
- PendingQty, SLC, Source, CommodityCode;
- PhaseInQty, PhaseInEnds, PhaseInOn, PhaseInActive, PhaseInEndReason;
- AppInboundQty, AppOutboundQty;
- TransferRuleId, TransferRuleName, ExcessSupply, ExcessUnit, AllowSend, AllowReceive, RedistMax, RedistUnit, RedistMinValue;
- ExcessKeep, FreeExcess, ConvNeed, RedistCap, RedistEligible;
- SuggestedInQty, SuggestedConvInQty, SuggestedOutQty.

RecommendedOrderQty and StockingTarget change meaning (step 8 and 9).

**Gold `Fact_NonJD_TransferSuggestion` (new):**
- Grain: Kind + Franchise + PartNumber + FromBranch + ToBranch.
- Columns: Seq, Qty, FromCost, ToCost, Value, FromOnHand, FromExcessKeep, FromFreeExcess (before allocation), ToOnHand, ToOnOrder, ToTarget, ToNeed (ConvNeed or the room), ToRate, plus FromBin, ToBin and Description for the CSV and the screens, and BuiltAtUtc.
- Written with `.save("Tables/Fact_NonJD_TransferSuggestion")`, then VACUUM, declared in `dp_refresh_dag.json` under `Build_Gold_NonJD_Reorder` (`produces`).

**Gold reads (new):**
- `Silver_PartInformation`: PendingQty, SLC, Source, CommodityCode (already a shortcut).
- `NonJD_TransferRules` and `NonJD_Transfers` (staging tables from the new dataflows; new shortcuts in DP_Presentation).
- Build the staging table before its shortcut: a known gotcha.

**Staging (DP_Staging):**
- `df_NonJD_TransferRules_Raw` → `NonJD_TransferRules`, raw like `NonJD_OrderRules`: numbers as `number` (DOUBLE), blank text as null.
- `df_NonJD_Transfers_Raw` → `NonJD_Transfers`: one row per transfer line joined to its header (TransferId, Status, PlacedAt, FromBranch, ToBranch, LineId, Franchise, PartNumber, Qty, Kind, Created).
  - Cancelled transfers are filtered out in the dataflow. Placed transfers older than 30 days are too, to keep it small. Gold applies the exact committed rule.
- `df_NonJD_PartSettings_Raw` and `df_NonJD_OrderRules_Raw`: the new columns.

**Excluded branches (D6)** never appear: transfer lines to or from them are ignored in Gold, and the app doesn't offer them.

## The lists

On the Report Site, created by Brian and verified through Graph.

**`NonJD_TransferRules` (new):**

| Column | Type | Default / notes |
|---|---|---|
| Title (RuleName) | Text | Required by SharePoint, as for order rules |
| Priority | Number | Required |
| Active | Yes/No | Yes |
| Archived | Yes/No | No |
| Franchise, DealerGroupCode, Branch, SLC, Source, VendorCode, ProductGroup, CommodityCode | Text | Blank = any |
| StartMonth, EndMonth | Number | Season, as for order rules |
| ExcessSupply | Number (1 dp) | 12 |
| ExcessUnit | Choice Weeks / Months | Months |
| AllowSend | Yes/No | Yes |
| AllowReceive | Yes/No | Yes |
| RedistMax | Number (1 dp) | 6 |
| RedistUnit | Choice Weeks / Months | Months |
| RedistMinValue | Number (2 dp) | 25 |
| Notes | Multiple lines | |

Ben starts with **no rows**: the built-in default applies everywhere, and the app shows it as a read-only row. Typical first rules: "Cotton, off season: AllowSend No at branches 2 and 4"; "Branch 92: RedistMax 0".

**`NonJD_OrderRules`, new columns:** SLC, Source, VendorCode, ProductGroup, CommodityCode (Text, blank = any; A11).

**`NonJD_PartSettings`, new columns:**
- PhaseInQty (Number, 0 dp);
- PhaseInEnds (Date only);
- PhaseInOn (Date only; written by the app, display only).

**`NonJD_Transfers` (new; mirrors `NonJD_Orders`):**
- Title `<From>-<To>-<yyyymmdd-hhmm>` (Central);
- FromBranch, ToBranch;
- Status: Choice Draft / Exported / Placed / **Cancelled**. "Placed" is shown as **Entered in Equip**;
- PlacedAt (Date and time);
- ExportCount;
- Parameters JSON: `{dataAsOf, saveId, lineCount, source: "Reorder" | "OneTime" | "Transfers", rulesSource, transferRules: [{id, name, modified}]}`.
- Indexed columns: FromBranch and ToBranch.

**`NonJD_TransferLines` (new; mirrors `NonJD_OrderLines`):**
- Title `from|to|franchise|partNumber`;
- TransferId (Number, indexed);
- Franchise, PartNumber (raw);
- Kind (Choice Conventional / Redistribution);
- SuggestedQty, Qty;
- Cost (sender), LineValue;
- Description, FromBin, ToBin.

Separate lists rather than reusing `NonJD_Orders`, because:
- the transfer columns differ (two branches, a Kind, PlacedAt, Cancelled);
- the dataflow can read a small list instead of every order line ever saved;
- an order's franchise rule doesn't fit a mixed-franchise ticket.

The app's `OrderSaver`, its recovery (saveId, line re-match, never delete), the CSV writer and the order page are reused with a list parameter.

## The contract (v3)

Bump `contractVersion` to **3**. Field meanings change (target includes phase-in; recommendedQty subtracts committed app transfers; the order rule's criteria are wider). The app refuses v2 data and v2 apps refuse v3 data, with the existing messages. Deploy the app first, then publish, as in C10.

**`reorder_<branch>.json.gz`, new fields (camelCase of the Gold columns):**
- pendingQty, slc, source, commodityCode;
- phaseInQty, phaseInEnds, phaseInOn, phaseInActive, phaseInEndReason;
- appInboundQty, appOutboundQty;
- transferRuleName, excessSupply, excessUnit, allowSend, allowReceive, redistMax, redistUnit, redistMinValue;
- excessKeep, freeExcess, convNeed, redistCap, redistEligible;
- suggestedInQty, suggestedConvInQty, suggestedOutQty.

Nullable: slc, source, commodityCode, phaseInQty, phaseInEnds, phaseInOn and phaseInEndReason. Every other new field is never null; `""` is used for blank text.

- **Changed meaning:** `target` (step 8), `recommendedQty` (step 9).
- **`surplusQty`:** unchanged, shown as "Above target".

**New files:**
- `transfer_rules.json.gz`: `{dataAsOf, rules: [...]}`, every `NonJD_TransferRules` column Gold reads, raw, ordered by id. Same rules as `rules.json.gz`.
- `transfer_suggestions.json.gz`: `{dataAsOf, lines: [{kind, franchise, partNumber, fromBranch, toBranch, seq, qty, fromCost, toCost, value, description, fromBin, toBin}], committed: [{transferId, lineId, status, placedAt, fromBranch, toBranch, franchise, partNumber, qty}]}`. All branches in one file. It is about 2–3K lines a day, well under the 4 MB upload limit. `committed` is the set Gold used, for the per-group parity check.

**Unchanged:**
- `history_<branch>`;
- `surplus.json.gz` (the Other branches hint before a branch loads);
- `transfers.json.gz` (Equip's outstanding transfers, display only; A15);
- `rules.json.gz` gains the five new criteria fields.

**`_meta.json`:** `contractVersion 3`, `counts.transferSuggestions`.

**Settings the app reads live:** add PhaseInQty, PhaseInEnds and PhaseInOn. **Transfers the app reads live:** `NonJD_Transfers` + `NonJD_TransferLines` (open and recently placed), for step 8b.

**The publish:**
- `check_columns` covers the new tables and columns. A rule with a non-finite number fails the publish, as for order rules.
- The suggestions file is uploaded every run (it embeds `dataAsOf`), before `_meta.json`.

## The UI

**Recommended Reorder:**
- **Several branches (Q2, A20):**
  - Branch and franchise checkboxes with Select all / Clear, the same component and loader as One-Time 0.3.0. The URL is `?branches=1,92&franchises=AM,KU`; the old `?branch=` still works.
  - One branch looks exactly as today.
  - Several branches give one table with a **Branch** column, grouped by branch with a heading row (parts, value), a Branch filter, and a Totals by branch table.
  - Ticks are per branch + part. **Create order** makes one order per branch + franchise through the existing review and saver, with `branches` / `franchises` in Parameters, as in One-Time.
  - The D12 switch, quick actions and parity banners apply per row.
- **The transfer step** (Q3): a stepper at the top, **1 Transfers → 2 Order**.
  - **Step 1** opens first when any suggestion goes into the selected branches; otherwise it shows "No transfers suggested" and step 2 is open.
  - It starts loading every branch in the background as soon as the page opens, 4 at a time, with progress. Until every branch is loaded it shows the morning's suggestions from the file, marked "as of this morning".
  - Two sections: **Conventional** (ticked; A12) and **Redistribution into these branches** (unticked).
  - Columns: To (when several branches are selected), part, description, need, From, qty (editable 0..suggested), sender on hand and months of supply before → after, receiver months of supply before → after, value, kind.
  - Footer: "N transfers cover M order lines and $X you won't buy". Ticking previews the effect on step 2's quantities straight away (Part 4).
  - **Save transfers** writes the ticked lines as transfer orders, one per From + To. The app then re-reads the transfer lists and recalculates; the transfers show as "Saved" with links.
  - **Continue to order** with unsaved ticks asks "Save the N ticked transfers first?" (**Save and continue** / **Continue without them**). The order only ever counts saved transfers.
  - **Step 2** is today's order screen. A line that a saved transfer reduced shows "Transfer in: N from branch X". A line it covered fully shows status OK with that note, so it drops out of "Reorder needed only".
- **Row detail:** a "Transfers" section with the suggestion (or why there isn't one: "No other branch has stock above 12 months of supply").

**One-Time Order:**
- The wizard becomes Set up → **Transfers** → Review, conventional only (A21).
- The step has the same table, save and question as Reorder.
- Review subtracts saved transfers in. The Transfers step is skipped when nothing is suggested.

**Transfers page (new menu item, `/transfers`):**
- **Suggestions:** every suggestion, all branches (live once loaded, the morning file before), with filters for kind, From, To, franchise and status (suggested / saved). Shannon can work redistribution by sender here. Tick + Save as in step 1. CSV export of the filtered list.
- **Transfer orders:** the `NonJD_Transfers` list, filtered by From / To / status, newest first. Drafts older than 7 days are flagged (A23).
- **Transfer order page:** lines with editable quantities while Draft (as orders), **Export CSV** (`PartNumber,Franchise,Description,Qty,FromBin,ToBin,Cost,LineValue`, with the same CSV rules), **Mark entered in Equip** (needs an export first; sets PlacedAt), and **Cancel** (Draft or Exported only, asks first; nothing is deleted).

**Transfer rules page (new, beside Rules):**
- The same layout and behaviour as Rules: list, state, Archive / Show archived, editor, validation messages from the engine, and the built-in default as a read-only row.
- The pick order is spelled out, with one sentence on roles: "The sending branch's rule decides what counts as excess; the receiving branch's rule decides whether it takes transfers and how much redistribution."
- **Try it** (all branches loaded): before / after counts and dollars of conventional and redistribution lines, the order dollars avoided, and the 20 parts that change most.

**Part page:**
- **Other branches** columns: On hand, Target, **Above target** (renamed, A16), **Excess** (FreeExcess), **Months of supply**, Sold 12 mo, plus the totals row.
- A "Suggested transfers" line for this part.
- **Detail** explanation: new clauses for phase-in and saved transfers in (below).

**Phase-in (Q8):**
- **Settings tab:** "Phase in" with a quantity and an end date (default today + 12 months, Central). Saving writes PhaseInQty, PhaseInEnds and PhaseInOn = today. Clearing it clears all three.
- **Quick action** on Reorder rows and Part Lookup results: **Phase in…**, with the same patch rules as Mask (only the changed columns).
- **Special statuses:** new statuses **Phase-in** (active; shows the quantity and end date) and **Phase-in ended** ("expired 2027-10-27" / "met the demand minimum"), so someone can tidy it. Filter and CSV columns: PhaseInQty, PhaseInEnds.
- **Explanation:**
  - Active: "Phase-in of `<qty>` until `<date>` sets the target (it ends early once the part has `<max(minDemands,1)>` demands)."
  - Ended at its date: "The phase-in ended on `<date>`."
  - Ended at the minimum: "The phase-in ended because the part reached `<minDemands>` demands."
- **Saved transfers in:** "; `<N>` coming by transfer from branch `<X>` (saved `<date>`)".

**Home:**
- Unchanged scope (the default branch).
- New line: "N transfers suggested into Branch X (this morning)", from the file, linking to `/reorder?branches=X` on step 1.
- The order count still shows the order before suggestions are accepted.

**Wording:** "Excess" = the transfer meaning everywhere; "Above target" for the old figure. The wording test checks that "Surplus" never appears.

## Performance

| Item | Estimate | Basis |
|---|---|---|
| Load every branch (reorder + history), first time in a session | 10–12 s sequential today; aim for about 4 s at 4 at a time | 0.3.0 on Fedora, Plan C notes |
| Memory | Roughly 60–100 MB for 200K parts with arrays | One-Time's reduced cache (shared zero rows) holds 19 branches today; the engine needs about 20 more scalar fields a part |
| Engine for all branches | About 1 s (200K × the 70 ms / 17K measured) | Run on load, on a settings, rules or committed-transfers change, never on a tick |
| Allocation | Under 100 ms | A few thousand groups of at most 19 rows |
| Ticking | Recompute only the receiving part (Part 4) | — |

- If memory or time is a problem, the fallback is a Web Worker plus a columnar store (typed arrays). Not planned up front.
- **Gold:** one more join (PartInformation columns), a rules join like today's, and an `applyInPandas` over a few thousand groups. Expect under a minute added to `Build_Gold_NonJD_Reorder`.
- **The new dataflows are tiny.**

## Phasing (suggested order of work)

| Phase | What | Value | Data change |
|---|---|---|---|
| **1. App 0.4.0: multi-branch Recommended Reorder** | Checkboxes, Branch column, one order per branch + franchise, and a shared all-branch engine loader (generalise `oneTimeBranches.ts` into an engine cache with 4-way parallel loading; One-Time and Part Lookup move onto it) | Shannon works several stores at once next week. The loader is the foundation for transfers | None (contract v2) |
| **2. Data + contract v3 + phase-in** | **Brian:** lists and columns. **Then:** dataflows, Gold (Parts 1–3, the suggestion table), reference (incl. the allocation loop), publish v3, app engine (phase-in, criteria, committed transfers, transfer inputs, allocation, parity), Settings tab phase-in, Special statuses, Part page columns, a **read-only Transfers page** (suggestions with CSV), and the "Above target" / "Excess" wording. Deploy the app, then Prod Gold + publish together (as round 1) | Phase-in live. Daily transfer suggestions visible and exportable, so Shannon can key them into Equip by hand straight away | Yes: v3 |
| **3. App 0.6.0: the transfer step** | Live allocation in Reorder, ticking and preview, saving transfer orders, transfer order pages (export, entered in Equip, cancel), Transfer rules page with Try it, Home line. Gold's committed-transfer input is already in phase 2 (it reads an empty list until now) | The full Q3 flow | None beyond v3 |
| **4. App 0.7.0: One-Time transfers + documents** | The One-Time Transfers step; user guide, REORDER-RULES and a TRANSFER-RULES guide for Ben; the "Round 2 changes" doc | Q3 complete | None |

- Phase 2 is the big one and should be its own plan with C-style tasks (lists → dataflows → reference first → Gold → publish → engine → screens → switch-over).
- Send Ben the assumption table before phase 3: the step's look and defaults (A12, A13, A14) are the most likely to change.

## Risks

| Risk | Effect | Mitigation |
|---|---|---|
| **PendingQty means something else** (Decision 3) | Free excess too high or too low | Check in Equip before phase 2. If pending isn't in on hand, drop `− pend` (one term in three places) |
| **Equip timing:** a transfer keyed before the morning's data copy and marked Entered the same day is counted twice for that day (Equip's on order + the app) | A slightly smaller order for one day | Acceptable and conservative. A14 picks the next day's data as the hand-over |
| **Abandoned drafts** hold stock forever | Stock looks unavailable | Flag after 7 days (A23); Cancel is one click |
| **Two users ticking the same excess before either saves** | Both save; the sender is asked for more than its excess | The save re-reads the committed lines first and refuses lines whose sender no longer has the free stock ("Branch 92 now has 3 free, not 5"), adjusting or dropping them before writing |
| **All-branch load on slower PCs** | The step waits 5–15 s | Load in the background from page open; show the morning's suggestions meanwhile; cache per session |
| **Rules complexity for Ben** (two lists, roles) | Wrong rules | No rows needed to start (the default works); Try it shows the effect before saving; a short TRANSFER-RULES guide |
| **Global allocation surprises** ("why did branch 3 get it, not us?") | Trust | The row detail names the rule: "Branch 7 is out of stock and needs 4, so it was filled first" |
| **Three implementations of a sequential algorithm** | Parity bugs | Reference written independently in Python, a Gold fixture, a differential fuzz with planted bugs (as in C5), and per-group parity in the app |
| **Cost differs by branch** | Value shown is off for some lines | Show the receiver's cost (what isn't bought); keep FromCost in the data |
| **Transfer freight and handling cost ignored** (A7) | Small transfers aren't worth a truck slot | The redistribution minimum (A9); Ben can add a conventional minimum later (one rule field) |
| **Contract bump** | Old app breaks on new data | Deploy the app first (C10 procedure); the v2/v3 refusal messages already exist |

## Out of scope for round 2

- Spiking (Q6), EOQ / pre-approved (Q7), JD parts.
- Combined orders shipped to one branch and transferred on.
- Creating Equip transfer tickets from the app (only possible if JD's `EquipTransfers` connection is ever shared).
- Branch-pair costs or routes (A7).
- **Price change history (Brian, 2026-10-27; a later round, with JD parts).** Show a part's price changes in the app, reusing the separate JD price project's data (`Fact_PartPriceChange` / `_Branch`, `Fact_JDNationalPriceChange`). That data covers JD parts only, so it fits when JD parts join the app; for non-JD parts it depends on how their prices change (question N5 for Ben).
