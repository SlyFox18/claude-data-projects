# Service Time Sheets — Audit Report

> **Status:** Production ✅ — Live in RP - Service Reports  
> **Last Updated:** 2026-05-28  
> **Workspace:** RP - Service Reports  
> **Audience:** CFO, Service Manager, Payroll

---

## 📊 Project Overview

A payroll audit tool that cross-references technician-submitted service time sheets against what was actually invoiced in EquipRDB. For every RO a tech submits on a time sheet, the report shows the hours and dollars the source system recorded — and surfaces any discrepancy before draw pay is approved.

The report reads submitted Excel workbooks directly from SharePoint, normalizes each tech's tab into a flat row, then joins against EquipRDB invoice and punch records to classify each submission into one of six audit buckets.

### Business Value Delivered

- ✅ **Catch overclaims before payroll is cut** — flags techs claiming more hours than invoiced
- ✅ **Surface underpay risk** — identifies ROs where system billed more than the tech claimed
- ✅ **Track draw advances** — distinguishes formal multi-period draw ROs from completed work
- ✅ **Location-level accountability** — scorecard shows flag rates and dollar exposure per branch
- ✅ **Tech risk leaderboard** — ranks technicians by net overclaim dollar amount
- ✅ **Drill-through to tech and RO level** — investigate any flag in two clicks

---

## 📁 Project Structure

```
service time sheets/
├── README.md                          # This file
├── CLAUDE.md                          # Claude context for future sessions
├── queries/
│   ├── df_ServiceTimeSheets_Raw.pq    # Phase 1: SharePoint → Lakehouse raw table
│   └── Fact_ServiceTimeSheet_Audit.pq # Phase 4: Audit fact table (main ETL)
├── reports/
│   └── Service Time Sheets.SemanticModel/
│       └── definition/
│           └── tables/
│               ├── _Measures.tmdl              # All DAX measures
│               └── Fact_ServiceTimeSheet_Audit.tmdl  # Fact table definition
├── sample time sheets/                # Reference Excel workbooks
├── team form/                         # PDF and JSON for the submission form
├── screen shots/                      # Prototype screenshots
└── report example - old/              # Legacy v1 report (Forms-based, archived)
```

---

## 🗄️ Data Model

### Architecture

```
SharePoint (.xlsx files)
        ↓
df_ServiceTimeSheets_Raw (Dataflow Gen2, Phase 1)
        ↓
LH_Master_Data.service_time_sheets (Lakehouse table)
        ↓
Fact_ServiceTimeSheet_Audit (Dataflow Gen2, Phase 4)  ←── TechnicianInvoiceDetail
        ↓                                              ←── TechnicianPunchedDetail
LH_Master_Data.Fact_ServiceTimeSheet_Audit             ←── WKROFILE
        ↓
Service Time Sheets.SemanticModel (Fabric Semantic Model)
        ↓
Service Time Sheets Report (Power BI)
```

### Fact Table

**`Fact_ServiceTimeSheet_Audit`**
- **Grain:** One row per technician per RO per pay period
- **Source:** `LH_Master_Data.service_time_sheets` (joined to three EquipRDB tables)
- **Refresh:** Phase 4 of Pipeline_Master_Orchestrator

| Column Group | Columns | Notes |
|---|---|---|
| Context | Branch, Location, PayPeriod, PayStart, PayEnd | Branch resolved: TID first, TPD fallback |
| Tech identity | TechName, TechNum, TechLevel, PayRate, TechNameFromTab | PayRate from tech level lookup |
| RO identity | CustomerName, Model, RONumber, RONumberText, PctComplete | RONumberText is the join key (text) |
| Sheet hours | Draw1Hrs–FinalDrawHrs, CurrentDrawHrs, ShopHrs, FieldHrs, AfterHours, Mileage | Layout-dependent columns |
| Claimed total | TotalClaimedHrs | CurrentDrawHrs OR ShopHrs+FieldHrs, plus AfterHours |
| Tech pay | TechPay | TotalClaimedHrs × PayRate |
| System hours | InvoicedHrs, PunchedHrs | From TID and TPD respectively |
| System dollars | TotalLaborCost, LaborBilled, LastInvoiceDate | From TID |
| RO status | IsClosed | From WKROFILE — "Y" = billing final |
| Audit | HoursDifference, PaidDifference, AuditStatus | Calculated in fact table |
| Lineage | SourceFile, LoadTimestamp | |

