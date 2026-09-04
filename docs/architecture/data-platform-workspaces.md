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

**Variable Library:** `DP - Environment Config`, lives in `DP - Staging - Dev`, git-synced under
`workspaces/DP - Staging - Dev/DP - Environment Config.VariableLibrary`. Value sets: `Default`
(built-in), `Dev`, `Prod`.

Variables defined so far:

| Variable | Type | Current value (all 3 value sets) |
|---|---|---|
| `staging_lakehouse_id` | String | `not-yet-created` (placeholder — set to the real Staging lakehouse GUID once created in Plan 2) |
| `presentation_lakehouse_id` | String | `not-yet-created` (placeholder — set to the real Presentation lakehouse GUID once created in Plan 2) |

**Gotcha (confirmed 2026-09-04):** Variable Library value sets require non-blank values to save —
leaving a value empty blocks both saving and adding further value sets. Also, the Git integration
connect dialog's "Git folder" field defaults to the repo **root** if left blank, which pulls in
every other workspace's items as pending updates — always fill it in explicitly (no leading slash),
and check the Updates count immediately after connecting before touching anything else.
