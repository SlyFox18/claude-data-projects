# Power Apps V1 — Formula Reference Guide
# Non-JD Parts Order Tool

App name: `Non-JD Parts Order Tool`  
Layout: Tablet (landscape)  
Fabric tables: `fact_nonjd_reorder` (206,663 rows), `fact_nonjd_saleshistory` (12.4M rows)  
Config list: `config_PartSettings` (SharePoint)

---

## Data Sources

| Name in App | Type | Connection |
|---|---|---|
| `fact_nonjd_reorder` | SQL Server | Fabric SQL Analytics Endpoint → `lh_master_data` → `dbo.fact_nonjd_reorder` |
| `fact_nonjd_saleshistory` | SQL Server | Same endpoint → `dbo.fact_nonjd_saleshistory` |
| `config_PartSettings` | SharePoint | `https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite` |

**Fabric SQL Analytics Endpoint server:**  
xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com

---

## App-Level Variables (set in OnStart)

| Variable | Type | Purpose |
|---|---|---|
| `colBranches` | Collection | Distinct branch list from fact_nonjd_reorder |
| `varSelectedBranch` | Text | Currently selected branch (drives all screen filters) |
| `varSelectedPart` | Record | Part row from fact_nonjd_reorder (set on drill-through) |
| `varReorderSortCol` | Text | Current sort column name for Screen 2 gallery |
| `varReorderSortAsc` | Boolean | Sort direction for Screen 2 gallery |
| `varShowOrdersOnly` | Boolean | Screen 2 toggle: show only parts needing reorder |
| `varLowMarginOnly` | Boolean | Screen 2 toggle: show only low-margin parts |
| `varWizardStep` | Number | Screen 3 wizard step (1–4) |
| `colSelectedFranchises` | Collection | Screen 3 Step 2 selected franchises |
| `colAllMonths` | Collection | 60-month calendar for Screen 3 Step 3 |
| `colSelectedOffsets` | Collection | Screen 3 Step 3 selected month offsets |
| `varPartTab` | Text | Screen 4 active tab: "Detail" / "History" / "Settings" |
| `varShowSearch` | Boolean | Screen 4 search bar visibility |
| `varExistingConfig` | Record | Screen 4 Settings tab: existing config_PartSettings row |

---

## App OnStart Formula

```
// Load branch list
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
Set(varLowMarginOnly, false);

// 60-month calendar for One Time Order wizard
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

---

## Screen 1 — Home (scrHome)

### Refresh timestamp label
```
"Pipeline runs daily at 7 AM · " & Text(Today(), "mmm d, yyyy")
```

### Navigation tiles

| Tile | OnSelect |
|---|---|
| Recommended Reorder | `Navigate(scrReorder, ScreenTransition.Fade)` |
| One Time Order | `Set(varWizardStep, 1); Navigate(scrOneTimeOrder, ScreenTransition.Fade)` |
| Part Information | `Set(varSelectedPart, Blank()); Navigate(scrPartInfo, ScreenTransition.Fade)` |
| (reserved) | — |

---

## Screen 2 — Recommended Reorder (scrReorder)

### Branch dropdown
```
// Items:
colBranches

// OnChange:
Set(varSelectedBranch, ddBranch.Selected.Result)
```

### Franchise dropdown
```
// Items:
["All"] & Sort(Distinct(Filter(fact_nonjd_reorder, Branch = varSelectedBranch), Franchise), Result, SortOrder.Ascending)
```

### Gallery Items (galReorder)
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

### Sort header OnSelect (example for Order Qty column)
```
If(
    varReorderSortCol = "RecommendedOrderQty",
    Set(varReorderSortAsc, !varReorderSortAsc),
    Set(varReorderSortCol, "RecommendedOrderQty");
    Set(varReorderSortAsc, false)
)
```

### Gallery drill-through (template OnSelect)
```
Set(varSelectedPart, ThisItem);
Navigate(scrPartInfo, ScreenTransition.Fade)
```

### Result count label
```
Text(CountRows(galReorder.AllItems), "[$-en-US]#,##0") & " parts"
```

### Low Margin badge (inside gallery template)
```
// Text:
If(ThisItem.MarginFlag = "LOW", "⚠ LOW", "")

// Color:
If(ThisItem.MarginFlag = "LOW", RGBA(220, 38, 38, 1), Transparent)
```

### Export button (Phase 1 — collect + notify)
```
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
Notify(
    "Export: " & CountRows(colExportData) & " parts collected. Power Automate export coming in Phase 2.",
    NotificationType.Information
)
```

---

## Screen 3 — One Time Order (scrOneTimeOrder)

### Step 1: Criteria
```
// Next button OnSelect:
If(
    IsBlank(txtOrderName.Text),
    Notify("Order Name is required", NotificationType.Error),
    ClearCollect(colSelectedFranchises, Distinct(Filter(fact_nonjd_reorder, Branch = varSelectedBranch), Franchise));
    Set(varWizardStep, 2)
)
```

### Step 2: Franchise multi-select gallery
```
// Gallery Items:
Sort(Distinct(Filter(fact_nonjd_reorder, Branch = varSelectedBranch), Franchise), Result)

