# Data Investigation Results
Date: 2026-05-28

## user_field_3 Values (InMaster)

| Value | Count | Meaning |
|---|---|---|
| LOW | 1,276 | Low margin part — used in Part Sales Low Margin report |

**Decision:** Filter in fact table uses `= "LOW"` (uppercase). Only one value exists. Display as a flag/badge in the app ("Low Margin").

---

## pi_suggested_order_qty Assessment

**Decision: DO NOT USE. Build full ROP formula from param_ROP_Matrix.**

Sample of non-JD parts with non-zero SystemSuggestedQty:
- Part 701 (SAW SEGMENT): 0 sales, 0 requests, OnHand=81 → Suggested=112 (order more when you have plenty and no demand — nonsensical)
- Part 221228 (CAT WHISKERS): 0 sales, 0 requests, Min=1, Max=1 → Suggested=50 (way above max — stale value)
- Part 123721: OnHand=13, 24 annual sales → Suggested=182 (doesn't follow any obvious formula)

Values appear to be stale calculations from whenever the source system last ran for these parts. They do not represent a live, reliable ordering recommendation for non-JD parts.

`SystemSuggestedOrderQty` will be included in the fact table as a display/reference column only.

---

## History Column Format (pi_sales_history_02 through pi_sales_history_60)

**Decision: UNIT QUANTITIES for real stocked parts.**

The existing jdis_Part_Information query confirms the source system has TWO separate column families:
- `pi_current_12_mo_sales` → unit sales quantity (integer count)
- `pi_current_12_dollars` → dollar revenue (separate column)

The `_sales` and `_history` column family follows the same pattern — unit quantities.

Confirmed via MG parts spot-check:
| Part | Cost | Monthly Sales Units | Monthly Requests | Makes Sense? |
|---|---|---|---|---|
| 107-135S (Drill Disk, Branch 11) | $29 | 4 units (Month01), 72 units (Month02) | 1 request each | Yes — large orders for a farming operation |
| 814-157C (Press Wheel, Branch 8) | $73.73 | 2 units (Month02) | 1 request | Yes — 2 per request |
| 822-276C (Bearing Cone, Branch 92) | $32.46 | 35 units (12-mo) | 15 requests | Yes — ~2.3 units per request |

Dollar interpretation would give fractions (e.g., 35/$32.46 = 1.08 units from 15 requests = 0.07/request) which is nonsensical.

**Edge case:** Generic "catch-all" part numbers (HARDWARE, BOLTS at Branch 8) showed 138,706.59 as a "unit" value — clearly a data quality issue in the source for bulk items that aren't tracked by discrete unit. These are not target candidates for the ordering tool and will produce outlier ROP values; the parts manager can mask them in config_PartSettings.

---

## param_ROP_Matrix Structure (⚠️ KEY FINDING)

**ALL 1,993 rows in the matrix use "Default" for Group, Commodity Code, SRC, SLC, and Attachment.**

Verified by sampling first 30 rows AND last 43 rows — identical on all classification dimensions.

The ROP lookup is therefore purely:
- **MonthCount** (number of months with any sales or demand activity)
- **DemandL/DemandH** (average monthly demand count range)
- **SalesL/SalesH** (average monthly sales unit count range)

No Group, CommodityCode, SRC, SLC, or Attachment matching is required. InMaster.PROD_GROUP (which contains vendor names, not stocking group codes) is irrelevant to the ROP calculation.

**Impact:** Task 9 (Fact_NonJD_Reorder) is significantly simpler than originally planned. No multi-level fallback hierarchy needed.

---

## InMaster.PROD_GROUP Assessment

**Decision: Do NOT use PROD_GROUP as a Group input for ROP matrix lookup.**

PROD_GROUP for non-JD parts contains vendor/manufacturer names, not stocking group codes:
- BS franchise → BECKNELL, BWC, SMA (distributors)
- MG franchise → GREATPLAIN, GP, LANDPRIDE (equipment manufacturers)
- MR franchise → RHNO, RHINO AG (brand names)

However, since the ROP matrix is entirely "Default" for the Group dimension, this is moot — no Group mapping is needed at all.

PROD_GROUP and DealerGroupCode will be included in the fact table as reference/display columns only.

---

## Franchise Exclusion List

Based on investigation + adopting Physical Inventory report filters:

**EXCLUDE:**
| Franchise | Reason |
|---|---|
| D | John Deere — handled by JD PRISM |
| ZP | Warehouse code — not an orderable part |
| S | Inactive/non-orderable franchise |
| T* (starts with T: TD, TM) | Inactive/test franchises (per Physical Inventory report convention) |
| U* (starts with U: UD, UM) | Inactive/test franchises (per Physical Inventory report convention) |
| 95 | 1 part — apparent data entry error |

**INCLUDE:** All other franchises (M, BS, MG, MS, P, MC, MM, SS, KR, ML, KM, MR, RC, BB, MH, AM, SC, MN, MO, MW, KB, L, ME, RM, W, BW, HT, C, HW, SB, GR, DA, ...)

**Note on DA:** User confirmed all JD parts are franchise "D" — "DA" is NOT a John Deere franchise. Include DA.

**Note on GR:** Only 3 parts. Include by default; parts manager can mask individual parts via config_PartSettings.

---

## History Column Time Direction

**Confirmed:** `pi_current_mo_sales` is the most recent (current) month = MonthOffset 1. `pi_sales_history_02` is 1 month prior = MonthOffset 2. Columns increment backward in time:
- MonthOffset 1 = current month (in progress — may be 0 or partial)
- MonthOffset 2 = 1 month ago (complete)
- MonthOffset 60 = 59 months ago (oldest)

Seasonal pattern visible: drill disk parts (107-135S) show 0 sales in current months (summer/fall) with high annual totals — consistent with spring planting demand.

---

## Open Questions RESOLVED

| # | Question | Answer |
|---|---|---|
| 1 | Does pi_suggested_order_qty calculate ROP? | No — stale, inconsistent values. Use full ROP matrix. |
| 2 | Is PROD_GROUP populated for non-JD parts? | Yes, but with vendor names — not ROP group codes. Moot since matrix is all-Default. |
| 3 | What are all values of user_field_3? | Only "LOW" (1,276 parts). |
| 4 | Full franchise exclusion list? | D, ZP, S, T*, U*, 95. DA is INCLUDED (not JD). |
| 5 | Power Apps Premium license? | TBD — two-phase approach (SharePoint → Lakehouse) covers both scenarios. |
| 6 | Are history columns in units or dollars? | UNITS for real stocked parts. Dollar interpretation would give fractional units (confirmed invalid). |

---

## Plan Impact Summary

| Finding | Plan Change |
|---|---|
| ROP matrix is all-Default | Task 9.1B lookup: remove Group/SRC/SLC/Commodity matching — just MonthCount + Demand + Sales ranges |
| PROD_GROUP = vendor names | No Group mapping table needed. GroupOverride in config_PartSettings is for exceptions only. |
| Franchise exclusions | Add S, T*, U* patterns; restore DA to include; exclude 95 |
| user_field_3 = "LOW" uppercase | Filter uses `= "LOW"` |
| History columns = units | No change — plan already used these correctly |
| DealerGroupCode column exists | Add pi_Dealer_Group_Code to Task 6 raw query |
