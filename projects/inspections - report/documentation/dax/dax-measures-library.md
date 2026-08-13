# DAX Measures Library - Inspections Report

> ⚠️ **STALE as of 2026-08-13 — measure-by-measure content below predates a major cleanup, do not trust counts/names below.** The model was audited and cleaned up on 2026-08-13 (see `docs/superpowers/plans/2026-08-12-inspections-report-rebuild.md` and `ARCHITECTURE.md` Decisions 8-9): 54 confirmed-dead measures were deleted (design-iteration leftovers, superseded "-Fixed" versions, debug scaffolding), 6 measures were renamed to drop leftover version suffixes, and all 128 survivors were organized into 11 display folders in the model itself (Core KPIs, Goals & % to Goal, Pending Queue, Job Code Breakdown, Work Order Detail, Work Order List, Recommendations Engine, HTML Cards & Visual Chrome, Page Headers & Subtitles, Trend - Rolling 12, _Helpers), each with a real description written from its actual DAX (visible as a tooltip in Desktop's field list).
>
> **The model itself — its folders and its measure tooltips — is now the authoritative, up-to-date reference**, not this file. This file's full rewrite to match is optional going forward rather than a required follow-up, since the model's own descriptions already cover what this document used to provide; update it only if a from-scratch narrative reference (as opposed to in-model tooltips) turns out to still be useful.

**Complete documentation of all 179 DAX measures in the Inspections Report.**

---

## 📊 Measure Summary

**Total Measures:** 179

| Category | Count |
|----------|-------|
| **Core Metrics** | 4 |
| **Goal Tracking** | 21 |
| **HTML Visualizations** | 41 |
| **Work Order Details** | 27 |
| **Pending Inspections** | 8 |
| **ServiceRecommendations** | 3 |
| **Averages & Calculations** | 8 |
| **CS690/CS770 Specific** | 3 |
| **Discount Analysis** | 14 |
| **Helper/Utility** | 43 |
| **Trend** | 7 |

---

## 📋 Table of Contents

- [Core Metrics](#core-metrics) (4 measures)
- [Goal Tracking](#goal-tracking) (21 measures)
- [HTML Visualizations](#html-visualizations) (41 measures)
- [Work Order Details](#work-order-details) (27 measures)
- [Pending Inspections](#pending-inspections) (8 measures)
- [ServiceRecommendations](#servicerecommendations) (3 measures)
- [Averages & Calculations](#averages-&-calculations) (8 measures)
- [CS690/CS770 Specific](#cs690cs770-specific) (3 measures)
- [Discount Analysis](#discount-analysis) (14 measures)
- [Helper/Utility](#helperutility) (43 measures)
- [Trend](#trend) (7 measures)

---

## Core Metrics

**4 measures in this category**

### Labor $$

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[Labor With Inspection] - [Inspection $$]
```

> ⚠️ **Filter-context warning:** `Labor $$` / `Labor With Inspection` do NOT clear an external `JobCode`/`InspectionCategory` filter (e.g. from a slicer) before summing — using them under such a filter will silently narrow the result to near-zero/incorrect values, since the inspection line itself is typically a $0/nominal charge while real labor is booked under other job codes on the same work order. **`Labor $$ (Filtered)`, the previous workaround, was deleted 2026-07-20** (it existed only for the trend view, which now uses `WO List - Total Labor` instead — see [Trend](#trend)). Prefer `WO List - Total Labor` in any context where a JobCode/InspectionCategory filter may be active (e.g. any visual with the page-wide Inspection Category slicer in scope) — it already handles this via its own `ISFILTERED()` branching logic. This is a proven, real trap, not a hypothetical one — see also the related but distinct `SELECTEDVALUE`-based blank-at-total trap under [Parts $ by Job Code](#parts--by-job-code) / [Labor $ by Job Code](#labor--by-job-code), which has independently bitten twice.

---

### Parts $ Total

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[Franchise] <> "ZP",
    NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
)
```

---

### Total

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax
[Parts $ Total] + [Inspection $$] + [Labor $$]
```

---

### Total Inspections

**Format:** `0`

**DAX:**
```dax

CALCULATE(
    COUNTROWS(Fact_LaborJobSummary),  
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

---

## Goal Tracking

**21 measures in this category**

### % to Goal - CS690-CS770 Inspections

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE(
    [CS690-CS770 Inspections],
    [CS690-CS770 Inspection Goal],
    0
)
```

---

### % to Goal - CS690-CS770 Labor

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE(
    [CS690-CS770 Labor With Inspection],
    [CS690-CS770 Labor Goal],
    0
)
```

---

### % to Goal - CS690-CS770 Parts

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE(
    [CS690-CS770 Parts Total],
    [CS690-CS770 Parts Goal],
    0
)
```

---

### % to Goal - Inspections

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE([Total Inspections], [Total Inspection Goal], 0)

```

---

### % to Goal - Labor With Inspection

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE(
    [Labor With Inspection],
    [Labor With Inspection Goal],
    0
)
```

---

### % to Goal - Parts

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE(
    [Parts $ Total],
    [Parts Goal],
    0
)
```

---

### CS690-CS770 Inspection Goal

**Format:** `0`

**DAX:**
```dax

CALCULATE(
    SUM('Inspection Goals'[2025 CS690/770 Inspections Goal]),
    TREATAS(
        VALUES(dim_BranchLocation[BranchID]),
        'Inspection Goals'[LOCATION]
    )
)
```

---

### CS690-CS770 Labor Goal

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM('Inspection Goals'[2025 CS690/770 Labor $$ w/ Inspection Goal]),
    TREATAS(
        VALUES(dim_BranchLocation[BranchID]),
        'Inspection Goals'[LOCATION]
    )
)
```

---

### CS690-CS770 Parts Goal

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM('Inspection Goals'[2025 CS690/770 Total Parts $$ Goal]),
    TREATAS(
        VALUES(dim_BranchLocation[BranchID]),
        'Inspection Goals'[LOCATION]
    )
)
```

---

### Labor With Inspection Goal

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM('Inspection Goals'[2025 Labor $$ w/ Inspection Goal]),
    TREATAS(
        VALUES(dim_BranchLocation[BranchID]),
        'Inspection Goals'[LOCATION]
    )
)
```

---

### Overall % to Goal

**Format:** `0%;-0%;0%`

**DAX:**
```dax

VAR InspPct = [% to Goal - Inspections]
VAR PartsPct = [% to Goal - Parts]
VAR LaborPct = [% to Goal - Labor With Inspection]

// Average of the three percentages
VAR OverallPct = (InspPct + PartsPct + LaborPct) / 3

RETURN OverallPct
```

---

### Overall % to Goal Inspections

**Format:** `0%;-0%;0%`

**DAX:**
```dax
[% to Goal - Inspections]
```

---

### Overall % to Goal Labor

**Format:** `0%;-0%;0%`

**DAX:**
```dax
[% to Goal - Labor With Inspection]
```

---

### Overall % to Goal Parts

**Format:** `0%;-0%;0%`

**DAX:**
```dax
[% to Goal - Parts]
```

---

### Parts $ Goal

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

SUM('Inspection Goals'[2025 Total Parts $$ Goal])
```

---

### Parts Goal

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM('Inspection Goals'[2025 Total Parts $$ Goal]),
    TREATAS(
        VALUES(dim_BranchLocation[BranchID]),
        'Inspection Goals'[LOCATION]
    )
)
```

---

### Total Inspection Goal

**Format:** `0`

**DAX:**
```dax

CALCULATE(
    SUM('Inspection Goals'[2025 Inspections Goal]),
    TREATAS(
        VALUES(dim_BranchLocation[BranchID]),
        'Inspection Goals'[LOCATION]
    )
)
```

---

### Total Inspection Goal All

**Format:** `0`

**DAX:**
```dax
[Total Inspection Goal]
```

---

### Total Labor Goal All

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax
[Labor With Inspection Goal]
```

---

### Total Labor Goal With Inspection

**DAX:**
```dax
SUM('Inspection Goals'[2025 Labor $$ w/ Inspection Goal])
```

---

### Total Parts Goal All

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax
[Parts $ Goal]
```

---

## HTML Visualizations

**41 measures in this category**

### Blur

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax
"<div style="" 
position: fixed;  
top: 0;  
left: 0;  
width: 100%;  
height: 100%;  
backdrop-filter: blur(50px); 
-webkit-backdrop-filter: blur(50px);  
z-index: 9999;
"">
</div>
"
```

</details>

---

### BranchPerformanceManualSort

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Get filtered branches
VAR FilteredBranches = 
    FILTER(
        VALUES(dim_BranchLocation[Branch]),
        NOT(dim_BranchLocation[Branch] IN {
           "3 - Denver City", "4 - Las Cruces", "5 - Deming",
            "7 - Ballinger", "12 - O'Donnell", "94 - Crosbyton", "97 - Colorado City"
        })
    )

// Calculate with sort rank
VAR BranchDataWithRank = 
    ADDCOLUMNS(
        FilteredBranches,
        "@Branch", dim_BranchLocation[Branch],
        "@Insp", [Total Inspections],
        "@InspGoal", [Total Inspection Goal],
        "@InspPct", [% to Goal - Inspections],
        "@Parts", [Parts $ Total],
        "@PartsGoal", [Parts $ Goal],
        "@PartsPct", [% to Goal - Parts],
        "@Labor", [Labor With Inspection],
        "@LaborGoal", [Total Labor Goal With Inspection],
        "@LaborPct", [% to Goal - Labor With Inspection]
    )

VAR BranchDataWithOverall = 
    ADDCOLUMNS(
        BranchDataWithRank,
        "@Overall", DIVIDE([@InspPct] + [@PartsPct] + [@LaborPct], 3, 0)
    )

// Add rank for sorting (1 = worst, higher = better)
VAR BranchDataSorted = 
    ADDCOLUMNS(
        BranchDataWithOverall,
        "@Rank", 
            RANKX(
                BranchDataWithOverall,
                [@Overall],
                ,
                ASC  // Lowest percentage gets rank 1
            )
    )

// Build HTML sorted by rank
VAR BranchRows = 
    CONCATENATEX(
        BranchDataSorted,
        VAR BranchName = [@Branch]
        VAR Insp = [@Insp]
        VAR InspGoal = [@InspGoal]
        VAR InspPct = [@InspPct]
        VAR Parts = [@Parts]
        VAR PartsGoal = [@PartsGoal]
        VAR PartsPct = [@PartsPct]
        VAR Labor = [@Labor]
        VAR LaborGoal = [@LaborGoal]
        VAR LaborPct = [@LaborPct]
        VAR Overall = [@Overall]
        
        VAR Icon = 
            IF(Overall >= 1.20, "🏆",
            IF(Overall >= 1.00, "✅",
            IF(Overall >= 0.90, "⚠️",
            "🚨")))
        
        VAR BG = IF(Overall < 1.00, "#fff5f5", "white")
        VAR Border = IF(Overall >= 1.00, "#10b981", "#ef4444")
        VAR IC = IF(InspPct >= 1.00, "#10b981", "#ef4444")
        VAR PC = IF(PartsPct >= 1.00, "#10b981", "#ef4444")
        VAR LC = IF(LaborPct >= 1.00, "#10b981", "#ef4444")
        
        RETURN
        "
        <div style='
            background: " & BG & ";
            padding: 12px 20px;
            margin-bottom: 8px;
            border-radius: 6px;
            border-left: 4px solid " & Border & ";
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
            display: flex;
            align-items: center;
            gap: 20px;
        '>
            <div style='flex: 0 0 180px; font-weight: 700; font-size: 15px; color: #1D3C4E;'>
                " & Icon & " " & BranchName & "
            </div>
            
            <div style='flex: 1; text-align: center; padding: 0 10px; border-right: 1px solid #e5e7eb;'>
                <div style='font-size: 11px; color: #6B7280; text-transform: uppercase; margin-bottom: 3px;'>Inspections</div>
                <div style='font-size: 14px; color: #1D3C4E; margin-bottom: 2px;'>
                    " & FORMAT(Insp, "#,##0") & " / " & FORMAT(InspGoal, "#,##0") & "
                </div>
                <div style='font-size: 16px; font-weight: 700; color: " & IC & ";'>
                    " & FORMAT(InspPct, "0%") & "
                </div>
            </div>
            
            <div style='flex: 1; text-align: center; padding: 0 10px; border-right: 1px solid #e5e7eb;'>
                <div style='font-size: 11px; color: #6B7280; text-transform: uppercase; margin-bottom: 3px;'>Parts</div>
                <div style='font-size: 14px; color: #1D3C4E; margin-bottom: 2px;'>
                    " & FORMAT(Parts/1000, "$#,##0") & "K / " & FORMAT(PartsGoal/1000, "$#,##0") & "K
                </div>
                <div style='font-size: 16px; font-weight: 700; color: " & PC & ";'>
                    " & FORMAT(PartsPct, "0%") & "
                </div>
            </div>
            
            <div style='flex: 1; text-align: center; padding: 0 10px;'>
                <div style='font-size: 11px; color: #6B7280; text-transform: uppercase; margin-bottom: 3px;'>Labor</div>
                <div style='font-size: 14px; color: #1D3C4E; margin-bottom: 2px;'>
                    " & FORMAT(Labor/1000, "$#,##0") & "K / " & FORMAT(LaborGoal/1000, "$#,##0") & "K
                </div>
                <div style='font-size: 16px; font-weight: 700; color: " & LC & ";'>
                    " & FORMAT(LaborPct, "0%") & "
                </div>
            </div>
        </div>
        ",
        "",
        [@Rank],  // Sort by rank column
        ASC       // Ascending = worst first
    )

RETURN
"
<div style='font-family: Segoe UI, Arial, sans-serif; height: 100%; overflow-y: auto; padding: 10px;'>
    <div style='font-size: 18px; font-weight: 700; color: white; margin-bottom: 15px; padding: 12px 20px; background: linear-gradient(to right, #1D3C4E, #3A7CA5); border-radius: 8px;'>
        📊 Branch Performance - Goals (15 Locations)
    </div>
    
    <div style='display: flex; padding: 8px 20px; margin-bottom: 5px; gap: 20px; font-size: 11px; font-weight: 600; color: #6B7280; text-transform: uppercase;'>
        <div style='flex: 0 0 180px;'>Branch</div>
        <div style='flex: 1; text-align: center;'>Inspections</div>
        <div style='flex: 1; text-align: center;'>Parts Revenue</div>
        <div style='flex: 1; text-align: center;'>Labor Revenue</div>
    </div>
    
    " & BranchRows & "
</div>
"
```

</details>

---

### CS690-CS770 Panel HTML

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR _Count = [CS690-CS770 Inspections]
VAR CountGoal = [CS690-CS770 Inspection Goal]
VAR CountPct = [% to Goal - CS690-CS770 Inspections]

VAR Labor = [CS690-CS770 Labor With Inspection]
VAR LaborGoal = [CS690-CS770 Labor Goal]
VAR LaborPct = [% to Goal - CS690-CS770 Labor]

VAR Parts = [CS690-CS770 Parts Total]
VAR PartsGoal = [CS690-CS770 Parts Goal]
VAR PartsPct = [% to Goal - CS690-CS770 Parts]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    background: white;
    border-radius: 12px;
    padding: 28px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    border-left: 6px solid #f59e0b;
'>
    <div style='
        font-size: 16px;
        font-weight: 700;
        color: #111827;
        margin-bottom: 24px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    '>
        🌽 CS690-CS770 Combine Inspections Performance
    </div>
    
    <div style='display: flex; gap: 24px;'>
        
        <!-- Card 1: Count -->
        <div style='
            flex: 1;
            background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
            border-radius: 10px;
            padding: 24px;
            border: 2px solid #f59e0b;
        '>
            <div style='font-size: 13px; color: #92400e; font-weight: 600; margin-bottom: 8px;'>
                Total Inspections
            </div>
            <div style='display: flex; align-items: center; gap: 12px; margin-bottom: 8px;'>
                <div style='font-size: 42px; font-weight: 700; color: #78350f; line-height: 1;'>
                    " & FORMAT(_Count, "#,##0") & "
                </div>
                <div style='
                    background: #15803d;
                    color: white;
                    padding: 4px 12px;
                    border-radius: 20px;
                    font-size: 14px;
                    font-weight: 700;
                '>
                    " & FORMAT(CountPct, "0%") & " ↑
                </div>
            </div>
            <div style='font-size: 13px; color: #92400e;'>
                Goal: " & FORMAT(CountGoal, "#,##0") & "
            </div>
        </div>
        
        <!-- Card 2: Labor -->
        <div style='
            flex: 1;
            background: #f8f9fa;
            border-radius: 10px;
            padding: 24px;
            border: 2px solid #e5e7eb;
        '>
            <div style='font-size: 13px; color: #6b7280; font-weight: 600; margin-bottom: 8px;'>
                Labor Revenue
            </div>
            <div style='display: flex; align-items: center; gap: 12px; margin-bottom: 8px;'>
                <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                    " & FORMAT(Labor, "$#,##0") & "
                </div>
                <div style='
                    background: " & IF(LaborPct >= 1, "#dc2626", "#f59e0b") & ";
                    color: white;
                    padding: 4px 12px;
                    border-radius: 20px;
                    font-size: 14px;
                    font-weight: 700;
                '>
                    " & FORMAT(LaborPct, "0%") & IF(LaborPct >= 1, " ↑", "") & "
                </div>
            </div>
            <div style='font-size: 13px; color: #6b7280;'>
                Goal: " & FORMAT(LaborGoal, "$#,##0") & "
            </div>
        </div>
        
        <!-- Card 3: Parts -->
        <div style='
            flex: 1;
            background: #f8f9fa;
            border-radius: 10px;
            padding: 24px;
            border: 2px solid #e5e7eb;
        '>
            <div style='font-size: 13px; color: #6b7280; font-weight: 600; margin-bottom: 8px;'>
                Parts Revenue
            </div>
            <div style='display: flex; align-items: center; gap: 12px; margin-bottom: 8px;'>
                <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                    " & FORMAT(Parts, "$#,##0") & "
                </div>
                <div style='
                    background: " & IF(PartsPct >= 1, "#dc2626", "#f59e0b") & ";
                    color: white;
                    padding: 4px 12px;
                    border-radius: 20px;
                    font-size: 14px;
                    font-weight: 700;
                '>
                    " & FORMAT(PartsPct, "0%") & IF(PartsPct >= 1, " ↑", "") & "
                </div>
            </div>
            <div style='font-size: 13px; color: #6b7280;'>
                Goal: " & FORMAT(PartsGoal, "$#,##0") & "
            </div>
        </div>
        
    </div>
</div>
"

```

</details>

---

### CS690-CS770 Panel HTML V2

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR _Count = [CS690-CS770 Inspections]
VAR CountGoal = [CS690-CS770 Inspection Goal]
VAR CountPct = [% to Goal - CS690-CS770 Inspections]

VAR Labor = [CS690-CS770 Labor With Inspection]
VAR LaborGoal = [CS690-CS770 Labor Goal]
VAR LaborPct = [% to Goal - CS690-CS770 Labor]

VAR Parts = [CS690-CS770 Parts Total]
VAR PartsGoal = [CS690-CS770 Parts Goal]
VAR PartsPct = [% to Goal - CS690-CS770 Parts]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    background: white;
    border-radius: 12px;
    padding: 20px 24px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    border-left: 6px solid #f59e0b;
    height: 180px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    box-sizing: border-box;
'>
    <div style='
        font-size: 14px;
        font-weight: 700;
        color: #111827;
        margin-bottom: 12px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    '>
        🌽 CS690-CS770 Combine Inspections Performance
    </div>
    
    <div style='display: flex; gap: 16px; flex: 1;'>
        
        <!-- Card 1: Count -->
        <div style='
            flex: 1;
            background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
            border-radius: 10px;
            padding: 16px;
            border: 2px solid #f59e0b;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        '>
            <div style='font-size: 11px; color: #92400e; font-weight: 600; margin-bottom: 4px;'>
                Total Inspections
            </div>
            <div>
                <div style='display: flex; align-items: center; gap: 8px; margin-bottom: 4px;'>
                    <div style='font-size: 36px; font-weight: 700; color: #78350f; line-height: 1;'>
                        " & FORMAT(_Count, "#,##0") & "
                    </div>
                    <div style='
                        background: #15803d;
                        color: white;
                        padding: 3px 8px;
                        border-radius: 20px;
                        font-size: 12px;
                        font-weight: 700;
                    '>
                        " & FORMAT(CountPct, "0%") & " ↑
                    </div>
                </div>
                <div style='font-size: 11px; color: #92400e;'>
                    Goal: " & FORMAT(CountGoal, "#,##0") & "
                </div>
            </div>
        </div>
        
        <!-- Card 2: Labor -->
        <div style='
            flex: 1;
            background: #f8f9fa;
            border-radius: 10px;
            padding: 16px;
            border: 2px solid #e5e7eb;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        '>
            <div style='font-size: 11px; color: #6b7280; font-weight: 600; margin-bottom: 4px;'>
                Labor Revenue
            </div>
            <div>
                <div style='display: flex; align-items: center; gap: 8px; margin-bottom: 4px;'>
                    <div style='font-size: 30px; font-weight: 700; color: #111827; line-height: 1;'>
                        " & FORMAT(Labor, "$#,##0") & "
                    </div>
                    <div style='
                        background: " & IF(LaborPct >= 1, "#dc2626", "#f59e0b") & ";
                        color: white;
                        padding: 3px 8px;
                        border-radius: 20px;
                        font-size: 12px;
                        font-weight: 700;
                    '>
                        " & FORMAT(LaborPct, "0%") & IF(LaborPct >= 1, " ↑", "") & "
                    </div>
                </div>
                <div style='font-size: 11px; color: #6b7280;'>
                    Goal: " & FORMAT(LaborGoal, "$#,##0") & "
                </div>
            </div>
        </div>
        
        <!-- Card 3: Parts -->
        <div style='
            flex: 1;
            background: #f8f9fa;
            border-radius: 10px;
            padding: 16px;
            border: 2px solid #e5e7eb;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        '>
            <div style='font-size: 11px; color: #6b7280; font-weight: 600; margin-bottom: 4px;'>
                Parts Revenue
            </div>
            <div>
                <div style='display: flex; align-items: center; gap: 8px; margin-bottom: 4px;'>
                    <div style='font-size: 30px; font-weight: 700; color: #111827; line-height: 1;'>
                        " & FORMAT(Parts, "$#,##0") & "
                    </div>
                    <div style='
                        background: " & IF(PartsPct >= 1, "#dc2626", "#f59e0b") & ";
                        color: white;
                        padding: 3px 8px;
                        border-radius: 20px;
                        font-size: 12px;
                        font-weight: 700;
                    '>
                        " & FORMAT(PartsPct, "0%") & IF(PartsPct >= 1, " ↑", "") & "
                    </div>
                </div>
                <div style='font-size: 11px; color: #6b7280;'>
                    Goal: " & FORMAT(PartsGoal, "$#,##0") & "
                </div>
            </div>
        </div>
        
    </div>
</div>
"
```

</details>

---

### Detail - Header

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Get user name
VAR _User = USERPRINCIPALNAME()
VAR _Position = SEARCH("@", _User, 1)
VAR _Name = LEFT(_User, _Position - 1)
VAR _FirstLetter = UPPER(LEFT(_Name, 1))
VAR _LastName = MID(_Name, 2, LEN(_Name) - 1)
VAR _FormattedLastName = 
    UPPER(LEFT(_LastName, 1)) & LOWER(MID(_LastName, 2, LEN(_LastName)))
VAR WelcomeName = _FirstLetter & "." & _FormattedLastName

// Get current date/time info
VAR CurrentDate = TODAY()
VAR DateDisplay = FORMAT(CurrentDate, "MMM D, YYYY")
VAR CurrentHour = HOUR(NOW())
VAR TimeGreeting = 
    IF(CurrentHour < 12, "Good Morning",
    IF(CurrentHour < 17, "Good Afternoon",
    "Good Evening"))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    height: 85px;
    padding: 15px 25px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 10px;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    box-sizing: border-box;
'>
    <!-- Left side: Dashboard Title -->
    <div style='display: flex; align-items: center; gap: 15px;'>
        <!-- Home icon -->
        <div style='
            width: 40px;
            height: 40px;
            background: rgba(255,255,255,0.15);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        '>
            🏠
        </div>
        
        <!-- Title -->
        <div>
            <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
                DASHBOARD
            </div>
            <div style='font-size: 26px; font-weight: 700; line-height: 1;'>
                Inspections - Details
            </div>
        </div>
    </div>
    
    <!-- Right side: Welcome & Date -->
    <div style='text-align: right;'>
        <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px;'>
            " & TimeGreeting & ", " & WelcomeName & "
        </div>
        <div style='font-size: 16px; font-weight: 600;'>
            📅 " & DateDisplay & "
        </div>
    </div>
</div>
"
```

</details>

---

### Discount Panel HTML

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR TotalDiscount = [Total Discount $]
VAR DiscountPct = [Total Discount %]
VAR ADV = [ADV Discount]
VAR Trucking = [Trucking Discount]
VAR PartsDisc = [Parts Discount]
VAR GrossRev = [Inspection $$] + [Parts $ Total] + [Labor With Inspection]
VAR NetRev = GrossRev + TotalDiscount

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    background: white;
    border-radius: 12px;
    padding: 28px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    border-left: 6px solid #dc2626;
'>
    <div style='
        font-size: 16px;
        font-weight: 700;
        color: #111827;
        margin-bottom: 24px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    '>
        💸 Discount Impact Analysis
    </div>
    
    <div style='display: flex; gap: 24px; align-items: center;'>
        
        <!-- Total Discount -->
        <div style='
            flex: 1;
            background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
            border-radius: 10px;
            padding: 24px;
            border: 2px solid #dc2626;
        '>
            <div style='font-size: 13px; color: #991b1b; font-weight: 600; margin-bottom: 8px;'>
                Total Discounts Applied
            </div>
            <div style='display: flex; align-items: center; gap: 12px; margin-bottom: 8px;'>
                <div style='font-size: 42px; font-weight: 700; color: #7f1d1d; line-height: 1;'>
                    " & FORMAT(TotalDiscount, "$#,##0") & "
                </div>
                <div style='
                    background: #dc2626;
                    color: white;
                    padding: 4px 12px;
                    border-radius: 20px;
                    font-size: 14px;
                    font-weight: 700;
                '>
                    " & FORMAT(DiscountPct, "0.0%") & "
                </div>
            </div>
            <div style='font-size: 13px; color: #991b1b;'>
                Of total revenue
            </div>
        </div>
        
        <!-- Breakdown -->
        <div style='flex: 2; display: flex; gap: 16px;'>
            
            <!-- ADV -->
            <div style='
                flex: 1;
                background: #f8f9fa;
                border-radius: 10px;
                padding: 20px;
                border: 2px solid #e5e7eb;
            '>
                <div style='font-size: 12px; color: #6b7280; font-weight: 600; margin-bottom: 6px;'>
                    ADV/Advertising
                </div>
                <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1;'>
                    " & FORMAT(ADV, "$#,##0") & "
                </div>
            </div>
            
            <!-- Trucking -->
            <div style='
                flex: 1;
                background: #f8f9fa;
                border-radius: 10px;
                padding: 20px;
                border: 2px solid #e5e7eb;
            '>
                <div style='font-size: 12px; color: #6b7280; font-weight: 600; margin-bottom: 6px;'>
                    Trucking
                </div>
                <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1;'>
                    " & FORMAT(Trucking, "$#,##0") & "
                </div>
            </div>
            
            <!-- Parts Promo -->
            <div style='
                flex: 1;
                background: #f8f9fa;
                border-radius: 10px;
                padding: 20px;
                border: 2px solid #e5e7eb;
            '>
                <div style='font-size: 12px; color: #6b7280; font-weight: 600; margin-bottom: 6px;'>
                    Parts Promo
                </div>
                <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1;'>
                    " & FORMAT(PartsDisc, "$#,##0") & "
                </div>
            </div>
            
        </div>
    </div>
</div>
"

```

</details>

---

### Discount Panel HTML V2

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR TotalDiscount = [Total Discount $]
VAR DiscountPct = [Total Discount %]
VAR ADV = [ADV Discount]
VAR Trucking = [Trucking Discount]
VAR PartsDisc = [Parts Discount]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    background: white;
    border-radius: 12px;
    padding: 20px 24px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    border-left: 6px solid #dc2626;
    height: 180px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    box-sizing: border-box;
'>
    <div style='
        font-size: 14px;
        font-weight: 700;
        color: #111827;
        margin-bottom: 12px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    '>
        💸 Discount Impact Analysis
    </div>
    
    <div style='display: flex; gap: 16px; align-items: stretch; flex: 1;'>
        
        <!-- Total Discount -->
        <div style='
            flex: 1;
            background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
            border-radius: 10px;
            padding: 16px;
            border: 2px solid #dc2626;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        '>
            <div style='font-size: 11px; color: #991b1b; font-weight: 600; margin-bottom: 4px;'>
                Total Discounts Applied
            </div>
            <div>
                <div style='display: flex; align-items: center; gap: 8px; margin-bottom: 4px;'>
                    <div style='font-size: 36px; font-weight: 700; color: #7f1d1d; line-height: 1;'>
                        " & FORMAT(TotalDiscount, "$#,##0") & "
                    </div>
                    <div style='
                        background: #dc2626;
                        color: white;
                        padding: 3px 8px;
                        border-radius: 20px;
                        font-size: 12px;
                        font-weight: 700;
                    '>
                        " & FORMAT(DiscountPct, "0.0%") & "
                    </div>
                </div>
                <div style='font-size: 11px; color: #991b1b;'>
                    Of total revenue
                </div>
            </div>
        </div>
        
        <!-- Breakdown -->
        <div style='flex: 2; display: flex; gap: 12px;'>
            
            <!-- ADV -->
            <div style='
                flex: 1;
                background: #f8f9fa;
                border-radius: 10px;
                padding: 16px;
                border: 2px solid #e5e7eb;
                display: flex;
                flex-direction: column;
                justify-content: space-between;
            '>
                <div style='font-size: 11px; color: #6b7280; font-weight: 600; margin-bottom: 4px;'>
                    ADV/Advertising
                </div>
                <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1;'>
                    " & FORMAT(ADV, "$#,##0") & "
                </div>
            </div>
            
            <!-- Trucking -->
            <div style='
                flex: 1;
                background: #f8f9fa;
                border-radius: 10px;
                padding: 16px;
                border: 2px solid #e5e7eb;
                display: flex;
                flex-direction: column;
                justify-content: space-between;
            '>
                <div style='font-size: 11px; color: #6b7280; font-weight: 600; margin-bottom: 4px;'>
                    Trucking
                </div>
                <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1;'>
                    " & FORMAT(Trucking, "$#,##0") & "
                </div>
            </div>
            
            <!-- Parts Promo -->
            <div style='
                flex: 1;
                background: #f8f9fa;
                border-radius: 10px;
                padding: 16px;
                border: 2px solid #e5e7eb;
                display: flex;
                flex-direction: column;
                justify-content: space-between;
            '>
                <div style='font-size: 11px; color: #6b7280; font-weight: 600; margin-bottom: 4px;'>
                    Parts Promo
                </div>
                <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1;'>
                    " & FORMAT(PartsDisc, "$#,##0") & "
                </div>
            </div>
            
        </div>
    </div>
</div>
"
```

</details>

---

### Discount Summary Card HTML

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR TotalDiscount = [Total Discount $]
VAR DiscountPct = [Total Discount %]
VAR ADV = [ADV Discount]
VAR Trucking = [Trucking Discount]
VAR PartsDisc = [Parts Discount]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    background: white;
    border-radius: 12px;
    padding: 24px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    border-left: 6px solid #dc2626;
    height: 170px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
'>
    <div>
        <div style='font-size: 13px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
            💸 Total Discounts Applied
        </div>
        <div style='display: flex; align-items: center; gap: 12px; margin-bottom: 4px;'>
            <div style='font-size: 36px; font-weight: 700; color: #dc2626; line-height: 1;'>
                " & FORMAT(TotalDiscount, "$#,##0") & "
            </div>
            <div style='
                background: #fecaca;
                color: #991b1b;
                padding: 4px 12px;
                border-radius: 20px;
                font-size: 14px;
                font-weight: 700;
            '>
                " & FORMAT(DiscountPct, "0.0%") & "
            </div>
        </div>
    </div>
    
    <div style='
        background: #fef2f2;
        padding: 10px 12px;
        border-radius: 6px;
        font-size: 11px;
        color: #7f1d1d;
        line-height: 1.5;
    '>
        <div style='display: flex; justify-content: space-between; margin-bottom: 3px;'>
            <span>ADV/Advertising:</span>
            <span style='font-weight: 600;'>" & FORMAT(ADV, "$#,##0") & "</span>
        </div>
        <div style='display: flex; justify-content: space-between; margin-bottom: 3px;'>
            <span>Trucking:</span>
            <span style='font-weight: 600;'>" & FORMAT(Trucking, "$#,##0") & "</span>
        </div>
        <div style='display: flex; justify-content: space-between;'>
            <span>Parts Promo:</span>
            <span style='font-weight: 600;'>" & FORMAT(PartsDisc, "$#,##0") & "</span>
        </div>
    </div>
</div>
"
```

</details>

---

### Goals - Header

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Get user name
VAR _User = USERPRINCIPALNAME()
VAR _Position = SEARCH("@", _User, 1)
VAR _Name = LEFT(_User, _Position - 1)
VAR _FirstLetter = UPPER(LEFT(_Name, 1))
VAR _LastName = MID(_Name, 2, LEN(_Name) - 1)
VAR _FormattedLastName = 
    UPPER(LEFT(_LastName, 1)) & LOWER(MID(_LastName, 2, LEN(_LastName)))
VAR WelcomeName = _FirstLetter & "." & _FormattedLastName

// Get current date/time info
VAR CurrentDate = TODAY()
VAR DateDisplay = FORMAT(CurrentDate, "MMM D, YYYY")
VAR CurrentHour = HOUR(NOW())
VAR TimeGreeting = 
    IF(CurrentHour < 12, "Good Morning",
    IF(CurrentHour < 17, "Good Afternoon",
    "Good Evening"))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    height: 85px;
    padding: 15px 25px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 10px;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    box-sizing: border-box;
'>
    <!-- Left side: Dashboard Title -->
    <div style='display: flex; align-items: center; gap: 15px;'>
        <!-- Home icon -->
        <div style='
            width: 40px;
            height: 40px;
            background: rgba(255,255,255,0.15);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        '>
            🏠
        </div>
        
        <!-- Title -->
        <div>
            <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
                DASHBOARD
            </div>
            <div style='font-size: 26px; font-weight: 700; line-height: 1;'>
                Inspections - Goals
            </div>
        </div>
    </div>
    
    <!-- Right side: Welcome & Date -->
    <div style='text-align: right;'>
        <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px;'>
            " & TimeGreeting & ", " & WelcomeName & "
        </div>
        <div style='font-size: 16px; font-weight: 600;'>
            📅 " & DateDisplay & "
        </div>
    </div>
</div>
"
```

</details>

---

### Hero Background with Dividers

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 30px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    height: 180px;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: space-around;
'>
    <!-- Section 1 space -->
    <div style='flex: 1;'></div>
    
    <!-- Divider 1 -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 2 space -->
    <div style='flex: 1;'></div>
    
    <!-- Divider 2 -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 3 space -->
    <div style='flex: 1;'></div>
    
    <!-- Divider 3 -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 4 space -->
    <div style='flex: 1;'></div>
</div>
"
```

</details>

---

### Hero Card HTML - Brand Colors A

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR Inspections = [Total Inspections]
VAR _Goal = [Total Inspection Goal]
VAR Pct = [% to Goal - Inspections]
VAR Above = Inspections - _Goal
VAR PctText = FORMAT(Pct, "0%")
VAR AboveText = FORMAT(Above, "+#,##0;-#,##0")
VAR Revenue = [Inspection $$] + [Parts $ Total] + [Labor $$]
VAR RevenueText = FORMAT(Revenue / 1000000, "$#,##0.0") & "M"

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 30px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    color: white;
    height: 180px;
    display: flex;
    align-items: center;
    justify-content: space-around;
'>
    <!-- Main Metric -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Inspections
        </div>
        <div style='font-size: 72px; font-weight: 700; line-height: 1;'>
            " & FORMAT(Inspections, "#,##0") & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; opacity: 0.9;'>
            Goal: " & FORMAT(_Goal, "#,##0") & " | " & PctText & " ↑
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 40px;'></div>
    
    <!-- Revenue -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Revenue
        </div>
        <div style='font-size: 56px; font-weight: 700; line-height: 1;'>
            " & RevenueText & "
        </div>
        <div style='font-size: 16px; margin-top: 10px; opacity: 0.9;'>
            Inspection + Parts + Labor
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 40px;'></div>
    
    <!-- Performance Badge -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Performance
        </div>
        <div style='
            font-size: 64px; 
            font-weight: 700; 
            line-height: 1;
            color: #4ade80;
        '>
            " & PctText & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; font-weight: 600;'>
            " & AboveText & " above goal
        </div>
    </div>
</div>
"
```

</details>

---

### Hero Card HTML - Brand Colors B

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR Inspections = [Total Inspections]
VAR _Goal = [Total Inspection Goal]
VAR Pct = [% to Goal - Inspections]
VAR Above = Inspections - _Goal
VAR PctText = FORMAT(Pct, "0%")
VAR AboveText = FORMAT(Above, "+#,##0;-#,##0")
VAR Revenue = [Inspection $$] + [Parts $ Total] + [Labor $$]
VAR RevenueText = FORMAT(Revenue / 1000000, "$#,##0.0") & "M"

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 30px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2C4F60 50%, #475569 100%);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    color: white;
    height: 180px;
    display: flex;
    align-items: center;
    justify-content: space-around;
'>
    <!-- Main Metric -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Inspections
        </div>
        <div style='font-size: 72px; font-weight: 700; line-height: 1;'>
            " & FORMAT(Inspections, "#,##0") & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; opacity: 0.9;'>
            Goal: " & FORMAT(_Goal, "#,##0") & " | " & PctText & " ↑
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 40px;'></div>
    
    <!-- Revenue -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Revenue
        </div>
        <div style='font-size: 56px; font-weight: 700; line-height: 1;'>
            " & RevenueText & "
        </div>
        <div style='font-size: 16px; margin-top: 10px; opacity: 0.9;'>
            Inspection + Parts + Labor
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 40px;'></div>
    
    <!-- Performance Badge -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Performance
        </div>
        <div style='
            font-size: 64px; 
            font-weight: 700; 
            line-height: 1;
            color: #4ade80;
        '>
            " & PctText & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; font-weight: 600;'>
            " & AboveText & " above goal
        </div>
    </div>
</div>
"
```

</details>

---

### Hero Card HTML - Brand Colors C

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR Inspections = [Total Inspections]
VAR _Goal = [Total Inspection Goal]
VAR Pct = [% to Goal - Inspections]
VAR Above = Inspections - _Goal
VAR PctText = FORMAT(Pct, "0%")
VAR AboveText = FORMAT(Above, "+#,##0;-#,##0")
VAR Revenue = [Inspection $$] + [Parts $ Total] + [Labor $$]
VAR RevenueText = FORMAT(Revenue / 1000000, "$#,##0.0") & "M"

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 30px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2C5F5F 50%, #166534 100%);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    color: white;
    height: 180px;
    display: flex;
    align-items: center;
    justify-content: space-around;
'>
    <!-- Main Metric -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Inspections
        </div>
        <div style='font-size: 72px; font-weight: 700; line-height: 1;'>
            " & FORMAT(Inspections, "#,##0") & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; opacity: 0.9;'>
            Goal: " & FORMAT(_Goal, "#,##0") & " | " & PctText & " ↑
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 40px;'></div>
    
    <!-- Revenue -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Revenue
        </div>
        <div style='font-size: 56px; font-weight: 700; line-height: 1;'>
            " & RevenueText & "
        </div>
        <div style='font-size: 16px; margin-top: 10px; opacity: 0.9;'>
            Inspection + Parts + Labor
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 40px;'></div>
    
    <!-- Performance Badge -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Performance
        </div>
        <div style='
            font-size: 64px; 
            font-weight: 700; 
            line-height: 1;
            color: #86efac;
        '>
            " & PctText & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; font-weight: 600;'>
            " & AboveText & " above goal
        </div>
    </div>
</div>
"
```

</details>

---

### Hero Card HTML - Brand Colors D

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR Inspections = [Total Inspections]
VAR _Goal = [Total Inspection Goal]
VAR Pct = [% to Goal - Inspections]
VAR Above = Inspections - _Goal
VAR PctText = FORMAT(Pct, "0%")
VAR AboveText = FORMAT(Above, "+#,##0;-#,##0")
VAR Revenue = [Inspection $$] + [Parts $ Total] + [Labor $$]
VAR RevenueText = FORMAT(Revenue / 1000000, "$#,##0.0") & "M"

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 30px;
    background: linear-gradient(135deg, #1D3C4E 0%, #25495D 100%);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    color: white;
    height: 180px;
    display: flex;
    align-items: center;
    justify-content: space-around;
'>
    <!-- Main Metric -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Inspections
        </div>
        <div style='font-size: 72px; font-weight: 700; line-height: 1;'>
            " & FORMAT(Inspections, "#,##0") & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; opacity: 0.9;'>
            Goal: " & FORMAT(_Goal, "#,##0") & " | " & PctText & " ↑
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 40px;'></div>
    
    <!-- Revenue -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Revenue
        </div>
        <div style='font-size: 56px; font-weight: 700; line-height: 1;'>
            " & RevenueText & "
        </div>
        <div style='font-size: 16px; margin-top: 10px; opacity: 0.9;'>
            Inspection + Parts + Labor
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 40px;'></div>
    
    <!-- Performance Badge -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Performance
        </div>
        <div style='
            font-size: 64px; 
            font-weight: 700; 
            line-height: 1;
            color: #fbbf24;
        '>
            " & PctText & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; font-weight: 600;'>
            " & AboveText & " above goal
        </div>
    </div>
</div>
"
```

</details>

---

### Hero Card HTML Option 2

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR Inspections = [Total Inspections]
VAR _Goal = [Total Inspection Goal]
VAR Pct = [% to Goal - Inspections]
VAR Above = Inspections - _Goal
VAR PctText = FORMAT(Pct, "0%")

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 40px;
    background: white;
    border-radius: 16px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.08);
    border-left: 6px solid #10b981;
    height: 180px;
    display: flex;
    align-items: center;
    justify-content: space-between;
'>
    <!-- Left: Main Number -->
    <div style='flex: 2;'>
        <div style='
            font-size: 16px; 
            color: #6b7280; 
            margin-bottom: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        '>
            Total Inspections
        </div>
        <div style='
            font-size: 84px; 
            font-weight: 700; 
            line-height: 1;
            color: #111827;
        '>
            " & FORMAT(Inspections, "#,##0") & "
        </div>
    </div>
    
    <!-- Right: Context Cards -->
    <div style='display: flex; gap: 20px; flex: 3; justify-content: flex-end;'>
        
        <!-- Goal Card -->
        <div style='
            background: #f3f4f6;
            padding: 24px 32px;
            border-radius: 12px;
            text-align: center;
            min-width: 180px;
        '>
            <div style='font-size: 14px; color: #6b7280; margin-bottom: 8px;'>
                Goal
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827;'>
                " & FORMAT(_Goal, "#,##0") & "
            </div>
        </div>
        
        <!-- Performance Card -->
        <div style='
            background: linear-gradient(135deg, #10b981 0%, #059669 100%);
            padding: 24px 32px;
            border-radius: 12px;
            text-align: center;
            color: white;
            min-width: 180px;
        '>
            <div style='font-size: 14px; opacity: 0.9; margin-bottom: 8px;'>
                Performance
            </div>
            <div style='font-size: 48px; font-weight: 700; line-height: 1;'>
                " & PctText & "
            </div>
            <div style='font-size: 13px; opacity: 0.9; margin-top: 4px;'>
                ↑ " & FORMAT(Above, "#,##0") & " above
            </div>
        </div>
        
    </div>
</div>
"
```

</details>

---

### Hero Card HTML with Pending

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR Inspections = [Total Inspections]
VAR _Goal = [Total Inspection Goal]
VAR Pct = [% to Goal - Inspections]
VAR Above = Inspections - _Goal
VAR PctText = FORMAT(Pct, "0%")
VAR AboveText = FORMAT(Above, "+#,##0;-#,##0")
VAR Revenue = [Inspection $$] + [Parts $ Total] + [Labor With Inspection]
VAR RevenueText = FORMAT(Revenue / 1000000, "$#,##0.1") & "M"
VAR Pending = [Pending Inspections Count]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 30px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    color: white;
    height: 185px;
    display: flex;
    align-items: center;
    justify-content: space-around;
'>
    <!-- Section 1: Main Metric -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Inspections
        </div>
        <div style='font-size: 72px; font-weight: 700; line-height: 1;'>
            " & FORMAT(Inspections, "#,##0") & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; opacity: 0.9;'>
            Goal: " & FORMAT(_Goal, "#,##0") & " | " & PctText & " ↑
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 2: Revenue -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Revenue
        </div>
        <div style='font-size: 56px; font-weight: 700; line-height: 1;'>
            " & RevenueText & "
        </div>
        <div style='font-size: 16px; margin-top: 10px; opacity: 0.9;'>
            Inspection + Parts + Labor
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 3: Performance -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Performance
        </div>
        <div style='
            font-size: 64px; 
            font-weight: 700; 
            line-height: 1;
            color: #4ade80;
        '>
            " & PctText & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; font-weight: 600;'>
            " & AboveText & " above goal
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 4: Pending NEW! -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Pipeline
        </div>
        <div style='font-size: 56px; font-weight: 700; line-height: 1;'>
            " & FORMAT(Pending, "#,##0") & "
        </div>
        <div style='font-size: 16px; margin-top: 10px; opacity: 0.9;'>
            Pending Inspections
        </div>
    </div>
</div>
"
```

</details>

---

### Hero Cards HTML Option 3

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR Inspections = [Total Inspections]
VAR _Goal = [Total Inspection Goal]
VAR Pct = [% to Goal - Inspections]
VAR Revenue = [Inspection $$] + [Parts $ Total] + [Labor $$]
VAR Hours = [Hours Worked With Inspection]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    display: flex;
    gap: 20px;
    height: 180px;
'>
    <!-- Card 1: Inspections -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 28px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #3b82f6;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 13px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px;'>
                📊 Total Inspections
            </div>
            <div style='font-size: 52px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(Inspections, "#,##0") & "
            </div>
        </div>
        <div style='
            background: #dbeafe;
            padding: 8px 12px;
            border-radius: 6px;
            font-size: 13px;
            color: #1e40af;
            font-weight: 600;
        '>
            Goal: " & FORMAT(_Goal, "#,##0") & " • " & FORMAT(Pct, "0%") & " ↑
        </div>
    </div>
    
    <!-- Card 2: Revenue -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 28px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #10b981;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 13px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px;'>
                💰 Total Revenue
            </div>
            <div style='font-size: 52px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(Revenue / 1000000, "$#,##0.0") & "M
            </div>
        </div>
        <div style='
            background: #d1fae5;
            padding: 8px 12px;
            border-radius: 6px;
            font-size: 13px;
            color: #065f46;
            font-weight: 600;
        '>
            Inspection + Parts + Labor
        </div>
    </div>
    
    <!-- Card 3: Hours -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 28px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #f59e0b;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 13px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px;'>
                ⏱️ Hours Worked
            </div>
            <div style='font-size: 52px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(Hours / 1000, "#,##0.0") & "K
            </div>
        </div>
        <div style='
            background: #fef3c7;
            padding: 8px 12px;
            border-radius: 6px;
            font-size: 13px;
            color: #92400e;
            font-weight: 600;
        '>
            Total work generated
        </div>
    </div>
</div>
"
```

</details>

---

### Home - Header

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Get user name
VAR _User = USERPRINCIPALNAME()
VAR _Position = SEARCH("@", _User, 1)
VAR _Name = LEFT(_User, _Position - 1)
VAR _FirstLetter = UPPER(LEFT(_Name, 1))
VAR _LastName = MID(_Name, 2, LEN(_Name) - 1)
VAR _FormattedLastName = 
    UPPER(LEFT(_LastName, 1)) & LOWER(MID(_LastName, 2, LEN(_LastName)))
VAR WelcomeName = _FirstLetter & "." & _FormattedLastName

// Get current date/time info
VAR CurrentDate = TODAY()
VAR DateDisplay = FORMAT(CurrentDate, "MMM D, YYYY")
VAR CurrentHour = HOUR(NOW())
VAR TimeGreeting = 
    IF(CurrentHour < 12, "Good Morning",
    IF(CurrentHour < 17, "Good Afternoon",
    "Good Evening"))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    height: 85px;
    padding: 15px 25px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 10px;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    box-sizing: border-box;
'>
    <!-- Left side: Dashboard Title -->
    <div style='display: flex; align-items: center; gap: 15px;'>
        <!-- Home icon -->
        <div style='
            width: 40px;
            height: 40px;
            background: rgba(255,255,255,0.15);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        '>
            🏠
        </div>
        
        <!-- Title -->
        <div>
            <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
                DASHBOARD
            </div>
            <div style='font-size: 26px; font-weight: 700; line-height: 1;'>
                Inspections
            </div>
        </div>
    </div>
    
    <!-- Right side: Welcome & Date -->
    <div style='text-align: right;'>
        <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px;'>
            " & TimeGreeting & ", " & WelcomeName & "
        </div>
        <div style='font-size: 16px; font-weight: 600;'>
            📅 " & DateDisplay & "
        </div>
    </div>
</div>
"
```

</details>

---

### Page Help Documentation

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

"
<div style='font-family: Segoe UI, Arial, sans-serif; padding: 25px; background: white; border-radius: 10px; max-width: 700px;'>
    
    <!-- Header -->
    <div style='background: linear-gradient(to right, #1D3C4E, #3A7CA5); color: white; padding: 15px 20px; border-radius: 8px; margin-bottom: 25px;'>
        <h2 style='margin: 0; font-size: 22px;'>📖 How This Page Works</h2>
        <p style='margin: 8px 0 0 0; font-size: 14px; opacity: 0.95;'>Understanding your parts & services recommendations</p>
    </div>

    <!-- What This Page Shows -->
    <div style='margin-bottom: 25px;'>
        <h3 style='color: #1D3C4E; font-size: 18px; margin-bottom: 12px; border-bottom: 2px solid #3A7CA5; padding-bottom: 8px;'>
            🎯 What This Page Shows
        </h3>
        <p style='color: #4B5563; font-size: 14px; line-height: 1.6; margin: 0;'>
            This page predicts what parts and services you'll need for your pending inspections. 
            It looks at what happened in the past when we completed similar inspections, then estimates 
            what you'll need for the inspections waiting in your queue right now.
        </p>
    </div>

    <!-- How We Calculate -->
    <div style='margin-bottom: 25px;'>
        <h3 style='color: #1D3C4E; font-size: 18px; margin-bottom: 12px; border-bottom: 2px solid #3A7CA5; padding-bottom: 8px;'>
            🔢 How We Calculate the Numbers
        </h3>
        
        <div style='background: #F3F4F6; padding: 15px; border-radius: 8px; margin-bottom: 12px;'>
            <h4 style='color: #1D3C4E; font-size: 15px; margin: 0 0 10px 0;'>
                <strong>Step 1:</strong> Look at History
            </h4>
            <p style='color: #4B5563; font-size: 14px; line-height: 1.6; margin: 0;'>
                We review all completed inspections of this type (example: IS-CS690 INSPECT). 
                For each one, we see what services were performed and what parts were used.
            </p>
        </div>

        <div style='background: #F3F4F6; padding: 15px; border-radius: 8px; margin-bottom: 12px;'>
            <h4 style='color: #1D3C4E; font-size: 15px; margin: 0 0 10px 0;'>
                <strong>Step 2:</strong> Calculate Frequency
            </h4>
            <p style='color: #4B5563; font-size: 14px; line-height: 1.6; margin: 0;'>
                <strong>Example:</strong> If we completed 224 IS-CS690 inspections, and GEN REPAIR 1 
                was needed on 124 of them, that's a <strong>55% frequency</strong>. 
                This means about half the time, this service is needed.
            </p>
        </div>

        <div style='background: #F3F4F6; padding: 15px; border-radius: 8px;'>
            <h4 style='color: #1D3C4E; font-size: 15px; margin: 0 0 10px 0;'>
                <strong>Step 3:</strong> Predict What You Need
            </h4>
            <p style='color: #4B5563; font-size: 14px; line-height: 1.6; margin: 0;'>
                If you have <strong>5 pending inspections</strong> and GEN REPAIR 1 happens 
                <strong>55% of the time</strong>, we estimate you'll need it for about 
                <strong>3 of those inspections</strong> (5 × 55% = 2.75, rounds to 3).
            </p>
        </div>
    </div>

    <!-- Understanding the Colors -->
    <div style='margin-bottom: 25px;'>
        <h3 style='color: #1D3C4E; font-size: 18px; margin-bottom: 12px; border-bottom: 2px solid #3A7CA5; padding-bottom: 8px;'>
            🎨 What the Colors Mean
        </h3>
        
        <div style='display: flex; align-items: center; margin-bottom: 10px;'>
            <div style='width: 30px; height: 30px; background: #ef4444; border-radius: 4px; margin-right: 12px;'></div>
            <div style='color: #4B5563; font-size: 14px;'>
                <strong>🔴 Red (50%+ frequency):</strong> Critical - Needed on most inspections. Stock up!
            </div>
        </div>
        
        <div style='display: flex; align-items: center; margin-bottom: 10px;'>
            <div style='width: 30px; height: 30px; background: #f59e0b; border-radius: 4px; margin-right: 12px;'></div>
            <div style='color: #4B5563; font-size: 14px;'>
                <strong>🟡 Yellow (30-49% frequency):</strong> Common - Often needed, keep some on hand.
            </div>
        </div>
        
        <div style='display: flex; align-items: center;'>
            <div style='width: 30px; height: 30px; background: #10b981; border-radius: 4px; margin-right: 12px;'></div>
            <div style='color: #4B5563; font-size: 14px;'>
                <strong>🟢 Green (under 30% frequency):</strong> Occasional - Sometimes needed, normal stock OK.
            </div>
        </div>
    </div>

    <!-- What to Do -->
    <div style='margin-bottom: 25px;'>
        <h3 style='color: #1D3C4E; font-size: 18px; margin-bottom: 12px; border-bottom: 2px solid #3A7CA5; padding-bottom: 8px;'>
            ✅ What You Should Do
        </h3>
        
        <div style='background: #EFF6FF; border-left: 4px solid #3A7CA5; padding: 15px; border-radius: 4px; margin-bottom: 12px;'>
            <p style='color: #1E40AF; font-size: 14px; line-height: 1.6; margin: 0;'>
                <strong>1. Check Your Inventory:</strong> Look at the red items first. Do you have enough 
                of these critical parts in stock?
            </p>
        </div>
        
        <div style='background: #EFF6FF; border-left: 4px solid #3A7CA5; padding: 15px; border-radius: 4px; margin-bottom: 12px;'>
            <p style='color: #1E40AF; font-size: 14px; line-height: 1.6; margin: 0;'>
                <strong>2. Schedule Your Team:</strong> Make sure you have technicians available who can 
                perform the most common services (high frequency items).
            </p>
        </div>
        
        <div style='background: #EFF6FF; border-left: 4px solid #3A7CA5; padding: 15px; border-radius: 4px;'>
            <p style='color: #1E40AF; font-size: 14px; line-height: 1.6; margin: 0;'>
                <strong>3. Plan Your Revenue:</strong> The estimated revenue shows your potential income 
                if all pending inspections are completed. Use this for forecasting.
            </p>
        </div>
    </div>

    <!-- Important Notes -->
    <div style='background: #FEF3C7; border-left: 4px solid #f59e0b; padding: 15px; border-radius: 4px;'>
        <h4 style='color: #92400E; font-size: 15px; margin: 0 0 8px 0;'>
            ⚠️ Important to Remember
        </h4>
        <ul style='color: #78350F; font-size: 13px; line-height: 1.6; margin: 8px 0 0 20px; padding: 0;'>
            <li style='margin-bottom: 6px;'>These are <strong>estimates</strong> based on past patterns, not guarantees</li>
            <li style='margin-bottom: 6px;'>Actual needs may vary - each unit is different</li>
            <li style='margin-bottom: 6px;'>Use this as a planning guide, not an exact shopping list</li>
            <li>Export the detailed tables below for ordering and staff planning</li>
        </ul>
    </div>

    <!-- Footer -->
    <div style='margin-top: 25px; padding-top: 15px; border-top: 1px solid #E5E7EB; text-align: center;'>
        <p style='color: #6B7280; font-size: 12px; margin: 0;'>
            💡 <strong>Tip:</strong> Review this page weekly to stay prepared for your pending inspections
        </p>
    </div>

</div>
"
```

</details>

---

### Parts Services Hero HTML Compact

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR PendingInsp = [Total Pending Inspections]
VAR ServiceRev = [Est Service Revenue]
VAR PartsRev = [Est Parts Value - For Pending]
VAR TotalRev = ServiceRev + PartsRev
VAR ServicePct = DIVIDE(ServiceRev, TotalRev, 0)
VAR PartsPct = DIVIDE(PartsRev, TotalRev, 0)

VAR SelectedJobCode = 
    IF(
        HASONEVALUE(Fact_PendingInspections[JobCode]),
        SELECTEDVALUE(Fact_PendingInspections[JobCode]),
        "All Job Codes"
    )

VAR ServiceRevText = 
    IF(ServiceRev >= 1000000, FORMAT(ServiceRev / 1000000, "$#,##0.0") & "M",
    IF(ServiceRev >= 10000, FORMAT(ServiceRev / 1000, "$#,##0.0") & "K",
    FORMAT(ServiceRev, "$#,##0")))

VAR PartsRevText = 
    IF(PartsRev >= 1000000, FORMAT(PartsRev / 1000000, "$#,##0.0") & "M",
    IF(PartsRev >= 10000, FORMAT(PartsRev / 1000, "$#,##0.0") & "K",
    FORMAT(PartsRev, "$#,##0")))

VAR TotalRevText = 
    IF(TotalRev >= 1000000, FORMAT(TotalRev / 1000000, "$#,##0.0") & "M",
    IF(TotalRev >= 10000, FORMAT(TotalRev / 1000, "$#,##0.0") & "K",
    FORMAT(TotalRev, "$#,##0")))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 20px 25px 15px 25px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 10px;
    box-shadow: 0 6px 20px rgba(0,0,0,0.12);
    color: white;
'>
    <!-- JobCode Header - More Compact -->
    <div style='
        text-align: center;
        font-size: 14px;
        font-weight: 600;
        opacity: 0.95;
        margin-bottom: 15px;
        padding-bottom: 10px;
        border-bottom: 1px solid rgba(255,255,255,0.2);
        letter-spacing: 0.5px;
    '>
        🔧 " & SelectedJobCode & "
    </div>
    
    <!-- Metrics Row - Reduced Height -->
    <div style='
        display: flex;
        align-items: center;
        justify-content: space-around;
        min-height: 90px;
    '>
        <!-- Card 1: Pending Inspections -->
        <div style='text-align: center; flex: 1;'>
            <div style='font-size: 11px; opacity: 0.85; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.8px;'>
                Pending Inspections
            </div>
            <div style='font-size: 48px; font-weight: 700; line-height: 1;'>
                " & FORMAT(PendingInsp, "#,##0") & "
            </div>
            <div style='font-size: 13px; margin-top: 6px; opacity: 0.85;'>
                Inspections awaiting service
            </div>
        </div>
        
        <!-- Divider -->
        <div style='width: 2px; height: 80px; background: rgba(255,255,255,0.3); margin: 0 20px;'></div>
        
        <!-- Card 2: Service Revenue -->
        <div style='text-align: center; flex: 1;'>
            <div style='font-size: 11px; opacity: 0.85; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.8px;'>
                Est. Service Revenue
            </div>
            <div style='font-size: 40px; font-weight: 700; line-height: 1;'>
                " & ServiceRevText & "
            </div>
            <div style='font-size: 13px; margin-top: 6px; opacity: 0.85;'>
                " & FORMAT(ServicePct, "0%") & " of total revenue
            </div>
        </div>
        
        <!-- Divider -->
        <div style='width: 2px; height: 80px; background: rgba(255,255,255,0.3); margin: 0 20px;'></div>
        
        <!-- Card 3: Parts Revenue -->
        <div style='text-align: center; flex: 1;'>
            <div style='font-size: 11px; opacity: 0.85; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.8px;'>
                Est. Parts Revenue
            </div>
            <div style='font-size: 40px; font-weight: 700; line-height: 1;'>
                " & PartsRevText & "
            </div>
            <div style='font-size: 13px; margin-top: 6px; opacity: 0.85;'>
                " & FORMAT(PartsPct, "0%") & " of total revenue
            </div>
        </div>
        
        <!-- Divider -->
        <div style='width: 2px; height: 80px; background: rgba(255,255,255,0.3); margin: 0 20px;'></div>
        
        <!-- Card 4: Total Revenue -->
        <div style='text-align: center; flex: 1;'>
            <div style='font-size: 11px; opacity: 0.85; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.8px;'>
                Total Opportunity
            </div>
            <div style='
                font-size: 44px; 
                font-weight: 700; 
                line-height: 1;
                color: #10b981;
            '>
                " & TotalRevText & "
            </div>
            <div style='font-size: 13px; margin-top: 6px; opacity: 0.85;'>
                Combined revenue potential
            </div>
        </div>
    </div>
</div>
"
```

</details>

---

### Pending - Header

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Get user name
VAR _User = USERPRINCIPALNAME()
VAR _Position = SEARCH("@", _User, 1)
VAR _Name = LEFT(_User, _Position - 1)
VAR _FirstLetter = UPPER(LEFT(_Name, 1))
VAR _LastName = MID(_Name, 2, LEN(_Name) - 1)
VAR _FormattedLastName = 
    UPPER(LEFT(_LastName, 1)) & LOWER(MID(_LastName, 2, LEN(_LastName)))
VAR WelcomeName = _FirstLetter & "." & _FormattedLastName

// Get current date/time info
VAR CurrentDate = TODAY()
VAR DateDisplay = FORMAT(CurrentDate, "MMM D, YYYY")
VAR CurrentHour = HOUR(NOW())
VAR TimeGreeting = 
    IF(CurrentHour < 12, "Good Morning",
    IF(CurrentHour < 17, "Good Afternoon",
    "Good Evening"))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    height: 85px;
    padding: 15px 25px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 10px;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    box-sizing: border-box;
'>
    <!-- Left side: Dashboard Title -->
    <div style='display: flex; align-items: center; gap: 15px;'>
        <!-- Home icon -->
        <div style='
            width: 40px;
            height: 40px;
            background: rgba(255,255,255,0.15);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        '>
            🏠
        </div>
        
        <!-- Title -->
        <div>
            <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
                DASHBOARD
            </div>
            <div style='font-size: 26px; font-weight: 700; line-height: 1;'>
                Pending Inspections
            </div>
        </div>
    </div>
    
    <!-- Right side: Welcome & Date -->
    <div style='text-align: right;'>
        <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px;'>
            " & TimeGreeting & ", " & WelcomeName & "
        </div>
        <div style='font-size: 16px; font-weight: 600;'>
            📅 " & DateDisplay & "
        </div>
    </div>
</div>
"
```

</details>

---

### Pending Hero Card HTML

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR TotalPending = [Total Pending Inspections]
VAR TotalHours = [Total Pending Hours]
VAR AvgAge = [Average Pending Age]
VAR AvgRevenue = [Average Inspection Revenue]
VAR EstRevenue = [Estimated Revenue - Pending]
VAR EstRevenueText = FORMAT(EstRevenue / 1000, "$#,##0.0") & "K"
VAR HoursText = FORMAT(TotalHours, "#,##0.0")
VAR AgeText = FORMAT(AvgAge, "0.0")

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 30px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
    color: white;
    height: 180px;
    display: flex;
    align-items: center;
    justify-content: space-around;
'>
    <!-- Section 1: Total Pending -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Pending Inspections
        </div>
        <div style='font-size: 72px; font-weight: 700; line-height: 1;'>
            " & FORMAT(TotalPending, "#,##0") & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; opacity: 0.9;'>
            Awaiting completion
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 2: Total Hours -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Total Hours Worked
        </div>
        <div style='font-size: 56px; font-weight: 700; line-height: 1;'>
            " & HoursText & "
        </div>
        <div style='font-size: 16px; margin-top: 10px; opacity: 0.9;'>
            Work in progress
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 3: Avg Age -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Average Pending Age
        </div>
        <div style='
            font-size: 64px; 
            font-weight: 700; 
            line-height: 1;
            color: #fbbf24;
        '>
            " & AgeText & "
        </div>
        <div style='font-size: 18px; margin-top: 10px; font-weight: 600;'>
            days since creation
        </div>
    </div>
    
    <!-- Divider -->
    <div style='width: 2px; height: 120px; background: rgba(255,255,255,0.3); margin: 0 30px;'></div>
    
    <!-- Section 4: Estimated Revenue -->
    <div style='text-align: center; flex: 1;'>
        <div style='font-size: 14px; opacity: 0.9; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 1px;'>
            Estimated Revenue
        </div>
        <div style='font-size: 56px; font-weight: 700; line-height: 1; color: #4ade80;'>
            " & EstRevenueText & "
        </div>
        <div style='font-size: 16px; margin-top: 10px; opacity: 0.9;'>
            Projected completion value
        </div>
    </div>
</div>
"
```

</details>

---

### Pending Inspection Types HTML

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Get ALL pending inspection types
VAR AllInspections = 
    ADDCOLUMNS(
        SUMMARIZE(
            Fact_PendingInspections,
            Fact_PendingInspections[JobCode]
        ),
        "@Count", CALCULATE(COUNTROWS(Fact_PendingInspections)),
        "@EstRev", [Avg Revenue by Job Code] * CALCULATE(COUNTROWS(Fact_PendingInspections))
    )

// Calculate average inspection revenue
VAR AvgRevenue = [Average Inspection Revenue]
VAR AvgRevenueText = FORMAT(AvgRevenue, "$#,##0")

// Build HTML for each inspection type - SORTED BY COUNT DESCENDING
VAR InspectionCards = 
    CONCATENATEX(
        AllInspections,
        VAR JobCode = Fact_PendingInspections[JobCode]
        VAR _Count = [@Count]
        VAR EstRev = [@EstRev]
        
        // BETTER FORMATTING: Show dollars if under $10K, otherwise show K format
        VAR EstRevText = 
            IF(
                EstRev < 10000,
                FORMAT(EstRev, "$#,##0"),  // Shows as $800, $2,500, etc.
                FORMAT(EstRev / 1000, "$#,##0.0") & "K"  // Shows as $15.3K, $125.7K, etc.
            )
        
        VAR JobCodeShort = 
            SWITCH(
                TRUE(),
                CONTAINSSTRING(JobCode, "TRACTOR"), "🚜 Tractor",
                CONTAINSSTRING(JobCode, "HARVESTREADY"), "🌾 Harvest Ready",
                CONTAINSSTRING(JobCode, "CS690"), "🌾 CS690 Combine",
                CONTAINSSTRING(JobCode, "CS770"), "🌾 CS770 Combine",
                CONTAINSSTRING(JobCode, "STRIPPER"), "🧹 Stripper",
                CONTAINSSTRING(JobCode, "COMPACT"), "🏗️ Compact",
                CONTAINSSTRING(JobCode, "SPRAYER"), "💧 Sprayer",
                CONTAINSSTRING(JobCode, "AMS"), "📡 AMS",
                "📋 " & JobCode
            )
        RETURN
        "
        <div style='
            background: white;
            padding: 12px 15px;
            border-radius: 6px;
            margin-bottom: 8px;
            box-shadow: 0 1px 4px rgba(0,0,0,0.08);
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-left: 4px solid #3A7CA5;
        '>
            <div style='flex: 2;'>
                <div style='font-size: 15px; font-weight: 600; color: #1D3C4E; margin-bottom: 2px;'>
                    " & JobCodeShort & "
                </div>
                <div style='font-size: 12px; color: #6B7280;'>
                    " & FORMAT(_Count, "#,##0") & " pending WOs
                </div>
            </div>
            <div style='flex: 1; text-align: right;'>
                <div style='font-size: 18px; font-weight: 700; color: #3A7CA5;'>
                    " & EstRevText & "
                </div>
                <div style='font-size: 10px; color: #6B7280;'>
                    Est. Revenue
                </div>
            </div>
        </div>
        ",
        "",
        [@Count],  // SORT BY COUNT
        DESC       // DESCENDING (highest first)
    )

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 15px;
    background: linear-gradient(to bottom, #f8fafc, #e2e8f0);
    border-radius: 12px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    height: 100%;
    overflow-y: auto;
'>
    <!-- Header with Title and Avg Revenue -->
    <div style='
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 15px;
        padding-bottom: 12px;
        border-bottom: 2px solid #3A7CA5;
    '>
        <div style='
            font-size: 18px; 
            font-weight: 700; 
            color: #1D3C4E;
        '>
            📊 Pending Inspections - WIP
        </div>
        <div style='text-align: right;'>
            <div style='font-size: 11px; color: #6B7280; text-transform: uppercase; letter-spacing: 0.5px;'>
                Avg Inspection Revenue
            </div>
            <div style='font-size: 20px; font-weight: 700; color: #3A7CA5;'>
                " & AvgRevenueText & "
            </div>
        </div>
    </div>
    
    <!-- All Inspection Cards -->
    " & InspectionCards & "
</div>
"
```

</details>

---

### Recommend - Header

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Get user name
VAR _User = USERPRINCIPALNAME()
VAR _Position = SEARCH("@", _User, 1)
VAR _Name = LEFT(_User, _Position - 1)
VAR _FirstLetter = UPPER(LEFT(_Name, 1))
VAR _LastName = MID(_Name, 2, LEN(_Name) - 1)
VAR _FormattedLastName = 
    UPPER(LEFT(_LastName, 1)) & LOWER(MID(_LastName, 2, LEN(_LastName)))
VAR WelcomeName = _FirstLetter & "." & _FormattedLastName

// Get current date/time info
VAR CurrentDate = TODAY()
VAR DateDisplay = FORMAT(CurrentDate, "MMM D, YYYY")
VAR CurrentHour = HOUR(NOW())
VAR TimeGreeting = 
    IF(CurrentHour < 12, "Good Morning",
    IF(CurrentHour < 17, "Good Afternoon",
    "Good Evening"))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    height: 85px;
    padding: 15px 25px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 10px;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    box-sizing: border-box;
'>
    <!-- Left side: Dashboard Title -->
    <div style='display: flex; align-items: center; gap: 15px;'>
        <!-- Home icon -->
        <div style='
            width: 40px;
            height: 40px;
            background: rgba(255,255,255,0.15);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        '>
            🏠
        </div>
        
        <!-- Title -->
        <div>
            <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
                DASHBOARD
            </div>
            <div style='font-size: 26px; font-weight: 700; line-height: 1;'>
                Parts & Service Recommendations
            </div>
        </div>
    </div>
    
    <!-- Right side: Welcome & Date -->
    <div style='text-align: right;'>
        <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px;'>
            " & TimeGreeting & ", " & WelcomeName & "
        </div>
        <div style='font-size: 16px; font-weight: 600;'>
            📅 " & DateDisplay & "
        </div>
    </div>
</div>
"
```

</details>

---

### Revenue Breakdown Cards HTML

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR InspectionRev = [Inspection $$]
VAR PartsRev = [Parts $ Total]
VAR LaborRev = [Labor With Inspection]
VAR Hours = [Hours Worked With Inspection]
VAR HoursInspection = [Hours Worked]
VAR Multiplier = DIVIDE(Hours, HoursInspection, 0)

VAR PartsPct = [% to Goal - Parts]
VAR LaborPct = [% to Goal - Labor With Inspection]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    display: flex;
    gap: 20px;
    height: 160px;
'>
    <!-- Card 1: Inspection $$ -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #1D3C4E;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                💵 Inspection Revenue
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(InspectionRev / 1000, "$#,##0") & "K
            </div>
        </div>
        <div style='
            background: #e0f2fe;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #0c4a6e;
            font-weight: 600;
            text-align: center;
        '>
            Direct inspection labor
        </div>
    </div>
    
    <!-- Card 2: Parts $ -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #10b981;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                🔧 Parts Revenue
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(PartsRev / 1000000, "$#,##0.0") & "M
            </div>
        </div>
        <div style='
            background: #d1fae5;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #065f46;
            font-weight: 600;
            text-align: center;
        '>
            " & FORMAT(PartsPct, "0%") & " to goal ↑
        </div>
    </div>
    
    <!-- Card 3: Labor With Inspection -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #3b82f6;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                💼 Total Labor
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(LaborRev / 1000000, "$#,##0.0") & "M
            </div>
        </div>
        <div style='
            background: #dbeafe;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #1e40af;
            font-weight: 600;
            text-align: center;
        '>
            " & FORMAT(LaborPct, "0%") & " to goal ↑
        </div>
    </div>
    
    <!-- Card 4: Hours Multiplier -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #f59e0b;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                ⏱️ Total Hours
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(Hours / 1000, "#,##0.0") & "K
            </div>
        </div>
        <div style='
            background: #fef3c7;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #92400e;
            font-weight: 600;
            text-align: center;
        '>
            " & FORMAT(Multiplier, "#,##0.0") & "x multiplier 🚀
        </div>
    </div>
</div>
"
```

</details>

---

### Revenue Breakdown Cards HTML V2

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR InspectionRev = [Inspection $$]
VAR PartsRev = [Parts $ Total]
VAR LaborRev = [Labor With Inspection]
VAR TotalRev = InspectionRev + PartsRev + LaborRev
VAR InspectionPct = DIVIDE(InspectionRev, TotalRev, 0)

VAR Hours = [Hours Worked With Inspection]
VAR HoursInspection = [Hours Worked]
VAR AdditionalHours = Hours - HoursInspection

VAR PartsPct = [% to Goal - Parts]
VAR LaborPct = [% to Goal - Labor With Inspection]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    display: flex;
    gap: 20px;
    height: 160px;
'>
    <!-- Card 1: Inspection $$ -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #1D3C4E;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                💵 Inspection Revenue
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(InspectionRev / 1000, "$#,##0") & "K
            </div>
        </div>
        <div style='
            background: #e0f2fe;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #0c4a6e;
            font-weight: 600;
            text-align: center;
        '>
            Only " & FORMAT(InspectionPct, "0%") & " of total • Drives upsell
        </div>
    </div>
    
    <!-- Card 2: Parts $ -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #10b981;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                🔧 Parts Revenue
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(PartsRev / 1000000, "$#,##0.0") & "M
            </div>
        </div>
        <div style='
            background: #d1fae5;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #065f46;
            font-weight: 600;
            text-align: center;
        '>
            From inspection work orders
        </div>
    </div>
    
    <!-- Card 3: Labor With Inspection -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #3b82f6;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                💼 Total Labor
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(LaborRev / 1000000, "$#,##0.0") & "M
            </div>
        </div>
        <div style='
            background: #dbeafe;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #1e40af;
            font-weight: 600;
            text-align: center;
        '>
            All work from inspections
        </div>
    </div>
    
    <!-- Card 4: Hours with Better Context -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 24px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #f59e0b;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                ⏱️ Total Hours
            </div>
            <div style='font-size: 36px; font-weight: 700; color: #111827; line-height: 1;'>
                " & FORMAT(Hours / 1000, "#,##0.0") & "K
            </div>
        </div>
        <div style='
            background: #fef3c7;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #92400e;
            font-weight: 600;
            text-align: center;
        '>
            +" & FORMAT(AdditionalHours / 1000, "#,##0.0") & "K additional hours 🚀
        </div>
    </div>
</div>
"
```

</details>

---

### Revenue Breakdown Cards HTML V3

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR InspectionRev = [Inspection $$]
VAR PartsRev = [Parts $ Total]
VAR LaborRev = [Labor With Inspection]
VAR LaborAdditional = [Labor $$]

VAR Hours = [Hours Worked With Inspection]
VAR HoursInspection = [Hours Worked]
VAR AdditionalHours = [Additional Hours Worked]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    display: flex;
    gap: 20px;
    height: 180px;
'>
    <!-- Card 1: Inspection $$ -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 20px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #1D3C4E;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 11px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px;'>
                💵 Inspection Revenue
            </div>
            <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1.1;'>
                " & FORMAT(InspectionRev, "$#,##0") & "
            </div>
        </div>
        <div style='
            background: #e0f2fe;
            padding: 8px 10px;
            border-radius: 6px;
            font-size: 11px;
            color: #0c4a6e;
            line-height: 1.4;
        '>
            Labor charged for performing the 1,421 inspection job codes
        </div>
    </div>
    
    <!-- Card 2: Parts $ -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 20px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #10b981;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 11px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px;'>
                🔧 Parts Revenue
            </div>
            <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1.1;'>
                " & FORMAT(PartsRev, "$#,##0") & "
            </div>
        </div>
        <div style='
            background: #d1fae5;
            padding: 8px 10px;
            border-radius: 6px;
            font-size: 11px;
            color: #065f46;
            line-height: 1.4;
        '>
            Parts sold on work orders that included an inspection job code
        </div>
    </div>
    
    <!-- Card 3: Labor With Inspection -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 20px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #3b82f6;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 11px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px;'>
                💼 Total Labor Revenue
            </div>
            <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1.1;'>
                " & FORMAT(LaborRev, "$#,##0") & "
            </div>
        </div>
        <div style='
            background: #dbeafe;
            padding: 8px 10px;
            border-radius: 6px;
            font-size: 11px;
            color: #1e40af;
            line-height: 1.4;
        '>
            All labor on WOs with inspections (" & FORMAT(InspectionRev, "$#,##0") & " insp + " & FORMAT(LaborAdditional, "$#,##0") & " other)
        </div>
    </div>
    
    <!-- Card 4: Hours -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 20px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #f59e0b;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 11px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px;'>
                ⏱️ Total Hours Worked
            </div>
            <div style='font-size: 28px; font-weight: 700; color: #111827; line-height: 1.1;'>
                " & FORMAT(Hours, "#,##0") & "
            </div>
        </div>
        <div style='
            background: #fef3c7;
            padding: 8px 10px;
            border-radius: 6px;
            font-size: 11px;
            color: #92400e;
            line-height: 1.4;
        '>
            All hours on WOs with inspections (" & FORMAT(HoursInspection, "#,##0") & " insp + " & FORMAT(AdditionalHours, "#,##0") & " other)
        </div>
    </div>
</div>
"
```

</details>

---

### Revenue Breakdown Cards HTML V4

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR InspectionRev = [Inspection $$]
VAR PartsRev = [Parts $ Total]
VAR LaborRev = [Labor With Inspection]
VAR LaborAdditional = [Labor $$]

VAR Hours = [Hours Worked With Inspection]
VAR HoursInspection = [Hours Worked]
VAR AdditionalHours = [Additional Hours Worked]

VAR PartsPct = [% to Goal - Parts]
VAR LaborPct = [% to Goal - Labor With Inspection]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    display: flex;
    gap: 20px;
    height: 175px;
'>
    <!-- Card 1: Inspection $$ -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 22px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #1D3C4E;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                💵 Inspection Revenue
            </div>
            <div style='font-size: 34px; font-weight: 700; color: #111827; line-height: 1.1; margin-bottom: 4px;'>
                " & FORMAT(InspectionRev, "$#,##0") & "
            </div>
        </div>
        <div style='
            background: #e0f2fe;
            padding: 10px 12px;
            border-radius: 6px;
            font-size: 12px;
            color: #0c4a6e;
            line-height: 1.4;
        '>
            Labor charged for performing the 1,421 inspection job codes
        </div>
    </div>
    
    <!-- Card 2: Parts $ -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 22px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #10b981;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                🔧 Parts Revenue
            </div>
            <div style='display: flex; align-items: center; gap: 10px; margin-bottom: 4px;'>
                <div style='font-size: 34px; font-weight: 700; color: #111827; line-height: 1.1;'>
                    " & FORMAT(PartsRev, "$#,##0") & "
                </div>
                <div style='
                    background: #10b981;
                    color: white;
                    padding: 4px 10px;
                    border-radius: 20px;
                    font-size: 13px;
                    font-weight: 700;
                    white-space: nowrap;
                '>
                    " & FORMAT(PartsPct, "0%") & " ↑
                </div>
            </div>
        </div>
        <div style='
            background: #d1fae5;
            padding: 10px 12px;
            border-radius: 6px;
            font-size: 12px;
            color: #065f46;
            line-height: 1.4;
        '>
            Parts sold on work orders that included an inspection job code
        </div>
    </div>
    
    <!-- Card 3: Labor With Inspection -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 22px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #3b82f6;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                💼 Total Labor Revenue
            </div>
            <div style='display: flex; align-items: center; gap: 10px; margin-bottom: 4px;'>
                <div style='font-size: 34px; font-weight: 700; color: #111827; line-height: 1.1;'>
                    " & FORMAT(LaborRev, "$#,##0") & "
                </div>
                <div style='
                    background: #3b82f6;
                    color: white;
                    padding: 4px 10px;
                    border-radius: 20px;
                    font-size: 13px;
                    font-weight: 700;
                    white-space: nowrap;
                '>
                    " & FORMAT(LaborPct, "0%") & " ↑
                </div>
            </div>
        </div>
        <div style='
            background: #dbeafe;
            padding: 10px 12px;
            border-radius: 6px;
            font-size: 12px;
            color: #1e40af;
            line-height: 1.4;
        '>
            All labor on WOs with inspections (" & FORMAT(InspectionRev, "$#,##0") & " insp + " & FORMAT(LaborAdditional, "$#,##0") & " other)
        </div>
    </div>
    
    <!-- Card 4: Hours -->
    <div style='
        flex: 1;
        background: white;
        border-radius: 12px;
        padding: 22px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
        border-top: 4px solid #f59e0b;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    '>
        <div>
            <div style='font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;'>
                ⏱️ Total Hours Worked
            </div>
            <div style='font-size: 34px; font-weight: 700; color: #111827; line-height: 1.1; margin-bottom: 4px;'>
                " & FORMAT(Hours, "#,##0") & "
            </div>
        </div>
        <div style='
            background: #fef3c7;
            padding: 10px 12px;
            border-radius: 6px;
            font-size: 12px;
            color: #92400e;
            line-height: 1.4;
        '>
            All hours on WOs with inspections (" & FORMAT(HoursInspection, "#,##0") & " insp + " & FORMAT(AdditionalHours, "#,##0") & " other)
        </div>
    </div>
</div>
"
```

</details>

---

### Top 10 Parts Needed

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Get current selected JobCode
VAR CurrentInspectionCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR CompletedInsp = [Completed Inspections - Selected JobCode]

// Get top 10 parts that are relevant for this JobCode
VAR TopParts = 
    TOPN(
        10,
        ADDCOLUMNS(
            FILTER(
                dim_Parts,
                [Show Part for JobCode] = 1
            ),
            "@PartNumber", dim_Parts[PartNumber],
            "@Description", dim_Parts[Description],
            "@TimesSold", [Part Sold Count - For JobCode],
            "@Frequency", [Part Frequency % - For JobCode],
            "@AvgQty", [Avg Part Quantity - For JobCode],
            "@EstQty", [Est Quantity Needed - For Pending],
            "@UnitPrice", dim_Parts[SellPrice1],
            "@TotalValue", [Est Quantity Needed - For Pending] * dim_Parts[SellPrice1]
        ),
        [@TimesSold],
        DESC
    )

// Build parts cards
VAR PartsRows = 
    CONCATENATEX(
        TopParts,
        VAR PartNum = [@PartNumber]
        VAR PartDesc = [@Description]
        VAR Times = [@TimesSold]
        VAR Freq = [@Frequency]
        VAR AvgQty = [@AvgQty]
        VAR EstQty = [@EstQty]
        VAR UnitPrice = [@UnitPrice]
        VAR TotalValue = [@TotalValue]
        
        // Determine if this is critical (high frequency)
        VAR BorderColor = IF(Freq >= 0.5, "#ef4444", IF(Freq >= 0.3, "#f59e0b", "#10b981"))
        VAR FreqLabel = 
            IF(Freq >= 0.5, "🔴 Critical", 
            IF(Freq >= 0.3, "🟡 Common", 
            "🟢 Occasional"))
        
        // Format values
        VAR TotalValueText = 
            IF(
                TotalValue >= 10000,
                FORMAT(TotalValue / 1000, "$#,##0.0") & "K",
                FORMAT(TotalValue, "$#,##0")
            )
        
        VAR UnitPriceText = FORMAT(UnitPrice, "$#,##0.00")
        
        // Truncate description if too long
        VAR ShortDesc = 
            IF(
                LEN(PartDesc) > 35,
                LEFT(PartDesc, 32) & "...",
                PartDesc
            )
        
        RETURN
        "
        <div style='
            padding: 14px 18px;
            margin-bottom: 10px;
            border-left: 4px solid " & BorderColor & ";
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.08);
        '>
            <!-- Header Row -->
            <div style='display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;'>
                <div style='font-weight: 700; font-size: 16px; color: #1D3C4E;'>
                    " & PartNum & "
                </div>
                <div style='font-weight: 700; font-size: 16px; color: #10b981;'>
                    " & TotalValueText & "
                </div>
            </div>
            
            <!-- Description -->
            <div style='font-size: 12px; color: #6B7280; margin-bottom: 8px;'>
                " & ShortDesc & " • " & UnitPriceText & " ea • Need: " & FORMAT(EstQty, "#,##0.0") & " units
            </div>
            
            <!-- Frequency Info -->
            <div style='display: flex; align-items: center; gap: 8px; margin-bottom: 8px;'>
                <div style='font-size: 13px; color: #6B7280; min-width: 100px;'>
                    " & FORMAT(Times, "#,##0") & " of " & FORMAT(CompletedInsp, "#,##0") & "
                </div>
                <div style='flex: 1; height: 10px; background: #e5e7eb; border-radius: 5px; overflow: hidden;'>
                    <div style='width: " & FORMAT(Freq, "0%") & "; height: 100%; background: linear-gradient(to right, " & BorderColor & ", " & BorderColor & "dd);'></div>
                </div>
                <div style='font-size: 14px; font-weight: 700; color: #1D3C4E; min-width: 45px; text-align: right;'>
                    " & FORMAT(Freq, "0%") & "
                </div>
            </div>
            
            <!-- Frequency Label -->
            <div style='font-size: 12px; font-weight: 600;'>
                " & FreqLabel & "
            </div>
        </div>
        ",
        "",
        [@TimesSold],
        DESC
    )

RETURN
"
<div style='font-family: Segoe UI, Arial, sans-serif; padding: 20px; background: #f8fafc; border-radius: 12px; height: 100%; overflow-y: auto;'>
    <!-- Header -->
    <div style='
        font-size: 20px; 
        font-weight: 700; 
        color: #1D3C4E; 
        margin-bottom: 18px; 
        padding-bottom: 12px; 
        border-bottom: 3px solid #3A7CA5;
        display: flex;
        align-items: center;
        gap: 10px;
    '>
        <span style='font-size: 24px;'>📦</span>
        <span>Top 10 Parts Recommended</span>
    </div>
    
    <!-- Parts Cards -->
    " & PartsRows & "
</div>
"
```

</details>

---

### Top 10 Services Needed

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

// Filter to current inspection JobCode
VAR CurrentInspectionCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])

// Get top 10 services for this inspection
VAR TopServices = 
    TOPN(
        10,
        FILTER(
            ServiceRecommendations,
            ServiceRecommendations[InspectionJobCode] = CurrentInspectionCode
        ),
        ServiceRecommendations[TimesAdded],
        DESC
    )

// Build service cards
VAR ServiceRows = 
    CONCATENATEX(
        TopServices,
        VAR JobCode = ServiceRecommendations[JobCode]
        VAR JobType = ServiceRecommendations[JobType]
        VAR Times = ServiceRecommendations[TimesAdded]
        VAR TotalLabor = ServiceRecommendations[TotalLabor]
        VAR CompletedInsp = ServiceRecommendations[CompletedInspections]
        
        // Calculate frequency %
        VAR Freq = DIVIDE(Times, CompletedInsp, 0)
        
        // Calculate avg labor per service
        VAR AvgLabor = DIVIDE(TotalLabor, Times, 0)
        
        // Determine if this is critical (high frequency)
        VAR BorderColor = IF(Freq >= 0.5, "#ef4444", IF(Freq >= 0.3, "#f59e0b", "#10b981"))
        VAR FreqLabel = 
            IF(Freq >= 0.5, "🔴 Critical", 
            IF(Freq >= 0.3, "🟡 Common", 
            "🟢 Occasional"))
        
        // Format labor amount
        VAR LaborText = 
            IF(
                TotalLabor >= 10000,
                FORMAT(TotalLabor / 1000, "$#,##0.0") & "K",
                FORMAT(TotalLabor, "$#,##0")
            )
        
        VAR AvgLaborText = FORMAT(AvgLabor, "$#,##0")
        
        RETURN
        "
        <div style='
            padding: 14px 18px;
            margin-bottom: 10px;
            border-left: 4px solid " & BorderColor & ";
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.08);
        '>
            <!-- Header Row -->
            <div style='display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;'>
                <div style='font-weight: 700; font-size: 16px; color: #1D3C4E;'>
                    " & JobCode & "
                </div>
                <div style='font-weight: 700; font-size: 16px; color: #10b981;'>
                    " & LaborText & "
                </div>
            </div>
            
            <!-- Job Type -->
            <div style='font-size: 12px; color: #6B7280; margin-bottom: 8px;'>
                " & JobType & " • Avg: " & AvgLaborText & " per service
            </div>
            
            <!-- Frequency Info -->
            <div style='display: flex; align-items: center; gap: 8px; margin-bottom: 8px;'>
                <div style='font-size: 13px; color: #6B7280; min-width: 100px;'>
                    " & FORMAT(Times, "#,##0") & " of " & FORMAT(CompletedInsp, "#,##0") & "
                </div>
                <div style='flex: 1; height: 10px; background: #e5e7eb; border-radius: 5px; overflow: hidden;'>
                    <div style='width: " & FORMAT(Freq, "0%") & "; height: 100%; background: linear-gradient(to right, " & BorderColor & ", " & BorderColor & "dd);'></div>
                </div>
                <div style='font-size: 14px; font-weight: 700; color: #1D3C4E; min-width: 45px; text-align: right;'>
                    " & FORMAT(Freq, "0%") & "
                </div>
            </div>
            
            <!-- Frequency Label -->
            <div style='font-size: 12px; font-weight: 600;'>
                " & FreqLabel & "
            </div>
        </div>
        ",
        "",
        ServiceRecommendations[TimesAdded],
        DESC
    )

RETURN
"
<div style='font-family: Segoe UI, Arial, sans-serif; padding: 20px; background: #f8fafc; border-radius: 12px; height: 100%; overflow-y: auto;'>
    <!-- Header -->
    <div style='
        font-size: 20px; 
        font-weight: 700; 
        color: #1D3C4E; 
        margin-bottom: 18px; 
        padding-bottom: 12px; 
        border-bottom: 3px solid #3A7CA5;
        display: flex;
        align-items: center;
        gap: 10px;
    '>
        <span style='font-size: 24px;'>📋</span>
        <span>Top 10 Services Recommended</span>
    </div>
    
    <!-- Service Cards -->
    " & ServiceRows & "
</div>
"
```

</details>

---

### Top 5 Parts Compact

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR CurrentInspectionCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR CompletedInsp = [Completed Inspections - Selected JobCode]

// Get all relevant parts with metrics
VAR AllParts = 
    ADDCOLUMNS(
        FILTER(dim_Parts, [Show Part for JobCode] = 1),
        "@PartNumber", dim_Parts[PartNumber],
        "@Description", dim_Parts[Description],
        "@TimesSold", [Part Sold Count - For JobCode],
        "@Frequency", [Part Frequency % - For JobCode],
        "@EstQty", [Est Quantity Needed - For Pending],
        "@UnitPrice", dim_Parts[SellPrice1],
        "@TotalValue", [Est Quantity Needed - For Pending] * dim_Parts[SellPrice1]
    )

// Create composite sort: TimesSold * 1,000,000 + TotalValue
// This ensures TimesSold is primary sort, TotalValue breaks ties
VAR PartsWithCompositeSort = 
    ADDCOLUMNS(
        AllParts,
        "@CompositeSort", ([@TimesSold] * 1000000) + [@TotalValue]
    )

// Get top 5 using composite sort
VAR Top5Parts = 
    TOPN(
        5,
        PartsWithCompositeSort,
        [@CompositeSort],
        DESC
    )

VAR PartsRows = 
    CONCATENATEX(
        Top5Parts,
        VAR PartNum = [@PartNumber]
        VAR PartDesc = [@Description]
        VAR Times = [@TimesSold]
        VAR Freq = [@Frequency]
        VAR EstQty = [@EstQty]
        VAR TotalValue = [@TotalValue]
        
        VAR BorderColor = IF(Freq >= 0.5, "#ef4444", IF(Freq >= 0.3, "#f59e0b", "#10b981"))
        VAR Icon = IF(Freq >= 0.5, "🔴", IF(Freq >= 0.3, "🟡", "🟢"))
        
        VAR ValueText = 
            IF(TotalValue >= 10000, FORMAT(TotalValue / 1000, "$#,##0.0") & "K", FORMAT(TotalValue, "$#,##0"))
        
        VAR ShortDesc = IF(LEN(PartDesc) > 25, LEFT(PartDesc, 22) & "...", PartDesc)
        
        RETURN
        "
        <div style='
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 10px 14px;
            margin-bottom: 6px;
            background: white;
            border-left: 3px solid " & BorderColor & ";
            border-radius: 6px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.06);
        '>
            <div style='font-size: 18px; min-width: 24px;'>" & Icon & "</div>
            <div style='font-weight: 700; font-size: 15px; color: #1D3C4E; min-width: 100px;'>
                " & PartNum & "
            </div>
            <div style='font-size: 12px; color: #6B7280; min-width: 150px;'>
                " & ShortDesc & "
            </div>
            <div style='flex: 1; display: flex; align-items: center; gap: 8px;'>
                <div style='font-size: 12px; color: #6B7280; min-width: 70px;'>
                    " & FORMAT(Times, "#,##0") & " / " & FORMAT(CompletedInsp, "#,##0") & "
                </div>
                <div style='flex: 1; height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden; max-width: 100px;'>
                    <div style='width: " & FORMAT(Freq, "0%") & "; height: 100%; background: " & BorderColor & ";'></div>
                </div>
                <div style='font-size: 13px; font-weight: 700; color: #1D3C4E; min-width: 40px;'>
                    " & FORMAT(Freq, "0%") & "
                </div>
            </div>
            <div style='font-weight: 700; font-size: 15px; color: #10b981; text-align: right; min-width: 70px;'>
                " & ValueText & "
            </div>
        </div>
        ",
        "",
        [@CompositeSort],
        DESC
    )

RETURN
"
<div style='font-family: Segoe UI, Arial, sans-serif; padding: 16px; background: #f8fafc; border-radius: 10px; height: 100%;'>
    <div style='font-size: 18px; font-weight: 700; color: #1D3C4E; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 2px solid #3A7CA5;'>
        📦 Top 5 Parts
    </div>
    " & PartsRows & "
    <div style='margin-top: 10px; font-size: 11px; color: #6B7280; text-align: center;'>
        See full details table below ↓
    </div>
</div>
"
```

</details>

---

### Top 5 Services Compact

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR CurrentInspectionCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])

// Get unique job codes for this inspection
VAR AllJobCodes = 
    CALCULATETABLE(
        VALUES(ServiceRecommendations[JobCode]),
        ServiceRecommendations[InspectionJobCode] = CurrentInspectionCode
    )

// Calculate aggregated metrics for each job code (same as table)
VAR ServicesWithMetrics = 
    ADDCOLUMNS(
        AllJobCodes,
        "@JobCode", ServiceRecommendations[JobCode],
        "@TimesAdded", 
            CALCULATE(
                SUM(ServiceRecommendations[TimesAdded]),
                ServiceRecommendations[InspectionJobCode] = CurrentInspectionCode
            ),
        "@CompletedInsp", 
            CALCULATE(
                MAX(ServiceRecommendations[CompletedInspections]),
                ServiceRecommendations[InspectionJobCode] = CurrentInspectionCode
            ),
        "@TotalLabor", 
            CALCULATE(
                SUM(ServiceRecommendations[TotalLabor]),
                ServiceRecommendations[InspectionJobCode] = CurrentInspectionCode
            )
    )

// Add calculated metrics (matching your measures exactly)
VAR ServicesWithCalcs = 
    ADDCOLUMNS(
        ServicesWithMetrics,
        "@Frequency", DIVIDE([@TimesAdded], [@CompletedInsp], 0),
        "@AvgLabor", DIVIDE([@TotalLabor], [@TimesAdded], 0)
    )

// Add revenue calculation
VAR ServicesWithRevenue = 
    ADDCOLUMNS(
        ServicesWithCalcs,
        "@EstRevenue", 
            VAR PendingCount = [Total Pending Inspections]
            VAR EstOpp = PendingCount * [@Frequency]
            RETURN EstOpp * [@AvgLabor]
    )

// Create composite sort: TimesAdded * 1,000,000 + EstRevenue
// This ensures TimesAdded is primary sort, EstRevenue breaks ties
VAR ServicesWithCompositeSort = 
    ADDCOLUMNS(
        ServicesWithRevenue,
        "@CompositeSort", ([@TimesAdded] * 1000000) + [@EstRevenue]
    )

// Get top 5 using composite sort
VAR Top5Services = 
    TOPN(5, ServicesWithCompositeSort, [@CompositeSort], DESC)

VAR ServiceRows = 
    CONCATENATEX(
        Top5Services,
        VAR JobCode = [@JobCode]
        VAR Times = [@TimesAdded]
        VAR CompletedInsp = [@CompletedInsp]
        VAR Freq = [@Frequency]
        VAR EstRevenue = [@EstRevenue]
        
        VAR BorderColor = IF(Freq >= 0.5, "#ef4444", IF(Freq >= 0.3, "#f59e0b", "#10b981"))
        VAR Icon = IF(Freq >= 0.5, "🔴", IF(Freq >= 0.3, "🟡", "🟢"))
        
        VAR RevenueText = 
            IF(EstRevenue >= 10000, FORMAT(EstRevenue / 1000, "$#,##0.0") & "K", FORMAT(EstRevenue, "$#,##0"))
        
        RETURN
        "
        <div style='
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 10px 14px;
            margin-bottom: 6px;
            background: white;
            border-left: 3px solid " & BorderColor & ";
            border-radius: 6px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.06);
        '>
            <div style='font-size: 18px; min-width: 24px;'>" & Icon & "</div>
            <div style='font-weight: 700; font-size: 15px; color: #1D3C4E; min-width: 140px;'>
                " & JobCode & "
            </div>
            <div style='flex: 1; display: flex; align-items: center; gap: 8px;'>
                <div style='font-size: 12px; color: #6B7280; min-width: 70px;'>
                    " & FORMAT(Times, "#,##0") & " / " & FORMAT(CompletedInsp, "#,##0") & "
                </div>
                <div style='flex: 1; height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden; max-width: 120px;'>
                    <div style='width: " & FORMAT(Freq, "0%") & "; height: 100%; background: " & BorderColor & ";'></div>
                </div>
                <div style='font-size: 13px; font-weight: 700; color: #1D3C4E; min-width: 40px;'>
                    " & FORMAT(Freq, "0%") & "
                </div>
            </div>
            <div style='font-weight: 700; font-size: 15px; color: #10b981; text-align: right; min-width: 70px;'>
                " & RevenueText & "
            </div>
        </div>
        ",
        "",
        [@CompositeSort],
        DESC
    )

RETURN
"
<div style='font-family: Segoe UI, Arial, sans-serif; padding: 16px; background: #f8fafc; border-radius: 10px; height: 100%;'>
    <div style='font-size: 18px; font-weight: 700; color: #1D3C4E; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 2px solid #3A7CA5;'>
        📋 Top 5 Services
    </div>
    " & ServiceRows & "
    <div style='margin-top: 10px; font-size: 11px; color: #6B7280; text-align: center;'>
        See full details table below ↓
    </div>
</div>
"
```

</details>

---

### WO Details - Context Header

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR WONumber = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
VAR BranchName = SELECTEDVALUE(Fact_LaborJobSummary[BranchName])
VAR WODate = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderCreationDate])
VAR InvoiceNum = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])

// Get customer name
VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
VAR CustomerNum = 
    CALCULATE(
        SELECTEDVALUE(Fact_WorkOrderParts[CustomerNumber]),
        Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice
    )
VAR CustomerName = 
    IF(
        NOT(ISBLANK(CustomerNum)),
        LOOKUPVALUE(
            dim_CustomerList[PrimaryName],
            dim_CustomerList[CustomerNumber], CustomerNum
        ),
        "Customer Not Found"
    )

VAR DateDisplay = FORMAT(WODate, "MMM D, YYYY")

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 15px 25px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 10px;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    min-height: 70px;
'>
    <!-- Left side: Back arrow + Work Order Number + Details -->
    <div style='display: flex; align-items: center; gap: 15px; flex: 1;'>
        <!-- Back arrow -->
        <div style='
            width: 40px;
            height: 40px;
            background: rgba(255,255,255,0.15);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        '>
            ←
        </div>
        
        <!-- Work Order Number and Label -->
        <div>
            <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
                WORK ORDER DETAILS
            </div>
            <div style='font-size: 22px; font-weight: 700; display: flex; align-items: center; gap: 10px;'>
                <span style='color: #10b981;'>🔧</span>
                <span>#" & WONumber & "</span>
            </div>
        </div>
        
        <!-- Date, Invoice, Customer - Horizontal -->
        <div style='
            display: flex;
            gap: 25px;
            margin-left: 30px;
            padding-left: 30px;
            border-left: 1px solid rgba(255,255,255,0.2);
        '>
            <!-- Date -->
            <div>
                <div style='font-size: 10px; opacity: 0.75; margin-bottom: 3px;'>DATE</div>
                <div style='font-size: 13px; font-weight: 600;'>📅 " & DateDisplay & "</div>
            </div>
            
            <!-- Invoice -->
            <div>
                <div style='font-size: 10px; opacity: 0.75; margin-bottom: 3px;'>INVOICE</div>
                <div style='font-size: 13px; font-weight: 600;'>📄 " & InvoiceNum & "</div>
            </div>
            
            <!-- Customer -->
            <div>
                <div style='font-size: 10px; opacity: 0.75; margin-bottom: 3px;'>CUSTOMER</div>
                <div style='font-size: 13px; font-weight: 600;'>👤 " & CustomerName & "</div>
            </div>
        </div>
    </div>
    
    <!-- Right side: Branch -->
    <div style='text-align: right; margin-left: 20px;'>
        <div style='font-size: 11px; opacity: 0.75; margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.8px;'>
            BRANCH
        </div>
        <div style='font-size: 18px; font-weight: 600;'>
            " & BranchName & "
        </div>
    </div>
</div>
"
```

</details>

---

### WO Details - Summary Card

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR LaborTotal = [WO Total Labor]
VAR PartsTotal = [WO Net Parts]
VAR GrandTotal = [WO Grand Total]

// Job Codes stats
VAR JobCodeCount = 
    CALCULATE(
        DISTINCTCOUNT(Fact_LaborJobSummary[JobCode]),
        Fact_LaborJobSummary[WorkOrderNumber] = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
    )

VAR TotalHours = 
    CALCULATE(
        SUM(Fact_LaborJobSummary[ActualHoursWorked]),
        Fact_LaborJobSummary[WorkOrderNumber] = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
    )

// Top job code - FIXED
VAR TopJobCodeTable = 
    TOPN(
        1,
        ADDCOLUMNS(
            VALUES(Fact_LaborJobSummary[JobCode]),
            "@Hours", 
                CALCULATE(
                    SUM(Fact_LaborJobSummary[ActualHoursWorked]),
                    Fact_LaborJobSummary[WorkOrderNumber] = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
                )
        ),
        [@Hours],
        DESC
    )

VAR TopJobCodeName = MAXX(TopJobCodeTable, Fact_LaborJobSummary[JobCode])
VAR TopJobHours = MAXX(TopJobCodeTable, [@Hours])

// Parts stats
VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])

VAR TotalParts = 
    CALCULATE(
        SUM(Fact_WorkOrderParts[Quantity]),
        Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice,
        Fact_WorkOrderParts[Franchise] <> "ZP",
        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
    )

VAR UniquePartNumbers = 
    CALCULATE(
        DISTINCTCOUNT(Fact_WorkOrderParts[PartNumber]),
        Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice,
        Fact_WorkOrderParts[Franchise] <> "ZP",
        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
    )

// Most expensive part - FIXED
VAR MostExpensivePartTable = 
    TOPN(
        1,
        ADDCOLUMNS(
            CALCULATETABLE(
                VALUES(Fact_WorkOrderParts[PartNumber]),
                Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice,
                Fact_WorkOrderParts[Franchise] <> "ZP",
                NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
            ),
            "@Value", 
                CALCULATE(
                    SUM(Fact_WorkOrderParts[SaleValue]),
                    Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice
                )
        ),
        [@Value],
        DESC
    )

VAR MostExpensivePartNum = MAXX(MostExpensivePartTable, Fact_WorkOrderParts[PartNumber])
VAR MostExpensivePartValue = MAXX(MostExpensivePartTable, [@Value])

// Calculations
VAR LaborPct = DIVIDE(LaborTotal, GrandTotal, 0)
VAR PartsPct = DIVIDE(PartsTotal, GrandTotal, 0)
VAR AvgHourlyRate = DIVIDE(LaborTotal, TotalHours, 0)
VAR PartsPerHour = DIVIDE(TotalParts, TotalHours, 0)

// Determine work type
VAR WorkType = 
    IF(LaborPct > 0.6, "Labor Heavy",
    IF(PartsPct > 0.6, "Parts Heavy",
    "Balanced"))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    width: 308px;
    height: 634px;
    background: white;
    border-radius: 10px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    overflow: hidden;
    display: flex;
    flex-direction: column;
'>
    <!-- Header -->
    <div style='
        background: linear-gradient(135deg, #1D3C4E 0%, #3A7CA5 100%);
        color: white;
        padding: 20px;
    '>
        <div style='font-size: 13px; opacity: 0.9; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.8px;'>
            Work Order Summary
        </div>
        <div style='font-size: 24px; font-weight: 700;'>
            Overview
        </div>
    </div>
    
    <!-- Content Area -->
    <div style='padding: 20px; flex: 1; display: flex; flex-direction: column; gap: 20px;'>
        
        <!-- Quick Stats Section -->
        <div>
            <div style='font-size: 11px; color: #6B7280; font-weight: 600; margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.5px;'>
                📊 Quick Stats
            </div>
            <div style='background: #F9FAFB; border-radius: 8px; padding: 15px;'>
                <div style='display: flex; justify-content: space-between; margin-bottom: 8px;'>
                    <span style='color: #6B7280; font-size: 13px;'>Job Codes</span>
                    <span style='font-weight: 600; font-size: 14px;'>" & FORMAT(JobCodeCount, "#,##0") & "</span>
                </div>
                <div style='display: flex; justify-content: space-between; margin-bottom: 8px;'>
                    <span style='color: #6B7280; font-size: 13px;'>Total Hours</span>
                    <span style='font-weight: 600; font-size: 14px;'>" & FORMAT(TotalHours, "#,##0.0") & "</span>
                </div>
                <div style='display: flex; justify-content: space-between; margin-bottom: 8px;'>
                    <span style='color: #6B7280; font-size: 13px;'>Parts Used</span>
                    <span style='font-weight: 600; font-size: 14px;'>" & FORMAT(TotalParts, "#,##0") & "</span>
                </div>
                <div style='display: flex; justify-content: space-between;'>
                    <span style='color: #6B7280; font-size: 13px;'>Unique Items</span>
                    <span style='font-weight: 600; font-size: 14px;'>" & FORMAT(UniquePartNumbers, "#,##0") & "</span>
                </div>
            </div>
        </div>
        
        <!-- Work Type Section -->
        <div>
            <div style='font-size: 11px; color: #6B7280; font-weight: 600; margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.5px;'>
                🔧 Work Type
            </div>
            <div style='
                background: " & IF(WorkType = "Labor Heavy", "#EFF6FF", IF(WorkType = "Parts Heavy", "#FEF3C7", "#F0FDF4")) & ";
                border-left: 4px solid " & IF(WorkType = "Labor Heavy", "#3A7CA5", IF(WorkType = "Parts Heavy", "#f59e0b", "#10b981")) & ";
                border-radius: 6px;
                padding: 12px 15px;
            '>
                <div style='font-size: 16px; font-weight: 700; color: #1D3C4E; margin-bottom: 6px;'>
                    " & WorkType & "
                </div>
                <div style='font-size: 12px; color: #6B7280;'>
                    " & FORMAT(LaborPct, "0%") & " Labor • " & FORMAT(PartsPct, "0%") & " Parts
                </div>
            </div>
        </div>
        
        <!-- Top Items Section -->
        <div>
            <div style='font-size: 11px; color: #6B7280; font-weight: 600; margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.5px;'>
                ⭐ Top Items
            </div>
            <div style='background: #F9FAFB; border-radius: 8px; padding: 15px;'>
                <div style='margin-bottom: 12px; padding-bottom: 12px; border-bottom: 1px solid #E5E7EB;'>
                    <div style='color: #3A7CA5; font-size: 11px; margin-bottom: 4px; font-weight: 600;'>Most Hours</div>
                    <div style='font-weight: 600; font-size: 13px; color: #1D3C4E; margin-bottom: 2px;'>" & TopJobCodeName & "</div>
                    <div style='font-size: 12px; color: #6B7280;'>" & FORMAT(TopJobHours, "#,##0.0") & " hours</div>
                </div>
                <div>
                    <div style='color: #f59e0b; font-size: 11px; margin-bottom: 4px; font-weight: 600;'>Most Expensive Part</div>
                    <div style='font-weight: 600; font-size: 13px; color: #1D3C4E; margin-bottom: 2px;'>" & MostExpensivePartNum & "</div>
                    <div style='font-size: 12px; color: #6B7280;'>" & FORMAT(MostExpensivePartValue, "$#,##0") & "</div>
                </div>
            </div>
        </div>
        
        <!-- Efficiency Metrics Section -->
        <div>
            <div style='font-size: 11px; color: #6B7280; font-weight: 600; margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.5px;'>
                📈 Efficiency
            </div>
            <div style='background: #F9FAFB; border-radius: 8px; padding: 15px;'>
                <div style='display: flex; justify-content: space-between; margin-bottom: 8px;'>
                    <span style='color: #6B7280; font-size: 13px;'>Avg Hourly Rate</span>
                    <span style='font-weight: 600; font-size: 14px; color: #3A7CA5;'>" & FORMAT(AvgHourlyRate, "$#,##0") & "/hr</span>
                </div>
                <div style='display: flex; justify-content: space-between;'>
                    <span style='color: #6B7280; font-size: 13px;'>Parts per Hour</span>
                    <span style='font-weight: 600; font-size: 14px; color: #f59e0b;'>" & FORMAT(PartsPerHour, "#,##0.0") & "</span>
                </div>
            </div>
        </div>
        
        <!-- Total Revenue Badge -->
        <div style='
            background: linear-gradient(135deg, #10b981 0%, #059669 100%);
            color: white;
            border-radius: 8px;
            padding: 15px;
            text-align: center;
            margin-top: auto;
        '>
            <div style='font-size: 11px; opacity: 0.9; margin-bottom: 4px;'>TOTAL REVENUE</div>
            <div style='font-size: 28px; font-weight: 700;'>" & FORMAT(GrandTotal, "$#,##0") & "</div>
        </div>
        
    </div>
</div>
"
```

</details>

---

### WO Details - Summary Cards

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR LaborTotal = [WO Total Labor]
VAR GrossParts = [WO Gross Parts]
VAR PartsDiscount = [WO Parts Discount]
VAR NetParts = [WO Net Parts]
VAR GrandTotal = [WO Grand Total]

// Get total hours worked
VAR TotalHours = 
    CALCULATE(
        SUM(Fact_LaborJobSummary[ActualHoursWorked]),
        Fact_LaborJobSummary[WorkOrderNumber] = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
    )

// Format values
VAR LaborText = FORMAT(LaborTotal, "$#,##0")
VAR GrossPartsText = FORMAT(GrossParts, "$#,##0")
VAR DiscountText = FORMAT(PartsDiscount, "$#,##0")
VAR NetPartsText = FORMAT(NetParts, "$#,##0")
VAR GrandTotalText = FORMAT(GrandTotal, "$#,##0")

// Calculate percentages for context
VAR LaborPct = DIVIDE(LaborTotal, GrandTotal, 0)
VAR PartsPct = DIVIDE(NetParts, GrandTotal, 0)

// Calculate labor rate per hour
VAR LaborRate = DIVIDE(LaborTotal, TotalHours, 0)
VAR LaborRateText = FORMAT(LaborRate, "$#,##0")

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    display: flex;
    gap: 15px;
    padding: 0;
'>
    <!-- Card 1: Labor Total with Hours -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #3A7CA5;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Labor Total
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #3A7CA5;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & LaborText & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
            " & FORMAT(TotalHours, "#,##0.0") & " hours • " & LaborRateText & "/hr
        </div>
    </div>

    <!-- Card 2: Gross Parts -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #f59e0b;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Gross Parts
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #f59e0b;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & GrossPartsText & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
            Before discount
        </div>
    </div>

    <!-- Card 3: Parts Discount -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #ef4444;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Parts Discount
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #ef4444;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & DiscountText & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
        </div>
    </div>

    <!-- Card 4: Net Parts -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #f59e0b;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Net Parts
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #f59e0b;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & NetPartsText & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
            " & FORMAT(PartsPct, "0%") & " of total
        </div>
    </div>

    <!-- Card 5: Grand Total -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #10b981;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Grand Total
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #10b981;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & GrandTotalText & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
            Work order total
        </div>
    </div>
</div>
"
```

</details>

---

### WO List - Completion Trend Card

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR MinDate = MIN(Fact_LaborJobSummary[WorkOrderCreationDate])
VAR MaxDate = MAX(Fact_LaborJobSummary[WorkOrderCreationDate])
VAR TotalMonths = DATEDIFF(MinDate, MaxDate, MONTH) + 1
VAR AvgPerMonth = DIVIDE([WO List - Total Orders], TotalMonths, 0)

// Get month-by-month counts for sparkline effect
VAR MonthlyData = 
    ADDCOLUMNS(
        CALENDAR(MinDate, MaxDate),
        "@Month", [Date],
        "@Count", 
            CALCULATE(
                DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderCreationDate]),
                DATESINPERIOD(Fact_LaborJobSummary[WorkOrderCreationDate], [CreationDateAge], 1, MONTH)
            )
    )

VAR PeakMonth = 
    MAXX(
        MonthlyData,
        [@Count]
    )

VAR PeakMonthDate = 
    MAXX(
        FILTER(MonthlyData, [@Count] = PeakMonth),
        [@Month]
    )

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.08);
    border-left: 4px solid #3A7CA5;
'>
    <div style='
        font-size: 11px;
        color: #6B7280;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.8px;
        margin-bottom: 15px;
    '>
        📅 Inspection Timeline
    </div>
    
    <div style='display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;'>
        <div>
            <div style='font-size: 13px; color: #6B7280; margin-bottom: 4px;'>Date Range</div>
            <div style='font-size: 16px; font-weight: 600; color: #1D3C4E;'>
                " & FORMAT(MinDate, "MMM D, YYYY") & " - " & FORMAT(MaxDate, "MMM D, YYYY") & "
            </div>
        </div>
        <div style='text-align: right;'>
            <div style='font-size: 13px; color: #6B7280; margin-bottom: 4px;'>Avg per Month</div>
            <div style='font-size: 20px; font-weight: 700; color: #3A7CA5;'>
                " & FORMAT(AvgPerMonth, "#,##0.0") & "
            </div>
        </div>
    </div>
    
    <div style='
        padding: 12px;
        background: #EFF6FF;
        border-radius: 6px;
        display: flex;
        align-items: center;
        gap: 10px;
    '>
        <div style='font-size: 24px;'>📈</div>
        <div>
            <div style='font-size: 12px; color: #1E40AF; margin-bottom: 2px;'>Peak Activity</div>
            <div style='font-size: 14px; font-weight: 600; color: #1D3C4E;'>
                " & FORMAT(PeakMonth, "#,##0") & " inspections in " & FORMAT(PeakMonthDate, "MMMM YYYY") & "
            </div>
        </div>
    </div>
</div>
"
```

</details>

---

### WO List - Context Header

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR SelectedJobCode = 
    IF(
        HASONEVALUE(Fact_LaborJobSummary[JobCode]),
        SELECTEDVALUE(Fact_LaborJobSummary[JobCode]),
        "All Job Codes"
    )

VAR SelectedBranch = 
    IF(
        HASONEVALUE(Fact_LaborJobSummary[BranchName]),
        SELECTEDVALUE(Fact_LaborJobSummary[BranchName]),
        "All Branches"
    )

VAR BranchDisplay = SelectedBranch

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    padding: 15px 25px;
    background: linear-gradient(135deg, #1D3C4E 0%, #2E5266 50%, #3A7CA5 100%);
    border-radius: 10px;
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
'>
    <!-- Left side: Back indicator + Title -->
    <div style='display: flex; align-items: center; gap: 15px;'>
        <!-- Back arrow indicator -->
        <div style='
            width: 40px;
            height: 40px;
            background: rgba(255,255,255,0.15);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        '>
            ←
        </div>
        
        <!-- Title and breadcrumb -->
        <div>
            <div style='font-size: 12px; opacity: 0.85; margin-bottom: 4px; letter-spacing: 0.5px;'>
                WORK ORDER LIST
            </div>
            <div style='font-size: 22px; font-weight: 700; display: flex; align-items: center; gap: 10px;'>
                <span style='color: #10b981;'>🔧</span>
                <span>" & SelectedJobCode & "</span>
            </div>
        </div>
    </div>
    
    <!-- Right side: Branch info -->
    <div style='text-align: right;'>
        <div style='font-size: 11px; opacity: 0.75; margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.8px;'>
            Branch
        </div>
        <div style='font-size: 18px; font-weight: 600;'>
            " & BranchDisplay & "
        </div>
    </div>
</div>
"
```

</details>

---

### WO List - Date Range

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR MinDate = MIN(Fact_LaborJobSummary[WorkOrderCreationDate])
VAR MaxDate = MAX(Fact_LaborJobSummary[WorkOrderCreationDate])
RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    text-align: center;
    padding: 12px 20px;
    background: #EFF6FF;
    border-left: 4px solid #3A7CA5;
    border-radius: 6px;
    margin: 10px 0;
'>
    <span style='font-size: 13px; color: #1E40AF; font-weight: 600;'>
        📅 Work orders from " & FORMAT(MinDate, "MMM D, YYYY") & " to " & FORMAT(MaxDate, "MMM D, YYYY") & "
    </span>
</div>
"
```

</details>

---

### WO List - Split Visual

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR LaborPct = [WO List - Labor %]
VAR PartsPct = [WO List - Parts %]

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    width: 380px;
    height: 115px;
    padding: 20px;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 6px rgba(0,0,0,0.08);
    display: flex;
    flex-direction: column;
    justify-content: center;
    box-sizing: border-box;
'>
    <div style='
        font-size: 12px; 
        color: #6B7280; 
        font-weight: 600; 
        margin-bottom: 12px; 
        text-transform: uppercase;
        letter-spacing: 0.5px;
    '>
        Revenue Split
    </div>
    <div style='display: flex; height: 40px; border-radius: 6px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);'>
        <div style='
            flex: " & FORMAT(LaborPct, "0.00") & ";
            background: #3A7CA5;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 14px;
            font-weight: 600;
        '>
            Labor " & FORMAT(LaborPct, "0%") & "
        </div>
        <div style='
            flex: " & FORMAT(PartsPct, "0.00") & ";
            background: #f59e0b;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 14px;
            font-weight: 600;
        '>
            Parts " & FORMAT(PartsPct, "0%") & "
        </div>
    </div>
</div>
"
```

</details>

---

### WO List - Summary Cards HTML

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR WorkOrders = [WO List - Total Orders]
VAR TotalRevenue = [WO List - Total Revenue]
VAR LaborRevenue = [WO List - Total Labor]
VAR PartsRevenue = [WO List - Total Parts]
VAR LaborPct = [WO List - Labor %]
VAR PartsPct = [WO List - Parts %]
VAR AvgPerOrder = [WO List - Avg per Order]

// Format values
VAR TotalRevText = 
    IF(TotalRevenue >= 1000000, FORMAT(TotalRevenue / 1000000, "$#,##0.0") & "M",
    IF(TotalRevenue >= 10000, FORMAT(TotalRevenue / 1000, "$#,##0.0") & "K",
    FORMAT(TotalRevenue, "$#,##0")))

VAR LaborRevText = 
    IF(LaborRevenue >= 1000000, FORMAT(LaborRevenue / 1000000, "$#,##0.0") & "M",
    IF(LaborRevenue >= 10000, FORMAT(LaborRevenue / 1000, "$#,##0.0") & "K",
    FORMAT(LaborRevenue, "$#,##0")))

VAR PartsRevText = 
    IF(PartsRevenue >= 1000000, FORMAT(PartsRevenue / 1000000, "$#,##0.0") & "M",
    IF(PartsRevenue >= 10000, FORMAT(PartsRevenue / 1000, "$#,##0.0") & "K",
    FORMAT(PartsRevenue, "$#,##0")))

VAR AvgPerOrderText = 
    IF(AvgPerOrder >= 10000, FORMAT(AvgPerOrder / 1000, "$#,##0.0") & "K",
    FORMAT(AvgPerOrder, "$#,##0"))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    display: flex;
    gap: 15px;
    padding: 0;
'>
    <!-- Card 1: Work Orders -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #1D3C4E;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Work Orders
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #1D3C4E;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & FORMAT(WorkOrders, "#,##0") & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
            In this selection
        </div>
    </div>

    <!-- Card 2: Labor Revenue -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #3A7CA5;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Labor Revenue
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #3A7CA5;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & LaborRevText & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
            " & FORMAT(LaborPct, "0%") & " of total
        </div>
    </div>

    <!-- Card 3: Parts Revenue -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #f59e0b;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Parts Revenue
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #f59e0b;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & PartsRevText & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
            " & FORMAT(PartsPct, "0%") & " of total
        </div>
    </div>

    <!-- Card 4: Total Revenue -->
    <div style='
        flex: 1;
        background: white;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        border-top: 4px solid #10b981;
    '>
        <div style='
            font-size: 11px;
            color: #6B7280;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-bottom: 12px;
        '>
            Total Revenue
        </div>
        <div style='
            font-size: 42px;
            font-weight: 700;
            color: #10b981;
            line-height: 1;
            margin-bottom: 8px;
        '>
            " & TotalRevText & "
        </div>
        <div style='
            font-size: 12px;
            color: #6B7280;
        '>
            " & AvgPerOrderText & " avg per order
        </div>
    </div>
</div>
"
```

</details>

---

### WO List - Top Work Order Callout

**Type:** HTML Visual

<details>
<summary>Click to expand DAX (HTML code included)</summary>

```dax

VAR TopWO = 
    TOPN(
        1,
        ADDCOLUMNS(
            VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
            "@Revenue", 
                VAR CurrentWO = Fact_LaborJobSummary[WorkOrderNumber]
                RETURN
                    CALCULATE(
                        [WO List - Total Labor] + [WO List - Total Parts],
                        Fact_LaborJobSummary[WorkOrderNumber] = CurrentWO
                    )
        ),
        [@Revenue],
        DESC
    )

VAR TopWONumber = MINX(TopWO, Fact_LaborJobSummary[WorkOrderNumber])

VAR TopWORevenue = 
    CALCULATE(
        [WO List - Total Labor] + [WO List - Total Parts],
        Fact_LaborJobSummary[WorkOrderNumber] = TopWONumber
    )

VAR TopWORevText = 
    IF(TopWORevenue >= 10000, FORMAT(TopWORevenue / 1000, "$#,##0.0") & "K",
    FORMAT(TopWORevenue, "$#,##0"))

RETURN
"
<div style='
    font-family: Segoe UI, Arial, sans-serif;
    width: 380px;
    height: 115px;
    padding: 20px;
    background: linear-gradient(to right, #10b981, #059669);
    color: white;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-sizing: border-box;
'>
    <div style='display: flex; align-items: center; gap: 12px;'>
        <div style='font-size: 28px;'>🏆</div>
        <div>
            <div style='font-size: 11px; opacity: 0.9; margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.5px;'>
                Highest Revenue
            </div>
            <div style='font-size: 18px; font-weight: 700;'>
                Work Order #" & TopWONumber & "
            </div>
        </div>
    </div>
    <div style='font-size: 28px; font-weight: 700;'>
        " & TopWORevText & "
    </div>
</div>
"
```

</details>

---

## Work Order Details

**27 measures in this category**

### Test - WO Count

**Format:** `0`

**DAX:**
```dax

DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber])
```

---

### WO Branch Display

**DAX:**
```dax

"Branch: " & SELECTEDVALUE(Fact_LaborJobSummary[BranchName])
```

---

### WO Count - Direct Date

**Format:** `0`

**DAX:**
```dax

CALCULATE(
    DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber]),
    DATESBETWEEN(
        dim_DateTable[Date],
        DATE(2024, 12, 1),
        DATE(2025, 4, 30)
    )
)
```

---

### WO Date

**Format:** `General Date`

**DAX:**
```dax

SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderCreationDate])
```

---

### WO Date Display

**DAX:**
```dax

