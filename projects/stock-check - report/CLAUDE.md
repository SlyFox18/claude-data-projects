# Stock Check Report — Claude Context

## Status
**Production** ✅ — Live in RP - Service Reports. Power Automate daily alert active.
**Requested by:** Corp Aftermarket Sales Manager
**Primary audience:** Corp Sales Manager (kurhurst@spitractor.com)

## Business Purpose
Internal work orders (WO type = `'i'`) represent service work performed on stock (unsold) equipment. This report gives the Corp Sales Manager visibility into open stock check WOs in real time, plus a daily email alert each morning showing WOs entered the previous business day.

---

## Fact Table — `Fact_InternalWorkOrders`

**Dataflow:** `df_Fact_InternalWorkOrders` in LH_Master_Data → Dataflows → 04 - Fact  
**Grain:** One row per **Work Order × Job Code** — this is critical. A single WO can have multiple rows.  
**Refresh:** Full daily, Phase 4  
**Scope:** `CreatedOn >= 2026-01-01`, `JobType = 'I'` (Internal WOs only)

### Source Joins
| Table | Purpose |
|---|---|
| `wkrodesc` | Base table — job codes, filter `JobType = 'I'` |
| `WKROFILE` | WO header: dates, status, equipment IDs |
| `wkothsub` | Est hours, standard labor flag, invoice reference |
| `wkmechwk` | Actual and invoiced hours — SUM per WO × JobCode before joining |
| `vhstock` | Make/Model for stock units (LEFT JOIN on StockNumber) |
| `WKVEHFL` | Make/Model for registered/fleet units (LEFT JOIN on Registration, fallback) |

### Key Column Notes
- `IsClosed`: string `"Y"` or `"N"` — NOT boolean. All DAX filters use `= "Y"` or `= "N"`.
- `ProgressStatus`: raw codes stored as **UPPERCASE** in the data (`BI`, `WF`, `VP`, `WIP`, `VA`, `IV`, `CA`, `WP`). The DAX SWITCH measures use lowercase (`bi`, `wf`, etc.) — this works because DAX text comparison is case-insensitive. Do NOT change the SWITCH to uppercase.
- `Equipment`: calculated column defined as `[Make] & " " & [Model]` — declared inline in the column definition in TMDL, not as a separate expression property.

---

## Semantic Model

**Path:** `reports/Stock Check.SemanticModel/definition/`  
**Measures file:** `tables/_Measures.tmdl`

### Tables
| Table | Source |
|---|---|
| `Fact_InternalWorkOrders` | LH_Master_Data lakehouse |
| `dim_BranchLocation` | LH_Master_Data lakehouse |
| `dim_DateTable` | LH_Master_Data lakehouse |
| `Data Refresh` | LH_Master_Data lakehouse |

### Relationships
- `Fact_InternalWorkOrders[Branch]` → `dim_BranchLocation[BranchID]` (single direction)
- `Fact_InternalWorkOrders[CreatedOn]` → `dim_DateTable[Date]` (single direction)

### DAX Measures Summary
| Measure | Notes |
|---|---|
| `Total WOs` | DISTINCTCOUNT WorkOrder |
| `Open WOs` | DISTINCTCOUNT WorkOrder where IsClosed = "N" |
| `Branches with Open WOs` | Needs CROSSFILTER — uses bothDirections to count branch dimension |
| `Active Branches` | Same CROSSFILTER pattern as above |
| `Days Open` | TODAY() − MIN(CreatedOn), only when HASONEVALUE(WorkOrder) |
| `Days Open or to Close` | Open → TODAY() − CreatedOn; Closed → ClosedDate − CreatedOn |
| `Avg Days Open` | AVERAGEX over open WOs |
| `Avg Days to Close` | AVERAGEX over closed WOs using SUMMARIZE |
| `Over 14 Days` | Count of open WOs where Days Open > 14 |
| `Hrs Worked / Invoiced / Estimated` | SUM of respective columns |
| `Progress Status Label` | SWITCH on ProgressStatus — returns human-readable label |
| `Days Open Color` | Returns "#FCA5A5" if > 14, else BLANK() |
| `Home - Header` | HTML gradient banner with date range subtitle |
| `Page 2 - Header` | Same pattern, title = "Stock Checks History" |
| `KPI Row - Open Stock Checks` | HTML 4-metric bar: Open WOs, Branches, Avg Days Open, Over 14 Days |
| `KPI Row - History` | HTML 4-metric bar: Total WOs, Open WOs (color-coded), Avg Days to Close, Active Branches |
| `WO Detail - Header` | HTML header for drill-through page, shows WO # and branch |
| `WO Detail - Card` | HTML 2×2 detail card — Equipment, WO Details, Job Details, Hours & Financials |
| `Status Badge` | HTML pill badge per status code (not used in tables — for HTML visual only) |