### No Model Relationships

The semantic model uses a **single fact table with no dimension relationships**. All filtering is done via the columns on the fact table itself (Location, TechName, PayPeriod, AuditStatus). This is intentional — the data is already denormalized at the fact table level, and adding shared dimensions would add complexity without benefit for this use case.

---

## 🔎 Audit Status — Six-Bucket Logic

The `AuditStatus` column is the core output of the report. Buckets are evaluated in order:

| # | Status | Condition | Action |
|---|--------|-----------|--------|
| 1 | **Draw - Open RO** | InvoicedHrs = null AND any of Draw1/2/3/FinalDrawHrs > 0 | CFO tracks these — pay advance on in-progress work |
| 2 | **Pending Invoice** | InvoicedHrs = null AND no draw history | Work submitted (possibly complete) but not yet billed |
| 3 | **Match** | `ABS(Claimed − Invoiced) < 0.001` | No discrepancy — exact match within tolerance |
| 4 | **Invoiced More Than Claimed** | InvoicedHrs > TotalClaimedHrs | System billed more than tech claimed; tech may be owed more |
| 5 | **Partial Invoice - In Progress** | Claimed > Invoiced AND IsClosed ≠ "Y" AND PunchedHrs > InvoicedHrs × 1.1 | RO still open — more billing expected; not a real overclaim |
| 6 | **Claimed More Than Invoiced** | All other Claimed > Invoiced cases | Genuine discrepancy — review before approving pay |

**Key distinction — Draw vs Pending Invoice:**
- A tech taking a **draw advance** fills in the Draw date + hours columns (Draw1–FinalDrawHrs). These are cross-period entries representing in-progress work.
- A tech submitting **completed work** only fills CurrentDrawHrs. If there is no invoice yet, this lands in "Pending Invoice" — it is not a draw advance.

**Key distinction — Partial Invoice vs Claimed More:**
- `IsClosed = "Y"` from WKROFILE is the authoritative signal that billing is final. When an RO is closed and Claimed > Invoiced, the gap is real (bucket 6).
- When the RO is still open (`IsClosed ≠ "Y"`), more job codes will be invoiced. Bucket 5 catches this so it does not generate false overclaim flags.
- The additional check `PunchedHrs > InvoicedHrs × 1.1` ensures punch records confirm more work exists (filters out credit/reversal rows with negative InvoicedHrs, which should not land in Partial Invoice).

---

## 💰 Pay Rate Table

| Tech Level | Hourly Rate | Notes |
|---|---|---|
| Level 3 | $40/hr | |
| Level 4 | $43/hr | |
| Level 5 | $46/hr | |
| SM (Service Manager) | null | Managers do not receive draw pay |

> Validate with HR before any production payroll run. Rates may change.

---

## 📋 Column Layout Auto-Detection

Time sheet Excel files come in four layouts depending on the tech. The raw dataflow detects the layout by reading the column 13 header text in row 7 of each tech tab:

| Layout | Trigger | Columns 13–16 |
|---|---|---|
| Standard (no mileage) | Col 13 starts with "current" | CurrentDrawHrs, AfterHours |
| Standard + Mileage | Col 13 "current", 15 cols | CurrentDrawHrs, AfterHours, Mileage |
| Shop/Field | Col 13 starts with "shop" | ShopHrs, FieldHrs, AfterHours |
| Shop/Field + Mileage | Col 13 "shop", 16 cols | ShopHrs, FieldHrs, AfterHours, Mileage |

`TotalClaimedHrs` is then calculated as:
```
= (CurrentDrawHrs if not null, else ShopHrs + FieldHrs) + AfterHours
```

---

## 🎨 Report Pages (6 Pages)

### Home — Navigation & Status Guide
- **Purpose:** Entry point with a visual drill-through flow diagram and audit status color legend
- **Key Visuals:** Navigation flow (Home → Audit → Drill → RO Detail), status guide cards, key terms glossary
- **Audience:** All users, especially first-time viewers

### Page 1: Executive Summary
- **Purpose:** Pay-period-level overview — where are the flags and how much do they cost?
- **Key Visuals:**
  - **Hero Card** — 6-section KPI bar: Total ROs, Claimed More (+ Overclaim $), Invoiced More (+ Risk $), Draw Advances (+ Draw pay $), Audited Pay, Net Overclaim
  - **Tech Risk Leaderboard** — matrix ranked by Net Overclaim $, showing Overclaim Hrs, # Claimed More, Overclaim Rate %
  - **Location Scorecard** — matrix by location: Total ROs, Match, Claimed >, Invoiced >, Pending, Draw $, Overclaim $, Flag Rate
