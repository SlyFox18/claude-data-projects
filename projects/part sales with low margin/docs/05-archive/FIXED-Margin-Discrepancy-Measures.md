# FIXED: Margin Discrepancy Measures to Match Old Report

## Root Cause

The old report uses a **measure reference** inside ADDCOLUMNS:
```dax
ADDCOLUMNS(
    'Parts_Low_Margin_jdis_InMaster',
    "MarginDiscrepancy", [Margin $ Discrepancy]  // ← Measure
)
```

The new report calculates it **inline**:
```dax
ADDCOLUMNS(
    dim_Parts_LowMargin,
    "MarginDiscrepancy", [Actual Margin $ (INV)] - [Desired Margin $]  // ← Inline
)
```

**Issue**: The inline calculation doesn't properly evaluate in row context when filters are applied.

## Solution: Create Base Measure + Update KPI Measures

### Step 1: Create Missing Base Measure

Add this measure to `_Measures` table:

```dax
Margin $ Discrepancy = [Actual Margin $ (INV)] - [Desired Margin $]
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

This measure will:
- Be used in the table as a column
- Be referenced in the Positive/Negative measures
- Properly respect filter context

---

### Step 2: Update Positive Margin $ Discrepancy

**Replace current measure** with:

```dax
Positive Margin $ Discrepancy =
SUMX(
    FILTER(
        ADDCOLUMNS(
            dim_Parts_LowMargin,
            "MarginDiscrepancy", [Margin $ Discrepancy]
        ),
        [MarginDiscrepancy] > 0
    ),
    [MarginDiscrepancy]
)
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

**Key change**: Reference `[Margin $ Discrepancy]` measure instead of inline calculation.

---

### Step 3: Update Negative Margin $ Discrepancy

**Replace current measure** with:

```dax
Negative Margin $ Discrepancy =
SUMX(
    FILTER(
        ADDCOLUMNS(
            dim_Parts_LowMargin,
            "MarginDiscrepancy", [Margin $ Discrepancy]
        ),
        [MarginDiscrepancy] < 0
    ),
    [MarginDiscrepancy]
)
```

**Format**: `$#,0.00;($#,0.00);$#,0.00`

**Key change**: Reference `[Margin $ Discrepancy]` measure instead of inline calculation.

---

### Step 4: Net Margin $ Discrepancy (Already Correct)

This measure is already correct:

```dax
Net Margin $ Discrepancy = [Positive Margin $ Discrepancy] + [Negative Margin $ Discrepancy]
```

No changes needed.

---

## How to Apply in Power BI Desktop

### Option A: Edit TMDL Directly (Recommended)

1. **Close Power BI Desktop** (critical!)
2. Open `_Measures.tmdl` in text editor
3. Add the new `Margin $ Discrepancy` measure (around line 188, after `% Difference`)
4. Update `Positive Margin $ Discrepancy` (line 210)
5. Update `Negative Margin $ Discrepancy` (line 224)
6. Save file
7. Open Power BI Desktop

### Option B: Edit in Power BI Desktop

1. Open Power BI Desktop
2. Go to Data view
3. Select `_Measures` table
4. Click "New measure" and add:
   ```dax
   Margin $ Discrepancy = [Actual Margin $ (INV)] - [Desired Margin $]
   ```
5. Edit `Positive Margin $ Discrepancy` measure (replace inline calc with measure reference)
6. Edit `Negative Margin $ Discrepancy` measure (replace inline calc with measure reference)
7. Save report

---

## Complete TMDL Code Block

Here's the complete section to add/replace in `_Measures.tmdl`:

```tmdl
measure '% Difference' =
        DIVIDE(
            ([MDP Value] - [Inventory Cost]),
            ([MDP Value] + [Inventory Cost]) / 2,
            0
        )
    formatString: "0.0%;-0.0%;0.0%"
    lineageTag: pct-difference-measure

measure '% Diff Discr (Low) Color Code' =
        SWITCH(
            TRUE(),
            [% Difference] >= 0, 1,
            [% Difference] <= -0.000001 && [% Difference] > -0.05, 2,
            [% Difference] <= -0.051 && [% Difference] > -0.1, 3,
            [% Difference] <= -0.10 && [% Difference] > -0.15, 8,
            [% Difference] <= -0.15, 4,
            BLANK()
        )
    formatString: "0"
    lineageTag: pct-diff-color-code-measure

measure 'Margin $ Discrepancy' = [Actual Margin $ (INV)] - [Desired Margin $]
    formatString: "\$#,0.00;(\$#,0.00);\$#,0.00"
    lineageTag: margin-discrepancy-measure

measure 'Positive Margin $ Discrepancy' =
        SUMX(
            FILTER(
                ADDCOLUMNS(
                    dim_Parts_LowMargin,
                    "MarginDiscrepancy", [Margin $ Discrepancy]
                ),
                [MarginDiscrepancy] > 0
            ),
            [MarginDiscrepancy]
        )
    formatString: "\$#,0.00;(\$#,0.00);\$#,0.00"
    lineageTag: positive-margin-discrepancy-measure

measure 'Negative Margin $ Discrepancy' =
        SUMX(
            FILTER(
                ADDCOLUMNS(
                    dim_Parts_LowMargin,
                    "MarginDiscrepancy", [Margin $ Discrepancy]
                ),
                [MarginDiscrepancy] < 0
            ),
            [MarginDiscrepancy]
        )
    formatString: "\$#,0.00;(\$#,0.00);\$#,0.00"
    lineageTag: negative-margin-discrepancy-measure

measure 'Net Margin $ Discrepancy' = [Positive Margin $ Discrepancy] + [Negative Margin $ Discrepancy]
    formatString: "\$#,0.00;(\$#,0.00);\$#,0.00"
    lineageTag: net-margin-discrepancy-measure
```

---

## Why This Fixes It

### Before (Broken):
```dax
ADDCOLUMNS(
    dim_Parts_LowMargin,
    "MarginDiscrepancy", [Actual Margin $ (INV)] - [Desired Margin $]
    // ↑ Inline calculation evaluates outside filter context
)
```

### After (Fixed):
```dax
ADDCOLUMNS(
    dim_Parts_LowMargin,
    "MarginDiscrepancy", [Margin $ Discrepancy]
    // ↑ Measure reference evaluates in row context WITH filter context
)
```

When you reference a measure inside ADDCOLUMNS, DAX evaluates it for each row WITH the current filter context (branch, franchise, etc.).

When you calculate inline with other measures, DAX might evaluate them at a different scope, ignoring filters.

---

## Expected Results After Fix

**KPI Cards** (Branch 1, Franchise <> 'S'):
- Positive Margin $ Discrepancy ≈ $1.43M
- Negative Margin $ Discrepancy ≈ ($10.48K)
- Net Margin $ Discrepancy ≈ $1.42M

**Table Row Count**:
- ~70+ rows with LOW flag

---

## Additional Note: Table Column

For the table visual, you should also use the new `[Margin $ Discrepancy]` measure directly instead of creating a "Row" version. The measure will automatically evaluate per row in table context.

**Table Visual Columns** should include:
- Branch, Franchise, PartNumber, Part Description
- Total SOH Qty, Inventory Cost, MDP Value, Sell Value
- Desired Margin %, Actual Margin % (INV)
- Desired Margin $, Actual Margin $ (INV)
- **`[Margin $ Discrepancy]`** ← Use this measure
- LowMarginFlag
- Sell Price
