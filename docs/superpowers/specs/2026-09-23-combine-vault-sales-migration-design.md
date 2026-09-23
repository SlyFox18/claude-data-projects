# Combine Vault Sales Migration — Design Spec

## 1. Problem Statement

`Combine Vault Sales` is the third and last of 3 remaining Parts reports
Brian is working through this batch (First Pass Fill and MD Invoices With
No Freight both complete), per his own "easiest first" sequencing. It was
deliberately deferred earlier this project — both the dims catalog audit
(`dim_BranchPartInventory`/`dim_Branch12_Parts`) and the facts catalog audit
flagged it as blocked on a real circular dependency between
`Fact_Branch12_Transactions` and `dim_Branch12_Parts`, needing a real
build-order decision before it could be tackled.

Real investigation (full reads of all 3 real production dataflows, TMDL
greps against the report's current tables, `fab ls`/`dp_backend_scope.json`
checks against `DP_Presentation`) confirmed:

- **The "circular dependency" is not a true blocking cycle.**
  `df_Fact_Branch12_Transactions.Dataflow` joins `dim_Branch12_Parts` only
  to look up `PartNumberKey` for each transaction.
  `df_Dim_Branch12_Parts.Dataflow` joins `Fact_Branch12_Transactions` only
  to compute R12 sales metrics (`Demands`, `R12_Sales_Qty`,
  `R12_Sales_Dollars`) per part. Each dataflow reads the *other's last
  materialized Lakehouse table* via `Lakehouse.Contents`, not a live
  in-transaction join — production resolves this today by daily refresh
  order alone (eventually consistent, one day stale in the worst case).
- **`dim_Branch12_Parts.PartNumberKey` is a fragile sequential index**
  (`Table.AddIndexColumn` over alphabetically-sorted parts, regenerated
  from scratch every refresh) — the same shift-risk pattern already flagged
  as a real, confirmed incident elsewhere in this project (`CustomerKey`).
  Brian confirmed (2026-09-23): fix this now rather than port it faithfully,
  since new key-generation logic is needed here regardless.
- **Replacing the sequential index with a stable hash of `PartNumber`
  eliminates the circular dependency entirely**, not just makes it
  eventually consistent. If both the fact and the dimension compute
  `PartNumberKey` via the same deterministic formula, the fact no longer
  needs to join the dimension at all — it computes its own key. The real
  dependency graph becomes one-directional: Fact → (dim_Branch12_Parts,
  dim_BranchPartInventory).
- **`dim_BranchPartInventory` has no circular dependency** — it already
  only reads `Fact_Branch12_Transactions` (for compound-key scoping) and
  `jdis_Part_Information`/`Silver_PartInformation`, one direction. Its real
  production dataflow includes an extensively-documented history of a
  clutter-row problem and 2 reverted attempts to tighten the join with an
  `IsSale = TRUE` condition (both corrupted the report's Grand Total for
  unrelated measures, root cause not fully understood) — this spec
  faithfully preserves the current, accepted compound-key-only join, no
  attempt to "fix" the known, accepted stray-zero-row limitation.
- **Nothing exists yet in `DP_Presentation`** for any of the 3 tables
  (confirmed via `fab ls` and a `dp_backend_scope.json` grep) — this is
  genuinely new Gold-layer work, not a registration gap like MD Invoices.
- **Real sources already available**: `Silver_InTrans` and
  `Silver_PartInformation` are both already shortcut into `DP_Presentation`
  (confirmed via `fab ls`), so no new Silver-layer work is needed.
- **`dim_DateTable[IsRolling365Days]`** is used by the `Sales R12` measure
  (explicitly flagged as a "check this still exists" gotcha in the report's
  own `CLAUDE.md`) — the same "today-relative column dropped from
  `DP_Presentation.dim_DateTable`" risk class hit twice already this
  project (Pin Capture, First Pass Fill), confirmed clean once (MD
  Invoices). Built into this spec from the start rather than discovered via
  a failed Desktop refresh.

## 2. Scope

**In scope:**
1. Build `Build_Gold_Branch12Transactions.Notebook` → `Fact_Branch12_Transactions`,
   self-contained (no dependency on any Branch12 dimension).
2. Build `Build_Gold_Branch12Parts.Notebook` → `dim_Branch12_Parts`,
   depends on the fact above (built first) for R12 metrics.
3. Build `Build_Gold_BranchPartInventory.Notebook` → `dim_BranchPartInventory`,
   depends on the fact above.
4. Register all 3 in `deploy/dp_backend_scope.json` (tier=gold, cadence=daily)
   from the start.
5. Repoint the report's 6 real data tables (`Fact_Branch12_Transactions`,
   `dim_Branch12_Parts`, `dim_BranchLocation`, `dim_BranchPartInventory`,
   `dim_DateTable`, `dim_Parts`), with the same exhaustive usage-audit-
   before-trim discipline used on every other report this project, and the
   `dim_DateTable` real-schema cross-check built in from the start.

**Explicitly out of scope:**
- Any change to the real production `df_Fact_Branch12_Transactions.Dataflow`,
  `df_Dim_Branch12_Parts.Dataflow`, or `df_Dim_BranchPartInventory.Dataflow`
  — all left running/as-is.
- "Fixing" `dim_BranchPartInventory`'s known, accepted stray-zero-row
  limitation (the reverted `IsSale = TRUE` attempts) — faithfully preserved,
  not revisited.