### Critical DAX Pattern: Multi-Row WOs
The fact table is at WO × JobCode grain. When a WO has multiple job codes:
- `SELECTEDVALUE(Fact_InternalWorkOrders[JobCode])` returns BLANK
- `WO Detail - Card` handles this with a COUNTROWS check:
  ```
  VAR _JobCodeCount = COUNTROWS(VALUES(Fact_InternalWorkOrders[JobCode]))
  VAR _JobCode = IF(_JobCodeCount = 1, SELECTEDVALUE(...), FORMAT(_JobCodeCount, "0") & " codes (see table below)")
  ```

### Status Code Reference
| Code (in data) | Label | Color |
|---|---|---|
| BI | Booked-In | #3b82f6 (blue) |
| VA | Equipment Arrived | #0ea5e9 (sky) |
| WIP | Work Commenced | #f97316 (orange) |
| WF | Work Finished | #10b981 (green) |
| IV | Equipment Invoiced | #8b5cf6 (purple) |
| CA | Customer Advised | #6366f1 (indigo) |
| VP | Equipment Picked-up | #22c55e (bright green) |
| WP | Work Pending | #6b7280 (gray) |

---

## Report Pages (3)

### Page 1 — Open Stock Checks
Filters to `IsClosed = "N"` only.
- HTML header (gradient banner with date range)
- KPI row HTML visual: Open WOs, Branches with Open WOs, Avg Days Open, Over 14 Days
- Horizontal bar chart: Open WOs by Branch
- Table: WO#, Branch, Make/Model, Stock#, Date In, Days Open (red if > 14), Status
- Slicers: Branch (dropdown), Status (dropdown)

### Page 2 — Historical Log
All WOs from 2026-01-01 regardless of status.
- HTML header
- KPI row HTML visual: Total WOs, Open WOs, Avg Days to Close, Active Branches
- Slicers: Date Range, Branch, Status, WO# search
- Matrix or table with WO → Job Code drill-down

### Page 3 — WO Detail (Drill-Through)
Drill-through page from pages 1 and 2 — scoped to a single WO.
- HTML header showing WO # and Branch
- HTML 2×2 detail card (Equipment, WO Details, Job Details, Hours & Financials)
- Table showing all job codes for that WO

---

## Power Automate Flow — Stock Check Daily Alert

**Flow name:** Stock Check Daily Alert  
**Location:** Power Automate (same tenant)  
**Trigger:** Recurrence — Weekly, Mon–Fri, 9:00 AM CST

### Flow Structure (True branch inside Condition)
```
Recurrence (Mon-Fri, 9 AM)
  → Initialize variables (varHTMLRows as string)
  → Compose: TodayCST  — utcNow() converted to CST
  → Compose: DayOfWeek — dayOfWeek(TodayCST)
  → Compose: StartDate — if Monday, lookback 3 days; else 1 day
    Expression: addDays(formatDateTime(outputs('TodayCST'),'yyyy-MM-dd'), if(equals(outputs('DayOfWeek'),1),-3,-1))
  → Run a query against a dataset (Power BI connector)
      Workspace: RP - Service Reports
      Dataset: Stock Check
      DAX query: built via Compose, filters CreatedOn = StartDate through today
  → Condition: Should We Send
      length(body('Run_a_query_against_a_dataset')?['firstTableRows']) > 0
      True branch:
        → Apply to each (firstTableRows)
            → Compose: StatusColor (SWITCH on uppercase status codes)
            → Compose: StatusLabel (SWITCH on uppercase status codes)
            → Append to string variable: varHTMLRows (concat() expression)
        → Compose: FullEmailHTML (text mode — full HTML template)
        → HTTP action (Microsoft Graph sendMail)
      False branch: (no actions — no email if 0 rows)
```

### Critical Flow Details

**DAX Query Column Names:** The Power BI `Run a query against a dataset` action returns column names wrapped in brackets. Always reference them as:
- `items('Apply_to_each')?['[WorkOrder]']`
- `items('Apply_to_each')?['[Branch]']`
- `items('Apply_to_each')?['[Equipment]']`
- `items('Apply_to_each')?['[StockNumber]']`
- `items('Apply_to_each')?['[ProgressStatus]']`
- `items('Apply_to_each')?['[DateEntered]']`

**ProgressStatus in flow data:** Comes back UPPERCASE from the DAX query. StatusColor and StatusLabel Compose expressions must use uppercase codes (`BI`, `WF`, `VP`, etc.).

