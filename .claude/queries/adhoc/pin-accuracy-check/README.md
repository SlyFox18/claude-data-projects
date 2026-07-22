# Pin Capture - Accuracy Feasibility Check (Ad Hoc)

**Requested by:** Brian, 2026-07-22
**Purpose:** A Parts team member asked whether captured PIN numbers on the Pin
Capture report are actually *correct*, not just present. The production
report (`Fact_PinTransactions`) only flags whether `PinNo`/`Notation` is
non-blank - it never validates the value against anything. This is a
feasibility pull to see whether real validation is possible, and to give
Brian line-level data to review before deciding whether to invest in
building it into the report.

## Method

`build_report.py` queries `LH_Master_Data` directly via DuckDB over OneLake
(`delta_scan`, Azure CLI credential chain) - no dataflow/notebook needed for
a one-off feasibility check.

- **Population:** `InTrans_Incremental` lines, last 24 months, `Type IN
  ('I','C')` - the same filter `Fact_PinTransactions.pq` uses - where `PinNo`
  is non-blank.
- **"Known PIN" pool:** `WKVEHFL.VIN` + `vhstock.VIN`, combined and
  normalized (upper, strip spaces/dashes). These are genuine John Deere
  Product Identification Numbers - the "VIN" column name is legacy DMS
  naming, not an automotive VIN.
- **IsKnownPin:** does the normalized captured `PinNo` exist anywhere in
  that pool?
- **Owner match:** for lines where `PinNo` matched a known VIN, pull that
  equipment's registered owner (`WKVEHFL.AccountNumber` or
  `vhstock.OwnerContactCode`) and compare to the invoice's own `CustomerNo`.

## Important caveat baked into the data: `OwnerSource`

`vhstock.OwnerContactCode` uses a different (name-based, alphanumeric)
customer coding scheme than the AR `CustomerNo` used everywhere else (e.g.
`ROSSHILLC2190` vs. a numeric account like `72067`). A mismatch against a
vhstock-sourced owner is **not** reliable evidence of a wrong PIN - it's
just two different ID systems being compared. `WKVEHFL.AccountNumber` uses
the same numbering scheme as `CustomerNo`, so those mismatches are the
meaningful ones. The `Detail` tab's `CustomerOwnerCheck` column already
separates these out ("Mismatch" only applies to WKVEHFL-sourced owners;
vhstock-sourced owners are labeled "Not Comparable (different ID scheme)").

## Paths tested and ruled out

- `InTrans.StockNo` (candidate join key): **0% populated** on parts lines -
  dropped entirely.
- `RONumber -> wkothsub.InvoiceNumber -> WorkOrder -> WKROFILE.Registration
  -> WKVEHFL`: tested and found **0 matches** across 13,278 pin-captured
  invoices. PIN capture happens almost entirely on plain parts-counter
  invoices, not RO-linked transactions, so this path doesn't apply to this
  population.
- `MachineId` (a field on the parts line): turned out to be a free-text
  nickname staff type in (often customer name + partial PIN digits), not a
  system key. Matches `WKVEHFL.Registration` directly ~66% of the time but
  doesn't add an independent signal beyond the direct PIN match already
  used here.
- The direct normalized-PIN-against-known-VIN-pool match (what this script
  uses) needs no join through invoice/work-order tables at all - by far the
  simplest usable signal found.

## Results (2026-07-22 run, corrected)

| Stage | Count | % of prior stage |
|---|---|---|
| Total parts lines (24mo, Invoice/Credit) | 1,375,968 | - |
| Lines with a PIN captured | 39,018 | 2.8% of total |
| PIN matches a known real equipment PIN | 24,721 | 63.4% of captured |
| - of which, owner is WKVEHFL-comparable | 24,209 | 97.9% of known-PIN matches |
| - Customer matches registered owner (Match) | 20,190 | 83.4% of WKVEHFL-comparable |
| - Customer does NOT match registered owner (Mismatch) | 3,944 | 16.3% of WKVEHFL-comparable |