- `Stock Status Categories` and `YTD Metrics` — confirmed local/calculated
  tables, nothing to migrate.
- This is the last report in this informal 3-report batch; no further
  sequencing decisions needed after this one (`Job Code Parts Advisor` and
  `Labor Performance V2` remain separately unscheduled, per the catalog
  doc).

## 3. Architecture

### 3.1 `Build_Gold_Branch12Transactions.Notebook`

Faithful port of `df_Fact_Branch12_Transactions.Dataflow`'s real business
logic — nothing here is wrong or needs fixing, just ported:
- Source: `Silver_InTrans`, filtered to `Branch = '12'` and a 3-year rolling
  window, using the same DST-safe US/Central "now" fix already applied on
  `Build_Gold_FirstPassFill.Notebook` (replacing the original's naive
  `DateTime.LocalNow()`).
- `IsSale`/`IsTransfer` flags, `SalesQty`/`InventoryAddQty`,
  `CostValue`/`SaleValue`/`MarginDollars`/`MarginPercent` sign-correction
  logic ported exactly (negative `Qty` = sale, positive = inventory
  addition; cost values flip sign for sales).
- `PartNumberKey` computed as a stable hash of the cleaned
  (uppercased/trimmed) `PartNumber` (e.g. `xxhash64`) — **not** looked up
  from `dim_Branch12_Parts`. This is the one real departure from the
  original logic, and it's what breaks the circular dependency. A reserved
  sentinel value (`-1`, matching the original's "Unknown" convention) is
  used only for blank/null `PartNumber`.

### 3.2 `Build_Gold_Branch12Parts.Notebook`

Faithful port of `df_Dim_Branch12_Parts.Dataflow`, with the same
`PartNumberKey` change:
- Source: `Silver_PartInformation` filtered to `Branch = '12'`, plus the
  now-built `Fact_Branch12_Transactions` for R12 metrics (`Demands`,
  `R12_Sales_Qty`, `R12_Sales_Dollars` — last 365 days, `IsSale = true`
  only, left-joined back so parts with no sales still appear with zeroed
  metrics).
- `PartNumberKey` computed via the exact same hash formula as the fact, so
  the two align without either reading the other's specific prior state.
  The "Unknown" placeholder row keeps its literal `PartNumberKey = -1`,
  matching the fact's own null-guard sentinel.
- All other columns (inventory snapshot, pricing, classifications,
  `IsAvailable`/`HasRecentSales`/`IsReturnable` flags, unit margin calcs)
  ported as-is.

### 3.3 `Build_Gold_BranchPartInventory.Notebook`

Faithful port of `df_Dim_BranchPartInventory.Dataflow` — no logic changes:
- Source: `Silver_PartInformation` excluding Branch 12, inner-joined to
  the compound key `(TransferBranch, PartNumber)` derived from
  `Fact_Branch12_Transactions`, scoping the dimension to only the
  (branch, part) pairs the vault has actually transferred.
- Deliberately **no** `IsSale` condition on the join — this was tried twice
  in production and reverted both times for corrupting the report's Grand
  Total in ways not fully understood. Preserved exactly as-is, including
  the documented known/accepted stray-zero-row limitation.

### 3.4 Report-layer repoint

Standard exhaustive real-usage audit (`pbir` + DAX-grep + bookmark check +
`relationships.tmdl` cross-reference) across all 6 real data tables.
`dim_DateTable` gets the same explicit extra step used on every prior
report: cross-check every DAX-confirmed-used column (starting from the
known `IsRolling365Days` usage) against the real 14-column
`DP_Presentation.dim_DateTable` schema before trimming — any genuinely used
"today-relative" column gets restored as a DAX calculated column sourced
from `'Data Refresh'[Date]`, replicating the exact original logic from
`LH_Master_Data/Dataflows/03 - Dimensions/df_Dim_Date.Dataflow`.

## 4. Verification Plan

1. **`Fact_Branch12_Transactions`**: row count and a sample of
   `SaleValue`/`MarginDollars`/`IsSale` values compared against real
   production, via DuckDB.
2. **`dim_Branch12_Parts`**: row count comparison; spot-check that
   `PartNumberKey` values are stable across 2 consecutive notebook runs
   (proving the hash-based key is genuinely deterministic, not just
   assumed to be).
3. **`dim_BranchPartInventory`**: row count and a compound-key spot-check
   (confirm no (Branch, PartNumber) pair exists without a real transfer
   record in the fact) against real production.
4. **Post-migration**: Brian's standard Desktop pull/refresh/publish/
   visually-confirm cycle, then the standard post-publish DuckDB row-count
   check across all 3 new backend tables plus the 3 shared dimensions
   already live elsewhere (`dim_BranchLocation`, `dim_DateTable`,
   `dim_Parts`).

## 5. What This Spec Deliberately Does Not Cover

- `dim_BranchPartInventory`'s known, accepted stray-zero-row limitation —
  confirmed out of scope, not revisited.
- A broader audit of `dim_Branch12_Parts` ↔ `dim_Parts`'s bidirectional
  relationship (flagged as a performance risk in the report's own
  `CLAUDE.md`) — a report-layer modeling concern, not a backend migration
  concern; left as-is unless it blocks the repoint itself.
- `Job Code Parts Advisor` and `Labor Performance V2` — separately
  unscheduled, not part of this batch.
