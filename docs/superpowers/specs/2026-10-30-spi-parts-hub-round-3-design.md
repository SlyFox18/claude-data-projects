# SPI Parts Hub round 3: returns and scrap, One-Time templates, Cleanup checks (design)

> **Status:** design approved section by section by Brian, 2026-10-30 (brainstorm). Next: the implementation plan for
> phase 1 (Plan I, app 0.9.0). Phases 2 and 3 get their own plans when phase 1 has shipped.
> **Origin:** `projects/part order tool - app/FUTURE-IDEAS.md` F6 (returns and scrap), F8 (templates), F1 (Cleanup
> checks); Brian's scrap work for Ben, `projects/corp parts excel reports/Scrap/` (demand at other branches).
> **Context:** test phase. Saved documents are test data and may be deleted (Brian, 2026-10-30).

## Goal

Give users settings-driven tools instead of hard-coded terms:
- **Returns:** franchise return rules (allowance, no-sales period, credit %) re-used whenever a return is worked,
  company-wide, with a pre-pick up to the allowance and expected vs received credit.
- **Scrap:** franchise scrap rules, with the demand at other branches on every line and **Transfer instead** so only
  what truly has no home is scrapped.
- **Templates** for One-Time Orders, shared and editable, with a change history.
- **Cleanup checks** users build from conditions, so new checks need no release.

## Phases

| Phase | Version | Contents |
|---|---|---|
| 1 | 0.9.0 | Returns & scrap area, rules, New return / New scrap list, saved documents, holds, Fabric purchases table |
| 2 | 0.10.0 | One-Time templates with change history |
| 3 | 0.11.0 | Cleanup checks (condition builder), Equip stock value in the publish |

## Decisions (Brian, 2026-10-30)

| # | Decision |
|---|---|
| R1 | Return and scrap terms are **rules users edit in the app**, not hard-coded. Picking a franchise re-uses its rule. |
| R2 | Return rule fields: name, franchise; **allowance %** and **based on** (chosen per rule: last-12-months purchases from the franchise, current stock value, or the value of the qualifying parts); **no sales for** N months; **not received for** N months (optional); **smallest line value** (optional); **credit %**; leave-out switches (ManualOrder, parts with a minimum); season (optional). |
| R3 | **Company-wide** allowance per franchise: one return lists qualifying parts from every branch, each line with its branch. |
| R4 | The tool **pre-ticks the worst non-sellers first** (oldest last sale, then highest value) up to the allowance; a meter warns when over; saving is still allowed. Fixed pick order. |
| R5 | The CSV shows **cost, credit % and credit value**. |
| R6 | Returns and scrap are **saved documents** with statuses and archive (their own lists; see "Data", D1). |
| R7 | **Scrap rules**: franchise (or All), no sales for N months, smallest unit cost, leave-out switches. No allowance or credit. |
| R8 | **Demand elsewhere** on scrap and return lines: requests at other branches in the last **18 months** (a setting), with the branches named. |
| R9 | **Transfer instead** goes by default **all to the branch with the most demand**; the user can pick another branch with demand. |
| R10 | Open returns / scrap **hold stock in the app only**: marked where the part shows, kept off other return / scrap lists; Gold and the reference check are unchanged. |
| R11 | **Templates** are shared, anyone can edit, every save records who changed what. |
| R12 | **Cleanup checks**: a condition builder (field · comparison · value, all must match) over a fixed field list; return / scrap rules stay fixed forms. |
| R13 | Returns and scrap are their **own area**, "Returns & scrap", with a launch card. |
| R14 | Return statuses: Draft → Exported → **Sent to vendor** → **Credit received** (actual amount entered), plus an optional **RA number**. Scrap: Draft → Exported → **Scrapped**. Both: Cancel (until Sent / Scrapped), archive. |
| R15 | The **purchases** allowance base ships in phase 1 (a Fabric change). |
| R16 | **Transfer instead** is **on by default for scrap** lines with demand elsewhere and **off by default for returns** (demand still shown). |

## Phase 1 (0.9.0): returns and scrap

### Data

**D1. Their own SharePoint lists.** Saved orders are one branch per order (branch on the header); a company-wide
return spans branches, so returns and scrap get their own header / line lists instead of changing NonJD_Orders. The
Orders page stays orders only. Brian creates the lists; the plan gives the exact columns.

| List | Row | Columns |
|---|---|---|
| `NonJD_ReturnRules` | a rule | Kind (`Return` / `Scrap`), Title (name), Franchise (blank = all franchises, scrap only), Active, Archived, AllowancePct, AllowanceBase (`Purchases12` / `StockValue` / `QualifyingValue`), NoSalesMonths, NotReceivedMonths, MinLineValue, MinUnitCost, CreditPct, LeaveOutManualOrder, LeaveOutMinimum, SeasonStart, SeasonEnd (built-in Modified / Modified By) |
| `NonJD_Returns` | a saved return or scrap list | Kind, Title (`<franchise>-RET-<yyyymmdd>-<hhmm>` / `-SCR-`), Franchise, Status, RANumber, ExpectedCredit, CreditReceived, Archived, Parameters (JSON: the rule as applied, the demand window, the data date, the branches) |
| `NonJD_ReturnLines` | a line | ReturnId, Branch, Franchise, PartNumber, Description, Bin, Qty, Cost, LineValue, CreditPct, CreditValue, LastSold, DemandElsewhere (text, e.g. `1 (5), 3 (2)`) |

