# How the order tool suggests quantities

This page explains how the Non-JD Parts Order Tool decides what to order, and how to change it. It is the
reference version of sections 3 to 5 of the user guide, updated for **round 2** (app version 0.5.0,
2026-10-28: phase-in, transfer suggestions and the new rule criteria, with Ben's answers of 2026-10-27).
Round 1 (0.2.0, 2026-10-26) followed Ben's answers of 2026-10-23.

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
   - **Phase-in** (round 2). A phase-in set on the part's Settings tab is **active** while all of these
     hold: it has a quantity; its end date hasn't passed (it still applies on its last day; no end date means
     no end); and the part has fewer demands in the window than its rule needs (at least 1). Once the part
     reaches the rule's demands, the rule stocks it on its own and the phase-in has done its job. It is worked
     out fresh every morning, so if demands drop back below the rule's number before the end date, the
     phase-in applies again.
8. **Target** = the largest of the rule target, the minimum (rounded up) and, while it is active, the phase-in
   quantity.
   - **Transfers saved in this app** (round 2) are counted next: a saved transfer into this branch is stock on
     its way (**transfers in**), and one out of this branch is stock already promised (**transfers out**,
     used for excess below). A saved transfer counts while it is a Draft or Exported, and once it is marked
     entered in Equip until the next morning's data, which then carries it in Equip's own on order. A
     cancelled transfer never counts. Saving transfers comes in the next version, so in 0.5.0 these are 0.
9. **Order** = target − on hand − on order − transfers in, never below 0 (on hand and on order count whole
   units). **A target of 0 always means order 0**, even when Equip shows negative stock. Transfers already
   keyed in Equip are in Equip's on order already, so they aren't subtracted a second time.
10. **Line value limits** (only if the rule sets them, and only when the part has a cost):
    - If the line (quantity × cost) is worth more than **MaxLineValue**, the quantity is cut back to what
      MaxLineValue buys, rounded down.
    - Then, if the line is worth less than **MinLineValue**, nothing is suggested.
11. **Manual order or masked:** the order is 0 (see "Part settings" below). They win over a phase-in.

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

Each row in the list is a rule. A rule can be narrowed by any of these **criteria**; blank means "any":
**Franchise**, **DealerGroupCode**, **Branch**, and since round 2 **SLC**, **Source**, **VendorCode**,
**ProductGroup** and **CommodityCode**. They compare ignoring case and spaces at either end. Each branch's own
part record decides (a part can have a different dealer group or SLC at different branches). VendorCode is the
whole number without leading zeros ("1234", not "01234"); 0 means parts with no vendor code. CommodityCode is
empty for most non-JD parts today. It can be limited to a season with **StartMonth** and **EndMonth** (1-12; 11 to 2
means November to February). Only rules with **Active** = Yes and **Archived** = No are used.

When several rules fit a part, the one with the **highest Priority** wins. On a tie, the more specific rule wins
(more of the eight criteria filled in), then the lowest Id. If nothing fits, a built-in default
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
- **Phase-in** (round 2): a quantity and an end date (default 12 months from the day it is set; blank means no
  end). It stocks a new part before it has the demands its rule needs: the target is at least the phase-in
  quantity while it is active (step 7). The end date can't be in the past. A part with an active phase-in can be
  filled by transfer even when it has no demand yet.
- Masks, Manual order and phase-in can be set from Recommended Reorder (row detail, **Part actions**) as well as
  the Part page. The **Special statuses** page lists every part that is masked, on Manual order, has a min
  override, has a phase-in (or one that has ended), or has a mask that has ended.
- Masked and Manual order parts are left off One-Time Orders. One-Time Orders ignore phase-in: they use their own
  calculation.

## Rules for editing the list

- Change values freely; don't rename or delete the columns themselves (the daily feed reads them by name).
- To retire a rule, **archive** it (Rules page, or Archived = Yes) instead of deleting it. Archived rules are
  never used and are hidden unless "Show archived" is on.
- A rule with a missing or out-of-range setting is skipped, and the morning refresh email names it.
- Give each rule a name (Title). It shows next to every suggestion in the tool.
- Changes apply in the app straight away and in the morning refresh the next day.

## Above target and Excess (round 2)

Two different figures, both on the Part page's **Other branches** table:

- **Above target** = on hand above that branch's own target (round 1 called this "Excess"). It says a branch has
  more than it needs, nothing more.
- **Excess** = stock that branch could send: the free stock above what it keeps. It keeps the **larger** of its
  target and its **excess supply** (default 12 months of supply). Free stock is on hand minus stock already
  committed to open tickets in Equip, minus transfers out saved in this app. This is John Deere's meaning of
  excess, as Ben asked.
- **Months of supply** = on hand ÷ the part's monthly rate (from its order rule). A part with no sales shows "—".

