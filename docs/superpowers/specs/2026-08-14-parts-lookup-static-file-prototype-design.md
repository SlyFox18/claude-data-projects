# Parts Lookup — Static-File Backend Prototype — Design Spec

**Date:** 2026-08-14
**Author:** Brian Fox
**Status:** Approved for implementation planning

---

## 1. Problem Statement

`parts-lookup-app` (the Fabric App built per `2026-07-15-parts-lookup-fabric-app-design.md`) is live, in real use across the Parts department, and by every account doing exactly the job it was built for — the only functional complaint received is a wish for more frequent refreshes. The problem is capacity, not functionality:

- Confirmed via a controlled self-test (one data refresh + 2 real searches, 2026-08-13): a genuinely tiny amount of real usage produced a measurable ~2,300 CU / ~31-minute billed spike on `fabric1cap1` (F4), and directly triggered Power BI's automated "capacity at 100%" alert.
- Root cause confirmed via the SQL Database's own Performance Dashboard in the same test: the actual compute work is trivial (sub-millisecond per search, under 1 second of CPU for the sync's MERGE step). The cost is almost entirely Fabric SQL Database's non-configurable "kept online" minimum-activity billing tax — a platform characteristic of the "SQL database in Fabric" product itself, not a flaw in this app's design.
- The app is still mid-rollout (aiming for ~70 users across 19 stores, all day). Projected forward, this tax does not scale linearly with user count (the kept-online window overlaps rather than stacking), but it is real, non-trivial, and competes with the rest of `fabric1cap1`'s workload — which is separately already running hot from other work (see `project_intrans_incremental_dedup_2026-08-11` memory).
- Decision made 2026-08-13 (after evaluating Power Apps/Dataverse, a custom Azure PaaS stack, and a dedicated on-prem gateway machine, all of which have real merits but real external dependencies — see Section 8): explore whether the app's actual query pattern (single exact-match lookup by part number) can be served without any live backend at all.

This spec covers **only the prototype** — validating whether a static, pre-partitioned file approach can serve this lookup pattern fast enough to be worth building for real. It is not a production migration plan.

---

## 2. Core Idea

The app's entire query surface is one shape: given a part number, return every branch/franchise row that carries it. That's a much narrower problem than "database" implies. Instead of a live query engine, pre-generate many small static files — one per part-number prefix bucket — and have the frontend fetch just the one bucket a search needs, then filter client-side for the exact match. No database, no API server, no query engine to host, patch, or pay for. Refresh = regenerate and replace the files.

---

## 3. Scope

### In scope (this prototype)
- Generate partitioned JSON files from a one-time extract of `InMaster_PartsLookup_Raw`
- Measure generation time, file count/size distribution at more than one prefix length
- Upload the generated files to a test SharePoint document library
- Measure read latency (fetch one partition + client-side filter) and basic concurrent-read behavior
- A go/no-go read against the success criteria in Section 5

### Out of scope (deferred until the prototype validates)
- Authentication
- Integrating with the real `parts-lookup-app` React frontend
- Production refresh scheduling/cadence
- Error handling, edge cases (not-found states, stale-data indicators)
- Where the recurring generation script ultimately runs in production (candidate: the dedicated gateway machine IT is building, per Section 8 — not needed to validate the core idea)
- Decommissioning the existing Fabric App (a separate decision, made only if this validates and a real migration plan follows)

---

## 4. Design Details

### 4.1 Data source
One-time extract from `InMaster_PartsLookup_Raw` (Lakehouse) via DuckDB reading OneLake directly — the same ad hoc pattern already used elsewhere in this repo (see `project_kurt_sales_adhoc_pattern` memory). A single lightweight read, not a recurring job, so no meaningful Fabric capacity cost. Does not touch the Equip ODBC connection at all for this test. Reuses the same column shape `PartsLookup_Sync.pq` already produces: `partNumber, branch, franchise, description, vendorCode, bin, binQty, onOrder, sellPrice1, superTo, superFrom, comments`.