**End to end:** ~52% of all pin-captured lines (20,190 / 39,018) are a
verified "real PIN, correct customer" match. ~37% of captured PINs don't
match any known equipment PIN at all (could be typos, equipment not in our
system, or genuinely wrong entries - not yet distinguished).

An earlier pass of this analysis (same day) produced inflated match figures
(~77%/~70%) due to a join fan-out bug - a normalized PIN matching more than
one equipment record (e.g. present in both WKVEHFL and vhstock) caused
those pin-captured lines to be double-counted. The numbers above are from
the corrected version of `build_report.py`, which dedupes to exactly one
row per original transaction line via a `ROW_NUMBER()` keyed on a synthetic
per-row `LineId`, not on business columns that can collide across
legitimately distinct lines.

## Branch breakdown

Brian requested this because a specific branch had raised the original
question; a full branch breakdown was pulled so that branch's numbers could
be seen in context against the rest of the network rather than in isolation.
25 branches have parts-invoice volume (a handful of internal shop-suffix
codes - `15I`, `4I`, `8I`, `13S`, `15S`, `11S` - carry effectively zero
volume and are not meaningful).

| Branch | Captured | Capture Rate | Known-PIN Match | Owner Match Rate | End-to-End Accuracy |
|---|---|---|---|---|---|
| 11 - Brownfield | 6,095 | 4.0% | 75.0% | 83.5% | 62.5% |
| 1 - Seminole | 5,161 | 3.8% | 50.7% | 74.9% | 36.4% |
| 4 - Mesquite | 5,102 | 5.3% | 62.4% | 84.7% | 51.5% |
| 3 - Denver City | 3,759 | 7.8% | 62.3% | 89.7% | 55.5% |
| 8 - Big Spring | 3,339 | 3.0% | 41.4% | 63.4% | **24.4%** |
| 2 - Tornillo | 3,066 | 2.9% | 49.9% | 86.6% | 41.9% |
| 13 - Lamesa | 2,770 | 3.0% | 72.6% | 86.1% | 60.3% |
| 16 - Morton | 1,858 | 3.6% | 75.5% | 88.3% | 65.9% |
| 92 - Slaton | 1,350 | 2.4% | 83.6% | 82.5% | 68.9% |
| 17 - Tahoka | 1,134 | 3.2% | 80.1% | 92.3% | **73.2%** |
| 15 - Levelland | 1,115 | 1.9% | 73.0% | 91.6% | 65.8% |
| 94 - Crosbyton | 842 | 2.6% | 70.8% | 89.3% | 61.5% |
| 7 - Ballinger | 785 | 3.6% | 59.1% | 94.3% | 56.4% |
| 96 - Snyder | 662 | 0.9% | 61.3% | 78.2% | 46.5% |
| 14 - Littlefield | 633 | 1.6% | 82.3% | 76.4% | 62.2% |
| 91 - Lorenzo | 540 | 0.8% | 63.5% | 75.0% | 46.7% |
| 93 - Lubbock | 312 | 0.5% | 48.4% | 68.0% | 32.1% |
| 95 - Abernathy | 269 | 0.5% | 78.1% | 79.8% | 60.2% |
| 6 - San Angelo | 226 | 0.3% | 64.2% | 86.8% | 52.2% |

**Standouts:**
- **Big Spring (8)** is the clear outlier - lowest end-to-end accuracy
  (24.4%) of any branch with real volume, driven by both a weak known-PIN
  match rate (41.4%) and the weakest owner-match rate (63.4%).
- **Seminole (1)** and **Lubbock (93)** are also notably below the network
  (36.4%, 32.1%).
- **Tahoka (17)** and **Slaton (92)** are the strongest performers (73.2%,
  68.9%) - worth understanding what those branches do differently.
