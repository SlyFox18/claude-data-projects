# Non-JD Parts Order Tool — Plan 2: Power Apps V1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 4-screen Power Apps Canvas App that lets parts managers review ROP-based reorder recommendations, run one-time orders, and look up part history — all backed by the Fabric tables built in Plan 1.

**Architecture:** Canvas App (tablet layout) connects to Fabric Lakehouse tables via the SQL Analytics Endpoint (SQL Server connector) for Fact_NonJD_Reorder and Fact_NonJD_SalesHistory, and to a SharePoint list for config_PartSettings. All heavy calculation is pre-computed in Fabric — the app is display and filter only (except Screen 3 which calculates at runtime). Branch-level filtering is applied first on every screen to keep row counts manageable (~10-15K per branch from the 206K-row Reorder fact).

**Tech Stack:** Power Apps Canvas App (tablet layout), SQL Server connector → Fabric SQL Analytics Endpoint, SharePoint connector, Excel Online connector, Power Fx formula language

**This is Plan 2 of 3:**
- **Plan 1 (done):** Fabric Foundation — all data tables built and pipeline running daily at 7 AM
- **Plan 2 (this plan):** Power Apps V1 — production Canvas App
- **Plan 3 (future):** Web App V2 — React + Azure Static Web App

**Design spec:** `docs/superpowers/specs/2026-05-28-non-jd-parts-order-tool-design.md`

**Key facts from Plan 1:**
- `fact_nonjd_reorder`: 206,663 rows (one per Branch+PartNumber, Cost > 0, in-scope franchises)
- `fact_nonjd_saleshistory`: 12,416,280 rows (60 months × 206,938 part+branch combos)
- MarginFlag = "LOW" (uppercase) is the only value used
- Tables are lowercase in Fabric (`fact_nonjd_reorder`, `fact_nonjd_saleshistory`)
- Pipeline runs daily 7 AM, complete by ~7:16 AM

---

## File Map

**Files to create in `data-projects` (documentation and reference):**

| File | Purpose |
|---|---|
| `projects/part order tool - app/POWERAPPS-GUIDE.md` | Screen-by-screen formula reference (key Power Fx formulas, not stored in git by app) |
| `projects/part order tool - app/exports/ReorderExportTemplate.xlsx` | Excel template in SharePoint for export (upload once to SharePoint) |

**Artifacts created in Power Apps / SharePoint (not git-tracked):**

| Artifact | Location | Purpose |
|---|---|---|
| Non-JD Parts Order Tool | Power Apps → make.powerapps.com | The Canvas App itself |
| config_PartSettings | SharePoint list at spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite | Per-part overrides written by app |
| ReorderExportTemplate.xlsx | SharePoint Documents library (same site) | Template for Excel export |

---

## Task 1: Prerequisites — SharePoint List + Fabric Connection String

**Files:** None (setup steps only)

### 1A — Create the config_PartSettings SharePoint list

- [ ] **Step 1.1 — Create the list**

Go to `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite` → New → List → Blank list → Name: `config_PartSettings` → Create.

- [ ] **Step 1.2 — Rename the Title column**

Click the `Title` column header → Column settings → Rename → `PartNumber` → Save.

- [ ] **Step 1.3 — Add remaining columns**

Add each column with these exact names and types:

| Column Name | Type | Notes |
|---|---|---|
| Branch | Single line of text | |
| GroupOverride | Single line of text | |
| MinOverride | Number | |
| EOQ | Number | |
| ForceNonSpiking | Yes/No | Default: No |
| PreApprovedOrderRule | Choice | Choices: "Use normal rules", "Force 1 time to proposed" |
| Masking | Yes/No | Default: No |
| MaskingExpiration | Date | |

- [ ] **Step 1.4 — Verify**

The list should have 9 columns: PartNumber (Title), Branch, GroupOverride, MinOverride, EOQ, ForceNonSpiking, PreApprovedOrderRule, Masking, MaskingExpiration. Add one test row manually (any values) to confirm the structure works, then delete it.

### 1B — Find the Fabric SQL Analytics Endpoint

- [ ] **Step 1.5 — Get the SQL endpoint server name**

In Fabric → LH_Master_Data lakehouse → in the top toolbar, open the mode dropdown (currently shows "Lakehouse") → switch to **"SQL analytics endpoint"** → click Settings (gear icon) or look for "Connection" in the right panel. Copy the **Server** value — it will look like `{guid}.datawarehouse.fabric.microsoft.com`. Save it somewhere; you'll need it in Task 2.

- [ ] **Step 1.6 — Verify the server name works**

