# Open Order Parts Advisor — Architecture

## Critical Join Warning

**InTrans RONumber = Invoice Number (NOT work order number)**

`InTrans_Incremental.RONumber` (source column: `REF_NO`) is the INVOICE number,
not the work order number. Joining on work order number produces ~1% of correct
row count. Always join: `wkothsub.InvoiceNumber = InTrans_Incremental.RONumber`.

This is the same bug that was fixed in Fact_WorkOrderParts (Inspections report).

## Frequency Calculation Logic

For each job code that appears on invoiced work orders (last 3 years):
- TotalOrdersWithJobCode = DISTINCT work orders where this job code appeared
- TimesWithPart = DISTINCT work orders where this job code AND this part appeared together
- FrequencyPct = TimesWithPart / TotalOrdersWithJobCode

Frequencies are GLOBAL (all branches combined) for statistical reliability.

## Open Order Parts Source (Task 1 Finding)

Parts on open (not-yet-invoiced) work orders are stored in a 3-table join:

```
InSalPar  (part lines: PART_NO, ORDER_QTY, FILE_NO, JOB_CODE)
  → InSalOrd  (order header: FILE_NO, RO_NUMBER, RO_BRANCH, TYPE)
    → WkRoFile  (WO status: ro_closed_ind = 'N' for open orders)
```

Filter for work order parts: `InSalOrd.TYPE = 'W'`
Filter for open orders: `WkRoFile.ro_closed_ind = 'N'`
Raw Lakehouse tables: insalpar and insalord already exist (no new Phase 1 dataflow needed).

## Job Description Lookup

`wkothsub` does not have a job description column.
Job descriptions are in `WkCodeFl.DESCRIPTION`, joinable via `JOB_CODE`.
Not included in v1 — job code alone is sufficient for the recommendation engine.

## Open Order Filter

`WkRoFile.ro_closed_ind = 'N'` — confirmed via source system investigation.
Returns ~65,340 open work orders as of investigation date.

## WKCDPART Table (Future Enhancement)

A standard parts-per-job-code template table exists (`WKCDPART`, ~1,836 rows).
This is a hand-curated version of what the frequency calculation computes statistically.
Out of scope for v1 — could be used as a validation layer or recommendation seed in v2.

## Investigation Findings

- Open order parts table: InSalPar + InSalOrd (see join above)
- Job description column in wkothsub: not present (use WkCodeFl.DESCRIPTION)
- Open order filter: `ro_closed_ind = 'N'`
- InTrans_Incremental oldest record: TBD (confirm in Fabric Lakehouse analytics endpoint)
