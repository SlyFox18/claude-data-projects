# Page 2: Inventory Cost Discrepancy - Field Mapping

## Page Overview

**Purpose**: Identify parts where inventory cost differs from Manufacturer's Dealer Price (MDP), indicating potential pricing issues or inventory valuation discrepancies.

**Business Value**:
- Positive discrepancy = Inventory cost is LOWER than MDP (good - better margin than expected)
- Negative discrepancy = Inventory cost is HIGHER than MDP (bad - worse margin than expected)

---

## Top KPI Cards (3 cards)

### Card 1: + Margin $ Discrepancy
**Old Report Value**: $1.43M

**Measure to Use**:
```dax
[Positive Margin $ Discrepancy]
```

**What it shows**: Total dollar amount where actual margin is BETTER than desired margin (inventory cost < MDP value)

**Formatting**: Currency, $#,0.00K or $#,0.00M

---

### Card 2: - Margin $ Discrepancy
**Old Report Value**: ($10.49K)

**Measure to Use**:
```dax
[Negative Margin $ Discrepancy]
```

**What it shows**: Total dollar amount where actual margin is WORSE than desired margin (inventory cost > MDP value)

**Formatting**: Currency, $#,0.00K, show negative in parentheses

**Note**: This is already negative, so display as-is

---

### Card 3: Net Margin $
**Old Report Value**: $1.42M

**Measure to Use**:
```dax
[Net Margin $ Discrepancy]
```

**What it shows**: Net difference (Positive + Negative). Overall impact on margins.

**Formatting**: Currency, $#,0.00M

---

## Main Table Configuration

### Dimension/Grouping Columns (Left side)

| Column # | Display Name | Source | Description |
|----------|--------------|--------|-------------|
| 1 | BR | `dim_Parts_LowMargin[Branch]` | Branch code |
| 2 | FR | `dim_Parts_LowMargin[Franchise]` | Franchise code |
| 3 | Part No | `dim_Parts_LowMargin[PartNumber]` | Part number |
| 4 | Description | *Need to add* | Part description (from dim_Parts or Fact_InTrans) |

**Note**: Description column is missing. Need to add relationship to dim_Parts or use RELATED/LOOKUPVALUE.

---

### Measure Columns (Right side)

| Column # | Display Name | Measure | Format | Description |
|----------|--------------|---------|--------|-------------|
| 5 | Total SOH Qty | `[Total SOH Qty]` | #,##0 | Quantity on hand + bulk bin |
| 6 | Inventory Cost | `[Inventory Cost]` | $#,0.00 | Total inventory cost (SOH × unit cost) |
| 7 | MDP Value | `[MDP Value]` | $#,0.00 | Manufacturer Dealer Price × SOH |
| 8 | Sell Price 1 Value | `[Sell Value]` | $#,0.00 | Sell Price 1 × SOH |
| 9 | Desired Margin % (MDP) | `[Desired Margin %]` | 0.0% | (Sell Value - MDP Value) / Sell Value |
| 10 | Actual Margin % (INV Cost) | `[Actual Margin % (INV)]` | 0.0% | (Sell Value - Inventory Cost) / Sell Value |
| 11 | Desired Margin $ (MDP) | `[Desired Margin $]` | $#,0.00 | Sell Value - MDP Value |
| 12 | Actual Margin $ (INV Cost) | `[Actual Margin $ (INV)]` | $#,0.00 | Sell Value - Inventory Cost |
| 13 | Margin $ Discrepancy | *Calculated column* | $#,0.00 | Actual Margin $ - Desired Margin $ |
| 14 | Low | `[LowMarginFlag]` or filter | "LOW" | Low margin flag indicator |
| 15 | New Sell Price | *Needs creation* | $#,0.00 | Suggested sell price to achieve target margin? |

---

## Measure for Column 13: Margin $ Discrepancy (Per Row)

This is **NOT** the Positive/Negative measures (those are totals). This is per-row discrepancy:

```dax
Margin $ Discrepancy (Row) = [Actual Margin $ (INV)] - [Desired Margin $]
```

**Interpretation**:
- **Positive value** (green): Inventory cost is lower than MDP = better margin
- **Negative value** (red): Inventory cost is higher than MDP = worse margin

---

## Conditional Formatting

### Column 10: Actual Margin % (INV Cost)
- **Orange/Red highlight** when value is LOW (< 15% typically)
- Matches the "14.1%" highlighted rows in screenshot

### Column 13: Margin $ Discrepancy
- **Dark red** when negative and large (< -$10)
- Shows significant inventory cost vs MDP discrepancies

