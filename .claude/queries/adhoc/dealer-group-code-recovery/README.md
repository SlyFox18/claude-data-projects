# Dealer Group Code Recovery - Branch 2 & 4 (Ad Hoc)

**Requested by:** Brian, 2026-09-16
**Purpose:** Curt made an accidental mass update in the EquipRDB source system
on 2026-09-15 that set `DealerGroupCode` to `COTTON` for parts at Branch 2 and
Branch 4. This pulls the pre-change values from the last weekly snapshot taken
before the mistake, so Curt can manually restore the correct codes.

## Method

`build_report.py` queries the `LH_Master_Data` lakehouse directly via DuckDB
over OneLake (`delta_scan`, Azure CLI credential chain) - no dataflow or
notebook needed for a one-off pull like this.

- **Table:** `Fact_PartMaster_Snapshot_Weekly` - append-only weekly snapshot of
  `jdis_Part_Information` (24-month retention, so nothing here was at risk of
  being purged).
- **Snapshot used:** 2026-09-13 (Sunday) - the most recent weekly snapshot
  before Curt's 2026-09-15 mistake, confirmed present with 1,112,035 total
  rows across all branches.
- **Branch scope:** `Branch` is stored as text. Included plain `2` and `4`
  plus their sub-location suffix codes present in that snapshot (`2C`, `4B`,
  `4C`, `4I`, `4S` - a handful of rows each), in case Curt's mass update
  touched those too.

## Output

`Branch 2 and 4 - DealerGroupCode Pre-Change (2026-09-13 Snapshot).xlsx`

165,460 rows - one per PartNumber x Branch - with PartNumber, Description,
Branch, Franchise, CommodityCode, DealerGroupCode, and QuantityOnHand as of
the 2026-09-13 snapshot.

**Caveat for Curt:** 1,673 of these rows already show `DealerGroupCode =
COTTON` as of 9/13, i.e. legitimately COTTON before his mistake (there's a
real Cotton dealer group). This file can't distinguish "genuinely COTTON" from
"about to be corrupted to COTTON" on its own - but it doesn't need to: the
whole file is the correct pre-change state, so restoring every Branch 2/4 part
to the value in this file is the right fix either way (rows that were already
COTTON simply stay COTTON).

Also ~51K rows have a blank `DealerGroupCode` pre-change - that's the existing
baseline for parts with no group assigned, not a data quality issue introduced
by this pull.

Re-run `build_report.py` from this folder any time (requires `fab auth login`
and `az login` to be active). Note it will always pull the 2026-09-13 snapshot
specifically (hardcoded `SNAPSHOT_DATE`) - update that constant if a different
week's pre-change baseline is ever needed.