Example: a branch with 40 on hand, a target of 2, selling 1 a month, and 2 already promised by a saved transfer.
Above target is 40 − 2 = **38**. It keeps the larger of 2 and 12 months × 1 = 12, so its excess is 40 − 2 − 12 =
**26** (26 months of supply).

## Transfer suggestions (round 2)

Every morning, and live on the Transfers page, the tool suggests moving stock between branches before buying.
Each part (franchise + part number) is worked out on its own across all branches.

1. **Excess at each branch** as above. A part with no sales has everything above its target as excess; its
   target still protects an Equip minimum, a min override or a phase-in. A branch whose transfer rule says
   **AllowSend = No** has no excess to send.
2. **Conventional transfers: instead of buying.** A branch can receive when its line would be ordered (target
   above 0, not masked, not Manual order), its transfer rule allows receiving, and it has no excess of the part
   itself. Its **need** is target − on hand − on order − transfers in, before the line value limits. A
   **Min, no demand** line never pulls a transfer, unless the part has an active phase-in.
3. **Who goes first.** The branch with the **lowest months of supply receives first** (counting on hand, on
   order and transfers in); ties go to the largest need, then branch order. It takes from the branch with the
   **greatest months of supply** first (ties: the most excess, then branch order), choosing again after every
   line, until its need is filled or no excess is left. A branch with no sales counts as the fullest sender.
4. **Redistribution: extra stock to a branch that sells the part.** Once the conventional transfers are done,
   leftover excess can go to a branch that already stocks the part (target above 0), sells it, isn't masked or
   on Manual order, has no excess of its own and allows receiving. It is filled up to its **receive maximum**
   (default 6 months of supply, never above what it would itself keep), counting on hand, on order and
   transfers in, in the same order. A sender's rule can set a **minimum line value** for redistribution; the
   default is $0 (no minimum).
5. **Value** = quantity × the receiving branch's cost.
6. **The sending branch's own order never changes**: it always keeps at least its target.
7. **No branch-pair rules.** All branches are treated alike; Ben prefers to handle special cases by hand.

In 0.5.0 the suggestions are shown (Home, Recommended Reorder and the Transfers page), and are keyed into Equip by
hand. **The suggested order doesn't drop yet when a transfer is suggested.** Ticking transfers, saving them and
seeing the order recalculated come in the next version. Unticking a suggestion will put the order back to the
full quantity.

## Transfer rules (list NonJD_TransferRules)

Transfer rules work like order rules: the same criteria, priority, season, Active and Archived, and the same way
of picking one rule per part per branch. **The sending branch's rule** decides its excess, whether it may send,
and the redistribution minimum line value. **The receiving branch's rule** decides whether it may receive and its
receive maximum. When no rule fits, the built-in default applies: excess above **12 months**, sending and
receiving allowed, receive up to **6 months**, no minimum.

| Column | What it does | Blank means |
|---|---|---|
| **ExcessSupply** with **ExcessUnit** | What a branch keeps before stock counts as excess: 0-260 weeks or 0-60 months of supply | Required (unit blank = Months) |
| **AllowSend** | Yes / No: may this branch send the part | Yes |
| **AllowReceive** | Yes / No: may this branch receive it | Yes |
| **RedistMax** with **RedistUnit** | The receive maximum for redistribution: 0-104 weeks or 0-24 months of supply. 0 = this branch takes no redistribution | 6 months |
| **RedistMinValue** ($) | Redistribution lines worth less than this aren't suggested | 0 (no minimum) |

The list has no rows yet, so the built-in default applies everywhere. There is no page for transfer rules in the
app yet (planned with saving transfers): Brian or Ben edit the SharePoint list directly. The Transfers page shows
the rules in use under **Transfer rules in use**. A rule with a missing or out-of-range setting is **skipped**:
it shows there as Skipped with the reason, it isn't used, and the morning refresh email names it.

## Things we already know to look at

- **Old Equip minimums.** Since round 1 an Equip minimum always applies, as Ben asked, even on parts with no
  demand. Some are old or mistyped (one part has a minimum of 50,241, another has its price typed into the
  minimum). On 2026-10-26 they added 3,121 lines worth about $4.27M across all branches, $3.8M of it from six
  parts. Barry has since fixed those six in Equip, which brought the total down to about $463K. In the app these lines carry a **Min, no demand** tag and are hidden unless "Show minimums with no
  demand" is on. The **Cleanup** page lists them to fix in Equip, or set a min override of 0.
- **Units sold with no demand.** 973 parts sold units in the window with no demand recorded. They count as
  activity (not "No recent activity") but not as demands, so the rule doesn't stock them. Question open with
  Ben: why Equip records such sales.
- **Seasonal demand.** A 12-month average flattens a seasonal spike. Spiking is planned for when John Deere
  parts join; seasonal rules (like the cotton pair) work today.
