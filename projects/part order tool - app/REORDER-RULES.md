# How the order tool suggests quantities

This page explains how the Non-JD Parts Order Tool decides what to order, and how to change it. It is the
reference version of sections 3 and 4 of the user guide, updated for **round 1** (app version 0.2.0,
2026-10-26: Ben's answers of 2026-10-23).

The settings live in the SharePoint list **NonJD_OrderRules** on the Report Site, and can be changed on the
app's Rules page. Changes apply in the app straight away; the morning refresh picks them up the next day.
Branches **12, 5, 97, 4B and 93C** are left out of the tool.

## The calculation, step by step

For each part at each branch:

1. **Find the rule.** The tool picks one rule from the list (see "Which rule applies" below).
2. **Count demands.** A demand is one transaction (one request for the part), however many units it was for.
   The tool counts them over the rule's **HistoryMonths**, full months only. The current month is left out
   because it isn't finished.
3. **Add up units sold** over the same months (or the number of requests, if the rule's **DemandBasis** says
   so). Returns are netted off, and a total below 0 counts as 0.
4. **Monthly rate** = units sold ÷ HistoryMonths. A part that sold 12 in 12 months has a rate of 1 a month,
   whether those sales came in one month or twelve.
5. **Supply in months.** The rule's **Supply** is in **weeks** or **months** (**SupplyUnit**). Weeks are
   turned into months: weeks × 12 ÷ 52. So 12 weeks = 2.77 months.
6. **Rule target.** If the part had at least **MinDemands** demands, the rule target is monthly rate × months
   of supply, rounded up. Otherwise it is 0: the rule doesn't stock the part.
7. **Minimum.** A minimum set in this tool (**min override**) applies if there is one. If not, **Equip's
   minimum always applies**, even when the part had no demand. A minimum on a part with no demands and no
   units sold in the window is tagged **Min, no demand** (see below).
8. **Target** = the larger of the rule target and the minimum (rounded up).
9. **Order** = target − on hand − on order, never below 0 (on hand and on order count whole units).
   **A target of 0 always means order 0**, even when Equip shows negative stock.
10. **Line value limits** (only if the rule sets them, and only when the part has a cost):
    - If the line (quantity × cost) is worth more than **MaxLineValue**, the quantity is cut back to what
      MaxLineValue buys, rounded down.
    - Then, if the line is worth less than **MinLineValue**, nothing is suggested.
11. **Manual order or masked:** the order is 0 (see "Part settings" below).

## Worked examples (Dev data of 2026-10-26; the 12 months are October 2025 to September 2026)

Rule "Default": 12 months, 3 demands, 12 weeks of supply (2.77 months), units sold.

| Part | Demands | Sold | Rate a month | Rule target | Minimum | Target | On hand | Order |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Branch 1, 124184, Mobil 1 0W20 motor oil | 22 | 170 | 14.17 | 14.17 × 2.77 = 39.2 → 40 | none | 40 | 1 | **39** |
| Branch 11, 814-157C, 2" × 13" press wheel assembly | 14 | 57 | 4.75 | 4.75 × 2.77 = 13.2 → 14 | none | 14 | 3 | **11** |
| Branch 91, 1426W, 26" wide neck row crop sweep | 3 | 39 | 3.25 | 3.25 × 2.77 = 9 | Equip 12 | 12 | 2 | **10** |
| Branch 1, 1426W, the same sweep | 2 | 30 | 2.5 | 0 (2 demands, the rule needs 3) | none | 0 | 0 | **0**, Not stocked |
| Branch 1, 408DU, 4x8 cross hydraulic cylinder | 0 | 0 | 0 | 0 | Equip 2 | 2 | 0 | **2**, Min, no demand |

None of these parts had anything on order. With 12 months of history and supply in weeks there is a shortcut:
units sold in the year × weeks ÷ 52. For 124184: 170 × 12 ÷ 52 = 39.2, rounded up to 40.

- **Supply in months.** If the rule held **3 months** of supply, 124184 would get 14.17 × 3 = 42.5 → a target
  of 43 and an order of 43 − 1 = 42.
- **Line value limits.** 124184 costs $11.90, so the order of 39 is worth $464.10. With MaxLineValue $300 it is
  cut back to $300 ÷ $11.90 = 25.2 → **25** ($297.50; status Reorder with a "Max value" badge). With
  MinLineValue $50 and 37 on hand, the line would be 3 units = $35.70, under $50, so nothing is suggested
  (status **Below min value**). The cap is applied first, then the minimum.
- **Min override.** Branch 1, part 09-1785273 (pad for flex couplers) sold 4 in 1 demand, so the rule alone
  doesn't stock it. A min override of 5 set in the tool makes the target 5 and the order 5.
- **Demands vs units.** Branch 1's 1426W sold 30 units, but in only 2 transactions, so it isn't stocked.
  Demands count how often a part is asked for, not how many.

## Status

Each part gets the first status in this list that fits it (the app's labels):

| Status | Meaning |
|---|---|
| Manual order | Manual order is set on the part; it is never suggested until that is turned off |
| Masked | The part is masked and the mask hasn't ended; no order |
| No recent activity | The target is 0 and the part had no demands and no units sold in the window |
| Not stocked | Some activity, but the target came out 0 (usually fewer demands than MinDemands) and no minimum |
| Below min value | An order was due, but the line is worth less than MinLineValue; nothing is suggested |
| Above max value | An order was due, but one unit costs more than MaxLineValue; nothing is suggested |
| Out of stock | An order is suggested and there is none on hand |
| Reorder | An order is suggested; some stock is on hand |
| Stocked | Stocked, with enough on hand and on order; nothing to order |

**Excess** = on hand above that branch's target (a branch with 10 on hand and a target of 4 has an excess of
6). It shows under "Other branches" on the Part page and in the Reorder row detail.

## The settings

| Setting | What it does | Turn it up to… | Turn it down to… |
|---|---|---|---|
| **HistoryMonths** (1-59) | How far back demand is measured | Smooth out spikes; give slow parts more history | React faster to recent changes |
| **MinDemands** (0-9999) | Demands (transactions) in the window needed before the rule stocks a part | Stock fewer, steadier parts | Stock more parts, including occasional sellers |
| **Supply** with **SupplyUnit** (0-104 weeks or 0-24 months) | How much stock to hold, in weeks or months of supply. The list column is still named WeeksOfCover; a blank unit means Weeks | Hold more (long vendor lead times, busy season) | Hold less (quick resupply, off season) |
| **MinLineValue** ($, optional) | A line worth less than this isn't suggested | Fewer small lines | More small lines |
| **MaxLineValue** ($, optional) | A line is cut back to stay at or under this | Bigger lines allowed | Lines cut back sooner |
| **DemandBasis** | `UnitsSold` counts quantities; `Requests` counts how often it was asked for | Use Requests when a few big sales would overstate demand | |

MinLineValue can't be more than MaxLineValue. The old **MinActiveMonths** column is still in the list but is
no longer read.

## Which rule applies

Each row in the list is a rule. A rule can be narrowed to a **Franchise**, a **DealerGroupCode** and/or a
**Branch**; blank means "any". It can be limited to a season with **StartMonth** and **EndMonth** (1-12; 11 to 2
means November to February). Only rules with **Active** = Yes and **Archived** = No are used.

When several rules fit a part, the one with the **highest Priority** wins. On a tie, the more specific rule wins
(more of Franchise / DealerGroupCode / Branch filled in), then the lowest Id. If nothing fits, a built-in default
applies: 12 months, 3 demands, 12 weeks of supply, units sold, no line value limits.

**Example: cotton.** The list has two inactive example rules for dealer group code COTTON: "Cotton - in season"
(June-October, 10 weeks of supply, 2 demands) and "Cotton - off season" (November-May, 3 weeks of supply, 3
demands). Both have Priority 10, so they beat Default for cotton parts. Switch Active to Yes on both to use them.

Dealer group codes are set per branch in Equip, so a part coded COTTON at one branch may be coded differently at
another. 37% of active non-JD parts have no dealer group code; those use franchise or default rules.

## Part settings (list NonJD_PartSettings, the Part page's Settings tab)

- **Min override:** the part's own minimum; it replaces Equip's. A min override of 0 switches off an Equip
  minimum you don't trust.
- **Manual order:** the part is never suggested until someone turns it off.
- **Masked:** no order. The mask ends at the first of: the end of its expiry date (if one is set), or the
  part's first demand after the day it was masked. Example: masked on October 5 with no expiry, asked for on
  October 9: from the next morning's refresh the mask has ended and the part is suggested again if it needs
  ordering. (A mask saved before round 1 has no "masked on" date and ends only at its expiry.)
- Masks and Manual order can be set from Recommended Reorder (row detail and order review) as well as the Part
  page. The **Special statuses** page lists every part that is masked, on Manual order, has a min override, or
  has a mask that has ended.
- Masked and Manual order parts are left off One-Time Orders.

## Rules for editing the list

- Change values freely; don't rename or delete the columns themselves (the daily feed reads them by name).
- To retire a rule, **archive** it (Rules page, or Archived = Yes) instead of deleting it. Archived rules are
  never used and are hidden unless "Show archived" is on.
- A rule with a missing or out-of-range setting is skipped, and the morning refresh email names it.
- Give each rule a name (Title). It shows next to every suggestion in the tool.
- Changes apply in the app straight away and in the morning refresh the next day.

## Things we already know to look at

- **Old Equip minimums.** Since round 1 an Equip minimum always applies, as Ben asked, even on parts with no
  demand. Some are old or mistyped (one part has a minimum of 50,241, another has its price typed into the
  minimum). On 2026-10-26 they add 3,121 lines worth about $4.27M across all branches, $3.8M of it from six
  parts. In the app these lines carry a **Min, no demand** tag and are hidden unless "Show minimums with no
  demand" is on. The **Cleanup** page lists them to fix in Equip, or set a min override of 0.
- **Units sold with no demand.** 973 parts sold units in the window with no demand recorded. They count as
  activity (not "No recent activity") but not as demands, so the rule doesn't stock them. Question open with
  Ben: why Equip records such sales.
- **Seasonal demand.** A 12-month average flattens a seasonal spike. Spiking is planned for when John Deere
  parts join; seasonal rules (like the cotton pair) work today.
