# Open Order Parts Advisor

**Status:** In Development
**Workspace:** RP - Sandbox (testing) → RP - Service Reports (production)
**Spec:** [Design Spec](../../docs/superpowers/specs/2026-04-29-open-order-parts-advisor-design.md)

## Purpose

Surfaces recommended parts for open work orders based on 3 years of historical
job code → part frequency analysis. Helps the After Market Sales Manager and Corp
Service Manager identify parts that should be on an open order before it is invoiced.

## Report Pages

1. **Branch Summary** — scoreboard by branch: open ROs, total recommendations, est. $ opportunity
2. **Open Orders** — RO list sorted by estimated $ opportunity (drill-through to Page 3)
3. **RO Detail** — flat recommendation list for one RO, sorted by frequency %

## Data Tables

| Table | Grain | Source | Refresh |
|---|---|---|---|
| Fact_JobCodePartFrequency | JobCode × PartNumber | wkothsub + InTrans_Incremental | Full daily, Phase 4 |
| Fact_OpenOrders | WorkOrder × JobCode | WkRoFile + wkothsub | Full daily, Phase 4 |
| Fact_OpenOrderParts | WorkOrder × PartNumber | InSalPar + InSalOrd + WkRoFile | Full daily, Phase 4 |
| Recommendations | WorkOrder × JobCode × PartNumber | DAX calculated table | At model refresh |

## Query Library

- `.claude/queries/facts/Fact_JobCodePartFrequency.pq`
- `.claude/queries/facts/Fact_OpenOrders.pq`
- `.claude/queries/facts/Fact_OpenOrderParts.pq`

## Pipeline

Phase 4 of master orchestrator (after raw tables and dimensions are current).
Fact_JobCodePartFrequency is the most compute-intensive — add to the last Phase 4 wave.
InSalPar and InSalOrd raw tables already refreshed in Phase 1 (no new raw dataflow needed).