### 4.2 Partitioning scheme
Partition by a prefix of `partNumber`. Prefix length is a parameter to the generation script, not a fixed decision — generate at both 1-character and 2-character prefix length and compare resulting file count and size distribution before picking one. Real part-number distribution may be uneven; don't guess it upfront.

### 4.3 File format
Plain JSON, one file per prefix bucket, array of row objects. Simplest thing that works with a `fetch()` call from the frontend. No premature optimization toward a binary format — actual file sizes get measured in Section 5, and that data decides whether JSON is good enough.

### 4.4 Generation script
Runs locally (Brian's machine) for this prototype. This is explicitly a one-time/repeatable-on-demand validation run, not a production dependency — the single-point-of-failure concern that ruled out a personal machine for production (see decision history in `project_parts_lookup_tool` memory) doesn't apply to a test script.

### 4.5 Hosting for the read test
A sandbox/test SharePoint document library (not the production Parts site) — gives a realistic read-latency number against the actual hosting mechanism a real build would use, not a localhost approximation.

---

## 5. Success Criteria

| Measurement | Target |
|---|---|
| Full-dataset generation time (extract + partition + write, ~1.1M rows) | Small fraction of the 15-30 min target refresh window, leaving real headroom |
| Upload time to SharePoint | Comfortably fits inside the same window alongside generation |
| Single-lookup read latency (fetch one partition + client-side filter) | Well under 1 second |
| Concurrent reads (several simultaneous fetches) | No significant throttling/slowdown observed |
| File size distribution | No pathologically large partition files at whichever prefix length is chosen |

If these hold, the approach is worth building for real (a follow-up spec). If not, fall back to whichever of the Azure PaaS or dedicated-gateway-machine options IT makes available (Section 8).

---

## 6. Testing / Validation Plan

1. Extract full `InMaster_PartsLookup_Raw` via DuckDB, time the extract
2. Generate partitioned files at 1-char and 2-char prefix length; compare file count and size distribution; pick one (or note if neither is well-balanced and a different scheme is needed)
3. Upload the chosen partition set to a test SharePoint document library, time the upload
4. Build a minimal standalone test page (not the real app) that fetches a partition file and filters for a known part number; time it for a handful of real part numbers across different branches/prefixes
5. Fire several simultaneous fetches from the test page (or a small script) to check for throttling
6. Compare all results against Section 5 and record a clear go/no-go

---

## 7. Related Work

- **`2026-07-15-parts-lookup-fabric-app-design.md`** — the original Fabric App this prototype is evaluating an alternative to. Not being decommissioned yet; this prototype is a parallel evaluation.
- **`project_parts_lookup_tool` memory** — full incident history (three capacity incidents, the 2026-08-13 controlled test, and the four-option evaluation that led here: Power Apps/Dataverse closed out for cross-tenant/licensing reasons, Azure PaaS and the dedicated gateway machine both pending IT input, this static-file approach chosen as the only path with zero external dependency).
- **`project_kurt_sales_adhoc_pattern` memory** — precedent for the DuckDB/OneLake direct-read pattern used in Section 4.1.

---

## 8. Options Considered and Not Chosen for This Prototype

| Option | Status |
|---|---|
| Power Apps / Dataverse (reusing the JD barcode app's license pool) | Closed — that environment is JD-owned (different tenant, confirmed via cross-tenant licensing visibility test) and already in capacity overage. Fresh Dataverse capacity would cost $40/GB/month beyond entitlement, versus fractions of a cent/GB for OneLake. |
| Custom Azure PaaS (Static Web App + Function + Azure SQL Serverless) | Not ruled out — best long-term fit if it becomes available, preserves the existing React frontend almost entirely. Blocked pending IT confirming what Azure subscription(s) exist in the tenant (Brian's own `az` CLI access resolves to no usable subscription; Fabric's own API doesn't expose the underlying Azure linkage either). |
| Dedicated gateway machine (on-prem, near Equip server room) | Not ruled out — IT already planned this for Gateway reliability; could plausibly also host a small SQL Server Express + API. Pending confirmation of build status, specs, and network reachability from the 19 stores. |
| Static partitioned files (this spec) | Chosen for prototyping first — zero cost, zero external dependency, can be validated immediately. |