"Date: " & FORMAT(SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderCreationDate]), "MM/DD/YYYY")
```

---

### WO Grand Total

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[WO Total Labor] + [WO Net Parts]
```

---

### WO Gross Parts

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice,
        Fact_WorkOrderParts[Franchise] <> "ZP",
        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
    )
```

---

### WO Invoice Display

**DAX:**
```dax

"Invoice # " & SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
```

---

### WO Labor Total

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
    ALLEXCEPT(Fact_LaborJobSummary, Fact_LaborJobSummary[WorkOrderNumber])
)
```

---

### WO Labor Total - Fixed

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

IF(
    ISINSCOPE(Fact_LaborJobSummary[WorkOrderNumber]),
    // Row-level: Calculate for this specific WO
    CALCULATE(
        SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
        ALLEXCEPT(Fact_LaborJobSummary, Fact_LaborJobSummary[WorkOrderNumber])
    ),
    // Total row: Respect all filters
    CALCULATE(
        SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
)
```

---

### WO List - Avg per Order

**DAX:**
```dax

DIVIDE(
    [WO List - Total Revenue],
    [WO List - Total Orders],
    0
)
```

---

### WO List - Labor %

**DAX:**
```dax

DIVIDE(
    [WO List - Total Labor],
    [WO List - Total Revenue],
    0
)
```

---

### WO List - Parts %

**DAX:**
```dax

DIVIDE(
    [WO List - Total Parts],
    [WO List - Total Revenue],
    0
)
```

---

### WO List - Total Labor

**Format:** `\$#,0;(\$#,0);\$#,0`

**DAX:**
```dax

// Iterate over each work order visible in the drill-through context
SUMX(
    VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
    // For each work order, get ALL its labor (all job codes)
    CALCULATE(
        SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
        ALLEXCEPT(Fact_LaborJobSummary, Fact_LaborJobSummary[WorkOrderNumber]),
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
)
```

---

### WO List - Total Orders

**Format:** `0`

**DAX:**
```dax

DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber])
```

---

### WO List - Total Parts

**Format:** `\$#,0;(\$#,0);\$#,0`

**DAX:**
```dax

// Get all work orders in the drill-through context
VAR WorkOrdersInContext = VALUES(Fact_LaborJobSummary[WorkOrderNumber])

RETURN
// Sum ALL parts for these work orders
SUMX(
    WorkOrdersInContext,
    VAR CurrentWO = Fact_LaborJobSummary[WorkOrderNumber]
    VAR InvoiceForThisWO = 
        CALCULATE(
            SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber]),
            Fact_LaborJobSummary[WorkOrderNumber] = CurrentWO,
            NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber])),
            ALL(Fact_LaborJobSummary[JobCode])  // Remove JobCode filter here too
        )
    RETURN
        IF(
            NOT(ISBLANK(InvoiceForThisWO)),
            CALCULATE(
                SUM(Fact_WorkOrderParts[SaleValue]),
                Fact_WorkOrderParts[InvoiceNumber] = InvoiceForThisWO,
                Fact_WorkOrderParts[Franchise] <> "ZP",
                NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
            ),
            0
        )
)
```

---

### WO List - Total Revenue

**Format:** `\$#,0;(\$#,0);\$#,0`

**DAX:**
```dax

[WO List - Total Labor] + [WO List - Total Parts]
```

---

### WO Net Parts

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[WO Gross Parts] + [WO Parts Discount]
```

---

### WO Number Display

**DAX:**
```dax

"Work Order #" & SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
```

---

### WO Parts Discount

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice,
        Fact_WorkOrderParts[PartNumber] IN {"*10PROMO"}
    )
```

---

### WO Parts Total

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentWO = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
VAR InvoiceForThisWO = 
    CALCULATE(
        SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber]),
        Fact_LaborJobSummary[WorkOrderNumber] = CurrentWO,
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] = InvoiceForThisWO,
        Fact_WorkOrderParts[Franchise] <> "ZP",
        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
    )
