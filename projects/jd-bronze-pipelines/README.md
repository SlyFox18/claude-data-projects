# JD Bronze Pipelines — Reference & Runbook

JD built these pipelines; SPI owns the data, the tenant, the gateway host, and (since 2026-09-28)
has Owner access to everything needed to run and repair them without JD.

## Where everything lives

| Piece | Details |
|---|---|
| Workspace | **JD_FabricOneLake** `4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9` (Git-synced to `fabric-workspace-docs` → `/workspaces/JD_FabricOneLake`, branch `dev`) |
| Lakehouse | **JD_EquipRDB_Production_Bronze** `7348c3a6-8694-4d11-bc70-1bd55be84ea2` — DP_Staging's Bronze tables are OneLake shortcuts into it |
| Full pipeline | `PL_EquipRDB_To_Fabric_Full` `e2094bc4-2b08-4510-83db-bd0d19ec754f` — table list `watermarktable_full` (137 rows, 98 copied) — **daily 00:00 CST**, runs as the SPN |
| Incremental pipeline | `PL_EquipRDB_To_Fabric_Incremental` `c310aa3b-3143-49aa-b77c-a3ae13e5660b` — table list `watermarktable_incremental` (17) — **daily 6:30 AM CST** (Brian, 2026-09-28; the 30-min schedule stays off) |
| ODBC connection | `049694-Gateway` `b062a489-87a3-4c63-9bfe-fdfe2c4732fb` — `dsn=EquipRDB`, **Basic** auth. Owners: Brian, Deere CE Support, JDIS Support, the SPN, SPITractor_Fabric_Integration_Admin_Group |
| **Gateway** | **`049694-Gateway`** `e896ed96-9c3a-43b8-82da-dcb99af18260` — installed on **SPI01SR2034W** (Brian can RDP). Windows service **On-premises data gateway service** (`PBIEgwService`), startup **Automatic** |
| Service principal | `SPITractor_Fabric_Integration_Admin` — appId `2ce2664f-d2e7-4efb-aae9-f2244125de9b`, object `cfcc21e5-82a4-4532-93ab-ec1e41d9f8c2`, in SPI's Entra tenant. Brian is an app owner and holds his own client secret (password manager; note its expiry) |

The 17 incremental tables: Invoice, ArMaster, contact, WkInvReg, GlTrans, VhSalman, ArTrans,
Bin_Location, UAUDIT, INPUROHD, Barcode_Activity_Tracking, Parts_Pricing_Admin, VhStock_Notes,
VhStock_Notes_Audit, Service_Agreement_Header, RP_INVOICE_TAX_TC, Branch_Name. Everything else
comes from the Full pipeline.

**SPI has two other gateways** (both administered by Brian): `SPI-Data-Gateway`
`d98a8d2c-d0df-4a42-a281-aab18e49dbd7` (used by SPI's own dataflows, Windows auth) and
`SPI-Dev-Gateway` `ca642c75-d40d-4dc4-901d-90c122676926`. JD's pipelines do **not** use them.

## Health check

```
python tools/dp-migration/jd_bronze_check.py
```

Shows each pipeline's latest run at the **activity level** and the incremental watermarks.
**Never trust the pipeline's own "Completed" status** — the Full pipeline reports Completed even
when every copy fails.

## Runbook

### Symptom: "…ensure your on-premises data gateway can access ncu.frontend.clouddatahub.net…"
(or the connection shows **Offline** in Settings → Manage connections and gateways)

The gateway on SPI01SR2034W is down.

1. RDP to **SPI01SR2034W**.
2. `services.msc` → **On-premises data gateway service** → **Start**. Or, in an admin PowerShell:
   `Start-Service PBIEgwService`
3. Confirm Properties → Startup type **Automatic**, and Recovery tab → all three failures =
   **Restart the Service**.
4. Open the **On-premises data gateway** app → should say online → **Diagnostics** → network
   ports test.
5. If the service won't start: Event Viewer → Windows Logs → Application, or the app's
   **Export logs**. Check the service's Log On account (normally `NT SERVICE\PBIEgwService`).
6. Re-run whichever pipeline(s) missed runs (Full, then Incremental), then run the health check.

### Symptom: `DMTS_EntityNotFoundOrUnauthorized` on connection `b062a489`

The identity running the pipeline has lost access to the connection. A scheduled pipeline runs
as the **schedule's owner** — editing/re-enabling a schedule makes you the owner.

- Check Manage connections and gateways → `049694-Gateway` → Manage users.
- If Brian is missing: run as the SPN and re-grant:
  ```
  $env:SPN_CLIENT_SECRET = Read-Host -MaskInput "SPN secret"
  python tools\dp-migration\spn_grant_connection.py --grant
  Remove-Item Env:SPN_CLIENT_SECRET
  ```
- If the SPN secret has expired: Entra admin center → App registrations → All applications →
  SPITractor_Fabric_Integration_Admin → Certificates & secrets → new secret (needs Global Admin
  or Application Administrator via PIM, or app ownership). **Never delete JD's secret.**

### Things that do NOT work (tried 2026-09-28)

- **Take over** on JD's pipeline: changes item ownership only, not connection access.
- Pointing the pipeline at SPI's own gateway connections: pipeline ODBC activities don't support
  **Windows** auth, and SPI's DSN logs in via SQL Anywhere integrated login, so Basic/Anonymous
  fail with "Invalid user ID or password".
- Save as / creating a copy of the pipeline: Fabric refuses any pipeline referencing a connection
  the caller can't use.

## History

- **2026-09-04** — Incremental schedule paused (CU savings); later re-enabled, which made Brian
  the schedule owner → every run failed on connection access. 17 tables frozen at 09-04.
- **2026-09-26/27** — gateway service on SPI01SR2034W stopped; Full pipeline "Completed" with all
  98 copies failing on 09-27 and 09-28.
- **2026-09-28** — Brian granted Owner on the connection via the SPN; restarted the gateway;
  manual catch-up runs verified (Full 98/98, Incremental 16/16 + Parts_Pricing_Admin unchanged).
  A temporary `_SPI` pipeline copy was created and deleted (definition in Git history).

## Files

- `backup-2026-09-28/` — JD's original definitions, schedules and `.platform` for both pipelines
