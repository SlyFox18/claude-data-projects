# Cotton Harvester Inspection History — ad hoc pull for Casey

**Request (2026-10-21):** Casey and the CEO are visiting locations to talk about
inspections. Casey asked for inspection history for branches **6, 8, 96, 13**,
**2025-08-01 to today**, machines **CS770, CS690 ("CCS690"), 7460, CP770, CP690**.
He wanted an Excel sheet, not a report.

**Deliverable:** `Cotton Harvester Inspections - Br 6, 8, 13, 96 (2025-08-01 to <date>).xlsx`

| Tab | Grain |
|---|---|
| Summary | branch × model: inspection WOs, closed/open, customers, inspection labor, follow-up labor, parts, total, open-job estimate |
| Inspections | one row per inspection job: customer, serial, model, status, hours, $, and its work order totals |
| All Work on WOs | every job line on those work orders (the inspection + the repairs it turned up) |
| Parts on WOs | part lines on those invoices (reference only, see below) |
| Notes | scope and definitions for Casey |

First run: **63 inspection work orders**, $551K invoiced across them, $34K still
open. There were **no CP690 inspections** at these branches in this window.

## Things worth knowing

- **7460 has no inspection job code.** 7460s are booked as the generic
  `IS-STRIPPER INSPECT` (CS690s sometimes are too). So inspections are matched by
  **model-specific job code or by the machine on the work order**
  (`Silver_WkRoFile.Registration` → `Silver_WkVehFl.Model`). A job-code-only
  filter would have missed every 7460. The `Matched On` column shows which rule
  found each row.
- The report's inspection list (`lookup_InspectionJobCodes`) is used, with two
  changes: `IS-AMS SOFTWARE` is dropped (it's a software update), and JD's
  `<model>/9072/150` "Pre Harvest Inspection, Adjust & Calibrate" codes are added.
  Those aren't in the report's list but were used, e.g. Big Spring WO 689171.
- Checked against `Fact_LaborJobSummary`. Every inspection code for these models
  at these branches is in the workbook except 2 `IS-STRIPPER INSPECT` jobs on
  **7455** strippers, which weren't requested.
- **`Fact_WorkOrderParts` is missing invoices.** Invoice 1950991 (Br 8, WO 689171,
  $16K parts) has no lines at all. Over the 63 WOs the part-line total is about
  $43K short of `WkOthSub.InvParts`. So $ totals use the job lines, and the Parts
  tab is detail only. This probably makes the Inspections report's parts $ low
  too; worth looking into separately.

## Running it again

`timeout 600 python build_report.py` (about 1–2 min). It reads the Prod
DP_Presentation lakehouse via DuckDB/OneLake (`az login` credentials). The end
date is always today.
