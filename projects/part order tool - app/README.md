# Non-JD Parts Order Tool

**Status:** Redesign in progress (2026-10-20): React web app on the DP backend, replacing the Power Apps plan.
**Owner:** Brian Fox
**Stakeholder:** Parts Manager / Corp Parts Manager

## Overview

A parts reorder tool for non-John Deere parts. Replicates the core capabilities
of the JD PRISM ordering system for franchises not covered by that program (~40
franchises, 200K+ parts). Currently non-JD ordering is a fully manual process
using spreadsheets.

## Parts of the Tool

1. **Recommended Reorder** — automatic daily recommendations driven by sales history and the ROP parameter matrix
2. **One Time Order** — manual wizard with user-selected months and loading factor (mirrors the JD PRISM special-term order workflow)
3. **Part Information** — part lookup with 60-month history and per-part settings
4. **Home / Navigation** — wrapper connecting all three tools

## Current design and plans
- Spec: `docs/superpowers/specs/2026-10-20-non-jd-parts-order-tool-redesign-design.md`
- Plan A (data feed): `docs/superpowers/plans/2026-10-20-non-jd-parts-order-tool-data-feed.md`
- Plan B (web app): to be written against the file contract in `publish/README.md`
- Superseded: the 2026-05-28 spec and plans (LH_Master_Data + Power Apps). `ARCHITECTURE.md`, `POWERAPPS-GUIDE.md`
  and `canvas-sync/` describe that old design.

## Investigation Results

`projects/part order tool - app/DATA-INVESTIGATION.md` — Task 1 discovery findings

## Key Data Sources (DP)

The original design used ODBC, a SharePoint list and CSV uploads on LH_Master_Data; that is superseded. Current sources:

| Source | Table / file | Purpose |
|---|---|---|
| DP_Staging Silver | Silver_PartInformation | Part master |
| DP_Staging Silver | Silver_InMaster | Product group, margin flag (user_field_3) |
| DP_Staging Silver | Silver_PartStockingRules | Stocking rules |
| DP_Staging Silver | Silver_PartSalesHistory | Sales/request history (from JD Bronze InHistMQT) |
| SharePoint list | NonJD_PartSettings (via df_NonJD_PartSettings_Raw) | User-managed per-part overrides and masks |
| CSV | Files/config/nonjd/rop_matrix.csv (1,990 rows) | ROP calculation parameter matrix |

All of these feed Gold `Build_Gold_NonJD_Reorder`.

## Franchise Scope

Non-JD parts only. Excluded franchises: D (John Deere), ZP (warehouse code),
S (inactive), T* (TD, TM — test/inactive), U* (UD, UM — test/inactive), 95 (data error).
DA franchise is INCLUDED (confirmed not a JD franchise).

## ROP Calculation Key Findings

- `pi_suggested_order_qty` is NOT reliable for non-JD parts — stale values
- `InMaster.PROD_GROUP` contains vendor names, not stocking group codes (irrelevant — matrix is all-Default)
- The ROP parameter matrix is entirely "Default" for Group/Commodity/SRC/SLC — lookup uses only MonthCount + Demand range + Sales range
- Sales history columns (`pi_sales_history_*`) are unit quantities for real stocked parts
- `user_field_3` has one value: "LOW" (low margin flag)
