# Round 1 changes: what they do to the suggested order

*Dev data as of October 23, 2026* (Dev refresh of 2026-10-23 15:41 UTC; latest part request in the data 2026-10-23). Demand window: Oct 2025 to Sep 2026, the 12 full months before the run. Produced by `tools/dp-migration/nonjd_round1_impact.py` (Plan C, Task C1).

## What this shows

Ben, this is the suggested order for every branch, recalculated on the same day's data with your round 1 answers switched on one at a time. Each step keeps the changes before it, so the last row is the tool as it will work after round 1 (with the Default rule only: no cotton rule, no line value limits, no masks beyond the ones already set). **Lines** are parts with a suggested order, **$** is suggested quantity x cost, and **Stocked** is how many parts have a target above 0.

1. **Today's logic.** What the tool suggests today: Default rule, 12 months of history, sales in at least 3 different months, 6 weeks of supply; an Equip minimum only counts if the part sold in the last 12 months.
2. **Leave out branches 12, 5, 97, 4B, 93C.** Same, without the five branches you asked to leave off.
3. **3 demands instead of 3 active months.** A part is stocked when it had at least 3 demands (transactions) in the 12 months, however many months they fell in, instead of sales in 3 different months.
4. **Target 0 means order 0.** A part the rules don't stock is never ordered, even when on hand or on order shows negative.
5. **Equip minimum always applies.** The minimum in Equip sets the floor even when the part had no demand in the 12 months.
6. **Default at 12 weeks of supply.** The Default rule holds 12 weeks of supply instead of 6. This is the round 1 Default.

## All branches

| Step | Lines | $ | Stocked |
|---|---:|---:|---:|
| 1. Today's logic | 1,775 | $491,167 | 5,394 |
| 2. Leave out branches 12, 5, 97, 4B, 93C | 1,775 (no change) | $491,167 (no change) | 5,394 (no change) |
| 3. 3 demands instead of 3 active months | 2,336 (+561) | $604,904 (+$113,737) | 6,815 (+1,421) |
| 4. Target 0 means order 0 | 2,171 (-165) | $587,923 (-$16,981) | 6,815 (no change) |
| 5. Equip minimum always applies | 5,309 (+3,138) | $4,860,660 (+$4,272,737) | 10,422 (+3,607) |
| 6. Default at 12 weeks of supply | 5,775 (+466) | $5,355,625 (+$494,965) | 10,422 (no change) |

Step 1 includes the five branches that step 2 leaves out. They hold 7,710 in-scope parts but none is stocked (0) or suggested (0) today, so step 2 changes nothing now; it keeps the 15 Equip minimums there on parts with no demand out of step 5.

## Branches 1, 8 and 92

| Step | Branch 1 lines | Branch 1 $ | Branch 8 lines | Branch 8 $ | Branch 92 lines | Branch 92 $ |
|---|---:|---:|---:|---:|---:|---:|
| 1. Today's logic | 93 | $32,838 | 209 | $75,224 | 86 | $73,836 |
| 2. Leave out branches 12, 5, 97, 4B, 93C | 93 | $32,838 | 209 | $75,224 | 86 | $73,836 |
| 3. 3 demands instead of 3 active months | 145 | $38,759 | 224 | $78,539 | 109 | $109,335 |
| 4. Target 0 means order 0 | 143 | $38,062 | 176 | $71,522 | 107 | $108,729 |
| 5. Equip minimum always applies | 164 | $39,746 | 660 | $950,523 | 221 | $132,598 |
| 6. Default at 12 weeks of supply | 229 | $88,768 | 717 | $1,026,333 | 235 | $233,233 |

Stocked parts: Branch 1 419 at step 1, 574 at step 6; Branch 8 573 at step 1, 1,178 at step 6; Branch 92 168 at step 1, 327 at step 6.

## Equip minimums on parts with no demand

From step 5 the Equip minimum counts even when the part had no demand in the 12 months. These are the parts the Cleanup list will show (minimum set, no demand, no Min override in the app). What they add to the order:

| Step | Lines | $ |
|---|---:|---:|
| 5. Equip minimum always applies | 3,126 | $4,268,922 |
| 6. Default at 12 weeks of supply | 3,126 | $4,268,922 |

By branch at step 6 (largest first): 95 135 lines / $2,142,627; 8 484 lines / $878,861; 4 26 lines / $710,402; 16 9 lines / $136,316; 3 14 lines / $118,222; 91 645 lines / $117,292; 6 1,003 lines / $70,158; 93 58 lines / $27,368; others smaller.

The three largest lines below are $3,521,090 of the $4,268,922 (82%); without them these minimums add $747,832. Several of the largest minimums look like data-entry errors in Equip (a minimum far above anything the branch sells, or the price typed into the minimum field), which is what Cleanup is for. A Min override of 0 in the app, or fixing the minimum in Equip, takes a line off.

Top 10 of these lines by $ at step 6:

| Branch | Franchise | Part | Description | Equip min | On hand | On order | Order | Cost | $ |
|---|---|---|---|---:|---:|---:|---:|---:|---:|
| 95 | M | 990900100420702 | #2-2" FILL CAP | 50241 | 0 | 0 | 50241 | $41.82 | $2,101,079 |
| 8 | MR | 00767891 | COUPLING FLEX | 1105 | 0 | 0 | 1105 | $738.19 | $815,700 |
| 4 | M | WR-AR82561 | ISO SELECTIVE CONTROL VALVE COMPLETE REM | 777 | 0 | 0 | 777 | $777.75 | $604,312 |
| 3 | P | 100025 | ROTOR, LEFT 30'/32 HEADER PICKUP | 78 | 0 | 0 | 78 | $1,499.90 | $116,992 |
| 16 | SS | CTV-0505B | BLACK HOSE | 336 | 0 | 0 | 336 | $336.00 | $112,896 |
| 4 | M | VAWISO32 | ISO 32 ANTI WARE FOR 9800 KP | 726 | 0 | 0 | 726 | $72.60 | $52,708 |
| 6 | KB | 145019 | MODULE RIM W/3/4" STUD HOLE | 65 | 0 | 0 | 65 | $330.57 | $21,487 |
| 6 | M | 431150 | LOADING ARM | 42 | 0 | 0 | 42 | $340.42 | $14,298 |
| 4 | M | 10158 | REAR FAN BEARING | 45 | 0 | 0 | 45 | $315.45 | $14,195 |
| 4 | M | CR40E-50 | BROWN CAB KIT | 109 | 0 | 0 | 109 | $121.00 | $13,189 |

## Checks

- Step 1 against the current Dev Gold table, part by part: 0 parts only in Gold, 0 only in step 1, 0 with a different target, order or cost. Gold totals: 1,775 lines, $491,167, 5,394 stocked; Branch 1 93 lines / $32,838.
- Step 6 against the round 1 reference rules (`nonjd_reorder_check.py`) with one Default rule of 12 months / 3 demands / 12 weeks: identical totals.
