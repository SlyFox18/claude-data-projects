# Returns and scrap: a guide for Ben

This page explains the **Returns & scrap** area of SPI Parts Hub (app version 0.9.0, 2026-11-02; 0.9.1 the same
day): the return and scrap rules, exactly which parts a rule picks, how the return allowance and the pre-pick
work, demand at other branches and **Transfer instead**, and what happens to a return or scrap list once it is
saved. Section 8 of the user guide covers the same ground job by job, with fewer details.

The rules are kept in the SharePoint list **NonJD_ReturnRules** on the Report Site; saved returns and scrap lists in
**NonJD_Returns** (one row each) and **NonJD_ReturnLines** (one row per line). You work with all three in the app,
under **Returns & scrap**: **Returns**, **Scrap** and **Return & scrap rules**.

**Nothing in this area changes Equip.** A return or scrap list is a list you export and work from; the return or
the scrap is keyed into Equip as today. The orders and transfer suggestions don't change either (see "Holds").

## What the area is for

- **Vendor returns.** Many vendors let us send back a share of what we bought, for credit, when it hasn't sold.
  The tool finds the parts that haven't sold for a while at every branch, ticks the worst ones up to the vendor's
  allowance, and works out the expected credit.
- **Scrap.** Parts that haven't sold in years and that the vendor won't take back. Before anything is scrapped,
  the tool shows which other branches have asked for the part, so stock that could still sell goes there instead.

The vendor's terms (how much, which parts, the credit) are kept as a **return rule** per franchise, so nobody has
to remember them each time. The tool doesn't know any vendor's policy: each rule says what the person who set it
up typed in. **Use your vendor's terms.**

## The rules

One page, **Return & scrap rules**, with two tabs: **Return rules** and **Scrap rules**. Each rule shows its
franchise, its terms in one line (for example "10% of 12-mo purchases · no sales 24 mo · not received 12 mo ·
credit 85% · excl. Manual order / minimums"), its season, whether it is **Active**, **Off**, **Invalid** (with the
reason) or **Archived**, and who changed it last.

- **One active return rule per franchise.** Saving or switching on a second one asks "Rule 'MM annual return' is
  active for MM. Make this one active instead?". **Make this one active** switches the other off.
- **Scrap:** one active rule per franchise, plus one active **All franchises** rule, used for every franchise that
  has no scrap rule of its own. On 2026-11-02 there is one: **Scrap default** (All franchises, no sales 36 months,
  unit cost at least $0.10). There are no return rules yet.
- Rules are never deleted: **Archive** hides one; **Unarchive** brings it back. A saved change applies to new
  returns and scrap lists only: saved ones keep their lines.
- Anyone with Edit on the NonJD_ReturnRules list can change the rules (everyone in the test group). Without it the
  page says "You don't have permission to change return and scrap rules." and shows them read-only.

### The fields

| Field (SharePoint column) | What it does | Return | Scrap |
|---|---|---|---|
| **Name** (Title) | Required. Shown in the list and saved with every return or scrap list made with it. | ✓ | ✓ |
| **Franchise** | Picked from a list (0.9.1). A return rule needs one. A scrap rule can be **All franchises** (blank). Saved upper-case. | ✓ | ✓ |
| **No sales for** (NoSalesMonths) | Months, 1 to 59. Required. See "Which parts qualify". New rules start at 24 (return) or 36 (scrap). | ✓ | ✓ |
| **Not received for** (NotReceivedMonths) | Months, 1 to 59, or blank (no check). Leaves out parts the branch received from a supplier in that time. | ✓ | ✓ |
| **Min line value** (MinLineValue) | Dollars, or blank. A line worth less (qty × cost) is left out. | ✓ | |
| **Min unit cost** (MinUnitCost) | Dollars, or blank. A part costing less is left out. | | ✓ |
| **Leave out Manual order** (LeaveOutManualOrder) | On = parts set to Manual order are left out. | ✓ | ✓ |
| **Leave out minimums** (LeaveOutMinimum) | On = parts with an **Equip** minimum above 0 are left out. | ✓ | ✓ |
| **Allowance %** (AllowancePct) | 0 to 100. Required on a return rule. | ✓ | |
| **Based on** (AllowanceBase) | What the allowance % is taken of: 12-month purchases, stock value or the qualifying parts' value (next section). Required on a return rule. | ✓ | |
| **Credit %** (CreditPct) | 0 to 100, of the line value at cost; blank = not known (no credit figures). | ✓ | |
| **Season starts** / **Season ends** (SeasonStart, SeasonEnd) | MM-DD (03-15 = March 15), both set or both blank (all year). 11-01 to 02-28 wraps the year end. Outside the season a document can still be made; the app says so. | ✓ | ✓ |
| **Active** | Off = not used. A new rule starts on. | ✓ | ✓ |