```

---

### WO Parts Total - Fixed

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

IF(
    ISINSCOPE(Fact_LaborJobSummary[WorkOrderNumber]),
    // Row-level: Calculate for this specific WO
    VAR CurrentWO = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
    VAR InvoiceForThisWO = 
        CALCULATE(
            SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber]),
            Fact_LaborJobSummary[WorkOrderNumber] = CurrentWO,
            NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
        )
    RETURN
        CALCULATE(
            SUM(Fact_WorkOrderParts[SaleValue]),
            Fact_WorkOrderParts[InvoiceNumber] = InvoiceForThisWO,
            Fact_WorkOrderParts[Franchise] <> "ZP",
            NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
        ),
    // Total row: Sum all parts respecting filters
    SUMX(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        VAR CurrentWO = Fact_LaborJobSummary[WorkOrderNumber]
        VAR InvoiceForThisWO = 
            CALCULATE(
                SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber]),
                Fact_LaborJobSummary[WorkOrderNumber] = CurrentWO,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        RETURN
            IF(
                NOT(ISBLANK(InvoiceForThisWO)),
                CALCULATE(
                    SUM(Fact_WorkOrderParts[SaleValue]),
                    Fact_WorkOrderParts[InvoiceNumber] = InvoiceForThisWO,
                    Fact_WorkOrderParts[Franchise] <> "ZP",
                    NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
                ),
                0
            )
    )
)
```

