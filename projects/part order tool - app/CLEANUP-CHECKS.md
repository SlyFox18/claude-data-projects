# Cleanup checks: a guide for Ben

This page explains the **Cleanup** area of SPI Parts Hub (app version 0.11.0, 2026-11-02): what a check is, the two
built-in checks, every field a check can use and where it comes from, every comparison, how blanks are treated, and
what the results page and its CSV show. Section 7 of the user guide covers the same ground job by job, with fewer
details.

Saved checks are kept in the SharePoint list **NonJD_CleanupChecks** on the Report Site (one row per check: name,
description, conditions, Active, Archived; the author is SharePoint's Created By, "changed by" its Modified By). You
work with them in the app, under **Cleanup** → **Checks**.

**Nothing in this area changes Equip.** A check is a list you filter, export and work through; the fix is made in
Equip as today. A fixed part leaves the list with the next morning's data.

## What a check is

A check is a list of parts, over **every branch at once**, that meet all of its **conditions**. Each condition is
one **field**, one **comparison** and (usually) one **value**, for example "On hand > 0". A part is listed only when
it meets **every** condition (there is no "or" yet: see "Not yet" below).

- **Over every branch.** A check looks at each branch's part record on its own (branch + franchise + part number),
  so a part can be on a check at one branch and not another.
- **Which parts.** Only the parts the tool carries: non-John Deere franchises, a cost above $0, and not at the
  branches left out of the tool (12, 5, 97, 4B, 93C). A check on "Cost = 0" finds nothing for that reason.
- **Which day.** The morning data (the date at the top right). A check doesn't see changes made in Equip during the
  day, nor rule or part-setting changes made in the app since the morning (Status is this morning's).
- **Counts** are over every branch. The launch page card is different: it shows only the minimums with no demand at
  the branch picked there.

## The built-in checks

Always at the top of the list, marked **Built in**. They can't be edited, switched off or archived.

### Minimums with no demand

The old Cleanup page, unchanged, now at **Cleanup → Minimums with no demand**.

- **Listed:** parts with an **Equip minimum above 0**, **no min override** in the app, and **no demands and no
  units sold** in the rule's history months, as worked out in this morning's run. These are the lines tagged
  **Min, no demand** on Recommended Reorder. These minimums **apply to the order**, so this is the list to fix.
- **Columns:** Branch, Franchise, Part, Description, **Equip min**, **On hand**, Cost, **Min × cost** (the stock value
  the minimum commits), **Would order $** ((Equip minimum rounded up − on hand − on order, never below 0) × cost) and
  **Last requested**.
- **CSV:** `Branch, Franchise, PartNumber, Description, EquipMinimum, OnHand, Cost, MinimumValue, WouldOrderValue,
  LastRequested`, named `Cleanup-minimums-<yyyymmdd>.csv`.
- **Prod, 2026-11-02:** 3,592 parts.

To take a listed part off the order, fix the minimum in Equip, or set a min override of 0 on its Part page.

### Stock value with no quantity

New in 0.11.0, from your "value without quantity" idea (FUTURE-IDEAS F1).

- **Exactly:** **Equip stock value (either way) ≥ $1.00** and **On hand ≤ 0**. In words: Equip shows a stock value of
  $1 or more, either way (+$1.00 or more, or −$1.00 or less), but nothing or less than nothing on hand.
- **Why values under $1 are left out:** Equip has many penny leftovers on parts with no stock (on Dev data, 292 of
  741 such parts were under $1, together −$19.31). They would bury the ones worth fixing. Brian decided this on
  2026-11-02.
- **Why it matters:** Equip's stock value adds up into what the inventory is worth on the books. A value with no
  stock behind it means the books carry stock that isn't on the shelf (or, negative, the other way round).
- **Columns:** Branch, Franchise, Part, Description, Bin, **On hand**, **Cost**, **Equip stock value** (with its sign).
  The total at the top is the sum of the Equip stock value of the parts listed, so it can be negative.
- **CSV:** `Branch, Franchise, PartNumber, Description, Bin, OnHand, Cost, EquipStockValue`.
- **Prod, 2026-11-02:** 415 parts. Example: RM-24V at branch 11, on hand −126, cost $500.00, Equip stock value
  −$63,000.00.

## Equip stock value is not on-hand value

Two different dollar figures appear in Cleanup:

| | **Equip stock value** | **On-hand value** |
|---|---|---|
| What it is | Equip's own stock value for the part: its **ON_HAND_VAL** column, as the part record shows it | The whole units on hand × cost, worked out by the app |
| Formula | None: taken from Equip as it is (rounded to the cent) | max(0, whole units on hand) × cost |
| Can be negative | Yes | No (negative stock counts as 0) |
| Where else used | Only here | The same figure as the returns allowance's "Stock value" |

They usually agree, but not always: Equip's value can carry leftovers from receipts, returns and cost changes, and
it can show a value with nothing on hand, which is exactly what the built-in check finds. Across every part on Prod
on 2026-11-02, the gap between the two added up to about $923,000 (ignoring sign); 3,322 parts had stock on hand but
an Equip stock value of 0.

## The fields

A check can use these fields, in this order in the field list. "Equip" means the branch's part record in Equip, as
the morning data copies it.

| Field | Kind | Where it comes from | Blank when |
|---|---|---|---|
| **On hand** | number | Equip quantity on hand (QuantityOnHand); can be negative | never |
| **On order** | number | Equip quantity on order (OnOrder; includes transfers open in Equip) | never |
| **Pending** | number | Equip pending quantity (PendingQty): stock committed to open tickets | never |
| **Back order** | number | Equip back-order quantity (BackOrderQty) | never |
| **Cost** | dollars | Equip cost per unit (Cost), to the cent | never |
| **On-hand value** | dollars | App: max(0, whole units on hand) × cost | never |
| **Equip stock value** | dollars | Equip stock value (ON_HAND_VAL, InventoryCost in the data), with its sign | never (Equip blank = $0) |
| **Equip stock value (either way)** | dollars | App: the size of Equip stock value, sign dropped (−$45 → $45) | never |
| **Equip minimum** | number | Equip stocking minimum (MinimumQty). The Equip figure, not the app's min override | no minimum set |
| **Equip maximum** | number | Equip stocking maximum (MaximumQty) | no maximum set |
| **Sales 12 months** | number | Equip 12-month sales (Current12MoSales) | never |
| **Sales 24 months** | number | App: Equip 12-month sales + the 12 months before (Current12MoSales + Previous12MoSales) | never |
| **Last requested** | date | Equip date last requested (DateLastRequested) | never requested |
| **Last received** | date | App: the newest receipt from a supplier (a purchase receipt in the part's transaction history) at that branch | never received |
| **Status** | choice | App: this morning's order status (Out of stock, Reorder, Stocked, Below min value, Above max value, Not stocked, No recent activity, Masked, Manual order) | never |
| **Franchise** | text | Equip franchise | rarely |
| **Dealer group** | text | Equip dealer group code at that branch | no dealer group ("(none)") |
| **Vendor** | text (a number) | Equip vendor number; 0 = no vendor | never |
| **Product group** | text | Equip product group at that branch (InMaster) | none set |
| **SLC** | text | Equip SLC | none set |
| **Source** | text | Equip source code | none set |
| **Manual order** | yes / no | App: the part's Manual order setting (as of this morning) | never |

**Not there (yet):** last sold (it needs every branch's monthly history, too heavy for a list over every branch),
the app's min override, mask and phase-in (use **Special statuses** for those), commodity code, sell and list price.

## The comparisons

| Field kind | Comparisons | Value |
|---|---|---|
| Number, dollars | **=**, **≠**, **<**, **≤**, **>**, **≥** | A number. Dollars compare to the cent; quantities to 2 decimals. |
| Equip minimum, Equip maximum | as above, plus **is blank**, **is not blank** | |
| Date (Last requested, Last received) | **before**, **before, or never**, **after**, **is blank**, **is not blank** | **N months ago** (1 to 120) or **a date** |
| Text (Franchise, Dealer group, Product group, SLC, Source) | **is**, **is not**, **one of**, **is blank**, **is not blank** | Text; for "one of", a list (type each, then Enter) |
| Vendor | **is**, **is not**, **one of** | A vendor number; leading zeros dropped (01058 = 1058) |
| Status | **one of** | Ticks |
| Manual order | **is yes**, **is no** | none |

- **Text** compares without regard to capitals or spaces at either end: "bs" is BS. Type **(none)** for the dealer
  group's "no dealer group".
- **"N months ago"** is counted from today each time the check runs (calendar months, Central time; the day is held
  to the month's end, so 1 month before March 31 is February 28). "Last received before 24 months ago" stays right
  month after month with no editing. **a date** is a fixed day.
- **before** and **after** are strict: "before 2025-01-01" doesn't include January 1, 2025.

## Blanks

| Comparison | Matches a blank? |
|---|---|
| = ≠ < ≤ > ≥ (numbers, dollars) | **No.** "Equip minimum ≠ 0" doesn't list parts with no minimum. |
| before, after | **No.** A part never requested isn't "before" any date. |
| **before, or never** | **Yes**: never counts as old. |
| is, one of (text) | **No** (except the dealer group's **(none)**, which is its blank). |
| **is not** (text) | **Yes**: a blank is not that text. "Product group is not FILTERS" includes parts with no product group; add "Product group is not blank" to leave them out. |
| is blank | Yes (that is what it is for) |
| is not blank | No |

## Saving, switching off, archiving

- **Name:** required, up to 255 characters. It can't repeat a built-in check's name, or the name of another saved
  check that is on and not archived (capitals and extra spaces don't count): "A check called X already exists."
- **At least one condition**, and every condition must be complete before **Save check** works.
- **Try it** shows the count and the first 20 parts while you edit, over every branch loaded, from this morning's
  data. Nothing is saved until **Save check** ("Check saved." / "Check updated.").
- **Changed meanwhile:** saving reads the check again first. If someone else saved it after you opened it, the app
  asks "<name> changed this check at <time>. Replace it with yours?". If it was archived or removed meanwhile, nothing
  is saved.
- **Switch off** keeps the check on the list, greyed and marked **Off**, below the checks that are on. It still
  counts and opens; Off only frees its name and moves it down. **Switch on** brings it back.
- **Archive** takes it off the list (Show archived brings it back, with **Unarchive**). An archived check can't be
  opened or edited. Nothing is ever deleted from the app.
- Anyone in the test group can create, edit, switch off and archive any check.

## The results page and the CSV

Every check except Minimums with no demand opens on the same results page:

- **Branch** and **Franchise** filters (All = every one), the count, and a total: the **Equip stock value** for
  Stock value with no quantity and for any check using either Equip stock value field; otherwise the **on-hand
  value**.
- **Columns:** Branch, Franchise, Part (a link to the Part page), Description, Bin, then each field the check's
  conditions use, once, in the field list's order (Franchise isn't repeated; "Equip stock value (either way)" shows as
  the signed Equip stock value). The built-in shows On hand, Cost and Equip stock value.
- Blank dates show **Never**, a part with no dealer group **(none)**, other blanks **—**.
- Click a heading to sort (first click largest / latest first, second click reverses). 200 rows at a time, with
  **Show 200 more**.
- **Export CSV** saves what the filters show, with the same columns: `Branch, Franchise, PartNumber, Description,
  Bin`, then one column per field, named from its label (OnHand, OnOrder, Pending, BackOrder, Cost, OnHandValue,
  EquipStockValue, EquipMinimum, EquipMaximum, Sales12Months, Sales24Months, LastRequested, LastReceived, Status,
  DealerGroup, Vendor, ProductGroup, SLC, Source, ManualOrder). Dollars as plain decimals (1234.50), dates
  YYYY-MM-DD, Manual order Yes / No, blanks empty. The file is `Cleanup-<check name>-<yyyymmdd>.csv`, with
  **-partial** at the end when not every branch had loaded.

## "Not in today's data yet"

Equip stock value arrived with 0.11.0's morning data (2026-11-02). If a morning's data ever lacks a field, a check
using it can't run: the list says **Not in today's data yet**, the check's page says "Equip stock value isn't in
today's data yet. It arrives with the next publish.", and the editor marks the field "(not in today's data yet)".
Tell Brian if you see it.

## Not yet

Ideas for later (FUTURE-IDEAS F1 follow-ups): **or** between conditions; **last sold** (needs the monthly history);
checks per person (shared vs personal); and a setting for the $1 threshold of Stock value with no quantity.