**D2. Fabric: purchases and last received.** A new Gold step (in `Build_Gold_NonJD_Reorder`'s DAG, after
`Silver_InTrans`) builds from InTrans purchase rows (Type `P`, purchases from suppliers):
- **12-month purchases at cost per branch and franchise** (the allowance base `Purchases12`), the 12 full months
  before the build's Central month, as the sales window does;
- **last received date per branch, franchise and part** (for "not received for").

Both are checked by `tools/dp-migration/nonjd_reorder_check.py` (0 differences on Dev and Prod) and published:
`purchases.json.gz` (branch, franchise, purchases12) and a `lastReceived` field per part in `reorder_<branch>.json.gz`.
Contract version 4; the app is deployed before the first v4 publish (the publish guard and the old app's lack of a
version check, as in v3). The exact InTrans columns and sign rules (returns to vendor netted or not) are settled in
the plan from the data, following `docs/architecture/dp-notebook-rules.md`.

**D3. Everything else** the screens need is already published: on hand, pending, cost, minimum, ManualOrder, app
transfers out, and 60 months of sales and requests per branch (`history_<branch>.json.gz`).

### The area

- **Launch card "Returns & scrap"**: "Vendor returns and scrap, by franchise rule." What's waiting: "N open returns ·
  N open scrap lists" (Draft or Exported); nothing when 0. Placed after Cleanup, before the Coming later cards.
- **Menu:** Returns (`/returns`), Scrap (`/scrap`), Return & scrap rules (`/return-rules`); document pages
  `/returns/:id` and `/scrap/:id`; the wizards `/returns/new` and `/scrap/new`.
- Returns and Scrap open on their saved documents, newest first, with **New return** / **New scrap list**, status
  pills and Show archived (as Transfer orders).

### Return & scrap rules

- One page, two tabs: **Return rules** and **Scrap rules**, built like Transfer rules: a table (name, franchise, the
  terms in one line such as "10% of 12-mo purchases · no sales 24 mo · credit 85%", season, Active, changed by / when)
  and an edit panel grouped **Which parts / Allowance / Credit / When**.
- **Validation:** percentages 0–100; NoSalesMonths 1–59 (the history holds 60 months); NotReceivedMonths blank or
  1–59; money fields blank or ≥ 0; season start and end both set or both blank (month and day; a season may wrap the
  year end).
- **One active return rule per franchise.** Saving a second active one asks: "Rule '<name>' is active for MM. Make
  this one active instead?" (the other is set inactive). **Scrap:** one active per franchise plus an optional active
  **All franchises** rule used where a franchise has none.
- **Try it** before saving, over every branch: return rule: qualifying parts, their value, the allowance in dollars
  and what the pre-pick would tick; scrap rule: qualifying parts and value, how many have demand elsewhere.
- Everyone can edit; archive, never delete.

### New return / New scrap list (three steps)

**Step 1, Set up.** Pick the franchise; its active rule is applied and shown in one line (link to the rule). Every
branch is ticked (excluded branches never appear); untick any. Outside the rule's season: a note, carry on allowed.
No active rule: "No return rule for MM yet" with **Create one**. The demand window (18 months) is shown and can be
changed for this document.

**Step 2, Parts.** One list across the ticked branches (the all-branch load used by transfers).

A line **qualifies** when, at that branch and franchise:
- available qty > 0, where **available = max(0, trunc(onHand) − max(0, trunc(pendingQty)) − appOutboundQty − held)**
  (held = qty on other open returns / scrap lists);
- **no units sold** in the last NoSalesMonths full months at that branch (history `sales`, indexes 1..N; the current
  partial month counts too: a sale this month disqualifies);
- not received in the last NotReceivedMonths (when set);
- return: line value (available × cost) ≥ MinLineValue (when set); scrap: cost ≥ MinUnitCost (when set);
- not left out (ManualOrder; a minimum > 0) when the switch is on.

**Columns:** Branch, Part, Description, Bin, Qty (starts at available; can be lowered, never raised), Cost, Value,
Credit (returns: value × CreditPct), Last sold (the newest month with units sold > 0, else "Over 5 years"),
**Demand elsewhere** (requests in the window at other branches, e.g. "1 (5), 3 (2)", busiest first), and Transfer
instead where there is demand elsewhere.

