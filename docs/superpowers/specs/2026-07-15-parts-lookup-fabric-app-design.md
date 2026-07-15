# Parts Cross-Branch Lookup Tool — Design Spec

**Date:** 2026-07-15
**Author:** Brian Fox
**Status:** Approved for implementation planning

---

## 1. Problem Statement

Parts staff at every store used a small in-store tool built into Equip to look up a part number and see which other branches carry it — franchise, bin quantity, sell price, comments, and supersession info — so they could arrange a transfer instead of a special order. That tool was retired starting 2026-07-14 and will not be replaced by the vendor. Ben (stakeholder) asked whether this can be replicated using Microsoft Fabric, with one hard constraint: **it cannot add any licensing cost.** The old tool had per-seat licensing at every store; the entire point of replacing it is to stop paying for that.

---

## 2. Scope

### In Scope
- Single-screen lookup: enter a part number, see every branch that carries it (where a supplier/vendor code is present), with franchise, bin qty, sell price 1, comments, and part supersession (SuperTo/SuperFrom)
- All franchises, all branches (not limited to non-JD, unlike the Non-JD Parts Order Tool)
- Read-only — no ordering, no editing, no settings screens
- Small, non-browser-feeling window (pinned/app-mode), mirroring the retired tool's footprint

### Out of Scope
- Ordering or transfer-request workflow (this tool only tells you where a part is — it doesn't move it)
- Editable per-part settings or overrides
- Sales history, ROP, or reorder recommendations (that's the separate Non-JD Parts Order Tool)
- Mobile-first design (store PC/counter use assumed, similar to the retired tool)

---

## 3. Platform Decision

### Ruled out

| Option | Why ruled out |
|---|---|
| Power Apps (canvas app) connected to Fabric/Lakehouse data | Requires a premium connector to reach Fabric data from Power Apps — real added licensing cost. Same constraint already documented in `part order tool - app/ARCHITECTURE.md`, which deliberately stayed on a free-tier SharePoint list until "Premium confirmed" (never confirmed). |
| Fabric Apps — Analytics/data-app template (the one `transfer-app-prototype` is built from) | Connects to a Power BI **semantic model** via the Execute DAX Queries API. Per Microsoft's own licensing docs, viewing Power BI content on a Fabric capacity below F64 requires each viewer to have Pro, PPU, or an individual trial license. Store parts staff confirmed to have M365 basic accounts only, no Power BI license — this would silently reintroduce the cost the project exists to remove. |
| Standalone web app (`transfer-app` pattern — React PWA + Netlify + Entra sign-in + thin read API) | Genuinely free and proven in this org for a similar store-floor audience, but a second platform to host/maintain outside Fabric. Superseded by the option below once its licensing model was confirmed. |

### Chosen: Fabric Apps — generic (Rayfin) template

A separate product from the Analytics template, despite sharing the "Fabric Apps" name. You define your own data model in TypeScript; Fabric Apps provisions its own SQL Database in Fabric, an auto-generated GraphQL API, and static hosting, authenticated via **Fabric SSO (Entra ID) only**. Billing is Fabric Capacity Units from the assigned capacity (SQL compute/storage, GraphQL query time, OneLake hosting) — there is no Power BI Pro/PPU/F64 viewer gate, because it isn't Power BI content. Any tenant user can sign in at no additional per-user cost.

**Tradeoff accepted:** it cannot read an existing database directly — it owns its schema. Data has to be pushed into its own database rather than queried live from the Lakehouse. Solved below by a small addition to the existing refresh pipeline.

**Prerequisite already satisfied:** the Fabric Apps (preview) tenant setting is already enabled (Brian is a Fabric admin and enabled it himself for the Transfers app work).

---

## 4. Fabric Data Layer

### Design constraint
Per this repo's established convention (see `part order tool - app/ARCHITECTURE.md`), do not modify existing shared raw dataflows for a new use case — build a purpose-built one.

### New raw table: `InMaster_PartsLookup_Raw`
- **Source:** `InMaster` table via ODBC (`dsn=EquipRDB64`) — same source as the existing `InMaster`/`InMaster_Raw` raw pulls, but a dedicated query for this tool's column set
- **Columns:** `BRANCH, FRANCHISE, PART_NO, PART_DESC, BIN_LOCATION, SUPER_FROM, SUPER_TO, VENDOR_CODE, SELL_PRICE1, NOTE, ON_HAND_QTY, Pending_Qty`
- **Filter at source:** `WHERE VENDOR_CODE IS NOT NULL` — matches the business rule directly and cuts row count before it leaves Equip
- **Computed column:** `BinQty = ON_HAND_QTY - Pending_Qty`
  - Validated against `jdis_Part_Information` (which tracks bin qty as its own independent field): 1,102,498 of 1,103,165 rows (99.94%) match exactly, average difference ~0.0015. Brian has also used this same formula for bin qty in another existing report. Accepted as correct.
  - **This removes the need to read `jdis_Part_Information` at all** — single-sourced from InMaster.
- **No join required.** Originally scoped as a two-source join against `jdis_Part_Information` for `BinQty`; superseded once the formula above was validated.

### Comments field
`NOTE` column in `InMaster` — confirmed 2026-07-15 (not present in `jdis_Part_Information`, and not `user_field_1`/`user_field_2` as originally guessed).

### Sync to the Fabric App's database
One sync step (Dataflow Gen2, or a notebook if needed) reads `InMaster_PartsLookup_Raw` from the Lakehouse and pushes it into the Fabric App's own SQL Database in Fabric.

**Open item:** unconfirmed whether the Fabric App's SQL Database in Fabric accepts writes from an external pipeline (plain `MERGE`/`INSERT` via a standard SQL connection) the same as any other Fabric SQL Database, versus requiring writes to go through the app's own GraphQL mutations. Needs a quick real test early in implementation — this determines whether the sync step is a normal Dataflow Gen2/notebook SQL write or something that has to shell out to the GraphQL API.

### Refresh cadence
Since `BinQty` is now derived entirely from `InMaster` (average refresh ~3 minutes, much faster than `jdis_Part_Information`'s 3x/day), the sync step is no longer capped by the slower table. Exact cadence deferred until the new raw table's actual refresh time is known — start conservative (e.g., hourly) and increase once real timing is observed. Not a blocker for building.

---

## 5. Fabric App Architecture

- **Data model (TypeScript, Rayfin decorators):** single entity `PartLocation` — `partNumber, branch, franchise, vendorCode, bin, binQty, sellPrice1, superTo, superFrom, comments, lastRefreshed`
- **API:** GraphQL, auto-generated by Fabric Apps from the entity above — query by `partNumber`
- **Frontend:** React (Rayfin CLI scaffold) — one screen: part number search box → results table, one row per branch (Franchise, Bin, Bin Qty, Sell Price 1, Super To/From, Comments)
- **Auth:** Fabric SSO (Entra ID), built into the platform — no separate app registration
- **Presentation:** pinned as a small, chromeless window (e.g. Edge "app mode") rather than a browser tab, to match the retired tool's footprint. Exact visual design deferred to implementation.

### Error handling / edge cases
- Part not found in any branch with a vendor code → explicit "not found" message, not a blank grid
- Freshness indicator in the UI given the refresh cadence isn't real-time
- Supersession fields (`SuperTo`/`SuperFrom`) shown even when `binQty = 0` — a superseded/superseding part number is useful on its own

---

## 6. Workspace / Capacity

- **Development:** `RP - Fabric Apps Sandbox` workspace, currently on a **trial capacity** — same workspace already used for the `transfer-app-shipment-poc` prototype
- **Before production rollout:** the workspace/app must move to a workspace backed by a real (non-trial) Fabric capacity. Fabric trial capacities are time-limited (60 days, admin-renewable but not indefinite) and unsuitable for a store-wide production tool. Not a blocker for building now — flagged as a go-live checklist item.

---

## 7. Testing / Validation Plan

- Confirm the Fabric App's SQL Database in Fabric accepts external pipeline writes (open item above) before building the sync step around an assumption
- Validate the new `InMaster_PartsLookup_Raw` query against known multi-branch parts (the sample row from the original ask had a blank vendor code — need real parts with populated vendor codes across multiple branches to validate cross-branch grain)
- Spot-check a handful of the ~0.06% rows where `BinQty ≠ ON_HAND_QTY - Pending_Qty` to confirm they're immaterial (timing skew) rather than a systematic issue with a specific part type or franchise
- Confirm actual refresh time for `InMaster_PartsLookup_Raw` once built, to set the real sync cadence

---

## 8. Related Work

- **Transfers app:** separate project, unrelated data, same underlying platform question. Three prototypes exist: a standalone React PWA (`transfer-app` — actually the shipment pickup/dropoff driver tool), a Power Apps canvas app, and a Fabric App using the Analytics/data-app template (`transfer-app-prototype`). Brian believes Fabric App is the best fit there too — but since that one uses the Analytics template tied to a Power BI semantic model (`Transfers.SemanticModel`), its viewer licensing depends on whether its audience already has Pro/PPU. Not yet confirmed; not part of this spec.
- **Non-JD Parts Order Tool** (`part order tool - app/`): precedent for the "don't modify shared raw dataflows" convention and the general InMaster/jdis_Part_Information data landscape.
