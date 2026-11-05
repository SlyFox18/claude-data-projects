# Inventory reports: a guide for Ben

This page explains the **Inventory management** area of SPI Parts Hub (app version 0.14.0, 2026-11-05): what the
built-ins **MLPF Gaps**, **Border Stores**, **2 & 4 Cotton** and **Corporate Stocking** check and how each condition maps to the workbook,
the Corp demand rule, the JD fields a copy can use, how fresh the data is, and how the app's lists compared with the
workbooks. Section 10 of the user guide
covers the same ground job by job, with fewer details; section 11 covers Border Stores and 2 & 4 Cotton, section 12 Corporate Stocking.

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
- Part numbers and invoice numbers are compared without trailing spaces, and part numbers with capitals ignored
  (since 2026-11-04: a few part records are stored lower-case in Equip; see the 0.13.0 comparison).

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

## Border Stores and 2 & 4 Cotton (0.13.0, 2026-11-04)

Both workbooks compare a part at one branch with **the same part at the other branches**. The app does it with two
new fields, worked out per row from the report's second list of conditions, **Count other branches where**:

- **Other-branch demands:** the sum of Corp demands over the part's rows (same part number, trimmed, capitals
  ignored) that pass the list, at branches other than the row's own. The workbooks' `OtherBranchDemands`.
- **Other branches with demand:** how many of those branches have Corp demands ≥ 1. The workbooks' `OtherLocationCount`.
- **Each other branch counts once:** a part stored twice at one branch (a trailing-space twin) adds its demands once,
  as SQL Anywhere groups them.

A report without the second list can't use the two fields. Both are columns after Corp demands, in the details panel,
and in the CSV as `OtherBranchDemands`, `OtherLocationCount`.

**The queries' code is the rule, not their header notes**, which are stale after several revisions (the notes say
Border Stores candidates are 7, 14, 95, 91, 96 with fewer than 3 demands; the code says 95, 91, 96 with at least 1).

| | Border Stores | 2 & 4 Cotton |
|---|---|---|
| **Rows to show** | Branch one of 95, 91, 96 · Corp demands ≥ 1 · Other-branch demands ≥ 10 · Other branches with demand ≥ 5 · On hand < 1 · the six part rules¹ | Branch one of 2, 4 · Corp demands = 0 · the same two thresholds · On hand < 1 · the six part rules¹ · the cotton group² |
| **Count other branches where** | Branch not one of 2, 4 · the six part rules¹ | Branch not one of 2, 4 · the six part rules¹ · the cotton group² |
| **Include parts with no activity** | off | on |
| **Prod, 2026-11-04** | 1,576 parts | 251 parts |

¹ On order = 0, Package qty = 1, Return indicator is R, Source is not AN, SLC doesn't start with 21, 90, 91, 99,
Super To is blank (as MLPF Gaps).
² **Any of** (Dealer group one of COTTON, STRIPPER, PICKER; Dealer group at any branch one of 690, 770, CS690,
JDCS690): the row's own dealer group is a cotton one, or the part number is coded as a cotton model at any branch.

**Columns:** the 12 MLPF columns, then Other-branch demands and Other branches with demand. Sorted by part number,
then branch.

### Parts with no activity

2 & 4 Cotton needs parts **2 and 4 carry but have never stocked or sold**: on 2026-11-03, 234 of the workbook's 248
rows. Those records are not in the active parts, so the morning data now also carries every other franchise D record
(Gold `Fact_CorpParts_JD_Idle`: nothing on hand, on order 0 or less, no sales in 24 months, no Corp demand; about
643,000 records at 40 branches, 11 MB compressed). The app loads them only for a report that needs them:

- **Include parts with no activity** (a report switch, on in 2 & 4 Cotton): the report runs over the active and
  the idle records. On the list such a report shows **Count (loads more data)** instead of a count.
- **Dealer group at any branch** (a field) always reads both, so a report using it loads them too.
- MLPF Gaps, Border Stores and 0.12.0 copies never load them.

### Copies: other branches, "any of" groups, new fields

- **Copy as my own** on either report gives the editor two lists: **Rows to show** (which branch rows are listed) and
  **Count other branches where** (which rows at other branches count). To compare different branches, change the
  Branch condition in Rows to show; to change which branches are counted, change the second list.
- **"Any of" groups:** a box **Any of these** in either list, 2 to 10 lines, passing when at least one line does (one
  level; no groups in groups). **Make it a plain condition** turns a one-line group back. Cleanup checks have them too.
- **New fields:** Other-branch demands, Other branches with demand (numbers), Dealer group at any branch (text: one
  of, not one of; trimmed, capitals ignored).
- **New comparison:** **not one of**, on every text field except Vendor (Cleanup).
- Stored as `{"v":2,"conditions":[…],"pool":[…],"includeIdle":true}` in the Conditions column; a report with no
  second list and no switch is still stored as a plain list, so 0.12.0 copies are unchanged. **0.12.0 can't read a
  report or check saved with groups, "not one of" or the new fields**, so 0.13.0 was deployed before anyone saved one.

### Compared with the workbooks (2026-11-03 evening, 2026-11-04)