---

### WO Timeline - Count by Creation Date

**Format:** `0`

**DAX:**
```dax

DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber])
```

---

### WO Total Labor

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
    Fact_LaborJobSummary[WorkOrderNumber] = SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber])
)
```

---

### WO Total Parts

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice,
        Fact_WorkOrderParts[Franchise] <> "ZP",
        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
        
    )
```

---

### WO Total Revenue

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[WO Labor Total] + [WO Parts Total]
```

---

### WO Total Revenue - Fixed

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[WO Labor Total - Fixed] + [WO Parts Total - Fixed]
```

---

## Pending Inspections

**8 measures in this category**

### Average Pending Age

**DAX:**
```dax

AVERAGE(Fact_PendingInspections[DaysSinceCreation])
```

---

### Est Parts Value - For Pending

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

SUMX(
    FILTER(
        dim_Parts,
        [Show Part for JobCode] = 1
    ),
    [Est Quantity Needed - For Pending] * dim_Parts[SellPrice1]
)
```

---

### Est Quantity Needed - For Pending

**Format:** `0`

**DAX:**
```dax

VAR PendingCount = 
    CALCULATE(
        COUNTROWS(Fact_PendingInspections),
        ALLEXCEPT(Fact_PendingInspections, Fact_PendingInspections[JobCode])
    )