**Allowance (returns):** AllowancePct × base, where the base is the franchise's company-wide 12-month purchases
(sum of `purchases.json.gz` over the ticked branches), its stock value (trunc(onHand) × cost over the ticked
branches), or the qualifying lines' value. Measured against line value at cost.

**Pre-pick (returns):** lines sorted by last sold ascending (never sold first), then value descending, then branch
order and part number; each line is ticked if it still fits in the allowance, otherwise skipped (smaller lines below
may still fit). A meter shows "$4,820 of $5,000 allowance", red when over; saving is allowed. Scrap: every qualifying
line starts ticked.

**Transfer instead:** the line goes to the branch with the most requests in the window (ties: branch order); a select
lists the branches with demand and their counts. The line leaves the return / scrap totals. Default on for scrap,
off for returns (R16). A branch that doesn't allow receiving the part (its transfer rule's AllowReceive) isn't
offered.

Search, branch filter, sticky footer with totals, as on the transfer steps.

**Step 3, Review & save.** Totals (lines, value at cost, expected credit, allowance), and the transfers to be made
grouped From → To. **Save** writes the document (Draft) with its lines, and the transfer orders through the existing
transfer saver (Parameters `source: "Return"` / `"Scrap"` and the document title: "From Return "MM-RET-…""). Before
saving, the app re-reads open returns, scrap lists and transfers; if the stock was taken meanwhile nothing is saved
and it says what changed. Leaving with unsaved work asks first.

### Saved documents

- **Lists:** title, franchise, branches, lines, value, expected / received credit, status pill, saved by / when.
- **Return page:** Draft (amber) → Exported (blue) → Sent to vendor (green) → Credit received (dark green); Cancel
  until Sent (releases the hold). While Draft: lower a quantity or remove a line. **Export CSV** (Branch, PartNumber,
  Description, Bin, Qty, Cost, LineValue, CreditPct, CreditValue, LastSold; a totals row; the spreadsheet-formula
  guard) and **Export by branch** (one file per branch, as pick lists). **RA number** editable any time. **Mark credit
  received** asks for the amount, then shows "Expected $4,250 · Received $3,980 (94%)". Sent, Credited and Cancelled
  documents can be archived.
- **Scrap page:** Draft → Exported → Scrapped, Cancel, archive; the CSV without credit columns.
- A status change is refused if someone else changed the document first (as orders).

### Holds (R10)

Open documents (Draft, Exported) are read with the app's shared data. Their lines show an "On return <title>" /
"On scrap <title>" tag on Recommended Reorder lines, transfer suggestions and Part Lookup, and their qty is held
(left off other return / scrap lists). The order and transfer calculations don't change.

## Phase 2 (0.10.0): One-Time templates

- A template stores the One-Time Set up: branches, franchises, dealer groups, the period, factor, method, minimums,
  line limits, with a name and description. **Periods are stored relative** ("Rolling 12", "Full year 2025", or
  fixed months), so a Rolling template stays current.
- On Set up: **Start from template** (fills everything in), **Save as template**, **Update template**, Archive.
- Every save writes a change entry ("Shannon · Oct 30: loading factor 1.5 → 2; added franchise KU"); the template
  shows its history; starting from one changed since you last used it says "Changed by Shannon on Oct 30".
- Lists `NonJD_OneTimeTemplates` and `NonJD_TemplateChanges` (columns in the phase 2 plan).

## Phase 3 (0.11.0): Cleanup checks

- Cleanup lists its checks: the built-in **Minimums with no demand** and saved checks, each rows of
  field · comparison · value (all must match), with a name, description and author; Active / Archived.
- Fields: on hand, pending, cost, on-hand value, Equip stock value, minimum, maximum, sales 12 / 24 months, last
  requested, last received, status, franchise, dealer group, vendor, product group, SLC, source. Comparisons: = ≠ < ≤
  > ≥, is blank / is not blank, before / after (dates), one of (lists).
- Ben's "value without quantity" check needs Equip's own stock value: phase 3 adds it to Gold and the publish.
- Each check: branch filter, count, export CSV. List `NonJD_CleanupChecks` (conditions as JSON).

## Testing

- Pure engine functions with unit tests: qualifying, available qty, allowance, pre-pick, last sold, demand
  elsewhere, Transfer instead's default branch, holds; template periods (phase 2); conditions (phase 3).
- Fabric: the purchases / last-received Gold output checked by the reference script, 0 differences on Dev and Prod;
  `dag_check.py` and the deploy tests.
- Mock data with parts covering every case (never sold, sold this month, received recently, minimum, ManualOrder,
  demand at several branches, a receiver that can't receive, held by another document).
- Each version: a mock click-through for Brian, a review pass, a real test on Fedora, then cleanup of test rows.

## Out of scope

- Holding returned / scrapped stock in Gold and the reference (R10's full hold).
- A configurable pre-pick order; OR conditions in Cleanup checks; per-person areas.
- JD parts returns (the area can take them later).
