# Service Time Sheets — System Design

**Date:** 2026-04-28
**Author:** Brian Fox
**Status:** Draft — pending stakeholder review

---

## Problem Statement

Service technicians submit time sheets each pay period that HR uses to calculate pay. The current process is entirely manual — Excel workbooks are emailed to HR, HR re-enters figures into a separate payroll sheet, and no validation against the source system ever occurs. There is no audit trail, no structured data, and no mechanism to detect whether submitted draws and hours match what is actually invoiced in the source system. The CFO identified this as a financial controls gap.

---

## Current State (As-Is)

- Each location's service manager compiles a single Excel workbook with one tab per technician
- The workbook is emailed to HR (plus a printed copy)
- HR Director manually extracts figures and enters them into a separate payroll sheet
- That sheet is passed to the payroll specialist
- No comparison against the source system (Invoice/ODBC) is performed
- Draws taken against open, uninvoiced repair orders are not reconciled against eventual invoice amounts
- The process varies by location — some managers may fill out sheets on behalf of techs, others may receive input from techs informally before compiling

**Scale:** 13 locations, ~58 technicians total. Lorenzo is the largest location (11 techs).

**Current Excel columns (per tech tab):**
Customer Name, Model, RO#, % Work Complete, Draw 1 Date, Draw 1 Hrs, Draw 2 Date, Draw 2 Hrs, Draw 3 Date, Draw 3 Hrs, Final Draw Date, Final Draw Hrs, Current Draw/Shop/Field Hours, After Hours
Totals: Total Hours, Holiday Hours, PTO Hours, No Pay Hours

---

## Goals

1. Eliminate HR manual re-entry — data flows from submission to report automatically
2. Create a structured, auditable record of every technician's submitted hours and draws per pay period
3. Build a Power BI report that compares submitted hours and draws against invoiced hours in the source system
4. Standardize the submission process across all locations with a defined, enforced workflow
5. Protect payroll data — only authorized users can access submissions
6. Keep the input experience as simple as possible for managers and techs (low technical ability)
7. Present a clear upgrade path to Power Apps when the organization is ready

---

## Success Criteria

- Zero manual re-entry by HR for the comparison/validation step
- All 13 locations submitting through the same structured process
- Power BI report showing hours and draw discrepancies per technician per pay period, refreshing automatically
- Payroll data not accessible to anyone outside of authorized HR, payroll, and management roles
- Service managers able to submit with no new software to install and no technical training beyond "save the file here"

---

## Options Considered

### Option A — Excel Redesign + OneDrive Drop Folder

Standardize the Excel template and move submission from email to a shared OneDrive/SharePoint folder. Power BI reads all files via a Fabric Dataflow folder connector.

**Pros:** Zero new tools, minimal disruption, managers still use Excel.
**Cons:** No automated HR notification. Template discipline is fragile — if someone alters the format the pipeline breaks. No audit trail for when files were submitted.

### Option B — Excel Redesign + SharePoint Folder + Fabric Dataflow + Power Automate Notification *(Recommended)*

Same standardized Excel template saved to a dedicated SharePoint site with folder-level security per location. A simple Power Automate flow fires on file arrival and notifies HR. A Fabric Dataflow reads all submissions on schedule, normalizes data across all tabs and files, and lands it in the Lakehouse. Power BI compares against Invoice data from the source system.

**Pros:** Eliminates HR re-entry. Structured data in Fabric feeds a reliable Power BI report. Managers need no special licensing — only basic M365 access to save a file. Power Automate notification uses a simple trigger with no complex extraction. Fits the existing Fabric architecture.
**Cons:** Requires a dedicated SharePoint site to be provisioned. The Excel template must be maintained and distributed to managers each time it changes.

### Option C — Power Apps Canvas App *(North Star / Future)*

Replace Excel entirely with a canvas app. Tech or manager fills out the form on any device. Data writes directly to a structured list. Manager approval step optional. Power BI reads from the same list.

