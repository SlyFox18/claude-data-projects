# Parts Lookup Tool

**Status:** In development (Fabric Foundation phase)
**Owner:** Brian Fox
**Stakeholder:** Ben

## Overview
Replaces the retired in-store Equip part-lookup utility. Parts staff enter a
part number and see every branch carrying it through a vendor — franchise,
bin, bin qty, sell price 1, comments, and part supersession.

## Delivery Plan
- **Plan 1 (current):** Fabric data foundation — raw table, Fabric App scaffold, sync pipeline
- **Plan 2:** Fabric App frontend — search screen, GraphQL query wiring, styling

## Key Data Source
| Source | Table | Purpose |
|---|---|---|
| ODBC (EquipRDB64) | InMaster | Single source — franchise, bin, vendor code, sell price, comments (NOTE), and BinQty computed as ON_HAND_QTY - Pending_Qty |

## Platform
Generic Fabric Apps (Rayfin template) — not the Analytics/data-app template, not Power Apps.
See `docs/superpowers/specs/2026-07-15-parts-lookup-fabric-app-design.md` for why.

## Design Spec
`docs/superpowers/specs/2026-07-15-parts-lookup-fabric-app-design.md`