**varHTMLRows:** Built using `concat()` expression mode (not text mode) in the Append to string variable action. Each iteration appends one `<tr>...</tr>` block only — no `<table>` or `<tbody>` tags inside.

**FullEmailHTML:** Uses **text mode** (NOT expression/fx mode). Has `@{variables('varHTMLRows')}` embedded directly in the HTML. This is the same pattern as the Parts Action Summary flow.

**Email sending:** Uses HTTP action with Microsoft Graph API — NOT Send email V2. Graph renders full HTML including CSS gradients.

### HTTP Action Configuration
| Field | Value |
|---|---|
| Method | POST |
| URI | `https://graph.microsoft.com/v1.0/users/bfox@spitractor.com/sendMail` |
| Headers | `Content-Type: application/json` |
| Auth type | Active Directory OAuth |
| Authority | `https://login.microsoftonline.com` |
| Audience | `https://graph.microsoft.com` |
| Tenant | 8a02a2b8-0092-4de5-8f76-4700d099feb1 |
| Client ID | 5612b236-88fb-4f69-a08f-22ca69392db3 |
| Credential type | Secret |

HTTP Body JSON:
```json
{
  "message": {
    "subject": "Stock Check Alert — @{length(body('Run_a_query_against_a_dataset')?['firstTableRows'])} Internal WOs Entered",
    "body": {
      "contentType": "HTML",
      "content": "@{outputs('FullEmailHTML')}"
    },
    "toRecipients": [{"emailAddress": {"address": "kurhurst@spitractor.com"}}]
  }
}
```

**To change the recipient:** Update `address` in the HTTP action body JSON. Test recipient is bfox@spitractor.com; production recipient is kurhurst@spitractor.com.

### Monday Lookback Logic
```
DayOfWeek output: 0=Sunday, 1=Monday, 2=Tuesday ... 6=Saturday
StartDate expression: addDays(today, if(equals(DayOfWeek, 1), -3, -1))
```
Monday looks back 3 days to catch Friday's entries. All other weekdays look back 1 day.

### Email Design
- Dark navy header (`#1D3C4E`) with South Plains Implement logo (HubSpot CDN URL)
- Row data with colored status badges using inline `background-color` from StatusColor Compose
- "View Full Report →" button in bright blue (`#0369a1`)
- Footer: "Stock Check Report — South Plains Implement"
- Logo URL: `https://2271149.fs1.hubspotusercontent-na2.net/hubfs/2271149/raw_assets/public/South-Plains-Website-Build/South%20Plains%20Website%20Template/images/south-plains-implement-logo.png`

---

## Pipeline

**Status:** Not yet integrated into Pipeline_Master_Orchestrator (deferred — pending report validation)  
**Target:** Phase 4, medium wave  
**Dataflow:** `df_Fact_InternalWorkOrders`  
**When adding to pipeline:** Add to Phase 4 Facts wave. Semantic model refresh goes in Phase 5. Flow trigger is 9 AM — well after pipeline completes ~6 AM.

---

## Report URLs
- **Report (production):** `https://app.powerbi.com/groups/fa9b2eef-d507-48ad-bbeb-242037941987/reports/f28f49cc-3616-48b5-b5e2-877ae552d5b9/e384167396533ecc066e?experience=power-bi`
- **Workspace:** RP - Service Reports

---

## Known Gotchas

1. **IsClosed is a string** — filter with `= "Y"` or `= "N"`, not TRUE/FALSE
2. **ProgressStatus is case-insensitive in DAX** but UPPERCASE in the raw data. The SWITCH measures use lowercase and work fine. The Power Automate StatusColor/StatusLabel Composes must use UPPERCASE.
3. **Multi-row WOs** — the WO × JobCode grain means SELECTEDVALUE returns blank on any measure scoped to JobCode when a WO has multiple codes. Use COUNTROWS(VALUES(...)) to detect this.
4. **CROSSFILTER required for branch counts** — `Branches with Open WOs` and `Active Branches` use CROSSFILTER to count the branch dimension correctly. Do not remove it.
5. **TMDL calculated columns** — the `Equipment` column uses inline expression syntax: `column Equipment = [Make] & " " & [Model]`. Do not use `expression =` as a separate property — it does not exist in TMDL.
6. **Flow JSON subject line** — the subject must be a single line with no newlines inside the string. A line break inside a JSON string value causes the HTTP action to fail with "invalid expression."
7. **concat() vs text mode** — varHTMLRows Append uses `concat()` expression mode. FullEmailHTML uses text mode. Do not swap these — `@{...}` tokens don't work inside concat(), and complex concat() strings don't belong in text-mode fields.