- PIN **capture rate** itself varies ~20x across branches (0.3% at San
  Angelo vs. 7.8% at Denver City) - a separate, likely larger, problem from
  accuracy that the existing report already surfaces.

## Output

`Pin Capture - Accuracy Check (Last 24 Months).xlsx`

- **Summary** tab: the funnel counts above.
- **By Branch** tab: the branch breakdown table above, plus raw counts
  (`TotalLines`, `PinCaptured`, `KnownPinMatch`, `WKVEHFLComparable`,
  `OwnerMatch`, `OwnerMismatch`) behind each rate.
- **Detail - PIN Captures** tab: one row per pin-captured line (39,018
  rows) - TransDate, Branch, RONumber, CustomerNo, BillToAcc, PartNumber,
  Description, SaleValue, PinNo, Notation, IsKnownPin, matched equipment
  Make/Model/Registration, OwnerSource, RegisteredOwnerAccount, and
  CustomerOwnerCheck (Match / Mismatch / Not Comparable / No Match). Filter
  and sample this tab to sanity-check plausibility before deciding whether
  to build this into the report.

Run manually - not part of any scheduled pipeline. Requires `az login` and
`fab auth login` to be active.

## Path to production (if Ben wants this built into the report)

This was a read-only feasibility pull against existing Lakehouse tables -
nothing here is wired into any dataflow or the Pin Capture semantic model.
To bring it into the actual report:

1. **Build a `lookup_EquipmentPins` dimension** (new Dataflow Gen2 in
   `03 - Dimensions`, same pattern as `lookup_UniqueCustomers_Invoice` -
   see [Dimension Flagging via Lookup Tables](../../../CLAUDE.md)). Source:
   `WKVEHFL.VIN` + `vhstock.VIN`, normalized (upper, strip spaces/dashes) as
   the key, carrying `OwnerAccount` and `OwnerSource` (`WKVEHFL` or
   `vhstock`). Both source tables already refresh daily in the Master
   Orchestrator pipeline (Phase 1), so this dimension can slot into Phase 3
   with no new source ingestion.
2. **Add calculated columns to `Fact_PinTransactions`** using `LOOKUPVALUE`
   against the new lookup table (no model relationship - consistent with
   existing repo convention): `Is Known Pin` and `Customer Owner Check`.
   `PinNo`, `CustomerNo`, and `Branch` are already on the fact table today -
   no change needed to the partition query itself.
3. **Resolve the `OwnerSource` comparability gap before publishing a single
   headline number.** `vhstock.OwnerContactCode` (name-based) can't be
   compared to `CustomerNo` (numeric AR account) directly - either exclude
   vhstock-sourced matches from the "wrong customer" calculation (as this ad
   hoc check does) or find/build a real cross-reference between
   `OwnerContactCode` and AR customer number if one exists in the source
   system.
4. **Manually sample the ~37% "No Match" bucket before treating it as an
   accuracy failure.** It currently conflates three different things:
   genuinely wrong/fabricated PINs, typos, and real equipment that's simply
   not in `WKVEHFL`/`vhstock` (older units, non-Deere attachments, equipment
   bought elsewhere). The `Detail` tab's "No Match" rows are the starting
   point for that review.
5. **New report surface:** likely a new measure (`% PIN Accuracy`, mirroring
   the existing `% Transactions with Pin`) and a branch-level breakdown
   table (mirroring the existing Branch Summary page), possibly with a
   hidden drillthrough into "Suspect PIN" lines for QA use - similar
   structure to the existing Overview / Branch Summary / Transaction Detail
   / Transaction Drill Through pages.
6. **Get Ben's sign-off** on the definition before it becomes a report KPI -
   in particular whether "accuracy" should be scored against the full
   captured population (currently 51.8% - includes the "No Match" bucket as
   failures) or only against PINs that resolve to a known machine (83.4% -
   treats "No Match" as a separate, uninvestigated category rather than an
   automatic fail). Those two framings tell very different stories and
   should be a deliberate choice, not a default.