Note the season is a **day** (MM-DD) here, while order and transfer rules use month numbers.

A rule with a problem can't be saved, and the form lists every problem ("No sales for must be 1 to 59 months.",
"Allowance % must be 0 to 100.", "Pick what the allowance is based on.", "Season start and end must both be set
(MM-DD) or both blank."). A rule changed directly in SharePoint into a bad state shows as **Invalid** with the
reason, and can't be switched on.

### Try it

While you edit a rule, **Try it** loads every branch and shows what the draft would pick **today**, over every
branch, from this morning's data and the open returns and scrap lists. Nothing is saved.

- Return rule: **Qualifying parts**, **Their value**, the **Allowance** in dollars, the **Expected credit**, and
  "Pre-pick ticks 12 parts, $3,950.00 of $4,000.00."
- Scrap rule: **Qualifying parts**, **Their value**, and how many have **demand elsewhere**.
- The 20 biggest parts by value: branch, part, qty, value, last sold, demand elsewhere and (returns) whether the
  pre-pick ticks it.

## The allowance

**Allowance = Allowance % × the base**, rounded to the cent. The base is always the franchise's, over the
branches ticked on the return (every branch by default):

| Based on | The base |
|---|---|
| **12-month purchases** (Purchases12) | New stock bought from suppliers in that franchise at those branches over the **last 12 complete months**, at cost. On 2026-11-02 that is November 2025 to October 2026. Returns to the supplier are **not** subtracted (it is what we bought, gross). It comes from Equip's purchase transactions (InTrans type P), in the morning data. |
| **Stock value** (StockValue) | The franchise's stock on hand at those branches × cost, today (whole units; a negative balance counts as 0). |
| **Qualifying value** (QualifyingValue) | The value of the parts the rule picks (each line's free qty × cost). |

**Example.** 10% of 12-month purchases of $40,000 is a **$4,000** allowance. With Qualifying value, 10% of $12,000
of qualifying parts is $1,200.

The allowance is measured against **line value at cost** (qty × cost), the same as the meter. Lines sent by
Transfer instead don't count against it.

## Which parts qualify

A rule is applied to every part of its franchise at every branch ticked on Set up (branches 12, 5, 97, 4B and 93C
are never in the tool). A part at a branch qualifies when **all** of these hold:

1. **Franchise.** The part's franchise is the rule's (matched ignoring case and spaces). A scrap rule for All
   franchises takes the franchise picked on Set up.
2. **Not left out.** Leave out Manual order: the part isn't on Manual order. Leave out minimums: its **Equip**
   minimum is 0 or blank. (A min override set in the app doesn't count here; only Equip's minimum.)
3. **Free stock.** **Available = on hand − committed to open tickets − on transfers saved in this app (going out)
   − already on other open returns and scrap lists**, in whole units, never below 0. It must be at least 1. This is
   the most a line can hold.
4. **No sales.** No units sold at that branch in the **current month** or the **No sales for** full months before
   it. With No sales for 24 on 2026-11-02, a sale any time from November 2024 to today disqualifies the part.
5. **Not received** (only if the rule sets it). The part's last receipt from a supplier at that branch (the newest
   purchase transaction) is older than **Not received for** months before today. A part never received passes.