VAR Frequency = [Part Frequency % - For JobCode]
VAR AvgQty = [Avg Part Quantity - For JobCode]
RETURN
    PendingCount * Frequency * AvgQty
```

---

### Estimated Revenue - Pending

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR PendingCount = [Total Pending Inspections]
VAR AvgRevenue = [Average Inspection Revenue]
RETURN
    PendingCount * AvgRevenue
```

---

### Pending Hours Worked

**DAX:**
```dax

SUM(Fact_PendingInspections[HoursWorked])
```

---

### Pending Inspections Count

**Format:** `0`

**DAX:**
```dax

COUNTROWS(Fact_PendingInspections)
```

---

### Total Pending Hours

**Format:** `0.0`

**DAX:**
```dax

SUM(Fact_PendingInspections[HoursWorked])
```

---

### Total Pending Inspections

**Format:** `0`

**DAX:**
```dax

COUNTROWS(Fact_PendingInspections)
```

---

## ServiceRecommendations

**3 measures in this category**

### Service Count - For JobCode

**Format:** `0`

**DAX:**
```dax

VAR SelectedInspectionCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR CurrentServiceCode = SELECTEDVALUE(Fact_LaborJobSummary[JobCode])
RETURN
    IF(
        NOT(ISBLANK(SelectedInspectionCode)) && 
        NOT(ISBLANK(CurrentServiceCode)) &&
        CurrentServiceCode <> SelectedInspectionCode,  // Check this OUTSIDE the CALCULATE
        
        // Get work orders that have the selected inspection
        VAR WorkOrdersWithInspection = 
            CALCULATETABLE(
                VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
                Fact_LaborJobSummary[JobCode] = SelectedInspectionCode,
                Fact_LaborJobSummary[IsInspection] = TRUE,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        
        // Count how many of those work orders ALSO have the current service
        VAR ServiceCount = 
            CALCULATE(
                DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber]),
                Fact_LaborJobSummary[WorkOrderNumber] IN WorkOrdersWithInspection,
                Fact_LaborJobSummary[JobCode] = CurrentServiceCode
            )
        
        RETURN ServiceCount
        ,
        BLANK()
    )
```

