/*
============================================================================
Dimension: dim_BranchPartInventory
Dataflow: df_Dim_BranchPartInventory
Location: LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

PURPOSE:
Current on-hand and bin quantities, by branch, for parts the Combine Vault
(Branch 12) has actually transferred to that SPECIFIC branch. Lets the
Combine Vault Sales report show whether a destination branch still has any
of a transferred part in stock, or whether it's since sold/moved.

GRAIN:
  One row per Branch + PartNumber — but ONLY for (Branch, PartNumber) pairs
  that appear together in Fact_Branch12_Transactions (see SCOPE).

SOURCE TABLES (Lakehouse):
  jdis_Part_Information      — parts master; has on-hand/bin qty per branch
                                (refreshed 3x daily: 7:30 AM, 9:30 AM, 4:00 PM)
  Fact_Branch12_Transactions — defines which (Branch, PartNumber) pairs are
                                in scope, via TransferBranch + PartNumber

SCOPE (IMPORTANT — do not loosen this to "any branch, any vault part"):
  - Branch 12 excluded. The vault's own on-hand/bin data already lives in
    dim_Branch12_Parts and is surfaced via the "(Vault Total)" measures —
    this table is for every OTHER branch.
  - Joined on the COMPOUND key (TransferBranch, PartNumber), not PartNumber
    alone. A part the vault transferred to Seminole but never to Ballinger
    should only produce a Seminole row here, not a Ballinger row just
    because Ballinger happens to independently stock the same part.
  - Earlier version of this query joined on PartNumber only, which let in
    every branch that carries a given vault part regardless of whether the
    vault ever actually shipped it there. That surfaced as extra "clutter"
    rows on the report with real inventory numbers but no transfer history.
    DAX-side row filtering (measure gating, visual-level filters) was tried
    to suppress those clutter rows and reliably corrupted the report's
    Grand Total for unrelated measures — this data-level compound-key scope
    is the fix, and avoids needing any filtering in the report at all.
  - KNOWN, ACCEPTED LIMITATION: a branch whose only TransferBranch-tagged
    row for a part is an inbound (IsSale = FALSE) inventory addition will
    still show up here with a real QuantityOnHand, even though it has no
    genuine outbound-transfer history (blank Demands/Days-Last-Sale on the
    report). Confirmed via AH163056 / Branch 95 (Abernathy): its only two
    TransferBranch=95 rows were both IsSale = FALSE.
    An IsSale = TRUE condition was added here on 2026-07-07 to close this
    gap (matching how Demands/Days-Last-Sale are filtered) and was REVERTED
    the same day — it reliably corrupted the report's Grand Total for
    unrelated Vault Total measures, just like the earlier DAX-side gating
    attempts did, for reasons not fully understood (see Combine Vault
    Sales/CLAUDE.md). Tightening this scope further is not safe without
    first understanding that mechanism. The occasional stray zero-value
    branch row is the accepted trade-off for a correct Grand Total.

OUTPUT COLUMNS:
  Branch           — Branch code
  PartNumber       — Part number
  QuantityOnHand   — Current on-hand qty at that branch (pi_On_Hand_Qty)
  BinQty           — Current bin qty at that branch (pi_Bin_Qty)

USAGE IN REPORTS:
  Combine Vault Sales → "Greater than Zero" page. In DAX (no model
  relationship needed — dim_BranchPartInventory is a standalone lookup
  table, matched via a filtered SUMX rather than LOOKUPVALUE since a
  dim_BranchLocation[Branch] display label can map to several BranchIDs):

    Qty on Hand (By Location) =
    IF(
        HASONEVALUE(dim_BranchLocation[Branch]),
        VAR CurrentBranchIDs = VALUES(dim_BranchLocation[BranchID])
        VAR CurrentPart = SELECTEDVALUE(dim_Branch12_Parts[PartNumber])
        RETURN
            SUMX(
                FILTER(
                    dim_BranchPartInventory,
                    dim_BranchPartInventory[PartNumber] = CurrentPart
                        && dim_BranchPartInventory[Branch] IN CurrentBranchIDs
                ),
                dim_BranchPartInventory[QuantityOnHand]
            ),
        BLANK()
    )

DATAFLOW PLACEMENT:
  Workspace:  LH_Master_Data
  Layer:      03 - Dimensions
  Dataflow:   df_Dim_BranchPartInventory
  Target:     LH_Master_Data Lakehouse → dim_BranchPartInventory table
  Refresh:    Daily, Phase 3 (after jdis_Part_Information raw refresh,
              alongside dim_Branch12_Parts). Depends on
              Fact_Branch12_Transactions for (Branch, PartNumber) scoping,
              so it must run after that fact refreshes (Phase 4) — place
              this dataflow in Phase 4/5 alongside or just after
              Fact_Branch12_Transactions, not with the earlier 7:45 AM
              dimensional wave.

CREATED: 2026-07-06
UPDATED: 2026-07-07 — scoped to (TransferBranch, PartNumber) compound key
  instead of PartNumber alone, to eliminate clutter rows at the data level.
UPDATED: 2026-07-07 — added, then reverted same day, an IsSale = TRUE
  condition on the compound-key scope. It fixed the inbound-only-row
  clutter case but corrupted the Grand Total worse than the clutter it
  fixed. See SCOPE note above.
============================================================================
*/

let
    // ========================================================================
    // STEP 1: TRANSFER SCOPE — (Branch, PartNumber) pairs the vault actually
    // shipped to that specific branch
    // ========================================================================
    // NOTE: an IsSale = TRUE condition was tried here (2026-07-07) to exclude
    // branches whose only TransferBranch-tagged rows are inbound (non-sale)
    // additions. It was reverted — see SCOPE note below — because it
    // reliably corrupted this report's Grand Total for unrelated measures,
    // the same failure mode DAX-side gating produced earlier. Do not re-add
    // it without first understanding why tightening this scope further
    // breaks Vault Total measures that don't even reference this table.
    VaultTransferPairs = Table.Distinct(
        Table.SelectColumns(
            Table.SelectRows(Fact_Branch12_Transactions, each [TransferBranch] <> null),
            {"TransferBranch", "PartNumber"}
        )
    ),

    // ========================================================================
    // STEP 2: LOAD PARTS MASTER FOR ALL BRANCHES, EXCLUDE BRANCH 12
    // ========================================================================
    Source = jdis_Part_Information,
    FilterNotVault = Table.SelectRows(Source, each [Branch] <> "12"),

    // Keep only (Branch, PartNumber) pairs with real transfer history —
    // compound-key inner join, not PartNumber alone
    ScopedToTransferPairs = Table.NestedJoin(
        FilterNotVault, {"Branch", "PartNumber"},
        VaultTransferPairs, {"TransferBranch", "PartNumber"},
        "TransferMatch", JoinKind.Inner
    ),
    RemoveMatchColumn = Table.RemoveColumns(ScopedToTransferPairs, {"TransferMatch"}),

    // ========================================================================
    // STEP 3: FINAL COLUMN SET AND TYPES
    // ========================================================================
    SelectColumns = Table.SelectColumns(RemoveMatchColumn,
        {"Branch", "PartNumber", "QuantityOnHand", "BinQty"}),

    Typed = Table.TransformColumnTypes(SelectColumns, {
        {"Branch",         type text},
        {"PartNumber",     type text},
        {"QuantityOnHand", type number},
        {"BinQty",         type number}
    }),

    Sorted = Table.Sort(Typed, {
        {"PartNumber", Order.Ascending},
        {"Branch",     Order.Ascending}
    })

in
    Sorted