**Pros:** Best UX, most dummy-proof, full workflow automation, no template maintenance.
**Cons:** Requires Power Apps licensing (~$10–20/user/month per-user plan, or confirm existing M365 entitlement). Significant build effort. Requires tech adoption of a new tool — premature given current state of service department's technology comfort level.

---

## Recommended Approach — Option B

### Architecture Overview

```
Service Manager
  └── Fills out Excel template (one workbook per location, one tab per tech)
  └── Saves to SharePoint: Service Time Sheets / [Location] /
        └── [Location] - [PayrollStartDate] to [PayrollEndDate].xlsx

Power Automate (simple trigger)
  └── New file detected in any location folder
  └── Sends notification email to HR Director + Payroll Specialist
        "Lorenzo time sheet submitted for 2026-03-23 to 2026-04-05"

Fabric Dataflow (scheduled, existing pipeline)
  └── SharePoint.Files() reads all workbooks across all location folders
  └── Excel.Workbook() expands all tabs per file
  └── Normalizes to one row per technician per RO per pay period
  └── Lands in Lakehouse: LH_Master_Data → service_time_sheets

Power BI Semantic Model + Report
  └── service_time_sheets (submitted data)
  └── TechnicianInvoiceDetailServiceForm or Invoice (source system data)
  └── Technician_Code_Names (tech lookup)
  └── dim_BranchLocation (branch dimension)
  └── Compares: submitted hours vs. invoiced hours per RO per tech
  └── Flags draws on open ROs, shows cumulative draw vs. eventual invoice
```

---

## Standardized Workflow (To Be Adopted by Service Department)

This is the process that the Corp Service Manager and HR Director need to agree on and communicate to all locations.

```
1. TECH (or manager on their behalf)
   Provides their RO entries, draw amounts, holiday/PTO hours
   for the pay period to the service manager

2. SERVICE MANAGER
   Opens the pre-built Excel template from the SharePoint folder
   Fills out one tab per technician
   Saves the completed workbook to their location's SharePoint folder
   File naming: [Location] - [YYYY-MM-DD] to [YYYY-MM-DD].xlsx
   Example: Lorenzo - 2026-03-23 to 2026-04-05.xlsx

3. POWER AUTOMATE (automatic)
   Detects new file → emails HR Director and Payroll Specialist
   with location name, pay period, and submission timestamp

4. HR DIRECTOR / PAYROLL SPECIALIST
   Receives Power Automate notification email
   Validates hours and draws before processing payroll
   *** SEE CONSTRAINT BELOW — HR does not currently have Power BI licenses ***
   Flags any discrepancies with the relevant service manager

5. PAYROLL PROCESSING
   Proceeds using the structured data (no manual re-entry)
```

**Open question for stakeholders:** Should individual techs sign off on their own entries before the manager submits? The prototype included a signature field. If yes, this stays as a printed/informal step until Option C (Power Apps) is implemented.

### Power BI Access for HR — Constraint and Options

**Current state:** Only the Corp Service Manager and CFO currently have Power BI licenses. HR Director and Payroll Specialist do not. This affects how the validation step works in practice.

Three options to resolve this:

**Option 1 — License HR for Power BI Pro (~$10/user/month, 2 users)**
HR gets direct access to the report and runs validation themselves each pay period. Clean, simple, gives HR full visibility. Cost is easily justified given the financial controls gap the CFO identified — this report exists specifically to protect payroll accuracy. Recommended.

**Option 2 — Corp Service Manager owns the validation step**
Corp Service Manager reviews the Power BI report each period and communicates any discrepancies to HR before payroll runs. HR never needs a license. Adds a manual coordination step and creates a dependency on one person's availability each pay period.

**Option 3 — Power Automate emails a comparison summary to HR**
After each submission, Power Automate generates a formatted email to HR showing submitted vs. invoiced hours per tech, flagging discrepancies. HR gets validation data without needing a license. More build complexity, less flexible than the full report (no drill-down, no slicing by period or location).

