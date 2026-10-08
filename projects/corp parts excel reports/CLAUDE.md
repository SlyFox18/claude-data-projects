# Corp Parts Excel Reports — Claude Context

Excel workbooks Brian builds for the Corp Parts team (Ben — Corp Parts Manager,
Barry, Curt). They live in a SharePoint library and each user refreshes them on
demand; Ben brings Brian small changes, Brian edits the query here and pastes it
into the workbook.

- **SharePoint:** https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite →
  **Corp Parts Excel Reports** library
- **Brian's synced copy:** `C:\Users\bfox\spitractor\South Plains Implement - Report Site - Corp Parts Excel Reports\`
- **Connection:** `dsn=EquipRDB` (standardized 2026-09-15 — Ben/Brian have this DSN;
  don't use `EquipRDB64` in these workbooks)
- **Access pattern:** one person at a time, not simultaneous co-authoring

## Workbook → query map

One folder per workbook, one `.pq` per Power Query, named exactly like the query
object inside the workbook.

| Workbook (SharePoint) | Folder | Queries | Source | Notes |
|---|---|---|---|---|
| Border Stores.xlsx | `Border Stores/` | `Border Stores` | live ODBC | candidate branches 95/91/96 vs. everyone except 2 & 4 (asymmetric by design) |
| 2 & 4 Cotton & Stripper Parts.xlsx | `2 & 4 Cotton & Stripper Parts/` | `2 & 4 Cotton & Stripper Parts` | live ODBC | Border Stores logic at branches 2 & 4; COTTON/STRIPPER/PICKER + cross-branch 690/770 model codes |
| COTTON 2026 TROUBLE PARTS.xlsx | `COTTON 2026 TROUBLE PARTS/` | `PartData` | live ODBC | Barry's sheet; company-wide part lookup (on order / R12 sales / bin qty) |
| MLPF Gaps.xlsx | `MLPF Gaps/` | `MLPF Gaps` | live ODBC | exactly 2 demands, all branches except 12, superseded parts excluded |
| SPI-Pieces In Set.xlsx | `SPI-Pieces In Set/` | `SPI - Pieces In Set`, `SPI - Pieces In Set - Filtered`, `SPI -Pieces In Set Review` | live ODBC (+ workbook table) | set-size detection + reorder rec; Review = InMaster PIS > 1 but Match % < 75% |
| SPI Corparate Stocking.xlsx | `SPI Corparate Stocking/` | `SPI Corparate Stocking` | file written by `build_report.py` (reads DP Prod) | **refresh ≠ new data** — see its README |

`_reference/` = business reference docs (commodity code groups PDF).
`_archive/` = pre-split docs and old workbook copies (`*.xlsx` here is gitignored).

## Change workflow

1. Edit the `.pq` in this folder (header notes included — every file carries its
   own PURPOSE / CRITERIA / NOTES / UPDATED log).
2. Test the SQL against the live source before handing it over (pull the SQL out
   of the `.pq` and run it via `pyodbc` `DSN=EquipRDB64` from Python — same database).
3. Brian pastes the whole file into the workbook's Advanced Editor.
4. **The workbook is the source of truth.** If unsure whether this folder still
   matches, extract the live query from the `.xlsx` (Power Query lives in
   `customXml/item*.xml` → base64 `DataMashup` → `Formulas/Section1.m`) and diff.
   Copy the workbook to the scratchpad first with PowerShell `Copy-Item` — files
   open in Excel are locked, and git-bash file ops misbehave in the OneDrive folder.

## Gotchas (all hit for real)

- **Workbook formula columns depend on query column names.** `SPI-Pieces In Set.xlsx`
  appends 7 formula columns (Tier, PIS Class, Dup Branch+Part?, On Buy List?, Stock
  Position, Months of Supply, Coverage Flag) to the query table, driven by settings
  sheets (Confidence Tiering, Buy List, Coverage & Stock). Renaming an output column
  (e.g. `Bin Qty`, `Sales Qty`, `Match %`) breaks them. Adding columns is fine.
- **Trailing spaces:** char columns compare trailing-blank-*sensitive* on this
  source (`'COTTON '` ≠ `'COTTON'`). Use `RTRIM()` on code columns in filters.
- **Dealer Group Code is per branch.** Branches 2 & 4 never carry the 690/770 model
  codes — the same part is COTTON/PICKER/blank there. Codes are `770`, `CS690`,
  `JDCS690` (`690` = 1 row); **no `CS770`**. 7460 doesn't exist.
- **jdis_Part_Information isn't unique on Branch + Part** — real grain is
  Branch + Part + Franchise, plus case/truncation duplicate rows. Dedup (see
  `JdisDedup` in the Pieces In Set queries) or filter Franchise before joining.
- **InMaster has cross-franchise duplicates** for the same Branch + Part — filter
  `FRANCHISE = 'D'`.
- **Pieces_In_Set = 1 is the default** (53K parts) — "a set" means > 1.
- **"Sub To" = `pi_Super_To`** (blank = empty string, never NULL; a few spaces-only).
- **Join strategy is volume-dependent.** Zero-fill anti-joins: `NOT EXISTS` is fast for
  high-volume branches (2 & 4), `LEFT JOIN` was the fix for low-volume ones. Inlining
  a small key list as a literal `IN (...)` beat both subquery forms for the 2 & 4
  cross-branch model-code lookup (5s vs. 250s / 10+ min).
- **Run heavy queries off-peak** when possible — InTrans is large, ODBC degrades
  during business hours.

## Open items

- **SPI Corparate Stocking** — switched to DP Prod 2026-10-07 (LH_Master_Data over-counts
  demand). DP Prod Silver is still refreshed manually, so run DP before the script if it
  flags stale input. Proposed next step: DP Gold notebook + workbook on the SQL endpoint
  (no script) — see `SPI Corparate Stocking/README.md`.
- **Order-upload export** (Curt/Barry) — blocked on the exact format spec from Ben.
- **Barry / Curt DSN setup** — Barry's DSN needs renaming to `EquipRDB`; Curt's status unknown.
- **SPI PIS box/bulk outliers + description truncation** — see notes in `SPI - Pieces In Set.pq`.