// Checkbox OnCheck:
Collect(colSelectedFranchises, {Franchise: ThisItem.Result})

// Checkbox OnUncheck:
Remove(colSelectedFranchises, LookUp(colSelectedFranchises, Franchise = ThisItem.Result))

// Next button:
If(IsEmpty(colSelectedFranchises), Notify("Select at least one franchise", NotificationType.Error), Set(varWizardStep, 3))
```

### Step 3: Month grid
```
// Gallery Items:
colAllMonths

// Checkbox Default:
ThisItem.IsSelected

// Checkbox OnChange:
Patch(colAllMonths, ThisItem, {IsSelected: Self.Value})

// Count label:
Text(CountRows(Filter(colAllMonths, IsSelected)), "[$-en-US]#,##0") & " months selected"

// Next button:
If(
    CountRows(Filter(colAllMonths, IsSelected)) = 0,
    Notify("Select at least one month", NotificationType.Error),
    Set(varWizardStep, 4);
    ClearCollect(colSelectedOffsets, Filter(colAllMonths, IsSelected))
)
```

### Step 4: Calculate (runtime against SalesHistory)
```
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
        LookUp(fact_nonjd_reorder, Branch = varSelectedBranch && PartNumber = PartNumber, OnOrder),
    "RecommendedQty",
        Max(0, AnticipatedSales - OnHandQty - OnOrderQty)
)
```
**Performance note:** Test with 1 franchise + 3 months first. If response > 15 seconds, escalate to Plan 3.

### Reset wizard
```
Set(varWizardStep, 1);
Reset(txtOrderName);
ClearCollect(colSelectedFranchises, Blank())
```

---

## Screen 4 — Part Information (scrPartInfo)

### OnVisible
```
If(IsBlank(varSelectedPart), Set(varShowSearch, true), Set(varShowSearch, false));
Set(varPartTab, "Detail")
```

### Search button OnSelect
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

### Detail tab — currency format
```
Text(varSelectedPart.Cost, "[$-en-US]$#,##0.00")
```

### Detail tab — date format
```
Text(varSelectedPart.DateCreated, "mmm d, yyyy")
```

### History gallery Items (galHistory)
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

### History Month column (MonthOffset → calendar month)
```
Text(
    DateAdd(Date(Year(Today()), Month(Today()), 1), -(ThisItem.MonthOffset - 1), TimeUnit.Months),
    "mmm yyyy"
)
```

### Settings tab — load existing config
```
Set(
    varExistingConfig,
    LookUp(
        config_PartSettings,
        PartNumber = varSelectedPart.PartNumber && Branch = varSelectedPart.Branch
    )
)
```

### Settings tab — Save button
```
If(
    IsBlank(varExistingConfig),
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
Set(varExistingConfig, LookUp(config_PartSettings, PartNumber = varSelectedPart.PartNumber && Branch = varSelectedPart.Branch));
Notify("Settings saved", NotificationType.Success)
```

### Settings tab — Clear button
```
Remove(config_PartSettings, varExistingConfig);
Set(varExistingConfig, Blank());
Notify("Overrides cleared", NotificationType.Success)
```

---

## Styling Constants

| Element | Color |
|---|---|
| Header background | `RGBA(30, 41, 59, 1)` — dark slate |
| Primary button | `RGBA(37, 99, 235, 1)` — blue |
| Secondary button | `RGBA(243, 244, 246, 1)` — light gray |
| Active tab underline | `RGBA(37, 99, 235, 1)` — blue |
| Low margin badge | `RGBA(220, 38, 38, 1)` — red |
| Home tile: Reorder | `RGBA(37, 99, 235, 1)` — blue |
| Home tile: One Time Order | `RGBA(5, 150, 105, 1)` — green |
| Home tile: Part Info | `RGBA(124, 58, 237, 1)` — purple |
| Home tile: (reserved) | `RGBA(156, 163, 175, 1)` — gray |
| Font | Segoe UI, 13pt body, 11pt secondary |

---

## Known Phase 2 Items

1. **Excel export:** Full file requires Power Automate flow. Phase 1 = collect + notify only.
2. **config_PartSettings in Reorder notebook:** MinOverride/EOQ not yet applied to ROP calc. Phase 2 = update `nb_Fact_NonJD_Parts_Order` to read overrides.
3. **Screen 3 performance:** Monitor against 12M-row SalesHistory. If > 15 sec on large selections, escalate to Plan 3 (React web app with SQL backend).
4. **ReorderCode filter on Screen 2:** Add a ReorderCode dropdown filter (same pattern as Franchise dropdown).