**Decision needed:** Confirm with CFO and HR Director which path to take before finalizing the workflow. If Option 1 is approved, add HR to the Power BI workspace with Viewer role.

---

## Excel Template Design

### Workbook-Level Header (applies to whole workbook)
| Field | Type | Notes |
|---|---|---|
| Location | Dropdown (locked values) | Drives mileage visibility flag |
| Payroll Start Date | Date picker | Monday of the pay period |
| Payroll End Date | Date picker | Sunday of the pay period |
| Pay Date | Date picker | Actual payroll processing date |
| Mileage Applicable | Auto (hidden) | Derived from Location — hides mileage column if N |

### Per-Tech Tab
Tab name = technician's name (e.g., "Nick Nunley")

**Tech Header (locked calculated fields — manager selects tech number, rest auto-fills):**
| Field | Source |
|---|---|
| Tech Number | Dropdown selection |
| Technician Name | Auto-filled from tech lookup table |
| Tech Level | Auto-filled from tech lookup table |
| Branch | Auto-filled from tech lookup table |
| Pay Rate | Auto-filled from tech lookup table (TECH LEVELS: Level 3 = $40, Level 4 = $43, Level 5 = $46 — confirm rates are current with HR before go-live) |

**RO Entry Table (one row per job — manager adds rows):**
| Field | Type | Notes |
|---|---|---|
| Customer Name | Free text | |
| Model | Free text | Equipment model |
| RO # | Number | Must be numeric |
| % Work Complete | Dropdown | 25%, 50%, 75%, 100% |
| Draw 1 Date | Date | Record-keeping only |
| Draw 1 Hrs | Number | Record-keeping only |
| Draw 2 Date | Date | Record-keeping only |
| Draw 2 Hrs | Number | Record-keeping only |
| Draw 3 Date | Date | Record-keeping only |
| Draw 3 Hrs | Number | Record-keeping only |
| Final Draw Date | Date | Record-keeping only |
| Final Draw Hrs | Number | Record-keeping only |
| Current Period Hrs | Number | **Hours being claimed this pay period** |
| After Hours | Number | Hours worked outside normal shift — tracked separately, confirm with HR whether these roll into Total Pay or are informational only |

**Summary Section (calculated, locked):**
| Field | Formula |
|---|---|
| Total Hours | SUM of Current Period Hrs |
| Holiday Hours | Manual entry |
| PTO Hours | Manual entry |
| No Pay Hours | Manual entry |
| Mileage (miles) | Manual entry — hidden if location = N |
| Mileage $ | Calculated (miles × per-mile rate) — hidden if location = N. **Open question: is the per-mile rate fixed company-wide, per-location, or manually entered each period? Confirm with HR before building formula.** |
| Subtotal | Calculated |
| Total Pay | Calculated |

**Draw Date Policy (to confirm with HR):**
Current recommendation: Draw date columns remain "for record keeping only" as they are today. The **Pay Date** at the workbook level is the official date of record for payroll. This matches the existing sheet behavior and avoids ambiguity.

---

## SharePoint Structure & Security

