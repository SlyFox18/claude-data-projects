# Inventory reports: a guide for Ben

This page explains the **Inventory management** area of SPI Parts Hub (app version 0.12.0, 2026-11-03): what the
built-in **MLPF Gaps** checks and how each condition maps to the workbook, the Corp demand rule, the JD fields a copy
can use, how fresh the data is, and how the app's list compared with MLPF Gaps.xlsx. Section 10 of the user guide
covers the same ground job by job, with fewer details.

Saved copies are kept in the SharePoint list **NonJD_InventoryReports** (one row per copy: name, description,
conditions, Active, Archived; the author is SharePoint's Created By, "changed by" its Modified By). You work with them
in the app, under **Inventory management** → **Reports**.

**Nothing in this area changes Equip, and the workbooks keep working.** A report is a list you filter, export and
work through.

## What a report is

A report is a list of JD parts, over **every branch at once**, that meet all of its **conditions**, the same way a
Cleanup check works (see CLEANUP-CHECKS.md). The differences from Cleanup:

- **Which parts.** Every **active** JD (franchise D) part record: on hand ≠ 0, on order > 0, a sale in the last 24
  months, or a Corp demand. On 2026-11-03 that was 250,867 records at 27 branches.
- **Every JD branch**, including the ones the rest of the tool leaves out (such as 12). Each report leaves out what
  its workbook leaves out.
- **Built in vs copies.** Each workbook becomes a built-in report that never changes. **Copy as my own** makes an
  editable copy; the built-in stays as it is.

## MLPF Gaps: what it checks

The built-in reads "JD parts with exactly 2 Corp demands and nothing on hand or on order, returnable, package qty 1,
not superseded (the MLPF Gaps workbook)." Every condition comes from a line of the workbook's query
(`projects/corp parts excel reports/MLPF Gaps/MLPF Gaps.pq`):

| Condition in the app | Workbook line | In words |
|---|---|---|
| Branch is not 12 | `i.BRANCH <> '12'` | not the Combine Vault |
| Corp demands = 2 | `HAVING COUNT(*) = 2` | exactly 2 demands (rule below) |
| On hand < 1 | `p.pi_On_Hand_Qty < 1` | nothing on hand |
| On order = 0 | `COALESCE(p.pi_On_Order, 0) = 0` | nothing on order |
| Package qty = 1 | `p.pi_Package_Qty = 1` | sold one at a time, not in a pack |
| Return indicator is R | `p.pi_Return_Indicator = 'R'` | returnable |
| Source is not AN | `p.pi_Source <> 'AN'` | source AN left out |
| SLC doesn't start with 21, 90, 91, 99 | `p.pi_SLC NOT LIKE '21%'` (and 90, 91, 99) | those SLC families left out |
| Super To is blank | `COALESCE(RTRIM(p.pi_Super_To), '') = ''` | not superseded |
| (the data set) | `i.FRANCHISE = 'D'` | JD parts only |

**Columns**, in the workbook's order: Branch, Part number, Description, Cost, Source, SLC, Commodity code, Commodity
group, Dealer group, On order, On hand, Corp demands. Sorted by part number, then branch, as the workbook is.

**CSV:** the table's columns with the workbook's headings (`Branch, PartNumber, Description, Cost, Source, SLC,
CommodityCode, CommodityGroup, DealerGroupCode, OnOrder, OnHandQty, Demands`), so it pastes beside MLPF Gaps.xlsx.
The file is `Inventory-<report name>-<yyyymmdd>.csv`, with **-partial** at the end when not every branch had loaded.

**Total cost (1 each)** next to the filters is the sum of Cost over the rows shown: MLPF parts have nothing on hand, so
it is what stocking one of each would cost.

**Prod, 2026-11-03:** 10,090 parts.

Two small differences from the workbook, neither seen in today's data:
- A blank Source or SLC: the app's "is not" and "doesn't start with" keep a blank, where the workbook's SQL would drop
  a NULL. There are none among the MLPF candidates.
- A part number stored twice, once with a trailing space: the app keeps both rows (the workbook shows one).

## The Corp demand rule

All the Corp Parts workbooks count demand the same way. The app works it out once, each morning, for every JD part
at every branch (the **Corp demands** field):

- One demand = **one customer invoice** for the part at that branch. Several lines for the part on one invoice, or a
  quantity of 5, still count once.
- The invoice is dated **7 days to 18 months** before the data time. The last week is left out.
- **Credits** are matched to the invoice they return (its original invoice number) and netted. A credit counts
  whenever it was made, even in the last week. An invoice **fully credited** back doesn't count; a partial return
  still counts as 1. A credit whose invoice is outside the window counts for nothing.
- **Transfers never count**, nor purchases, receipts or adjustments.
- Part numbers and invoice numbers are compared without trailing spaces.

Example: a part sold on two invoices in the last year, one of them later credited in full, has 1 Corp demand.

## The fields a copy can use

A copy's conditions can use these 19 fields, in this order in the field list. "Equip" means the branch's part record
in Equip, as the morning data copies it.

| Field | Kind | What it is | Blank when |
|---|---|---|---|
| **Branch** | text | The branch number | never |
| **Part number** | text | The JD part number | never |
| **Description** | text | Equip description | none set |
| **Corp demands** | number | The Corp demand count (rule above) | never (0 = none) |
| **On hand** | number | Equip quantity on hand; can be negative | never |
| **On order** | number | Equip quantity on order | never |
| **Cost** | dollars | Equip cost per unit, to the cent | never |
| **Package qty** | number | Equip package quantity (1 = sold singly) | Equip's value isn't a number |
| **Return indicator** | text | Equip return indicator (R = returnable, N, D) | none set |
| **Source** | text | Equip source code | none set |
| **SLC** | text | Equip SLC | none set |
| **Super To** | text | The part number this part is superseded to | not superseded |
| **Commodity code** | text | Equip commodity code | none set |
| **Commodity group** | text | The group for the commodity code, from CommodityCodeGroups.csv; **Other** when the code isn't in it | never |
| **Dealer group** | text | Equip dealer group code at that branch; type **(none)** for no dealer group | no dealer group |
| **Equip minimum** | number | The stocking minimum set in Equip | no minimum set |
| **Equip maximum** | number | The stocking maximum set in Equip | no maximum set |
| **Sales 12 months** | number | Equip 12-month sales | never |
| **Sales 24 months** | number | The last 12 months plus the 12 before | never |

A copy's table and CSV show the workbook's columns, then any other field its conditions use (for example Package qty,
Return indicator, Super To), headed by its label without spaces (PackageQty, ReturnIndicator, SuperTo, …).

## The comparisons

As in Cleanup checks (CLEANUP-CHECKS.md), plus two new ones for text:

| Field kind | Comparisons |
|---|---|
| Number, dollars | **=**, **≠**, **<**, **≤**, **>**, **≥**; Package qty, Equip minimum and maximum also **is blank**, **is not blank** |
| Text | **is**, **is not**, **one of**, **starts with**, **doesn't start with**; all but Branch and Part number also **is blank**, **is not blank** |

**Starts with / doesn't start with** take a list of starts (type each, then Enter): "SLC doesn't start with 21, 90,
91, 99" is true for SLC 40 and false for SLC 2105. Capitals and spaces at either end don't matter. A blank never
starts with anything, so "doesn't start with" keeps blanks (as "is not" does). They are in Cleanup checks too, on
every text field except Vendor.

## Data timing

- The JD parts come with the **morning data**: the DP refresh at 06:15, then the Gateway publish. Once a day.
  Each report says **Data as of …**.
- The workbook reads Equip **live**. A sale, receipt or order made today shows in the workbook but not in the app until
  tomorrow, so on any morning the two differ by a few parts.
- Changes to CommodityCodeGroups.csv reach the app the next morning.

## Compared with MLPF Gaps.xlsx (2026-11-03)

Brian refreshed MLPF Gaps.xlsx at 9:41 AM (10,065 rows) and it was compared, part by part, with the app's rule run
as of 9:40 AM over that morning's Prod data:

- **10,046 of 10,065 rows matched on every column.**
- 19 rows only in the workbook, 13 only in the app, 1 with a different value. Every one is explained, and none points
  to a mistake in the rule:

| Parts | Why |
|---|---|
| 11 (branch 4) | Stock received against back orders and invoiced this morning, after the app's data was taken |
| 7 | Sold or transferred on 11-02, then reordered before 9:41 AM |
| 9 | On hand or on order moved in Equip today, with no transaction in the app's data yet (most likely) |
| 6 | A data bug the comparison found: parts stored in Equip with a lower-case franchise "d" lost their package qty, return indicator and commodity code in the data. **Fixed** before release; these parts are now on MLPF Gaps |

Two invoices sat on the 7-day edge of the window (October 27): the workbook ran at 9:40, so they were in or out
depending on the minute. After the fix, the reference check on Prod (`corp_parts_check.py`) recomputed every JD part's Corp
demands independently and found **0 differences** (250,867 rows).

## Commodity group: why so much is "Other"

About **67%** of the JD part records show Commodity group **Other**. That is the same as the workbook: the group comes
from the same file, **CommodityCodeGroups.csv** on the Report Site (244 codes in 17 groups).

- About 19,000 records have **no commodity code** in Equip.
- The rest have a code that **isn't in the CSV**.

To give more parts a group, add their codes to CommodityCodeGroups.csv. The app picks it up the next morning, and the
workbook on its next refresh.

## Coming next

The other Corp Parts workbooks, each as its own small release with its own Excel comparison: **Border Stores** and
**2 & 4 Cotton** first, then **Corporate Stocking**, then **Pieces In Set**. Each checks first whether it needs new
fields.

Ideas for later (FUTURE-IDEAS F4): a JD Part page; actions from a report row (order, transfer, set a minimum); data
during the day instead of once a morning.
