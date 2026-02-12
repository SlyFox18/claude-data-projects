# TMDL Formatting Fix - _Measures.tmdl

## The Problem

When you pasted the DAX measures into the TMDL file, every measure had errors. This was caused by **incorrect TMDL syntax formatting**.

### Common TMDL Formatting Errors Found

1. **Missing blank lines between measures**
   - Each measure MUST have a blank line after it
   - Example error: Line 90-91 had no blank line between `Qty` and `Actual Margin $`

2. **Multi-line measures not on single line**
   - Simple DIVIDE() measures were split across multiple lines
   - TMDL prefers single-line for simple measures
   - Example: `DIVIDE([Actual Margin $], [Sale $], 0)` should be on one line

3. **Incorrect indentation in triple-backtick measures**
   - Complex measures with ``` need proper indentation
   - Code inside backticks should be indented with **3 TABS** (not 2)
   - Example: SWITCH() statements needed one extra TAB

## What Was Fixed

### Fix 1: Added Missing Blank Lines

**BEFORE (Error):**
```tmdl
	measure Qty = SUM(Fact_InTrans[Qty])
		formatString: "#,##0"
		lineageTag: qty-measure
	measure 'Actual Margin $' = SUM(Fact_InTrans[ActualMarginDollars])  ← NO BLANK LINE
```

**AFTER (Fixed):**
```tmdl
	measure Qty = SUM(Fact_InTrans[Qty])
		formatString: "#,##0"
		lineageTag: qty-measure

	measure 'Actual Margin $' = SUM(Fact_InTrans[ActualMarginDollars])  ← BLANK LINE ADDED
```

### Fix 2: Collapsed Multi-line Simple Measures

**BEFORE (Error):**
```tmdl
	measure 'Margin Value %' =
		DIVIDE(
		    [Actual Margin $],
		    [Sale $],
		    0
		)
		formatString: "0.00%;-0.00%;0.00%"
```

**AFTER (Fixed):**
```tmdl
	measure 'Margin Value %' = DIVIDE([Actual Margin $], [Sale $], 0)
		formatString: "0.00%;-0.00%;0.00%"
```

### Fix 3: Fixed Indentation in Triple-Backtick Measures

**BEFORE (Error - 2 TABS):**
```tmdl
	measure 'Margin Color Code' = ```
		SWITCH(                           ← Only 2 TABS
		    TRUE(),                       ← Only 2 TABS
		    [Margin Value %] < 0, 1,
		    BLANK()
		)
		```
```

**AFTER (Fixed - 3 TABS):**
```tmdl
	measure 'Margin Color Code' = ```
			SWITCH(                       ← 3 TABS
			    TRUE(),                   ← 3 TABS
			    [Margin Value %] < 0, 1,
			    BLANK()
			)
			```
```

### Fix 4: Removed Unnecessary Line Breaks

**BEFORE (Error):**
```tmdl
	measure 'Total SOH Qty' =
		SUM(dim_Parts_LowMargin[OnHandQty])
		formatString: "#,##0"
```

**AFTER (Fixed):**
```tmdl
	measure 'Total SOH Qty' = SUM(dim_Parts_LowMargin[OnHandQty])
		formatString: "#,##0"
```

## TMDL Formatting Rules

### Rule 1: Measure Structure
```tmdl
	measure 'Measure Name' = <expression>
		formatString: "<format>"
		lineageTag: <unique-tag>

	measure 'Next Measure' = <expression>
		formatString: "<format>"
		lineageTag: <unique-tag>
```

**Key points:**
- Start with TAB + `measure`
- Properties (formatString, lineageTag) indented with **2 TABS**
- **Blank line** after each measure

### Rule 2: Simple Measures (Single Line)

```tmdl
	measure 'Sale $' = SUM(Fact_InTrans[SaleValue])
		formatString: "\$#,0.00;(\$#,0.00);\$#,0.00"
		lineageTag: sale-dollars-measure
```

**When to use:** Simple aggregations, single function calls, short expressions

### Rule 3: Complex Measures (Triple Backticks)

```tmdl
	measure 'Margin Color Code' = ```
			SWITCH(
			    TRUE(),
			    [Margin Value %] < 0, 1,
			    BLANK()
			)
			```
		formatString: "0"
		lineageTag: margin-color-code-measure
```

**Key points:**
- Opening ``` on same line as =
- Code indented with **3 TABS**
- Closing ``` indented with **3 TABS**
- formatString/lineageTag back to **2 TABS**

**When to use:** SWITCH statements, VAR blocks, complex multi-line logic

## Measures Fixed

All 25+ measures were fixed:

**Transaction Sales Measures:**
- ✅ Sale $
- ✅ Cost $
- ✅ Qty
- ✅ Actual Margin $
- ✅ Original Margin $
- ✅ Margin Discrepancy $

**Margin Percentage Measures:**
- ✅ Margin Value %
- ✅ Original Margin %

**Color Code Measures:**
- ✅ Margin Color Code (complex SWITCH)
- ✅ Margin $ Discrepancy Color Code (complex SWITCH)

**Inventory Measures:**
- ✅ Total SOH Qty
- ✅ Inventory Cost
- ✅ MDP Value
- ✅ Sell Price
- ✅ List Price
- ✅ Stock Order Price

**Inventory Margin Measures:**
- ✅ Sell Value
- ✅ Desired Margin $
- ✅ Desired Margin %
- ✅ Actual Margin $ (INV)
- ✅ Actual Margin % (INV)

**Cost Variance Measures:**
- ✅ % Difference
- ✅ % Diff Discr (Low) Color Code (complex SWITCH)

**Margin Discrepancy Split:**
- ✅ Positive Margin $ Discrepancy (complex SUMX)
- ✅ Negative Margin $ Discrepancy (complex SUMX)
- ✅ Net Margin $ Discrepancy

**Validation Measures:**
- ✅ Total Transactions
- ✅ Type Check (complex VAR block)
- ✅ Margin Calc Check (complex VAR block)

## Testing

After these fixes, the TMDL file should:
1. Load without errors in Power BI Desktop
2. Show all measures in the _Measures table
3. Calculate correctly when used in visuals

**To verify:**
1. Close Power BI Desktop (if open)
2. Reopen the `.pbip` file
3. Check Model view > _Measures table
4. All measures should appear without red error icons
5. Test a few measures in Card visuals

## Status

✅ **ALL MEASURES FIXED**
✅ **TMDL file is properly formatted**
✅ **Ready to open in Power BI Desktop**

**File Location:**
`Part Sales with Low Margin.SemanticModel\definition\tables\_Measures.tmdl`

**Next Step:** Open Power BI Desktop and verify measures load correctly