Brian refreshed Border Stores.xlsx (17:01, 1,575 rows) and 2 & 4 Cotton & Stripper Parts.xlsx (16:59, 248 rows) on
2026-11-03, after the stores closed. They were compared with the reference rules as of 17:00 over Prod data of
2026-11-04, which is Equip as of about 19:00 on 11-03 (JD's evening copy):

- **Border Stores:** 1,573 of 1,575 rows matched on every column; 2 only in the workbook, 0 only in the app, 8 rows
  with different other-branch figures.
- **2 & 4 Cotton:** all 248 rows matched; 1 only in the app, 6 rows with different other-branch figures.

| Parts | Why |
|---|---|
| AM135526, AUC20589, AUC20590, R54027 (at 95 or 91), R55202 (96, so it drops below 10) | An order placed at another branch (1 or 17) after 5 pm, so that branch's row fails On order = 0 and stops counting |
| H161529, N374068 (2 & 4 Cotton) | The same, at branch 3 or 93 |
| JD9313, R236582, R297109, RE558115, AN122420, AN123600 | A transfer received at another branch after 5 pm (17:08 to 17:58): its on order cleared, so that branch now counts |
| AN277321 at 4 (only in the app) | Transferred from 4 to 2 at 16:48, while the workbook was refreshing |
| **TCA24616 at 95 (only in the workbook)** | **A bug the comparison found:** branch 8's record is stored lower-case (`tca24616`) while its invoices aren't, and Corp demands matched part numbers case-sensitively, so branch 8 had 0 demands instead of 3. **Fixed** before release: part numbers are now compared with capitals ignored, as in Equip |

After the release, on 2026-11-04: the reference check on Prod found 0 differences (250,911 active and 643,034 idle
records), and the app's CSVs matched the reference exactly (Border Stores 1,576, 2 & 4 Cotton 251). A test copy of
Border Stores for branches 7 and 14, with parts with no activity, found the same 1,027 parts as the reference.

## Corporate Stocking: one row per part (0.14.0, 2026-11-05)

The SPI Corparate Stocking workbook lists **parts, not branch rows**: a part with nothing on hand or on order at any
branch (except 2 and 4) that had a Corp demand at 3 or more branches. The app learnt a second kind of report,
**one row per part**, with four lists of conditions instead of one:

| List | What it decides | Corporate Stocking |
|---|---|---|
| **Records that count** | Which of the part's records (active and idle, every branch) make up the part. A record outside it doesn't count either way | Branch not one of 2, 4 · Package qty = 1 · Return indicator is R · Source is not AN · SLC doesn't start with 21, 90, 91, 99 |
| **Every counted record must** | The part is shown only when each counted record passes (and it has at least one) | On hand = 0 · On order = 0 · Super To is blank |
| **Demand counts where** | Which records' Corp demands count, whatever the first two lists say; each branch once (twins: the larger) | Branch not one of 2, 4 |
| **Parts to show** | Conditions on the part: R18 demands, Branches with demand, Locations with demand, and the part's text fields | Branches with demand ≥ 3 |

- **The query's code is the rule.** On order must be exactly 0 (a negative fails), and a branch's demand counts even
  when its record fails the part filters (a source AN record at 93 still adds its demands).
- **The part's fields:** R18 demands (the counted branches' Corp demands added up), Branches with demand, Locations
  with demand (codes in number order, others last, ", "-separated). Description, Source, SLC, Commodity code and
  Dealer group are the largest value over the counted records (SQL `MAX`); Cost the largest. Branches spell some
  descriptions differently by case; SQL Anywhere's pick isn't predictable, so the app takes the largest ignoring case,
  at the lowest branch among case variants.
- **Results:** the workbook's 12 columns and sort (Branches with demand desc, R18 demands desc, part number);
  **Demand at branch** instead of a branch filter; a part's panel lists every branch's record and whether it counted
  ("Yes", "No: not in Records that count", "No: fails Every counted record must") and whether its demand counted.
- **CSV:** the workbook's headings (… OnHandQty, R18 Demands, Count of Locations with Demands, Locations with Demands);
  copies keep them for these columns.
- **Always loads the parts with no activity:** 17 of the workbook's parts are kept off only by a Super To at a branch
  that has never stocked them. On the list it shows **Count (loads more data)**.
- **New report** (button on the list) starts from scratch with a **Report type** choice: one row per branch or one
  row per part. Copies keep their report's type.
- Stored as `{"v":3,"grain":"part","counted":[…],"every":[…],"demandAt":[…],"conditions":[…]}`. **0.13.x can't read
  it**, so 0.14.0 was deployed before anyone saved one. Branch reports are stored as before.

### Compared with the workbook (2026-11-05)

Brian refreshed SPI Corparate Stocking.xlsx at 08:01 on 2026-11-05 (1,819 parts). The reference check on that
morning's Prod data found 0 differences in Gold (251,019 active and 643,030 idle records). Against the workbook,
with the reference as of 08:01, **1,817 parts matched on every column**; at Gold's own data time (06:42) the app's
list differs from the workbook by these parts:

| Parts | Why |
|---|---|
| H103344, H96423, HXE81341 (only in Excel); AH96333, HXE37540 (one more demand in Excel) | Invoice 2015916 at branch 94 posted on 10-29 between 06:42 and 08:01: inside Excel's 18-month window, not yet inside the app's. It reaches the app the next morning |
| AFH210470 (only in the app) | Its 2025-05-05 07:20 invoice is still inside the app's window and had just left Excel's |
| H140180, RE506624 (only in Excel) | Branch 11's on hand or on order changed in Equip after JD's overnight copy (checked by Brian) |
| JD8914, R86105, RE155713, RE29408 (description) | Branches spell the description differently (leading spaces, punctuation); SQL Anywhere's `MAX` picks one the app can't copy exactly. Accepted by Brian |

After the release: the app's CSV matched the reference exactly (1,815 parts), and a test copy with Branches with
demand ≥ 4 found the same 618 parts, in the same order. The copy was stored as v3 and deleted.

## Coming next

The other Corp Parts workbooks, each as its own small release with its own Excel comparison: **Pieces In Set** next.
It checks first whether it needs new fields.

Ideas for later (FUTURE-IDEAS F4): a JD Part page; actions from a report row (order, transfer, set a minimum); data
during the day instead of once a morning.
