# Multi-Tech RO Visual De-alarm — Design Spec

**Date:** 2026-06-23
**Report:** Service Time Sheets
**Requested by:** CFO / Corp Service Manager (meeting 2026-06-23)
**Status:** Approved — ready for implementation

---

## Problem

In the Time Sheet Audit table (Page 2) and Tech Audit Detail drill-through (Page 3), rows belonging to shared work orders (multiple commission techs on the same RO) appear visually identical to real problem rows. Specifically, when one tech on a shared RO receives all the invoiced hours and another has a pending invoice, the first tech's row shows "Invoiced More Than Claimed" with a yellow background and amber numbers — the same treatment as a genuine underpay-risk row. The only current signal is a "2 Commission Techs" text value in the `Shared RO` column at the far right, which is easy to miss.

**Key constraint:** The data is at the Technician × RO × Pay Period grain. This cannot change — the source system allocates invoiced hours to individual techs, and the shared-RO scenario is a billing allocation difference rather than a tech-level discrepancy. The fix must work entirely within the existing grain.

---

## Solution: Color De-alarm + RO Status Column (Option B)

Two complementary changes applied to shared-RO "Invoiced More" rows:

1. **Visual de-alarm** — Change the row background and hours difference color from the alarming yellow/amber palette to a calm blue palette, so the row stops registering as a risk signal at a glance.
2. **Inline RO context** — Add a new `RO Status` column immediately after `Audit Status` that shows the aggregate RO-level outcome (e.g., `Match`, `Mixed`) for shared-RO rows. Single-tech rows show blank. The CFO can see in one row: tech-level status says "Invoiced More Than Claimed" AND the RO-level outcome says "Match" — without drilling anywhere.

The `AuditStatus` field value itself is **not changed** — it is used by slicers, filters, and the Multi-Tech RO Review page (Page 5) and must remain stable.

---

## Scope

- **Pages affected:** Page 2 (Time Sheet Audit), Page 3 (Tech Audit Detail)
- **No changes to:** ETL/Power Query, hero card KPIs, Multi-Tech RO Review (Page 5), Multi-Tech RO Detail (Page 4), Invoice Labor Reconciliation (Page 6)
- **Trigger condition:** `AuditStatus = "Invoiced More Than Claimed"` AND `SharedRO` contains `"Commission Techs"`
- The `SharedRO` column (`"2 Commission Techs"`) is kept as-is — it provides distinct information (the count) and is not replaced.

---

## Changes Required

### 1. New Calculated Column — `ROStatusDisplay` in `Fact_ServiceTimeSheet_Audit.tmdl`

Reuses the `CALCULATE(..., ALL(Fact_ServiceTimeSheet_Audit), RONumber = _RO)` pattern from the existing `SharedRO` column.

**Logic:**
- If the RO has only 1 commission tech → return `BLANK()`
- If the RO has > 1 commission tech → compute the RO-level audit outcome:
  - Count rows with each AuditStatus bucket scoped to that RONumber across the full table
  - Return short-form text: `"Match"`, `"Mixed"`, `"Claimed More"`, `"Invoiced More"`, `"Partial"`, `"Draw"`, or `"Pending"`
  - Priority order: Mixed (claimed + invoiced both > 0) → Claimed More → Invoiced More → Partial → Draw → Pending → Match

**Example output for RO 691944:**
- James Acker row: `"Match"` (RO aggregate = 7.49 claimed vs 7.49 invoiced)
- Branden Price row: `"Match"` (same RO, same aggregate)

### 2. New Measure — `RO Status Display Color` in `_Measures.tmdl`

Conditional formatting rule for the `ROStatusDisplay` column (font color). Maps short-form text to colors matching the existing status color palette:

| Value | Color |
|---|---|
| `"Match"` | `#16A34A` (green) |
| `"Claimed More"` | `#DC2626` (red) |
| `"Invoiced More"` | `#B45309` (amber) |
| `"Mixed"` | `#6D28D9` (purple) |
| `"Partial"` | `#8B5CF6` (light purple) |
| `"Draw"` | `#2563EB` (blue) |
| `"Pending"` | `#64748B` (slate) |
| BLANK | BLANK |

### 3. Update `Row Status Color` in `_Measures.tmdl`

Add new condition **before** the existing `SWITCH` on `AuditStatus`:

```
IF(
    SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[AuditStatus]) = "Invoiced More Than Claimed"
        && CONTAINSSTRING(SELECTEDVALUE(Fact_ServiceTimeSheet_Audit[SharedRO]), "Commission Techs"),
    "#EFF6FF",
    <existing SWITCH logic>
)
```

Result: Shared-RO "Invoiced More" rows get blue `#EFF6FF` background instead of yellow `#FEF3C7`.

### 4. Update `Hours Diff Color` in `_Measures.tmdl`

Same `IF` condition added before existing `SWITCH`:
- Shared-RO "Invoiced More" → `"#64748B"` (slate) instead of `"#B45309"` (amber)

### 5. Update `Hours Diff Color Bar` in `_Measures.tmdl`

Same `IF` condition:
- Shared-RO "Invoiced More" → `"#CBD5E1"` (light slate) instead of `"#facc15"` (yellow-gold)

### 6. Table Layout — Desktop (Pages 2 and 3, no TMDL edit)

- Add `ROStatusDisplay` field to the table visual on Pages 2 and 3
- Position: immediately after the `Audit Status` column
- Column header label: `RO Status`
- Apply `RO Status Display Color` as font color conditional formatting rule on this column
- No other column reordering needed

---

## Visual Before/After Summary

| Row | Before | After |
|---|---|---|
| Real "Invoiced More" (single tech) | Yellow background, amber numbers | Unchanged — still yellow |
| Shared-RO "Invoiced More" | Yellow background, amber numbers, "2 Commission Techs" at far right | Blue background, slate numbers, `RO Status = Match` right after Audit Status |

---

## Known Constraints & Gotchas

- **`AuditStatus` is a source column**, not a calculated column — do not add it to `Fact_ServiceTimeSheet_Audit.tmdl` as a calculated column. It arrives from the Lakehouse.
- **TMDL files do not support `//` comments** at the structural level. DAX `//` inside backtick measure expressions is fine.
- **Lineage tag uniqueness** — when adding the new calculated column and measure, check existing lineage tags in both files to avoid collision. Use the `f0f1f2f3-...` fake-UUID pattern with a unique suffix not already in the file.
- **`CONTAINSSTRING` in measures** — this is supported in DAX for conditional formatting measures using `SELECTEDVALUE()`. Verify behavior is correct in Desktop before publishing.
- **The `SharedRO` calculated column uses `ALL(Fact_ServiceTimeSheet_Audit)`** — `ROStatusDisplay` should use the same pattern for consistency.
- **Pages 2 and 3 only** — do not add `RO Status` column to Page 5 (Multi-Tech RO Review) or Page 4 (Multi-Tech RO Detail), which are already RO-grain views.

---

## Files to Edit

| File | Change |
|---|---|
| `reports/Service Time Sheets.SemanticModel/definition/tables/Fact_ServiceTimeSheet_Audit.tmdl` | Add `ROStatusDisplay` calculated column |
| `reports/Service Time Sheets.SemanticModel/definition/tables/_Measures.tmdl` | Add `RO Status Display Color`; update `Row Status Color`, `Hours Diff Color`, `Hours Diff Color Bar` |
| Power BI Desktop (Page 2 visual) | Add `ROStatusDisplay` column, apply CF |
| Power BI Desktop (Page 3 visual) | Add `ROStatusDisplay` column, apply CF |