6. **Value.** Return: the line (available × cost) is worth at least the **Min line value**, if set. Scrap: the
   part costs at least the **Min unit cost**, if set.
7. **Season** doesn't remove parts: outside the season the app only says so.

Each qualifying line shows its **Last sold**: the last month with units sold at that branch (for example 2023-03),
or **Over 5 years** when there is none in the 60 months of history.

## The pre-pick (returns)

A new return starts with lines ticked up to the allowance, worst sellers first:

1. The lines are put in order: **longest unsold first** (Over 5 years first, then the oldest Last sold month),
   then the **higher value** first, then branch order and part number.
2. Down that list, each line is ticked if it still fits in what is left of the allowance. A line that doesn't
   fit is skipped, and the next ones are still tried: a smaller line further down may fit.
3. With an allowance of 0, or none worked out, nothing is pre-ticked.

The order is fixed; you can't change it, but you can change any tick afterwards. The meter above the list reads
"$3,950.00 of $4,000.00 allowance" and turns red with "(over)" when the ticks go over. **Saving is still
allowed**: the vendor has the last word.

A **scrap** list has no allowance: every qualifying line starts ticked.

## Demand elsewhere

For each line, **Demand elsewhere** lists every other branch that asked for the same part (franchise and part
number), with the number of requests (transactions), busiest first:

- The window is the last **18 complete months** (the current month is left out). It can be changed for one
  document on Set up (**Demand window (months)**, 1 to 59).
- **Every other branch in the tool counts**, whether it is ticked on Set up or not. A branch with no requests
  isn't listed.
- Ties are listed in branch order.

Example (2026-11-02): branch 91's **9447** (98-3/8" GANG BOLT) showed "8 (2), 13 (2), 96 (2), 94 (1)".

## Transfer instead

A line with demand elsewhere can be **sent to that branch instead** of going back to the vendor or into the scrap.
Stock another branch is selling is worth more there than as a credit or as scrap.

- The branch box lists the branches with demand that **can receive the part**: the branch carries the part and
  its transfer rule allows receiving (**Receives** on; see TRANSFER-RULES.md). It starts on the **busiest** of
  them. If none can, the line says "No branch can receive it".
- **Scrap: on by default** for every line that has a branch to go to. **Returns: off by default** (the demand still
  shows).
- The whole line's qty goes to that one branch. It leaves the return or scrap totals and the allowance meter.
- Transfer instead doesn't check how much stock the receiving branch already has: it only goes by who asked.
- On save, these lines become ordinary **Conventional transfer orders**, one per From → To pair, titled like other
  transfer orders and marked **From Return "<title>"** or **From Scrap "<title>"**. They are worked like any other
  transfer order on the **Transfers** page (Export CSV, Mark entered in Equip). The document lists them under
  **Transfer orders made with it**.
- If **every** ticked line is Transfer instead, Review says "Nothing left to scrap: 3 parts go to other branches."
  (or "to return"), the button reads **Save transfers**, and only the transfer orders are saved: no return or scrap
  list is made.

Example (2026-11-02): 9447 at 91 started as Transfer instead to **8** (8, 13 and 96 tie at 2; branch order picks 8).
Branch 11's **6397** (BRKT, 2 × $239.62 = $479.24, last sold 2023-03) had no demand elsewhere, so it stayed on
the scrap list.

## Saving

**Review & save** shows the lines, value at cost, expected credit and allowance (returns), and the transfers grouped
From → To. Then:

1. The stock is **checked again**: the open returns, scrap lists and transfers are re-read, and every ticked line
   (kept or transferred) must still fit in its branch's free stock. If anything is short, **nothing is saved**; a
   banner names each part ("6397 at 11: 1 available now, 2 ticked"), and the Parts step marks those lines.