- **Slicers:** Pay Period (collapsible panel), Location
- **Header:** Shows selected pay period date range dynamically (e.g. "May 4 – May 17, 2026")
- **Audience:** CFO, Service Manager

### Page 2: Time Sheet Audit
- **Purpose:** Full row-level detail — every tech, every RO, every pay period
- **Key Visuals:** Conditional-formatted table with AuditStatus color coding, HoursDifference bar
- **Navigation:** Right-click a Tech Name → drill through to Page 3
- **Audience:** Payroll, Service Manager

### Page 3: Tech Audit Detail (Drill-Through)
- **Purpose:** All ROs for a single technician — draw history breakdown and hours vs invoiced
- **Key Visuals:** Hero Card (tech-level KPIs), Draw Strip (visual draw progression), per-RO detail table
- **Navigation:** Right-click an RO Number → drill through to Page 4
- **Audience:** Payroll, Service Manager investigating a specific tech

### Page 4: Multi-Tech RO Detail (Drill-Through)
- **Purpose:** All technicians on a single RO side by side — attribution analysis
- **Key Visuals:** RO Detail Hero Card, RO Attribution Summary (narrative + financial), per-tech table
- **Audience:** Service Manager investigating a shared RO

### Page 5: Multi-Tech RO Review (Standalone)
- **Purpose:** All ROs where more than one tech submitted hours — standalone view, no drill-through required
- **Key Visuals:** Rollup table with RO Audit Status, Techs count, hours comparison, financial summary
- **Audience:** Service Manager reviewing shared-work ROs as a batch

---

## 🔧 Data Source Details

### `service_time_sheets` (Phase 1 Raw — SharePoint)
- **Query:** `df_ServiceTimeSheets_Raw.pq`
- **Source:** SharePoint site `SouthPlainsImplement-ServicePayroll / Service Time Sheets /`
- **Scope:** All submitted `.xlsx` files, excluding `~$` temp files, `_Template` folders, and hidden sheets
- **Location detection:** Last segment of folder path (e.g. `.../Service Time Sheets/Lorenzo/` → `"Lorenzo"`)
- **Sheet filtering:** Visible sheets, not starting with `_`, not named "TEMPLATE"
- **Row filtering:** Drops rows where RONumber is null, blank, or 0

### `TechnicianInvoiceDetail` (Phase 1 Raw — EquipRDB)
- **Joined on:** RONumberText + TechNum (= WorkOrder + TechCode)
- **Provides:** InvoicedHrs, TotalLaborCost, LaborBilled, LastInvoiceDate, Branch
- **Important:** Only contains **invoiced** job codes. Open ROs with no invoiced work are absent — this is expected, not missing data.
- **Aggregation:** Grouped to {WorkOrder, TechCode} before joining to prevent fan-out (multiple job codes per RO → multiple rows → inflated hours)

### `TechnicianPunchedDetail` (Phase 1 Raw — EquipRDB)
- **Joined on:** RONumberText + TechNum (= WorkOrder + TechCode)
- **Provides:** PunchedHrs (all clocked hours regardless of invoice status)
- **Used for:** Partial Invoice detection — confirms more work exists than what's been invoiced
- **Aggregation:** Same fan-out prevention — grouped before joining

### `WKROFILE` (Phase 1 Raw — EquipRDB)
- **Joined on:** RONumberText (= WorkOrder)
- **Provides:** IsClosed ("Y" or null)
- **Critical role:** `IsClosed = "Y"` is the authoritative signal that an RO's billing is final. Used as the gate between "Partial Invoice - In Progress" (open RO, more billing coming) and "Claimed More Than Invoiced" (closed RO, real discrepancy).

---

## ⚠️ Known Issues & Gotchas