### Site
Dedicated SharePoint site separate from the existing Report Site.
Suggested name: `SouthPlainsImplement-ServicePayroll` (or HR's preferred name).
Keeps payroll-sensitive data completely isolated from general reporting content.

### Folder Structure
```
Service Time Sheets/           ← Document Library root
├── Abernathy/
├── Big Spring/
├── Brownfield/
├── Lamesa/
├── Levelland/
├── Littlefield/
├── Lorenzo/
├── Lubbock/
├── Morton/
├── San Angelo/
├── Seminole/
├── Slaton/
├── Snyder/
└── Tahoka/
```

Files accumulate — never overwritten. Every pay period creates a new file.
Naming convention: `[Location] - [YYYY-MM-DD] to [YYYY-MM-DD].xlsx`

### Permission Groups

| Role | SharePoint Access | Power BI Access |
|---|---|---|
| HR Director | Full access — all folders | All locations, all techs |
| Payroll Specialist | Full access — all folders | All locations, all techs |
| Corp Service Manager | Read — all folders | All locations, all techs |
| Location Service Manager | Write + Read — their folder only | Their location only (RLS) |
| Brian (admin) | Site admin | Full admin |
| Fabric service account | Read-only — all folders | N/A |

Location managers cannot see other locations' folders. SharePoint folder-level permission inheritance is broken at the location folder level.

---

## Fabric Data Pipeline

### Dataflow
- **Name:** `df_ServiceTimeSheets_Raw` (or similar, in `01 - Raw Sources` group)
- **Source:** `SharePoint.Files()` against the Service Time Sheets document library
- **Transformation steps:**
  1. Filter to `.xlsx` files only
  2. For each file: `Excel.Workbook()` to expand all sheets
  3. Filter out any non-tech tabs (e.g., cover sheets or summary tabs by name convention)
  4. For each tab: select and rename columns to PascalCase Lakehouse standard
  5. Add `SourceFile`, `Location` (parsed from folder path), `PayrollStartDate`, `PayrollEndDate` (parsed from filename)
  6. Union all tabs across all files into a single flat table
  7. Add `LoadTimestamp` for audit purposes
- **Output table:** `LH_Master_Data.service_time_sheets`
- **Schedule:** Fits into existing pipeline — runs after raw sources phase, before dimensions

### Key Columns in Output Table
`Location`, `PayrollStartDate`, `PayrollEndDate`, `PayDate`, `TechNumber`, `TechnicianName`, `TechLevel`, `Branch`, `CustomerName`, `Model`, `RONumber`, `PercentComplete`, `Draw1Date`, `Draw1Hrs`, `Draw2Date`, `Draw2Hrs`, `Draw3Date`, `Draw3Hrs`, `FinalDrawDate`, `FinalDrawHrs`, `CurrentPeriodHrs`, `AfterHours`, `HolidayHours`, `PTOHours`, `NoPayHours`, `MileageMiles`, `MileageDollars`, `Subtotal`, `TotalPay`, `SourceFile`, `LoadTimestamp`

---

## Power Automate Notification Flow

Simple trigger — no data extraction, no Office Scripts required.

**Trigger:** New file created in any subfolder of the Service Time Sheets document library
**Actions:**
1. Parse location name from folder path
2. Parse pay period from filename
3. Send email to HR Director + Payroll Specialist:
   - Subject: `[Location] time sheet submitted — [Pay Period]`
   - Body: Submitted by [file author], at [timestamp], file link

This flow runs under Brian's account or a service account. Managers never interact with it.

---

## Power BI Report

### Data Sources
| Table | Source | Purpose |
|---|---|---|
| `service_time_sheets` | Lakehouse | Submitted time sheet data |
| `TechnicianInvoiceDetailServiceForm` | Fabric Warehouse (existing) | Source system: hours punched, invoice hours, labor cost/sale per RO |
| `Technician_Code_Names` | Lakehouse (existing) | Tech code → name lookup |
| `dim_BranchLocation` | Lakehouse (existing) | Branch dimension |
| `dim_DateTable` | Lakehouse (existing) | Date dimension |

### Report Pages (proposed)

**Page 1 — Pay Period Summary**
Slicer: Pay Period, Location, Technician
Matrix: Technician | Submitted Hours | Invoiced Hours | Hours Difference | Total Draws | Labor Billed | Paid Difference
Conditional formatting: flag rows where submitted > invoiced (red), draws exceed invoice amount (red)

**Page 2 — RO Detail**
Drill-through from Page 1
Table: RO# | Customer | % Complete | Draw 1/2/3 | Final | Current Period Hrs | Invoice Hours | Invoice Labor Sale | Variance
Shows open ROs (not yet invoiced) with cumulative draws to date

**Page 3 — Draw Tracking**
Tracks draws over time per RO across multiple pay periods
Shows total draws taken vs. eventual invoice amount once the RO closes
Flags ROs where cumulative draws exceed invoiced labor

**Page 4 — Location Summary**
Branch-level rollup for Corp Service Manager view

### Key Measures (carry forward from prototype)
- `Submitted Hours` = SUM of CurrentPeriodHrs per tech per period
- `Invoiced Hours` = SUM of InvoiceHours from source system per tech per period
- `Hours Difference` = Invoiced Hours − Submitted Hours
- `Total Draws` = SUM of all Draw columns
- `Labor Billed` = Invoiced Hours × Pay Rate
- `Tech Pay` = Submitted Hours × Pay Rate
- `Paid Difference` = Labor Billed − Tech Pay
- `Cumulative Draws on RO` = total draws taken across all periods for a given RO#

---

## Option C — Power Apps Upgrade Path (For Stakeholder Presentation)

When the organization is ready, the Excel template is replaced by a Power Apps canvas app. The data model and Power BI report do not change — only the input mechanism changes.

**What it takes:**
- Power Apps per-user license (~$10–20/user/month) for each manager who submits — approximately 13–15 users
- Canvas app development: estimated 3–4 weeks build + testing
- Change management: training for service managers

**What you gain:**
- No template to maintain or distribute
- Tech number dropdown auto-fills all tech info — zero manual lookup
- "Add Another" repeating rows for ROs (no fixed row limit)
- Branch-level mileage flag is automatic (no hidden column logic)
- Manager approval step built into the flow
- Data goes directly to a structured list — no Excel parsing in the Dataflow
- Mobile-friendly if techs eventually submit their own entries

**Trigger for recommending the upgrade:** When template maintenance becomes a recurring pain point, or when the service department's technology comfort level increases enough to support training.

---

## Open Questions for Stakeholder Meetings

*(Items marked with an asterisk must be confirmed before building the Excel template)*

1. *__Power BI access for HR__* — HR Director and Payroll Specialist do not currently have Power BI licenses. Three options: license them (~$10/user/month), route validation through Corp Service Manager, or have Power Automate email a comparison summary. Recommend licensing HR — decision needed from CFO.
2. *__SharePoint site name and provisioning__* — Does IT need to create this, or can Brian provision it directly?
2. **Tech signature requirement** — Is a digital signature on each submission required for payroll, or is manager submission sufficient?
3. *__Mileage locations__* — Which locations pay mileage and which do not? (Need confirmed list to build the template flag)
4. *__Mileage rate__* — Is the per-mile reimbursement rate fixed company-wide, different per location, or manually entered each period?
5. *__After Hours definition__* — Do After Hours roll into Total Pay, or are they tracked separately for informational purposes only?
6. **Who submits for each location** — Is it always the service manager, or can a service writer also submit? One designated submitter per location is strongly recommended.
7. **HR re-entry elimination scope** — Does HR want to stop re-entering entirely (Power BI is the source of truth for validation), or do they want to keep their own payroll sheet fed automatically via Power Automate?
8. **Pay Date vs. Draw Date policy** — Confirm: draw date columns remain "record keeping only," pay date at workbook level is the official date of record.
9. *__Pay rates__* — TECH LEVELS CSV shows Level 3 = $40, Level 4 = $43, Level 5 = $46. Confirm these are current and whether any individual exceptions exist.
10. **Historical data** — Does HR want prior periods back-loaded into the system, or is the go-live date the clean start?
11. **Report access for location managers** — Should managers be able to see their own location's report, or is the Power BI report HR/management-only?

---

## Out of Scope (This Phase)

- Power Apps implementation
- Direct integration between the Excel template and the source system (RO lookup, auto-populating customer/model from RO#)
- Technician self-service submission (all submissions go through the service manager)
- Payroll system integration (the report informs payroll but does not feed the payroll system directly)