In SQL Server Management Studio or Azure Data Studio, connect to that server using your Microsoft account credentials. Confirm you can see the `lh_master_data` database and the tables `fact_nonjd_reorder` and `fact_nonjd_saleshistory` under `dbo` schema.

---

## Task 2: Create App and Connect Data Sources

- [ ] **Step 2.1 — Create the Canvas App**

Go to `make.powerapps.com` → Create → Blank app → Tablet layout → Name: `Non-JD Parts Order Tool` → Create.

- [ ] **Step 2.2 — Connect Fact_NonJD_Reorder**

Left panel → Data → Add data → search "SQL Server" → New connection → SQL Server Authentication (select Microsoft Entra ID) → Server: *(paste the endpoint from Step 1.5)* → Database: `lh_master_data` → Connect → select `dbo.fact_nonjd_reorder` → Connect.

The data source will appear in the left panel. Power Apps may register it as `fact_nonjd_reorder` — note the exact name it uses; this is what you reference in formulas.

- [ ] **Step 2.3 — Connect Fact_NonJD_SalesHistory**

Same connection (SQL Server, same server, same database) → select `dbo.fact_nonjd_saleshistory` → Connect.

- [ ] **Step 2.4 — Connect config_PartSettings**

Add data → SharePoint → `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite` → Connect → select `config_PartSettings` → Connect.

- [ ] **Step 2.5 — Verify each source**

