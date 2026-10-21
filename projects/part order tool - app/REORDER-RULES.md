# How the order tool suggests quantities

This page explains how the Non-JD Parts Order Tool decides what to order, and how to change it. The settings live in the SharePoint list **NonJD_OrderRules** on the Report Site. Changes take effect the next morning.

## The calculation, step by step

For each part at each branch:

1. **Find the rule.** The tool picks one rule from the list (see "Which rule applies" below).
2. **Measure demand.** It adds up the units sold (or the number of requests, if the rule says so) over the rule's **HistoryMonths**, counting full months only. The current month is left out because it isn't finished.
3. **Monthly rate.** Total demand ÷ HistoryMonths. A part that sold 12 in 12 months has a rate of 1 a month, whether those sales came in one month or twelve.
4. **Is it worth stocking?** If fewer than **MinActiveMonths** months had any demand, the rule doesn't stock the part. It's treated as a special-order part.
5. **Stocking target.** Monthly rate × **WeeksOfCover**, converted from weeks to months and rounded up.
6. **Minimum.** A minimum set in this tool always applies: the target is never below it. Equip's minimum quantity applies only if the part had some demand in the rule's history window. When a part has an Equip minimum but no demand, the minimum is ignored and the part is flagged ("Equip minimum ignored"), so those minimums can be reviewed and cleaned up in Equip.
7. **Suggested order.** Target − on hand − on order. Never below 0.

## Three real examples (branch data from 2026-10-20, rule "Default": 12 months, 3 active months, 6 weeks)

| Part | Sold in 12 months | Months with sales | Rate a month | 6 weeks of cover | Target | On hand | Order |
|---|---|---|---|---|---|---|---|
| Branch 1, 124184, Mobil 1 0W20 motor oil | 170 | 8 | 14.2 | 19.6 | 20 | 1 | 19 |
| Branch 11, 814-157C, 2" × 13" press wheel assembly | 57 | 8 | 4.75 | 6.6 | 7 | 3 | 4 |
| Branch 8, 1426W, 26" wide neck row crop sweep | 68 | 5 | 5.7 | 7.8 | 8 | 2 | 6 |

The minimum override from the tool also works: branch 1, part 09-1785273 (pad for flex couplers) sold 4 in one month only, so the rule alone wouldn't stock it. A minimum of 5 set in the tool makes the target 5 and the order 5.

## The settings

| Setting | What it does | Turn it up to… | Turn it down to… |
|---|---|---|---|
| **HistoryMonths** (1-59) | How far back demand is measured | Smooth out spikes; give slow parts more history | React faster to recent changes |
| **MinActiveMonths** (0-59) | How many months need demand before a part is stocked | Stock fewer, steadier parts | Stock more parts, including occasional sellers |
| **WeeksOfCover** (0-104) | How much stock to hold | Hold more (long vendor lead times, busy season) | Hold less (quick resupply, off season) |
| **DemandBasis** | `UnitsSold` counts quantities; `Requests` counts how often it was asked for | Use Requests when a few big sales would overstate demand | |

## Which rule applies

Each row in the list is a rule. A rule can be narrowed to a **Franchise**, a **DealerGroupCode** and/or a **Branch**; blank means "any". It can be limited to a season with **StartMonth** and **EndMonth** (1-12; 11 to 2 means November to February). Only rules with **Active** = Yes are used.

When several rules fit a part, the one with the **highest Priority** wins. On a tie, the more specific rule wins (more of Franchise / DealerGroupCode / Branch filled in). If nothing fits, a built-in default applies: 12 months, 3 active months, 6 weeks, units sold.

**Example: cotton.** The list has two inactive example rules for dealer group code COTTON: "Cotton - in season" (June-October, 10 weeks of cover, 2 active months) and "Cotton - off season" (November-May, 3 weeks). Both have Priority 10, so they beat Default for cotton parts. Switch Active to Yes on both to use them.

Dealer group codes are set per branch in Equip, so a part coded COTTON at one branch may be coded differently at another. 37% of active non-JD parts have no dealer group code; those use franchise or default rules.

## Rules for editing the list

- Change values freely; don't rename or delete the columns themselves (the daily feed reads them by name).
- A rule with a missing or out-of-range setting is skipped, and the morning refresh email names it.
- Give each rule a name (Title). It shows next to every suggestion in the tool.
- Changes apply after the next morning refresh.

## Things we already know to look at

- **Old Equip minimums.** Some parts with no sales for years carry large Equip minimums (one part has a minimum of 50,241). Before 2026-10-21 they made up most of the suggested order value. Now Equip's minimum is used only when the part has had demand, and the rest are flagged as "Equip minimum ignored". That flagged list is worth cleaning up in Equip; if you want a part stocked anyway, set a minimum for it in the tool.
- **Negative on hand.** A part with negative on hand gets an order that brings it back to 0, even if it isn't otherwise stocked.
- **Seasonal demand.** A 12-month average flattens a seasonal spike. A later option is to measure demand from the same months last year.