2. The Transfer instead lines are saved as transfer orders.
3. The return or scrap list is saved as a **Draft**, titled `<franchise>-RET-<yyyymmdd>-<hhmm>` or `-SCR-` (Central
   time), for example **AM-SCR-20261102-1026**. The rule as it was applied, the branches, the demand window and the
   data date are saved with it, so a later rule change doesn't alter it.

If a save stops part-way (a network problem), **Retry** carries on without saving anything twice.

## Statuses, and who can do what

| Status | Pill | Holds its parts | What can be done |
|---|---|---|---|
| **Draft** | amber | yes | Lower a line's qty (never raise it) or Remove a line. Export CSV / Export by branch. Cancel. |
| **Exported** | blue | yes | Export again. **Mark sent to vendor** (return) or **Mark scrapped** (scrap list). Cancel. Lines are fixed. |
| **Sent to vendor** (Sent) | green | no | Return only. **Credit received**: enter the amount actually credited. |
| **Credit received** (Credited) | dark green | no | Return only. Shows "Expected $4,250.00 · Received $3,980.00 (94%)". Archive. |
| **Scrapped** | green | no | Scrap list only. Archive. |
| **Cancelled** | grey | no | Archive. |

- **Return:** Draft → Exported → Sent to vendor → Credit received. **Scrap list:** Draft → Exported → Scrapped.
  Both can be **Cancelled** while Draft or Exported. Mark sent / Mark scrapped need an export first ("Export it
  first: the CSV is what goes to the vendor.").
- **RA number:** the vendor's return authorization number, typed on the return's page (saved on Enter). It can be
  changed at any time until the return is archived.
- **Expected credit** = the sum of the lines' credit (line value × Credit %), worked out again when a Draft's lines
  change and at export.
- **Archive** hides a finished one (sent, credited, scrapped or cancelled) from the lists unless **Show archived**
  is on. **Unarchive** brings it back. Nothing is ever deleted.
- **Cancelling doesn't cancel its transfer orders**; cancel those on the Transfers page if needed.
- Anyone with Edit on the NonJD_Returns and NonJD_ReturnLines lists (everyone in the test group) can do any of
  this. If someone else changed the document while you had it open, your change is refused ("This return was
  changed by someone else; reload it.") and the page shows what is stored.

The launch card counts the open ones: "1 open return · 2 open scrap lists" (Draft or Exported).

## Holds

While a return or scrap list is **Draft** or **Exported**, the quantity on each of its lines is **held in the app**:

- it isn't offered again on another return or scrap list (it is subtracted from Available);
- a grey tag shows where the part appears: **On return MM-RET-… (2)** or **On scrap AM-SCR-… (2)** (the list and
  the quantity held), linking to the list. The tags are on Recommended Reorder lines, on transfer suggestions by the
  sending branch (Reorder step 1, the Transfers page, One-Time Order's Transfers step) and on the Part page's Other
  branches table.

The hold is **in the app only**: Equip isn't changed, and the order and transfer calculations (and the morning
run) are worked out as before. So a held part can still be suggested as a transfer: check the tag before saving
one. The hold ends when the document is sent to the vendor, scrapped or cancelled. From then until the next
morning's data shows the stock gone from Equip, the tool counts it again, so key the return or scrap into Equip
promptly.

## The CSV

**Export CSV** downloads one file named after the document (for example `AM-SCR-20261102-1026.csv`), one line per
part:

- Return: `Branch, PartNumber, Description, Bin, Qty, Cost, LineValue, CreditPct, CreditValue, LastSold`
- Scrap list: `Branch, PartNumber, Description, Bin, Qty, Cost, LineValue, LastSold`

The last row is a **Total** of LineValue (and CreditValue). LastSold is the month (`2023-03`) or `Over 5 years`.
**Export by branch** (shown when the lines span more than one branch) downloads one file per branch, named
`<title>-<branch>.csv`, to use as pick lists. Either export marks the document Exported. Tip: open the file in
Notepad to see it exactly; Excel drops leading zeros from part numbers on screen.