Insert a temporary Label on Screen1. Set its Text to:
```
CountRows(fact_nonjd_reorder)
```
Preview the app. If it shows a number (may be capped at 500 in preview — that's fine), the connection works. Repeat for `fact_nonjd_saleshistory` and `config_PartSettings`. Delete the label when done.

- [ ] **Step 2.6 — Set app-level OnStart formula**

Select the App object (top of tree view) → OnStart property:

```
// Load the distinct branch list for dropdowns across all screens
ClearCollect(
    colBranches,
    Sort(
        Distinct(fact_nonjd_reorder, Branch),
        Result,
        SortOrder.Ascending
    )
);

// Default selections
Set(varSelectedBranch, First(colBranches).Result);
Set(varSelectedPart, Blank());
Set(varReorderSortCol, "RecommendedOrderQty");
Set(varReorderSortAsc, false);
Set(varShowOrdersOnly, true);
Set(varLowMarginOnly, false)
```

- [ ] **Step 2.7 — Add 4 screens**

In the left panel, add 3 more screens (you already have Screen1):
- Rename Screen1 → `scrHome`
- Add screen → rename → `scrReorder`
- Add screen → rename → `scrOneTimeOrder`
- Add screen → rename → `scrPartInfo`

- [ ] **Step 2.8 — Commit documentation**

```bash
git add "projects/part order tool - app/"
git commit -m "Non-JD Order Tool Plan 2: start Power Apps V1 — data sources connected"
```

---

## Task 3: Screen 1 — Home

**Purpose:** Navigation hub. Fast-loading. Shows last pipeline refresh time.

- [ ] **Step 3.1 — App header**

On `scrHome`, insert a Rectangle (full width, ~80px tall, top of screen) → Fill: `RGBA(30, 41, 59, 1)` (dark slate). Insert a Label inside: Text: `"Non-JD Parts Order Tool"`, Color: White, Font size: 20, Bold.

- [ ] **Step 3.2 — Refresh timestamp**

Insert a Label below the header:
```
"Data refreshed: " & Text(
    Max(fact_nonjd_reorder, DateCreated),
    "mmm d, yyyy h:MM AM/PM"
)
```
Font size: 12, Color: Gray.

Note: `DateCreated` is when the part record was created, not the pipeline run time. For a pipeline timestamp, we'd need to store it separately — for Phase 1, this label can be left as a static note or show today's date. Update to: `"Pipeline runs daily at 7 AM · " & Text(Today(), "mmm d, yyyy")`

- [ ] **Step 3.3 — Navigation tiles**

Insert 4 Buttons (or Rectangles with labels) in a 2×2 grid:

| Tile | Label | Navigate to | Color |
|---|---|---|---|
| Top-left | "Recommended Reorder" | scrReorder | `RGBA(37, 99, 235, 1)` (blue) |
| Top-right | "One Time Order" | scrOneTimeOrder | `RGBA(5, 150, 105, 1)` (green) |
| Bottom-left | "Part Information" | scrPartInfo | `RGBA(124, 58, 237, 1)` (purple) |
| Bottom-right | (reserved for future) | — | `RGBA(156, 163, 175, 1)` (gray) |

Each tile OnSelect:
```
Navigate(scrReorder, ScreenTransition.Fade)
```
(replace scrReorder with the appropriate screen for each tile)

- [ ] **Step 3.4 — Verify**

Preview app. Confirm all 4 tiles navigate to the correct (empty) screens. Confirm the branch list loaded (you can temporarily add `First(colBranches).Result` as a label to verify). Remove debug labels.

---

## Task 4: Screen 2 — Recommended Reorder (Filter Panel)

- [ ] **Step 4.1 — Screen header and back button**

On `scrReorder`, add the same dark header rectangle. Add title label: `"Recommended Reorder"`. Add a back arrow button (←) → OnSelect: `Navigate(scrHome, ScreenTransition.Back)`.

- [ ] **Step 4.2 — Branch dropdown**

Insert Dropdown → Name: `ddBranch`:
- Items: `colBranches`
- OnChange: `Set(varSelectedBranch, ddBranch.Selected.Result)`
- Default: `First(colBranches)`

Label above it: `"Branch"`

- [ ] **Step 4.3 — Franchise dropdown**

Insert Dropdown → Name: `ddFranchise`:
```
// Items:
["All"] & Sort(Distinct(Filter(fact_nonjd_reorder, Branch = varSelectedBranch), Franchise), Result, SortOrder.Ascending)
```
- Default: `"All"`

Label above: `"Franchise"`

- [ ] **Step 4.4 — Toggle: Orders only**

Insert Toggle → Name: `togOrdersOnly`:
- Default: `true`
- Label: `"Show reorder-needed only"`

OnChange: `Set(varShowOrdersOnly, togOrdersOnly.Value)`

- [ ] **Step 4.5 — Toggle: Low margin only**

Insert Toggle → Name: `togLowMargin`:
- Default: `false`
- Label: `"Low margin only"`

OnChange: `Set(varLowMarginOnly, togLowMargin.Value)`

- [ ] **Step 4.6 — Result count label**

Insert Label (below filters):
```
Text(CountRows(galReorder.AllItems), "[$-en-US]#,##0") & " parts"
```
This references the gallery from Task 5 — add this label after the gallery is built.

---

## Task 5: Screen 2 — Reorder Gallery, Sort, Export, Drill-Through

- [ ] **Step 5.1 — Build the gallery**

Insert Vertical Gallery → Name: `galReorder`. Set Items:

```
Sort(
    Filter(
        fact_nonjd_reorder,
        Branch = varSelectedBranch &&
        (ddFranchise.Selected.Value = "All" || Franchise = ddFranchise.Selected.Value) &&
        (!varShowOrdersOnly || RecommendedOrderQty > 0) &&
        (!varLowMarginOnly || MarginFlag = "LOW")
    ),
    RecommendedOrderQty,
    SortOrder.Descending
)
```

**Delegation note:** `Branch =` and `Franchise =` delegate to Fabric SQL. `MarginFlag = "LOW"` delegates. The toggle conditions (`!varShowOrdersOnly || RecommendedOrderQty > 0`) should delegate. If you see a delegation warning on the toggle condition, wrap it: add `RecommendedOrderQty > 0` as a direct filter condition controlled by the toggle visibility instead.

- [ ] **Step 5.2 — Gallery columns**

Inside the gallery template, add labels for each column. Use `ThisItem.FieldName` for each:

| Label | Field | Format |
|---|---|---|
| Part # | `ThisItem.PartNumber` | — |
| Description | `ThisItem.Description` | — |
| Franchise | `ThisItem.Franchise` | — |
| Vendor | `ThisItem.VendorCode` | — |
| On Hand | `ThisItem.QuantityOnHand` | `Text(ThisItem.QuantityOnHand, "[$-en-US]#,##0")` |
| Stocking Target | `ThisItem.StockingTarget` | `Text(ThisItem.StockingTarget, "[$-en-US]#,##0")` |
| Order Qty | `ThisItem.RecommendedOrderQty` | `Text(ThisItem.RecommendedOrderQty, "[$-en-US]#,##0")` |
| Est Value | `ThisItem.EstOrderValue` | `Text(ThisItem.EstOrderValue, "[$-en-US]$#,##0")` |
| Low Margin | `If(ThisItem.MarginFlag = "LOW", "⚠ LOW", "")` | Color: `RGBA(220, 38, 38, 1)` if LOW |

- [ ] **Step 5.3 — Column headers with sort**

Above the gallery, add label headers for each column. Make key ones tappable for sorting. Example for Order Qty header button OnSelect:

```
If(
    varReorderSortCol = "RecommendedOrderQty",
    Set(varReorderSortAsc, !varReorderSortAsc),
    Set(varReorderSortCol, "RecommendedOrderQty");
    Set(varReorderSortAsc, false)
)
```

Update the gallery Items formula to use `varReorderSortCol` and `varReorderSortAsc`:

```
Sort(
    Filter(
        fact_nonjd_reorder,
        Branch = varSelectedBranch &&
        (ddFranchise.Selected.Value = "All" || Franchise = ddFranchise.Selected.Value) &&
        (!varShowOrdersOnly || RecommendedOrderQty > 0) &&
        (!varLowMarginOnly || MarginFlag = "LOW")
    ),
    Switch(
        varReorderSortCol,
        "RecommendedOrderQty", RecommendedOrderQty,
        "EstOrderValue", EstOrderValue,
        "PartNumber", PartNumber,
        RecommendedOrderQty
    ),
    If(varReorderSortAsc, SortOrder.Ascending, SortOrder.Descending)
)
```

- [ ] **Step 5.4 — Drill-through to Part Information**

Gallery template OnSelect:

```
Set(varSelectedPart, ThisItem);
Navigate(scrPartInfo, ScreenTransition.Fade)
```

- [ ] **Step 5.5 — Export to Excel**

Create an Excel template file (`ReorderExportTemplate.xlsx`) with a blank Sheet1 and upload it to the SharePoint Documents library at `spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite/Shared Documents/`.

Add data connection: Excel Online (Business) → SharePoint → site above → Documents → `ReorderExportTemplate.xlsx` → connect.

Add Export button → OnSelect:

```
// Collect the current filtered results
ClearCollect(
    colExportData,
    Filter(
        fact_nonjd_reorder,
        Branch = varSelectedBranch &&
        (ddFranchise.Selected.Value = "All" || Franchise = ddFranchise.Selected.Value) &&
        (!varShowOrdersOnly || RecommendedOrderQty > 0) &&
        (!varLowMarginOnly || MarginFlag = "LOW")
    )
);
// Note: Full Excel export in standard license requires Power Automate flow.
// Phase 1: Notify user to manually export from this collection.
// Phase 2: Add Power Automate flow that receives colExportData and returns Excel file.
Notify(
    "Export: " & CountRows(colExportData) & " parts collected. Power Automate export coming in Phase 2.",
    NotificationType.Information
)
```

**Phase 1 export note:** Full Excel file generation requires a Power Automate flow (standard license). For Phase 1, the export button collects the data and can be connected to a flow later. Document this as a known gap.

- [ ] **Step 5.6 — Verify Screen 2**

Preview. Select a branch → gallery should populate. Toggle "reorder-needed only" on/off → row count changes. Toggle "low margin only" → filters correctly. Click a row → navigates to scrPartInfo (empty screen is fine for now). Sort headers work.

- [ ] **Step 5.7 — Commit**

```bash
git commit -m "Non-JD Order Tool Plan 2: Screen 2 Recommended Reorder complete"
```

---

## Task 6: Screen 3 — One Time Order (Steps 1 & 2)

**⚠️ Performance risk:** Step 4 of this wizard reads from `fact_nonjd_saleshistory` (12M rows) and filters by branch + selected franchises + selected month offsets at runtime. Test with a single branch and a small franchise selection first. If response time exceeds 10 seconds, document and escalate to Plan 3 (Web App V2 handles this more gracefully via SQL).

- [ ] **Step 6.1 — Screen structure**

On `scrOneTimeOrder`, add the header. Add a progress indicator (4 rectangle/circle shapes labeled 1–4 across the top, with the active step filled). Set a variable `varWizardStep` to track position.

Add `Set(varWizardStep, 1)` to the Home screen tile for One Time Order (so it resets when navigating in).

- [ ] **Step 6.2 — Step 1 controls (Criteria)**

These show when `varWizardStep = 1`. Wrap in a container with `Visible: varWizardStep = 1`.

Controls:
- Text input → Name: `txtOrderName`, Label: `"Order Name"`
- Dropdown → Name: `ddOrderCode`, Items: `["Standard", "Emergency", "Seasonal", "Clearance"]`, Label: `"Order Code"`
- Toggle → Name: `togPhaseIn`, Label: `"Include Phase-In Parts"`

Next button → OnSelect:
```
If(
    IsBlank(txtOrderName.Text),
    Notify("Order Name is required", NotificationType.Error),
    Set(varWizardStep, 2)
)
```

- [ ] **Step 6.3 — Step 2 controls (Parts Filter)**

Wrap in container with `Visible: varWizardStep = 2`.

Controls:
- **Franchise multi-select** (Power Apps doesn't have a native multi-select dropdown without premium; use a gallery of checkboxes):

  Insert a gallery → Items: `Sort(Distinct(Filter(fact_nonjd_reorder, Branch = varSelectedBranch), Franchise), Result)`. Template has a Checkbox + Label. Checkbox OnCheck/OnUncheck adds/removes from a collection:
  ```
  // Checkbox OnCheck:
  Collect(colSelectedFranchises, {Franchise: ThisItem.Result})
  // Checkbox OnUncheck:
  Remove(colSelectedFranchises, LookUp(colSelectedFranchises, Franchise = ThisItem.Result))
  ```

  Initialize in Step 1 Next button: add `ClearCollect(colSelectedFranchises, Distinct(Filter(fact_nonjd_reorder, Branch = varSelectedBranch), Franchise))` (select all by default).

- Back button → `Set(varWizardStep, 1)`
- Next button → `If(IsEmpty(colSelectedFranchises), Notify("Select at least one franchise", NotificationType.Error), Set(varWizardStep, 3))`

---

## Task 7: Screen 3 — One Time Order (Steps 3 & 4)

- [ ] **Step 7.1 — Step 3: Initialize month collection**

In the App OnStart (add to the existing formula):
```
// 60-month calendar collection for One Time Order wizard
ClearCollect(
    colAllMonths,
    ForAll(
        Sequence(60),
        {
            MonthOffset: Value,
            MonthDate: DateAdd(Date(Year(Today()), Month(Today()), 1), -(Value - 1), TimeUnit.Months),
            MonthLabel: Text(DateAdd(Date(Year(Today()), Month(Today()), 1), -(Value - 1), TimeUnit.Months), "mmm yyyy"),
            IsSelected: false
        }
    )
)
```

- [ ] **Step 7.2 — Step 3: Month grid**

Wrap in container with `Visible: varWizardStep = 3`.

Insert Gallery → Items: `colAllMonths`. Template: Checkbox + Label (`ThisItem.MonthLabel`).

Checkbox Default: `ThisItem.IsSelected`

Checkbox OnChange:
```
Patch(
    colAllMonths,
    ThisItem,
    {IsSelected: Self.Value}
)
```

Add Loading Factor input below the grid:
- Text input → Name: `txtLoadingFactor`, Default: `"1.0"`, Label: `"Loading Factor"`
- Label: `"(1.0 = 100% of selected months' sales. 1.2 = 20% uplift)"`

Count label: `Text(CountRows(Filter(colAllMonths, IsSelected)), "[$-en-US]#,##0") & " months selected"`

Back button → `Set(varWizardStep, 2)`
Next button → 
```
If(
    CountRows(Filter(colAllMonths, IsSelected)) = 0,
    Notify("Select at least one month", NotificationType.Error),
    Set(varWizardStep, 4);
    // Collect selected month offsets for the query
    ClearCollect(
        colSelectedOffsets,
        Filter(colAllMonths, IsSelected)
    )
)
```

- [ ] **Step 7.3 — Step 4: Calculate and preview**

Wrap in container with `Visible: varWizardStep = 4`.

Show a loading spinner while data loads. The calculation gallery Items:

```
// Get parts that match the franchise filter and have on-hand data
// Then for each part, calculate anticipated sales from selected months
// NOTE: This query runs at runtime against the 12M-row SalesHistory table.
// Delegation: Branch + Franchise filter delegates; the month offset IN filter may not.
// If slow: reduce franchise selection or accept the load time.
AddColumns(
    GroupBy(
        Filter(
            fact_nonjd_saleshistory,
            Branch = varSelectedBranch &&
            Franchise in colSelectedFranchises.Result
        ),
        "Branch", "PartNumber", "Franchise",
        "MonthRows"
    ),
    "AnticipatedSales",
        Sum(
            Filter(MonthRows, MonthOffset in colSelectedOffsets.MonthOffset),
            SalesQty
        ) * Value(txtLoadingFactor.Text),
    "OnHandQty",
        LookUp(fact_nonjd_reorder, Branch = varSelectedBranch && PartNumber = PartNumber, QuantityOnHand),
    "OnOrderQty",
        LookUp(fact_nonjd_reorder, Branch = varSelectedBranch && PartNumber = PartNumber, OnOrder)
)
```

Add calculated column for RecommendedQty:
```
"RecommendedQty", Max(0, AnticipatedSales - OnHandQty - OnOrderQty)
```

Filter the preview gallery to show only parts with RecommendedQty > 0.

**⚠️ Performance test checkpoint:** Run this step with one franchise selected and 3 months selected. Time the response. If over 15 seconds, this screen has a delegation/volume problem and needs a Power Automate intermediary — log the timing in DATA-INVESTIGATION.md.

- [ ] **Step 7.4 — Export button for Step 4**

Same pattern as Screen 2 export (Phase 1: collect + notify).

Back button → `Set(varWizardStep, 3)`
New Order button → reset wizard: `Set(varWizardStep, 1); Reset(txtOrderName); ClearCollect(colSelectedFranchises, Blank())`

- [ ] **Step 7.5 — Verify Screen 3**

Run wizard end to end: enter order name → select 2 franchises → select 3 months → Step 4 loads (note time). Verify AnticipatedSales = sum of those 3 months' SalesQty. Verify RecommendedQty = max(0, AnticipatedSales - OnHand - OnOrder).

---

## Task 8: Screen 4 — Part Information (Search + Detail Tab)

- [ ] **Step 8.1 — Screen entry from drillthrough vs. manual search**

On `scrPartInfo`, add header. On screen's OnVisible:
```
// If arrived via drill-through, varSelectedPart is already set.
// If navigated directly, clear it so the search bar shows.
If(IsBlank(varSelectedPart), Set(varShowSearch, true), Set(varShowSearch, false))
```

- [ ] **Step 8.2 — Search bar**

Add Text Input → Name: `txtPartSearch`, Hint: `"Enter part number..."`, Visible: `varShowSearch || IsBlank(varSelectedPart)`.

Search button → OnSelect:
```
Set(
    varSelectedPart,
    LookUp(
        fact_nonjd_reorder,
        PartNumber = txtPartSearch.Text && Branch = varSelectedBranch
    )
);
If(
    IsBlank(varSelectedPart),
    Notify("Part not found in branch " & varSelectedBranch, NotificationType.Warning),
    Set(varShowSearch, false)
)
```

- [ ] **Step 8.3 — Tab navigation**

Add 3 buttons at the top of the content area: `"Detail"`, `"History"`, `"Settings"`. Set `varPartTab` variable on each:
```
// Detail tab OnSelect:
Set(varPartTab, "Detail")
// History tab OnSelect:
Set(varPartTab, "History")
// Settings tab OnSelect:
Set(varPartTab, "Settings")
```

Underline the active tab: `If(varPartTab = "Detail", RGBA(37,99,235,1), Transparent)` on a thin rectangle below each tab button.

Initialize on screen OnVisible: `Set(varPartTab, "Detail")`

- [ ] **Step 8.4 — Detail tab content**

Visible when `varPartTab = "Detail"`. Show all part attributes as label pairs (bold label + value label):

```
// Key fields to display — use varSelectedPart.FieldName for each:
PartNumber, Description, Franchise, VendorCode, Source, SLC, CommodityCode
Bin, BulkBin, PackageQty
Cost (formatted as currency), SellPrice1, ListPrice
QuantityOnHand, OnOrder, BackOrderQty, MinimumQty, MaximumQty
ReorderCode, ActivityCode, Returnable
SuperTo, SuperFrom
DateCreated (formatted as date), DateLastRequested
SystemSuggestedOrderQty (labeled "System Suggested Qty")
MarginFlag (show as red badge if "LOW")
// ROP calculation results:
MonthCount, AvgMonthlyDemand, AvgMonthlySales, CalcROP, StockingTarget
RecommendedOrderQty (large, prominent), EstOrderValue
```

Format currency fields: `Text(varSelectedPart.Cost, "[$-en-US]$#,##0.00")`
Format date fields: `Text(varSelectedPart.DateCreated, "mmm d, yyyy")`

---

## Task 9: Screen 4 — History Tab

- [ ] **Step 9.1 — History gallery**

Visible when `varPartTab = "History"`. Insert Gallery → Name: `galHistory`.

Items:
```
Sort(
    Filter(
        fact_nonjd_saleshistory,
        PartNumber = varSelectedPart.PartNumber &&
        Branch = varSelectedPart.Branch
    ),
    MonthOffset,
    SortOrder.Ascending
)
```

**Delegation:** Both `PartNumber =` and `Branch =` delegate. This returns 60 rows max — fast.

- [ ] **Step 9.2 — History gallery columns**

Template columns:

| Column | Formula | Notes |
|---|---|---|
| Month | `Text(DateAdd(Date(Year(Today()), Month(Today()), 1), -(ThisItem.MonthOffset - 1), TimeUnit.Months), "mmm yyyy")` | Converts offset → calendar month |
| Sales Qty | `Text(ThisItem.SalesQty, "[$-en-US]#,##0")` | |
| Demand Count | `Text(ThisItem.DemandCount, "[$-en-US]#,##0")` | |

Add column headers above the gallery.

- [ ] **Step 9.3 — Verify History tab**

Navigate to a known part (e.g., search for part 107-135S, Branch 01 from Task 1 investigation). History tab should show 60 rows. MonthOffset 1 should show the current month. MonthOffset 60 should show approximately 5 years ago. Sales quantities should match what you'd expect from the source data.

---

## Task 10: Screen 4 — Settings Tab (config_PartSettings)

- [ ] **Step 10.1 — Load existing settings on tab open**

On the Settings tab container's OnVisible (or use `varPartTab = "Settings"` to trigger a formula):
```
Set(
    varExistingConfig,
    LookUp(
        config_PartSettings,
        PartNumber = varSelectedPart.PartNumber && Branch = varSelectedPart.Branch
    )
)
```

- [ ] **Step 10.2 — Settings form controls**

Add input controls visible when `varPartTab = "Settings"`. Default each to the existing value from `varExistingConfig` if it exists:

| Control Name | Type | Default formula |
|---|---|---|
| `txtGroupOverride` | Text input | `If(IsBlank(varExistingConfig), "", varExistingConfig.GroupOverride)` |
| `txtMinOverride` | Text input | `If(IsBlank(varExistingConfig), "", Text(varExistingConfig.MinOverride))` |
| `txtEOQ` | Text input | `If(IsBlank(varExistingConfig), "", Text(varExistingConfig.EOQ))` |
| `togForceNonSpiking` | Toggle | `If(IsBlank(varExistingConfig), false, varExistingConfig.ForceNonSpiking)` |
| `ddPreApprovedRule` | Dropdown | Items: `["Use normal rules", "Force 1 time to proposed"]`, Default: `If(IsBlank(varExistingConfig), "Use normal rules", varExistingConfig.PreApprovedOrderRule)` |
| `togMasking` | Toggle | `If(IsBlank(varExistingConfig), false, varExistingConfig.Masking)` |
| `dpMaskingExpiration` | Date picker | `If(IsBlank(varExistingConfig), Today(), varExistingConfig.MaskingExpiration)`, Visible: `togMasking.Value` |

- [ ] **Step 10.3 — Save button**

Button "Save Settings" → OnSelect:
```
If(
    IsBlank(varExistingConfig),
    // New record
    Patch(
        config_PartSettings,
        Defaults(config_PartSettings),
        {
            PartNumber: varSelectedPart.PartNumber,
            Branch: varSelectedPart.Branch,
            GroupOverride: txtGroupOverride.Text,
            MinOverride: If(IsBlank(txtMinOverride.Text), Blank(), Value(txtMinOverride.Text)),
            EOQ: If(IsBlank(txtEOQ.Text), Blank(), Value(txtEOQ.Text)),
            ForceNonSpiking: togForceNonSpiking.Value,
            PreApprovedOrderRule: ddPreApprovedRule.Selected.Value,
            Masking: togMasking.Value,
            MaskingExpiration: If(togMasking.Value, dpMaskingExpiration.SelectedDate, Blank())
        }
    ),
    // Update existing record
    Patch(
        config_PartSettings,
        varExistingConfig,
        {
            GroupOverride: txtGroupOverride.Text,
            MinOverride: If(IsBlank(txtMinOverride.Text), Blank(), Value(txtMinOverride.Text)),
            EOQ: If(IsBlank(txtEOQ.Text), Blank(), Value(txtEOQ.Text)),
            ForceNonSpiking: togForceNonSpiking.Value,
            PreApprovedOrderRule: ddPreApprovedRule.Selected.Value,
            Masking: togMasking.Value,
            MaskingExpiration: If(togMasking.Value, dpMaskingExpiration.SelectedDate, Blank())
        }
    )
);
// Reload the saved record
Set(varExistingConfig, LookUp(config_PartSettings, PartNumber = varSelectedPart.PartNumber && Branch = varSelectedPart.Branch));
Notify("Settings saved", NotificationType.Success)
```

- [ ] **Step 10.4 — Clear settings button**

Button "Clear Overrides" → OnSelect:
```
Remove(config_PartSettings, varExistingConfig);
Set(varExistingConfig, Blank());
Notify("Overrides cleared", NotificationType.Success)
```

- [ ] **Step 10.5 — Verify Settings tab**

1. Navigate to a part (any part + branch combo).
2. Settings tab → fill in MinOverride = 5, ForceNonSpiking = on → Save.
3. Check the `config_PartSettings` SharePoint list directly — confirm the row was created.
4. Navigate away from the part and back → confirm the saved values reload correctly.
5. Clear overrides → confirm row removed from SharePoint.

---

## Task 11: Polish, Publish, and Share

- [ ] **Step 11.1 — Consistent styling pass**

Apply these globally across all screens:
- Header: `RGBA(30, 41, 59, 1)` (dark slate)
- Primary button: `RGBA(37, 99, 235, 1)` (blue), white text
- Secondary button: `RGBA(243, 244, 246, 1)` (light gray), dark text
- Font: Segoe UI, size 13 for body, size 11 for secondary labels
- Gallery alternating row: use `If(Mod(ThisItem.PartNumber, 2) = 0, RGBA(249,250,251,1), White)` — note PartNumber is text; use `If(IsEven(galReorder.AllItems.IndexOf(ThisItem)), ...)` if needed

- [ ] **Step 11.2 — Loading states**

On Screen 2 and Screen 4 History tab, add a spinner (animated GIF or pulsing rectangle) that shows while the gallery is loading. Power Apps doesn't have a built-in loading state, so use:

```
// Add a label over the gallery:
Visible: IsEmpty(galReorder.AllItems) && !IsBlank(varSelectedBranch)
Text: "Loading..."
```

- [ ] **Step 11.3 — Empty state messages**

On the Reorder gallery, add a label visible when the gallery is empty:
```
Visible: IsEmpty(galReorder.AllItems)
Text: "No parts match the current filters."
```

On History gallery:
```
Visible: IsEmpty(galHistory.AllItems)
Text: "No history found for this part."
```

- [ ] **Step 11.4 — Publish the app**

File → Save → Publish → Publish this version.

- [ ] **Step 11.5 — Share with users**

In `make.powerapps.com` → Apps → find "Non-JD Parts Order Tool" → Share. Add the two users (parts manager + corp parts manager) with "Can use" permission. Send them the app link.

Also share the SharePoint site (or specifically the `config_PartSettings` list with Edit permissions) with both users so the Settings tab can write.

- [ ] **Step 11.6 — Document and commit**

Save the key Power Fx formulas to the guide document:

```bash
git add "projects/part order tool - app/POWERAPPS-GUIDE.md"
git commit -m "Non-JD Order Tool Plan 2: Power Apps V1 complete — published and shared"
```

---

## Self-Review

### Spec coverage check:

| Spec requirement | Covered in task |
|---|---|
| Screen 1: Home with nav tiles + refresh timestamp | Task 3 |
| Screen 2: Filters (Franchise, Branch, Low Margin) | Task 4 |
| Screen 2: Sortable gallery columns | Task 5.3 |
| Screen 2: Export to Excel/CSV | Task 5.5 (Phase 1 = collect; Phase 2 = flow) |
| Screen 2: Drill-through to Part Information | Task 5.4 |
| Screen 3: 4-step wizard | Tasks 6–7 |
| Screen 3: Month calendar grid | Task 7.2 |
| Screen 3: Loading Factor + AnticipatedSales formula | Task 7.3 |
| Screen 3: Export | Task 7.4 |
| Screen 4: Part attribute detail | Task 8.4 |
| Screen 4: 60-month history grid | Task 9 |
| Screen 4: config_PartSettings write | Task 10 |
| Performance warning on Screen 3 | Task 7.3 |

### Known gaps / Phase 2 items:

1. **Excel export (Screen 2 and Screen 3):** Full file generation requires Power Automate flow — documented in Task 5.5. Phase 1 collects data only.
2. **config_PartSettings in Fact_NonJD_Reorder:** The notebook currently doesn't apply config_PartSettings overrides to the ROP calculation. MinOverride, EOQ, etc. are stored in SharePoint but not yet consumed by the Reorder notebook. This is a Phase 2 data layer change — update `nb_Fact_NonJD_Parts_Order` to read config_PartSettings and apply MinOverride to the StockingTarget formula.
3. **Screen 3 performance:** May be slow on large franchise+month selections against 12M-row SalesHistory table. Monitor and escalate to Plan 3 if needed.
4. **Order Code filter on Screen 2:** The spec lists Order Code as a filter but `fact_nonjd_reorder` has `ReorderCode` from the source. Add a ReorderCode dropdown filter to Screen 2 (same pattern as Franchise dropdown — Task 4.3).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-01-non-jd-parts-order-tool-power-apps-v1.md`. Two execution options:

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