---

### Service Frequency %

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE(
    SUM(ServiceRecommendations[TimesAdded]),
    MAX(ServiceRecommendations[CompletedInspections]),
    0
)
```

---

### Service Frequency % - For JobCode

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE(
    [Service Count - For JobCode],
    [Completed Inspections - Selected JobCode],
    0
)
```

---

## Averages & Calculations

**8 measures in this category**

### Average Inspection Revenue

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    DIVIDE(
        SUM(Fact_LaborJobSummary[InvoicedLaborAmount]) + 
        [Parts $ Total],
        DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber])
    ),
    Fact_LaborJobSummary[IsInspection] = TRUE,
    NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
)
```

---

### Avg Labor $ - For Service

**Format:** `0`

**DAX:**
```dax

VAR SelectedInspectionCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR CurrentServiceCode = SELECTEDVALUE(Fact_LaborJobSummary[JobCode])
RETURN
    IF(
        NOT(ISBLANK(SelectedInspectionCode)) && 
        NOT(ISBLANK(CurrentServiceCode)) &&
        CurrentServiceCode <> SelectedInspectionCode,
        
        VAR WorkOrdersWithInspection = 
            CALCULATETABLE(
                VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
                Fact_LaborJobSummary[JobCode] = SelectedInspectionCode,
                Fact_LaborJobSummary[IsInspection] = TRUE,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        
        VAR TotalLabor = 
            CALCULATE(
                SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
                Fact_LaborJobSummary[WorkOrderNumber] IN WorkOrdersWithInspection,
                Fact_LaborJobSummary[JobCode] = CurrentServiceCode
            )
        
        VAR ServiceCount = [Service Count - For JobCode]
        
        RETURN DIVIDE(TotalLabor, ServiceCount, 0)
        ,
        BLANK()
    )
```

---

### Avg Labor $ by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

DIVIDE(
    [Labor $ by Job Code],
    [Inspection Count by Job Code],
    0
)
```

---

### Avg Labor & Parts by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

DIVIDE(
    [Labor $ by Job Code] + [Parts $ by Job Code],
    [Inspection Count by Job Code],
    0
)
```

---

### Avg Part Quantity - For JobCode

**Format:** `0`

**DAX:**
```dax

VAR SelectedJobCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR CurrentPart = SELECTEDVALUE(Fact_WorkOrderParts[PartNumber])
RETURN
    IF(
        NOT(ISBLANK(SelectedJobCode)) && NOT(ISBLANK(CurrentPart)),
        VAR CompletedWOs = 
            CALCULATETABLE(
                VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
                Fact_LaborJobSummary[JobCode] = SelectedJobCode,
                Fact_LaborJobSummary[IsInspection] = TRUE,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        
        VAR InvoicesForWOs = 
            CALCULATETABLE(
                VALUES(Fact_LaborJobSummary[InvoiceNumber]),
                Fact_LaborJobSummary[WorkOrderNumber] IN CompletedWOs,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        
        VAR TotalQty = 
            CALCULATE(
                SUM(Fact_WorkOrderParts[Quantity]),
                Fact_WorkOrderParts[InvoiceNumber] IN InvoicesForWOs,
                Fact_WorkOrderParts[PartNumber] = CurrentPart,
                Fact_WorkOrderParts[Franchise] <> "ZP"
            )
        
        VAR TimesUsed = [Part Sold Count - For JobCode]
        
        RETURN DIVIDE(TotalQty, TimesUsed, 0)
        ,
        BLANK()
    )
```

---

### Avg Parts $ by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

DIVIDE(
    [Parts $ by Job Code],
    [Inspection Count by Job Code],
    0
)
```

---

### Avg Revenue by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentJobCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
RETURN
    IF(
        NOT(ISBLANK(CurrentJobCode)),
        // Get all completed work orders with this job code
        VAR CompletedWOs = 
            CALCULATETABLE(
                VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
                Fact_LaborJobSummary[JobCode] = CurrentJobCode,
                Fact_LaborJobSummary[IsInspection] = TRUE,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        
        // Get invoices for those work orders
        VAR InvoicesForWOs = 
            CALCULATETABLE(
                VALUES(Fact_LaborJobSummary[InvoiceNumber]),
                Fact_LaborJobSummary[WorkOrderNumber] IN CompletedWOs,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        
        // Calculate total labor for these work orders
        VAR TotalLabor = 
            CALCULATE(
                SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
                Fact_LaborJobSummary[WorkOrderNumber] IN CompletedWOs
            )
        
        // Calculate total parts for these invoices
        VAR TotalParts = 
            CALCULATE(
                SUM(Fact_WorkOrderParts[SaleValue]),
                Fact_WorkOrderParts[InvoiceNumber] IN InvoicesForWOs,
                Fact_WorkOrderParts[Franchise] <> "ZP",
                NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
            )
        
        // Count of work orders
        VAR WOCount = COUNTROWS(CompletedWOs)
        
        RETURN
            DIVIDE(TotalLabor + TotalParts, WOCount, 0)
        ,
        BLANK()
    )
```

---

### Avg Service Labor

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

DIVIDE(
    SUM(ServiceRecommendations[TotalLabor]),
    SUM(ServiceRecommendations[TimesAdded]),
    0
)
```

---

## CS690/CS770 Specific

**3 measures in this category**

### CS690-CS770 Inspections

**Format:** `0`

**DAX:**
```dax

CALCULATE(
    COUNTROWS(Fact_LaborJobSummary),
    Fact_LaborJobSummary[IsInspection] = TRUE,
    Fact_LaborJobSummary[JobCode] IN {
        "IS-CS690 INSPECT",
        "IS-CS770 INSPECT", 
        "IS-STRIPPER INSPECT",
        "IS-CP690 INSPECT",
        "IS-CP770 INSPECT"
    }
)
```

---

### CS690-CS770 Labor With Inspection

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CS690WOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[JobCode] IN {
            "IS-CS690 INSPECT",
            "IS-CS770 INSPECT",
            "IS-STRIPPER INSPECT",
            "IS-CP690 INSPECT",
            "IS-CP770 INSPECT"
        }
    )
RETURN
    CALCULATE(
        SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
        Fact_LaborJobSummary[WorkOrderNumber] IN CS690WOs
    )
```

---

### CS690-CS770 Parts Total

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CS690Invoices = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[InvoiceNumber]),
        Fact_LaborJobSummary[JobCode] IN {
            "IS-CS690 INSPECT",
            "IS-CS770 INSPECT",
            "IS-STRIPPER INSPECT",
            "IS-CP690 INSPECT",
            "IS-CP770 INSPECT"
        },
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] IN CS690Invoices,
        Fact_WorkOrderParts[Franchise] <> "ZP",
        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
    )
```

---

## Discount Analysis

**14 measures in this category**

### ADV Discount

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY"}
)
```

---

### Avg % Discounted by Job Code

**Format:** `0.0%;-0.0%;0.0%`

**DAX:**
```dax

VAR TotalDiscount = ABS([Labor Discount by Job Code] + [Parts Discount by Job Code])
VAR TotalRevenue = [Labor $ by Job Code] + [Parts $ by Job Code]
RETURN
    DIVIDE(TotalDiscount, TotalRevenue, 0)
```

---

### Avg Labor Discount by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

DIVIDE(
    [Labor Discount by Job Code],
    [Inspection Count by Job Code],
    0
)
```

---

### Avg Part Discount by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

DIVIDE(
    [Parts Discount by Job Code],
    [Inspection Count by Job Code],
    0
)
```

---

### Labor Discount by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentJobCode = SELECTEDVALUE(Fact_LaborJobSummary[JobCode])
VAR WorkOrdersWithThisJobCode = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[JobCode] = CurrentJobCode,
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
VAR InvoicesForTheseWOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[InvoiceNumber]),
        Fact_LaborJobSummary[WorkOrderNumber] IN WorkOrdersWithThisJobCode,
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] IN InvoicesForTheseWOs,
        Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY"}  // ADV discount parts
    )
```

---

### Parts Discount

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[PartNumber] = "*10PROMO"
)
```

---

### Parts Discount by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentJobCode = SELECTEDVALUE(Fact_LaborJobSummary[JobCode])
VAR WorkOrdersWithThisJobCode = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[JobCode] = CurrentJobCode,
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
VAR InvoicesForTheseWOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[InvoiceNumber]),
        Fact_LaborJobSummary[WorkOrderNumber] IN WorkOrdersWithThisJobCode,
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] IN InvoicesForTheseWOs,
        Fact_WorkOrderParts[PartNumber] = "*10PROMO"
    )
```

---

### Parts Total $ - Discount $

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[Parts $ Total] + [Parts Discount] + [ADV Discount] + [Trucking Discount]
```

---

### Total $ - Discount $

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[Total] + [Parts Discount] + [ADV Discount] + [Trucking Discount]
```

---

### Total $ - Discounts by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[Labor $ by Job Code] + [Parts $ by Job Code] + 
[Labor Discount by Job Code] + [Parts Discount by Job Code]
```

---

### Total Discount $

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[Parts Discount] + [ADV Discount] + [Trucking Discount]
```

---

### Total Discount %

**Format:** `0.00%;-0.00%;0.00%`

**DAX:**
```dax

DIVIDE(
    ABS([Total Discount $]),
    [Inspection $$] + [Parts $ Total] + [Labor $$],
    0
)
```

---

### Trucking Discount

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[PartNumber] = "4900"
)
```

---

### Trucking Discount by Job Code

**DAX:**
```dax

VAR CurrentJobCode = SELECTEDVALUE(Fact_LaborJobSummary[JobCode])
VAR WorkOrdersWithThisJobCode = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[JobCode] = CurrentJobCode,
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
VAR InvoicesForTheseWOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[InvoiceNumber]),
        Fact_LaborJobSummary[WorkOrderNumber] IN WorkOrdersWithThisJobCode,
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] IN InvoicesForTheseWOs,
        Fact_WorkOrderParts[PartNumber] = "4900"
    )