### Data
- **Credit/reversal rows:** Some ROs have negative `InvoicedHrs` from billing reversals. With `IsClosed = "Y"`, these correctly land in "Claimed More Than Invoiced" rather than "Partial Invoice." The `PunchedHrs > InvoicedHrs × 1.1` guard in bucket 5 prevents negative InvoicedHrs from matching the partial invoice condition.
- **Branch on open ROs:** `TechnicianInvoiceDetail` only has Branch for invoiced ROs. For open ROs, Branch falls back to `TechnicianPunchedDetail.Branch`. If both are null, Branch will be blank.
- **SM techs:** Service managers appear in time sheets but have null PayRate and null TechPay. They are included in row counts but excluded from all dollar calculations.
- **Pay period label:** The `Home - Header Executive` measure reads `MIN(PayStart)` / `MAX(PayEnd)` from the fact table under the current filter context. When no Pay Period slicer is selected, it shows "All Pay Periods."

### Power Query
- **Layout detection** reads the raw column header from row 7 (index 5 in PQ). If a tech's template is malformed or the header is missing, `isShopField` defaults to false (standard layout). Validate any tech with all-null ShopHrs/FieldHrs and non-null CurrentDrawHrs.
- **RONumber is a float in the source** (e.g. `689990.0`). It is converted to text via `Text.From()` for all joins. The `RONumber` column in the fact table retains the numeric version for display.

### Report
- **Match tolerance is 0.001 hrs** (not zero, not 0.25). This handles floating-point rounding from the source system while still flagging any real billing gap.
- **`# Pending` measure** = Partial Invoice - In Progress (the ◆ bucket in the hero card). Not to be confused with `# Pending Invoice` which is the ⏰ bucket. Both exist as separate measures.

---

## 📐 Key DAX Measures

| Measure | Purpose |
|---|---|
| `# Claimed More` | Count of "Claimed More Than Invoiced" rows |
| `# Invoiced More` | Count of "Invoiced More Than Claimed" rows |
| `# Draw Open RO` | Count of "Draw - Open RO" rows |
| `# Pending Invoice` | Count of "Pending Invoice" rows |
| `# Pending` | Count of "Partial Invoice - In Progress" rows |
| `# Match` | Count of "Match" rows |
| `Net Overclaim $` | TechPay − LaborBilled for "Claimed More" rows (payroll cost of overclaims) |
| `Underpay Risk $` | (InvoicedHrs − ClaimedHrs) × PayRate for "Invoiced More" rows |
| `Overclaim Rate %` | # Claimed More ÷ (Match + Claimed More + Invoiced More) |
| `Draw Tech Pay` | Total TechPay for "Draw - Open RO" rows |
| `Auditable Tech Pay` | Total TechPay for all non-draw, non-pending rows |
| `Audited Rows` | Count of rows excluding Draw and Pending Invoice |
| `Home - Header Executive` | HTML card with pay period, greeting, date |
| `Hero Card - Audit Summary` | HTML 6-section KPI bar for Executive Summary |
| `Hero Card - Tech Detail` | HTML KPI bar for Tech Audit Detail page |
| `Hero Card - RO Detail` | HTML KPI bar for Multi-Tech RO Detail page |
| `Draw Strip` | HTML draw progression visual (D1 → D2 → D3 → Final → Current) |

---

## 📅 Change Log

### 2026-05-28 — Initial Production Build
- Built `df_ServiceTimeSheets_Raw` (SharePoint → Lakehouse, multi-layout Excel normalization)
- Built `Fact_ServiceTimeSheet_Audit` with four-source join (service_time_sheets + TID + TPD + WKROFILE)
- Implemented six-bucket AuditStatus classification
- Added `IsClosed` from WKROFILE as authoritative RO closure signal (replaces PunchedHrs-only heuristic)
- Tightened Match tolerance from 0.25 hrs → 0.001 hrs
- Built 6-page Power BI report with drill-through navigation
- Added HTML hero cards with dynamic dollar subtitles (Overclaim $, Risk $, Draw pay $)
- Pay period context in Executive Summary header (reflects slicer selection)
- Tech Risk Leaderboard + Location Scorecard on Executive Summary page
- Deployed to RP - Service Reports

---

## 🔗 Related Files

| File | Location | Purpose |
|---|---|---|
| `df_ServiceTimeSheets_Raw.pq` | `queries/` | SharePoint Excel ingestion query |
| `Fact_ServiceTimeSheet_Audit.pq` | `queries/` | Fact table ETL query |
| `_Measures.tmdl` | `reports/.../tables/` | All DAX measures |
| `Fact_ServiceTimeSheet_Audit.tmdl` | `reports/.../tables/` | Fact table TMDL definition |
| Sample time sheets | `sample time sheets/` | Reference Excel workbooks showing both layout types |
