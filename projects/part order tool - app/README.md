# Non-JD Parts Order Tool

**Status:** In development — Fabric Foundation phase (Plan 1)
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

## Delivery Plan

| Plan | Scope | Status |
|---|---|---|
| Plan 1 (current) | Fabric data layer — raw tables, parameters, fact tables | In progress |
| Plan 2 | Power Apps V1 — 4-screen Canvas App (production tool) | Not started |
| Plan 3 | Web App V2 — React app on same Fabric backend (learning project) | Future |

## Design Spec

`docs/superpowers/specs/2026-05-28-non-jd-parts-order-tool-design.md`

## Investigation Results

`projects/part order tool - app/DATA-INVESTIGATION.md` — Task 1 discovery findings

## Key Data Sources

| Source | Table | Purpose |
|---|---|---|
| ODBC (EquipRDB64) | jdis_Part_Information | Part master + 60-month history (new raw table — do not modify existing) |
| ODBC (EquipRDB64) | InMaster | Stocking months, margin flag (user_field_3) |
| SharePoint list | config_PartSettings | User-managed per-part overrides (Phase 1 storage) |
| CSV upload | param_ROP_Matrix | 1,993-row ROP calculation parameter matrix |
| Manual CSV | param_FranchiseScope | Franchise include/exclude list |

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