```

---

## Helper/Utility

**43 measures in this category**

### Additional Hours Invoiced

**DAX:**
```dax

[Hours Invoiced With Inspection] - [Hours Invoiced]
```

---

### Additional Hours Worked

**DAX:**
```dax

[Hours Worked With Inspection] - [Hours Worked]
```

---

### Applied Filters

**DAX:**
```dax

VAR MaxFilters = 7
RETURN
    IF (
        ISFILTERED ( dim_BranchLocation[Branch] ),
        VAR ___f =
            FILTERS ( dim_BranchLocation[Branch] )
        VAR ___r =
            COUNTROWS ( ___f )
        VAR ___t =
            TOPN ( MaxFilters, ___f, dim_BranchLocation[Branch] )
        VAR ___d =
            CONCATENATEX ( ___t, dim_BranchLocation[Branch], ", " )
        VAR ___x =
            "Branch:  " & ___d
                & IF ( ___r > MaxFilters, ", ... [" & ___r & " items selected]" ) & " "
        RETURN
            ___x & UNICHAR ( 13 )
                & UNICHAR ( 10 )
    )
```

---

### Completed Inspections - Selected JobCode

**Format:** `0`

**DAX:**
```dax

VAR SelectedJobCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
RETURN
    IF(
        NOT(ISBLANK(SelectedJobCode)),
        CALCULATE(
            DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber]),
            Fact_LaborJobSummary[JobCode] = SelectedJobCode,
            Fact_LaborJobSummary[IsInspection] = TRUE,
            NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
        ),
        BLANK()
    )
