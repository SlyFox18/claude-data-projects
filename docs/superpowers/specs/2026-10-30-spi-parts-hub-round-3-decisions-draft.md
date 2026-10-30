# SPI Parts Hub round 3: returns, scrap, templates, Cleanup checks (decisions so far, draft)

> **Status:** brainstorm in progress (Brian, 2026-10-30). Paused for the 0.8.1 One-Time settings fix (Barry);
> resume after 0.8.1 ships. Not a spec yet: the design is still to be presented and approved.
> **Origin:** `projects/part order tool - app/FUTURE-IDEAS.md` F6 (returns and scrap), F8 (templates), F1 (Cleanup checks).

## Scope and phasing

One design, built in phases, each shipped as its own version:
1. a shared rules framework + **returns and scrap** (with demand elsewhere and Transfer instead);
2. **One-Time templates**;
3. **Cleanup checks** (condition builder).

## Decisions (Brian, 2026-10-30)

| # | Decision |
|---|---|
| R1 | Return terms are **rules users edit in the app**, not hard-coded (they vary by franchise and change). Picking a franchise re-uses its rule. |
| R2 | Return rule fields: name, franchise (one active rule per franchise; archive old ones); **allowance %** and **based on** (D: chosen per rule from last-12-months purchases from the franchise, current stock value, or value of the qualifying parts); **no sales for** N months; **not received for** N months (optional); **smallest line value** (optional); **credit %**; leave-out switches (ManualOrder, parts with a minimum); season / active dates (optional). Brian: "looks good". |
| R3 | **Company-wide** allowance per franchise (B): one return lists qualifying parts from every branch; each line shows its branch. |
| R4 | Over the allowance (C): the tool **pre-ticks the worst non-sellers first** (oldest last sale, then highest value) up to the allowance; a meter warns when over, saving is still allowed. Fixed pick order for now. |
| R5 | The CSV shows **cost, credit % and credit value**. |
| R6 | Returns and scrap are **saved like orders** (Orders list with a type: Order / Return / Scrap), with archive. |
| R7 | **Scrap rules** use the same editor minus allowance and credit: franchise (or All), no sales for N months, smallest unit cost (Ben's list: $0.10), leave-out switches. |
| R8 | **Demand elsewhere** on scrap and return lines: requests at other branches in the last **18 months** (a setting), with the branches named (as `projects/corp parts excel reports/Scrap/`). Note: the app's history counts requests, not the workbook's netted-invoice rule, so the figures are close but not identical. |
| R9 | **Transfer instead**: a line with demand elsewhere goes by default **all to the branch with the most demand** (A); the user can change the branch from a list of branches with demand and their counts. Saving makes real transfer orders through the existing saver. |
| R10 | Saved returns / scrap **hold stock in the app only** (B): the app marks those lines ("On return …") on transfer suggestions and reorder lines and keeps them off other return / scrap lists; Gold and the reference check don't change. Full hold (Gold + reference + engine) can come later. |
| R11 | **Templates (F8)** are shared, anyone can edit; each save records who changed what, shown on the template. |
| R12 | **Cleanup checks (F1)**: approach 2: a **condition builder** (rows of field · comparison · value, all must match; OR later) over a fixed list of ~20 part fields, saved by name with a description; return / scrap rules stay fixed forms. |

## Data notes

- Purchases from suppliers are InTrans Type `P` (already in Silver_InTrans): allowance base "purchases" needs a 12-month
  purchases-by-franchise figure added to Gold and the publish.
- Everything else (on hand, cost, sales 12/24, lastRequested, 60 months of sales and requests per branch) is already
  published.

## Still to decide

- Where returns and scrap live (assumed: a new **Returns & scrap** area on the launch page).
- Template fields and the change-log format; Cleanup field list and comparisons.
- The approaches / design presentation, then the spec.
