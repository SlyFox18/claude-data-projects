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
| DP_Staging | DP - Staging - Dev | `876255e0-d462-4697-adc1-4a655f5bb101` | `Tables/InTrans` — OneLake shortcut (passthrough identity) into `JD_EquipRDB_Production_Bronze.InTrans` (`JD_FabricOneLake` workspace `4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`, lakehouse `7348c3a6-8694-4d11-bc70-1bd55be84ea2`). Verified 2026-09-04: row count, min/max timestamp, and the RO 1985073 spot check (9 rows) all match the source exactly — see `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut.py`. |

**Variable Library:** `DP - Environment Config`, lives in `DP - Staging - Dev`, git-synced under
`workspaces/DP - Staging - Dev/DP - Environment Config.VariableLibrary`. Value sets: `Default`
(built-in), `Dev`, `Prod`.

Variables defined so far:

| Variable | Type | Default | Dev | Prod |
|---|---|---|---|---|
| `staging_lakehouse_id` | String | `876255e0-d462-4697-adc1-4a655f5bb101` | `876255e0-d462-4697-adc1-4a655f5bb101` | `not-yet-created` (Prod staging lakehouse doesn't exist yet) |
| `presentation_lakehouse_id` | String | `not-yet-created` | `not-yet-created` | `not-yet-created` (set once the Presentation lakehouse is created) |

**Gotcha (confirmed 2026-09-04):** Variable Library value sets require non-blank values to save —
leaving a value empty blocks both saving and adding further value sets. Also, the Git integration
connect dialog's "Git folder" field defaults to the repo **root** if left blank, which pulls in
every other workspace's items as pending updates — always fill it in explicitly (no leading slash),
and check the Updates count immediately after connecting before touching anything else.