Use the existing `[% Diff Discr (Low) Color Code]` measure for color coding:
```dax
'% Diff Discr (Low) Color Code' =
    SWITCH(
        TRUE(),
        [% Difference] >= 0, 1,                              // Green - good
        [% Difference] <= -0.000001 && [% Difference] > -0.05, 2,   // Light concern
        [% Difference] <= -0.051 && [% Difference] > -0.1, 3,       // Moderate
        [% Difference] <= -0.10 && [% Difference] > -0.15, 8,       // Significant
        [% Difference] <= -0.15, 4,                          // Critical
        BLANK()
    )
```

---

## Filters Applied (Likely)

Based on the old report and page purpose:

1. **Branch slicer** - Filter by specific branches (01-Seminole selected in screenshot)
2. **Parts with inventory** - `[Total SOH Qty] > 0`
3. **Possibly**: Only show parts with discrepancies (optional)

---

## Missing Components to Add

### 1. Description Column
**Issue**: dim_Parts_LowMargin doesn't have Description

**Solution Option A**: Add calculated column to dim_Parts_LowMargin
```dax
Description = RELATED(dim_Parts[Description])
```

**Solution Option B**: Create measure
```dax
Part Description =
    SELECTEDVALUE(dim_Parts[Description],
    SELECTEDVALUE(Fact_InTrans[Description], ""))
```

**Recommended**: Option B (measure) - more flexible

---

### 2. New Sell Price Column (Optional)

If this column shows a **suggested new sell price** to achieve target margin:

```dax
Suggested Sell Price =
    VAR TargetMargin = 0.15  // 15% target margin
    VAR UnitInventoryCost = DIVIDE([Inventory Cost], [Total SOH Qty], 0)
    VAR SuggestedPrice = DIVIDE(UnitInventoryCost, (1 - TargetMargin), 0)
    RETURN SuggestedPrice
```

Or if it's just the current Sell Price 1:
```dax
New Sell Price = [Sell Price]
```

---

## Step-by-Step Recreation

1. **Create 3 KPI cards** at top:
   - Card 1: `[Positive Margin $ Discrepancy]`
   - Card 2: `[Negative Margin $ Discrepancy]`
   - Card 3: `[Net Margin $ Discrepancy]`

2. **Create table visual** with columns in this order:
   - BR, FR, Part No, Description (measure)
   - Total SOH Qty, Inventory Cost, MDP Value, Sell Price 1 Value
   - Desired Margin % (MDP), Actual Margin % (INV Cost)
   - Desired Margin $ (MDP), Actual Margin $ (INV Cost)
   - Margin $ Discrepancy (new measure)
   - Low (dim_Parts_LowMargin[LowMarginFlag])
   - New Sell Price (TBD)

3. **Add conditional formatting**:
   - Actual Margin % (INV Cost): Background color by value (< 15% = red/orange)
   - Margin $ Discrepancy: Background color by `[% Diff Discr (Low) Color Code]`

4. **Add slicers**:
   - Branch
   - Possibly Franchise
   - Possibly Low Margin Flag

5. **Add table filter**:
   - `[Total SOH Qty] > 0` (only show parts with inventory)

---

## Validation

Compare these totals between old and new reports:
- Total Positive Margin $ Discrepancy = $1.43M ✓
- Total Negative Margin $ Discrepancy = ($10.49K) ✓
- Net Margin $ = $1.42M ✓

If these match, the page is correctly configured.

---

## Additional Measures Needed

### Margin $ Discrepancy (Row Level)
```dax
Margin $ Discrepancy (Row) = [Actual Margin $ (INV)] - [Desired Margin $]
```

### Part Description (Measure)
```dax
Part Description =
    VAR FromDimParts = CALCULATE(
        SELECTEDVALUE(dim_Parts[Description]),
        USERELATIONSHIP(dim_Parts[PartNumber], dim_Parts_LowMargin[PartNumber])
    )
    VAR FromFactInTrans = SELECTEDVALUE(Fact_InTrans[Description])
    RETURN
    IF(
        FromDimParts <> BLANK(),
        FromDimParts,
        FromFactInTrans
    )
```

---

## Questions to Clarify

1. **What is "New Sell Price"?**
   - Is it a suggested price to achieve target margin?
   - Or is it just the current Sell Price 1?

2. **Should table be filtered by default?**
   - Only show parts with discrepancies > $X?
   - Only show LOW margin flagged parts?
   - Or show all parts with SOH > 0?

3. **What branches should be included by default?**
   - All branches or specific selection?