```

---

### CreationDateAge

**Format:** `0`

**DAX:**
```dax

SWITCH (
    TRUE (),
    MAX ( 'Fact_PendingInspections'[CreationDate] )
        < TODAY () - 60, 2,
    -- Over 2 months old
    MAX ( 'Fact_PendingInspections'[CreationDate] )
        < TODAY () - 30, 1,
    -- Over 1 month old
    0 -- Within the last month
)
```

---

### Current Invoice Number

**DAX:**
```dax

SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
```

---

### Customer Name

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
VAR CustomerNum = 
    CALCULATE(
        SELECTEDVALUE(Fact_WorkOrderParts[CustomerNumber]),
        Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice
    )
RETURN
    IF(
        NOT(ISBLANK(CustomerNum)),
        LOOKUPVALUE(
            dim_CustomerList[PrimaryName],
            dim_CustomerList[CustomerNumber], CustomerNum
        ),
        BLANK()
    )
```

---

### Est Service Opportunities

**Format:** `0`

**DAX:**
```dax

VAR PendingCount = 
    CALCULATE(
        COUNTROWS(Fact_PendingInspections),
        ALLEXCEPT(Fact_PendingInspections, Fact_PendingInspections[JobCode])
    )
RETURN
    PendingCount * [Service Frequency %]
```

---

### Est Service Revenue

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

[Est Service Opportunities] * [Avg Service Labor]
```

---

### Estimated Hours

**DAX:**
```dax

CALCULATE(
    SUM(Fact_LaborJobSummary[EstimatedHours]),
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

---

### Estimated Revenue by Job Code

**DAX:**
```dax

VAR CurrentJobCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR PendingCountThisCode = 
    CALCULATE(
        COUNTROWS(Fact_PendingInspections),
        Fact_PendingInspections[JobCode] = CurrentJobCode
    )
VAR AvgRevenueThisCode = 
    CALCULATE(
        DIVIDE(
            SUM(Fact_LaborJobSummary[InvoicedLaborAmount]) + [Parts $ Total],
            DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber])
        ),
        Fact_LaborJobSummary[JobCode] = CurrentJobCode,
        Fact_LaborJobSummary[IsInspection] = TRUE,
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
RETURN
    PendingCountThisCode * AvgRevenueThisCode
```

---

### Has Inspection

**Format:** `"TRUE";"TRUE";"FALSE"`

**DAX:**
```dax

VAR InspectionWOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
RETURN
    IF(
        SELECTEDVALUE(Fact_LaborJobSummary[WorkOrderNumber]) IN InspectionWOs,
        TRUE,
        FALSE
    )
```

---

### Hours Invoiced

**DAX:**
```dax

CALCULATE(
    SUM(Fact_LaborJobSummary[InvoicedHours]),
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

---

### Hours Invoiced With Inspection

**DAX:**
```dax

VAR InspectionWOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
RETURN
    CALCULATE(
        SUM(Fact_LaborJobSummary[InvoicedHours]),
        Fact_LaborJobSummary[WorkOrderNumber] IN InspectionWOs
    )
```

---

### Hours Realization Rate

**Format:** `0.0%;-0.0%;0.0%`

**DAX:**
```dax

DIVIDE(
    [Hours Worked],
    [Hours Invoiced],
    0
)
```

---

### Hours Worked

**DAX:**
```dax

CALCULATE(
    SUM(Fact_LaborJobSummary[ActualHoursWorked]),
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

---

### Hours Worked With Inspection

**DAX:**
```dax

VAR InspectionWOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
RETURN
    CALCULATE(
        SUM(Fact_LaborJobSummary[ActualHoursWorked]),
        Fact_LaborJobSummary[WorkOrderNumber] IN InspectionWOs
    )
```

---

### Inspection $$

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

---

### Inspection Count by Job Code

**Format:** `0`

**DAX:**
```dax

CALCULATE(
    DISTINCTCOUNT(Fact_LaborJobSummary[WorkOrderNumber]),
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

---

### Inspections Subtitle

**DAX:**
```dax

"Goal: " & FORMAT([Total Inspection Goal All], "#,##0") & " | " & FORMAT([% to Goal - Inspections], "0%") & " ↑"
```

---

### Labor $ by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentJobCode = SELECTEDVALUE(Fact_LaborJobSummary[JobCode])
VAR WorkOrdersWithThisJobCode = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[JobCode] = CurrentJobCode,
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
RETURN
    CALCULATE(
        SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
        Fact_LaborJobSummary[WorkOrderNumber] IN WorkOrdersWithThisJobCode
    )
```

> ⚠️ **`SELECTEDVALUE`-based blank-at-total trap:** this measure (and [Parts $ by Job Code](#parts--by-job-code) below) computes `CurrentJobCode` via `SELECTEDVALUE`, which returns `BLANK()` whenever more than one JobCode is in context — not just at the true grand total, but under *any* partial multi-value slicer/filter selection. Anything that wraps these directly (rather than an already context-safe measure like `WO List - Total Labor` / `WO List - Total Parts`) will silently blank out at totals or partial selections. This hazard is not hypothetical — it caused two real bugs fixed 2026-07-20: `Avg Parts $ /Inspection` and `Avg Parts $ by Job Code` (a separate, similarly-named measure actually bound to the Details page matrix column) both went blank at totals until repointed to `DIVIDE([WO List - Total Parts], [Inspection Count by Job Code], 0)`. `Labor $ by Job Code` / `Parts $ by Job Code` themselves are believed to be legacy/unused directly on any current visual, but treat any measure still wrapping them as suspect if it's expected to show a correct total row.

---

### Labor Subtitle

**DAX:**
```dax

VAR GoalM = [Total Labor Goal All] / 1000000
VAR Pct = [Overall % to Goal Labor]
RETURN
"Goal: $" & FORMAT(GoalM, "0.0") & "M | " & FORMAT(Pct, "0%")
```

---

### Labor With Inspection

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR InspectionWOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
RETURN
    CALCULATE(
        SUM(Fact_LaborJobSummary[InvoicedLaborAmount]),
        Fact_LaborJobSummary[WorkOrderNumber] IN InspectionWOs
    )
```

> ⚠️ See the filter-context warning under [Labor $$](#labor-) above — this measure never clears an external JobCode/InspectionCategory filter. `Labor $$ (Filtered)` was the previous workaround but was deleted 2026-07-20; use `WO List - Total Labor` instead wherever such a filter may be active.

---

### LastPunchDateAge

**Format:** `0`

**DAX:**
```dax

SWITCH (
    TRUE (),
    MAX ( 'Fact_PendingInspections'[CreationDate] )
        < TODAY () - 60, 2,
    -- Over 2 months old
    MAX ( 'Fact_PendingInspections'[CreationDate] )
        < TODAY () - 30, 1,
    -- Over 1 month old
    0 -- Within the last month
)
```

---

### Overall Subtitle

**DAX:**
```dax

"Total: " & FORMAT(([Inspection $$] + [Total Current Parts] + [Total Current Labor]) / 1000000, "$#,##0.1M")
```

---

### Part Description Filtered

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
RETURN
    IF(
        NOT(ISBLANK(CurrentInvoice)),
        CALCULATE(
            SELECTEDVALUE(Fact_WorkOrderParts[Description]),
            Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice
        ),
        BLANK()
    )
```

---

### Part Frequency % - For JobCode

**Format:** `0%;-0%;0%`

**DAX:**
```dax

DIVIDE(
    [Part Sold Count - For JobCode],
    [Completed Inspections - Selected JobCode],
    0
)
```

---

### Part Number Filtered

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
RETURN
    IF(
        NOT(ISBLANK(CurrentInvoice)),
        CALCULATE(
            SELECTEDVALUE(Fact_WorkOrderParts[PartNumber]),
            Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice
        ),
        BLANK()
    )
```

---

### Part Quantity Filtered

**Format:** `0`

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
RETURN
    IF(
        NOT(ISBLANK(CurrentInvoice)),
        CALCULATE(
            SUM(Fact_WorkOrderParts[Quantity]),
            Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice
        ),
        BLANK()
    )
```

---

### Part Sale Value Filtered

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
RETURN
    IF(
        NOT(ISBLANK(CurrentInvoice)),
        CALCULATE(
            SUM(Fact_WorkOrderParts[SaleValue]),
            Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice,
            Fact_WorkOrderParts[Franchise] <> "ZP"
        ),
        BLANK()
    )
```

---

### Part Sold Count - For JobCode

**Format:** `0`

**DAX:**
```dax

VAR SelectedJobCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR CurrentPart = SELECTEDVALUE(dim_Parts[PartNumber])  // ← Changed this line
RETURN
    IF(
        NOT(ISBLANK(SelectedJobCode)) && NOT(ISBLANK(CurrentPart)),
        VAR CompletedWOs = 
            CALCULATETABLE(
                VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
                Fact_LaborJobSummary[JobCode] = SelectedJobCode,
                Fact_LaborJobSummary[IsInspection] = TRUE,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        
        VAR InvoicesForWOs = 
            CALCULATETABLE(
                VALUES(Fact_LaborJobSummary[InvoiceNumber]),
                Fact_LaborJobSummary[WorkOrderNumber] IN CompletedWOs,
                NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
            )
        
        VAR PartSoldCount = 
            CALCULATE(
                DISTINCTCOUNT(Fact_WorkOrderParts[InvoiceNumber]),
                Fact_WorkOrderParts[InvoiceNumber] IN InvoicesForWOs,
                Fact_WorkOrderParts[PartNumber] = CurrentPart,
                Fact_WorkOrderParts[Franchise] <> "ZP"
            )
        
        RETURN PartSoldCount,
        
        BLANK()
    )
```

---

### Parts $ by Job Code

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR CurrentJobCode = SELECTEDVALUE(Fact_LaborJobSummary[JobCode])
VAR WorkOrdersWithThisJobCode = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[WorkOrderNumber]),
        Fact_LaborJobSummary[JobCode] = CurrentJobCode,
        Fact_LaborJobSummary[IsInspection] = TRUE
    )
VAR InvoicesForTheseWOs = 
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[InvoiceNumber]),
        Fact_LaborJobSummary[WorkOrderNumber] IN WorkOrdersWithThisJobCode,
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber]))
    )
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] IN InvoicesForTheseWOs,
        Fact_WorkOrderParts[Franchise] <> "ZP",
        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
    )
```

---

### Parts Subtitle

**DAX:**
```dax

VAR GoalM = [Total Parts Goal All] / 1000000
VAR Pct = [Overall % to Goal Parts]
RETURN
"Goal: $" & FORMAT(GoalM, "0.0") & "M | " & FORMAT(Pct, "0%")
```

---

### Parts for This WO

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] = CurrentInvoice
    )
```

---

### Show Part for JobCode

**Format:** `0`

**DAX:**
```dax

VAR SelectedJobCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR CurrentPart = SELECTEDVALUE(dim_Parts[PartNumber])
RETURN
    IF(
        NOT(ISBLANK(SelectedJobCode)) && NOT(ISBLANK(CurrentPart)),
        IF([Part Sold Count - For JobCode] > 0, 1, 0),
        0
    )
```

---

### Show Parts for This WO

**Format:** `0`

**DAX:**
```dax

VAR CurrentInvoice = SELECTEDVALUE(Fact_LaborJobSummary[InvoiceNumber])
VAR PartInvoice = SELECTEDVALUE(Fact_WorkOrderParts[InvoiceNumber])
RETURN
    IF(PartInvoice = CurrentInvoice, 1, 0)
```

---

### Show Service for JobCode

**Format:** `0`

**DAX:**
```dax

VAR SelectedInspectionCode = SELECTEDVALUE(Fact_PendingInspections[JobCode])
VAR CurrentServiceCode = SELECTEDVALUE(Fact_LaborJobSummary[JobCode])
RETURN
    IF(
        NOT(ISBLANK(SelectedInspectionCode)) && 
        NOT(ISBLANK(CurrentServiceCode)) &&
        CurrentServiceCode <> SelectedInspectionCode &&
        [Service Count - For JobCode] > 0,
        1,
        0
    )
```

---

### Test - Parts Revenue

**DAX:**
```dax

VAR CurrentWOs = VALUES(Fact_LaborJobSummary[WorkOrderNumber])
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] IN CurrentWOs,
        Fact_WorkOrderParts[Franchise] <> "ZP"
    )
```

---

### Test - Selected JobCode

**DAX:**
```dax

SELECTEDVALUE(Fact_PendingInspections[JobCode])
```

---

### Total Current Inspections

**Format:** `0`

**DAX:**
```dax
[Total Inspections]
```

---

### Total Current Labor

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax
[Labor With Inspection]
```

---

### Total Current Parts

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax
[Parts $ Total]
```

---

### Welcome Name

**DAX:**
```dax

VAR _User =
    USERPRINCIPALNAME ()
VAR _Position =
    SEARCH ( "@", _User, 1 )
VAR _Name =
    LEFT ( _User, _Position - 1 )
VAR _FirstLetter =
    UPPER ( LEFT ( _Name, 1 ) )
VAR _LastName =
    MID ( _Name, 2, LEN ( _Name ) - 1 )
VAR _FormattedLastName =
    UPPER ( LEFT ( _LastName, 1 ) )
        & LOWER ( MID ( _LastName, 2, LEN ( _LastName ) ) )
RETURN
    "Welcome Back, " & _FirstLetter & "." & _FormattedLastName
```

---

## Trend

**7 measures in this category**

Powers the Details page trend view: a rolling 12-month Parts $ / Labor $ chart (4 lines: Parts current, Labor current, Parts LY, Labor LY) and a two-stat KPI card whose fields carry prior-year reference labels. Updated 2026-07-20 after this session's bug fixes and a design change from Rolling 24 to Rolling 12 months (per Brian/Casey) — see the notes under each measure below for what changed and why.

`Parts $ Total (Filtered)` is a generalized invoice-number bridge — functionally the same pattern as `Parts $ Total` but built from a local `ValidInv` variable instead of the `ValidInvoiceNumbers` table, so it can be reused safely inside the trend visuals' month/rolling filter context. `Labor $$ (Filtered)` (the previous filter-safe labor variant) was **deleted this session** — the chart and card now use `WO List - Total Labor` instead (see below). The four `LY` measures are pure `CALCULATE(..., DATEADD(dim_DateTable[Date], -1, YEAR))` wrappers around existing measures, following the same established pattern as `Total Inspections LY` — no new business logic.

### Parts $ Total (Filtered)

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

VAR ValidInv =
    CALCULATETABLE(
        VALUES(Fact_LaborJobSummary[InvoiceNumber]),
        Fact_LaborJobSummary[IsInspection] = TRUE,
        NOT(ISBLANK(Fact_LaborJobSummary[InvoiceNumber])),
        ALL(dim_DateTable)
    )
RETURN
    CALCULATE(
        SUM(Fact_WorkOrderParts[SaleValue]),
        Fact_WorkOrderParts[InvoiceNumber] IN ValidInv,
        Fact_WorkOrderParts[Franchise] <> "ZP",
        NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
    )
```

> ⚠️ **Bug fixed 2026-07-20 (double-date-filter):** `Fact_LaborJobSummary` relates to `dim_DateTable` via `WorkOrderCreationDateKey`; `Fact_WorkOrderParts` relates via a separate `TransactionDateKey` relationship. Before the fix, the `ValidInv` VAR inherited the ambient month filter through the labor table's relationship, and the final `SUM` inherited it *again* through the parts table's relationship — double-restricting results to "invoice created AND transacted in the same month," which silently dropped most parts (a work order is often created weeks before its parts post). The `ALL(dim_DateTable)` added to the VAR removes the first restriction, so only the parts' own transaction date determines month membership. Confirmed fix: Feb 2025 went from $209,102 (buggy) to $745,951 (correct, matching the Details page matrix).

---

### Parts $ Total Fixed LY

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    [Parts $ Total (Filtered)],
    DATEADD( dim_DateTable[Date], -1, YEAR )
)
```

New this session — prior-year comparison line for the trend chart's Parts series.

---

### WO List - Total Labor LY

**Format:** `\$#,0;(\$#,0);\$#,0`

**DAX:**
```dax

CALCULATE(
    [WO List - Total Labor],
    DATEADD( dim_DateTable[Date], -1, YEAR )
)
```

New this session — prior-year comparison line for the trend chart's Labor series. Wraps `WO List - Total Labor` (see [Work Order Details](#work-order-details)) rather than the now-deleted `Labor $$ (Filtered)` — see the note under `Avg Labor $ / Inspection (Rolling 12)` below for why.

---

### Avg Parts $ / Inspection (Rolling 12)

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

DIVIDE([Parts $ Total (Filtered)], [Total Inspections], 0)
```

Renamed from `Avg Parts $ / Inspection (Rolling 24)` this session (Desktop Model-view rename, auto-propagated to all references) to match the chart/card's window change from rolling 24 months to rolling 12 months.

---

### Avg Labor $ / Inspection (Rolling 12)

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

DIVIDE([WO List - Total Labor], [Total Inspections], 0)
```

Renamed from `Avg Labor $ / Inspection (Rolling 24)` this session, same as above. Also **repointed from `Labor $$ (Filtered)` to `WO List - Total Labor`** — a design decision (not a bug fix): `Labor $$ (Filtered)` excluded the inspection line's own labor charge, a definition built for a different, Home-page revenue-breakdown context. Per Brian/Casey's explicit choice, the trend view now matches the Details page matrix's own Labor definition instead (`WO List - Total Labor` — includes everything, already filter-context-safe via its own `ISFILTERED()` branching, and touches only one fact table so there's no bridging risk). `Labor $$ (Filtered)` was deleted as no longer used anywhere.

---

### Avg Parts $ / Inspection (Rolling 12) LY

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    [Avg Parts $ / Inspection (Rolling 12)],
    DATEADD( dim_DateTable[Date], -1, YEAR )
)
```

New this session — feeds the KPI card's Parts stat as a secondary "reference" label (the modern Card visual supports a reference value per field) showing last year's same-period average.

---

### Avg Labor $ / Inspection (Rolling 12) LY

**Format:** `\$#,0.00;(\$#,0.00);\$#,0.00`

**DAX:**
```dax

CALCULATE(
    [Avg Labor $ / Inspection (Rolling 12)],
    DATEADD( dim_DateTable[Date], -1, YEAR )
)
```

New this session — same purpose as above, for the KPI card's Labor stat.

---