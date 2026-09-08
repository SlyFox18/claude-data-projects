# Data Platform Workspace Reference

Created 2026-09-04 as part of the JD Bronze migration / data platform redesign
(see `docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md`).

| Workspace | Workspace ID | Purpose | Git branch | Git folder | Capacity |
|---|---|---|---|---|---|
| DP - Staging - Dev | `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201` | Bronze shortcuts + silver (dev) | dev | `workspaces/DP - Staging - Dev` | fabric1cap1 (F8) |
| DP - Staging - Prod | `189e5c0a-548a-4feb-93d6-dda9ebbe96c1` | Bronze shortcuts + silver (prod) | main | `workspaces/DP - Staging - Prod` | fabric1cap1 (F8) |
| DP - Presentation - Dev | `73fd5443-240e-410a-990a-98827f32c087` | Gold + semantic models (dev) | dev | `workspaces/DP - Presentation - Dev` | fabric1cap1 (F8) |
| DP - Presentation - Prod | `7836042d-adb1-4846-b70d-bd42980054c5` | Gold + semantic models (prod) | main | `workspaces/DP - Presentation - Prod` | fabric1cap1 (F8) |

All 4 verified `gitConnectionState: ConnectedAndInitialized` with 0 pending changes as of 2026-09-04.
`fabric1cap1` capacity ID: `c703247c-8451-4349-b95d-93e4eac756e8` (F8, North Central US).

## Lakehouses

| Lakehouse | Workspace | Lakehouse ID | Contents |
|---|---|---|---|
| DP_Staging | DP - Staging - Dev | `876255e0-d462-4697-adc1-4a655f5bb101` | `Tables/InTrans` — OneLake shortcut (passthrough identity) into `JD_EquipRDB_Production_Bronze.InTrans` (`JD_FabricOneLake` workspace `4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`, lakehouse `7348c3a6-8694-4d11-bc70-1bd55be84ea2`). Verified 2026-09-04: row count, min/max timestamp, and the RO 1985073 spot check (9 rows) all match the source exactly — see `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut.py`. Also holds `Tables/Silver_InTrans` — see below. |
| DP_Presentation | DP - Presentation - Dev | `966efc8a-16f9-423b-aa43-e368fcd8fb91` | `Tables/dim_RepairOrder`, `Tables/Fact_PartsPromo` — see below. |

### `Silver_InTrans`

Built by `Build_Silver_InTrans.Notebook` (in `DP - Staging - Dev`, git-tracked at
`workspaces/DP - Staging - Dev/Build_Silver_InTrans.Notebook`). PySpark, PK-merge on
`(TransId, TransDatetime)` — not `TransId` alone, which the source system reuses for
unrelated transactions (see the notebook's header comment and project memory
`project_intrans_incremental_dedup_2026-08-11` for the full story). `ModifiedDate DESC
NULLS LAST` breaks rare genuine same-key conflicts. Written via path-based
`.save("Tables/Silver_InTrans")`, not `saveAsTable()`, to preserve exact PascalCase
(a third confirmed instance of `saveAsTable()` lowercasing physical table names in
this environment — see `feedback_fabric_saveastable_casing.md`).

Full column parity with `InTrans_Incremental` (all 66 raw `InTrans` columns, using the
same rename mapping already in production use in `df_InTrans_Incremental.Dataflow`'s
`mashup.pq`), not just the 11 columns Parts Promo needs — done deliberately once, so
the other 8+ fact tables that currently depend on `InTrans_Incremental`
(`Fact_WorkOrderParts`, `Fact_Transfers`, Parts Adjustments, Parts Not Re-Ordered,
Unique Parts Customers, etc.) can point at this table with zero column-name surprises
when they eventually migrate.

Verified 2026-09-08 via `.claude/queries/adhoc/dp-bronze-verify/verify_silver_intrans.py`
(independent DuckDB check, separate from the notebook's own verification cell):
20,462,845 rows (0.73% fewer than bronze's 20,612,638 — expected, true exact
duplicates + genuine same-key corrections collapsed), 0 duplicate
`(TransId, TransDatetime)` groups, 0 orphaned rows (nothing stale survived two earlier
flawed builds — first used `TransId` alone as the key, second used `saveAsTable()`
with the wrong case), and the RO 1985073 spot check still shows exactly 9 rows.

### `dim_RepairOrder` / `Fact_PartsPromo`

Built by `Build_Gold_PartsPromo.Notebook` (in `DP - Presentation - Dev`, git-tracked at
`workspaces/DP - Presentation - Dev/Build_Gold_PartsPromo.Notebook`). PySpark, reads
`Silver_InTrans` cross-workspace via its full OneLake path (no shortcut — a direct
same-tenant Spark read), reproduces the existing production business logic exactly
(`dim_RepairOrder.pq` / `Fact_PartsPromo_v2.pq`: promo = `PartNumber` starts with `*`;
non-promo aggregates exclude `Franchise = 'ZP'`; promo aggregates do not). Full
overwrite each run — both tables are small (promo-active orders since 2022-01-01
only). Written via path-based `.save()` from the start (no casing mistake to make
here, unlike `Silver_InTrans`'s first attempt).

As of 2026-09-08: 16,251 `dim_RepairOrder` rows, 16,918 `Fact_PartsPromo` rows.

**This is the actual bug-fix proof.** Verified via
`.claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo.py` — compared
`dim_RepairOrder` directly against `EquipRDB` (the real source system, not another
copy of our own data) for all 11 repair orders confirmed wrong in the original
investigation. **All 11 now match to the penny** (differences shown are
floating-point noise on the order of `1e-13`, not real discrepancies). The original
Parts Promo bug — RO 1985073 showing $229.18 instead of $627.64, and 10 other
orders similarly understated — is fixed at the gold layer.

**Variable Library:** `DP - Environment Config`, lives in `DP - Staging - Dev`, git-synced under
`workspaces/DP - Staging - Dev/DP - Environment Config.VariableLibrary`. Value sets: `Default`
(built-in), `Dev`, `Prod`.

Variables defined so far:

| Variable | Type | Default | Dev | Prod |
|---|---|---|---|---|
| `staging_lakehouse_id` | String | `876255e0-d462-4697-adc1-4a655f5bb101` | `876255e0-d462-4697-adc1-4a655f5bb101` | `not-yet-created` (Prod staging lakehouse doesn't exist yet) |
| `presentation_lakehouse_id` | String | `966efc8a-16f9-423b-aa43-e368fcd8fb91` | `966efc8a-16f9-423b-aa43-e368fcd8fb91` | `not-yet-created` (Prod presentation lakehouse doesn't exist yet) |

**Gotcha (confirmed 2026-09-04):** Variable Library value sets require non-blank values to save —
leaving a value empty blocks both saving and adding further value sets. Also, the Git integration
connect dialog's "Git folder" field defaults to the repo **root** if left blank, which pulls in
every other workspace's items as pending updates — always fill it in explicitly (no leading slash),
and check the Updates count immediately after connecting before touching anything else.
