# How to Add DAX Measures via TMDL File

## What is TMDL?

**Tabular Model Definition Language (TMDL)** is the text-based file format that Power BI uses to store semantic model definitions. By editing TMDL files directly, you can add multiple measures at once instead of creating them one-by-one in Power BI Desktop.

---

## Why Use TMDL Instead of Power BI UI?

**Manual Method (Power BI Desktop):**
- Create 25+ measures one at a time
- Type each formula manually
- Set format strings individually
- Time required: 30-45 minutes
- Error-prone (typos, copy/paste mistakes)

**TMDL Method (Direct File Edit):**
- Copy/paste all 25+ measures at once
- All formatting already included
- Time required: 2-3 minutes
- Less error-prone (all code pre-written)

**Result:** TMDL is 10-15x faster!

---

## Step-by-Step Instructions

### Step 1: Close Power BI Desktop

**CRITICAL:** You MUST close Power BI Desktop before editing TMDL files.

- Save your work in Power BI Desktop
- File > Exit
- Confirm all Power BI Desktop windows are closed

**Why?**
- Power BI locks TMDL files when open
- Changes won't be recognized if file is open
- Could cause file corruption if edited while open

### Step 2: Navigate to TMDL File Location

Open File Explorer and navigate to:
```
c:\Users\bfox\Documents\Git-Projects\data-projects\projects\part sales with low margin\reports\current\Part Sales with Low Margin.SemanticModel\definition\tables\
```

You should see a file named: `_Measures.tmdl`

### Step 3: Open TMDL File in Text Editor

**Recommended editors:**
- Visual Studio Code (best - syntax highlighting)
- Notepad++ (good)
- Windows Notepad (works, but basic)

Right-click `_Measures.tmdl` > Open With > Choose your editor

### Step 4: Locate Insertion Point

Find line 79 in `_Measures.tmdl`. It should look like this:

```tmdl
	```
	lineageTag: 49efea2a-3c06-4cab-8367-26b26caa141e

column Value
```

**Insertion point:** Between line 79 (ending ```) and line 81 (`column Value`)

You will paste the measures ABOVE `column Value`.

### Step 5: Copy DAX Measures from TMDL File

Open this file in another window:
```
c:\Users\bfox\Documents\Git-Projects\data-projects\projects\part sales with low margin\DAX-MEASURES-TMDL.txt
```

**Copy lines 10 through 254** (everything from first `measure` to last `measure`)

**Start at line 10:**
```tmdl
	// ========================================================================
	// TRANSACTION SALES MEASURES (Page 1: Parts Sales with Low Margins)
	// ========================================================================
```

**End at line 254:**
```tmdl
	lineageTag: margin-calc-check-measure
```

**DO NOT copy:**
- Lines 1-9 (header comments)
- Lines 256-270 (footer comments)

### Step 6: Paste Measures into _Measures.tmdl

1. Click at the end of line 79 (after the closing ```)
2. Press Enter to create a new blank line
3. Paste the copied measures
4. You should now have:
   - Line 79: `lineageTag: 49efea2a-3c06-4cab-8367-26b26caa141e`
   - Line 80: blank line
   - Line 81: First measure comment line
   - Lines 82-300+: All your measures
   - Last line before `column Value`: Last measure lineageTag

### Step 7: Verify Formatting

**Check for these common issues:**

1. **Indentation:** All measures should use TABS, not spaces
   - Each measure line starts with one TAB character
   - Sub-lines (formatString, lineageTag) start with two TABs

2. **No extra blank lines** between measures
   - Each measure flows directly into the next
   - Blank lines only between comment sections

3. **Backticks for multi-line formulas:**
   - Complex measures use triple backticks: ` ``` `
   - Should appear BEFORE the formula and AFTER the closing paren
   - Example:
   ```tmdl
   measure 'Margin Color Code' = ```
       SWITCH(
           TRUE(),
           [Margin Value %] < 0, 1,
           BLANK()
       )
       ```
   ```

### Step 8: Save the File

- File > Save (or Ctrl+S)
- Close the text editor
- Verify file size increased (should be ~15-20 KB larger)

### Step 9: Reopen Power BI Desktop

1. Open Power BI Desktop
2. File > Open > Navigate to:
   ```
   c:\Users\bfox\Documents\Git-Projects\data-projects\projects\part sales with low margin\reports\current\Part Sales with Low Margin.pbip
   ```
3. Wait for model to load (30-60 seconds)

**What should happen:**
- Power BI reads the updated `_Measures.tmdl` file
- Loads all new measures into the model
- No errors or warnings

### Step 10: Verify Measures Loaded

1. Switch to **Report** view
2. Open **Fields** pane (right side)
3. Expand `_Measures` table
4. You should see all new measures listed

**Expected measures (25 total):**
- Home - Header (existing - don't delete)
- Sale $
- Cost $
- Qty
- Actual Margin $
- Original Margin $
- Margin Discrepancy $
- Margin Value %
- Original Margin %
- Margin Color Code
- Margin $ Discrepancy Color Code
- Total SOH Qty
- Inventory Cost
- MDP Value
- Sell Price
- List Price
- Stock Order Price
- Sell Value
- Desired Margin $
- Desired Margin %
- Actual Margin $ (INV)
- Actual Margin % (INV)
- % Difference
- % Diff Discr (Low) Color Code
- Positive Margin $ Discrepancy
- Negative Margin $ Discrepancy
- Net Margin $ Discrepancy
- Total Transactions
- Type Check
- Margin Calc Check

### Step 11: Test a Measure

Create a **Card** visual and test one measure:

1. Click blank space on canvas
2. Visualizations pane > Click **Card** visual
3. Drag `Sale $` from _Measures to the card
4. Card should show a dollar value (not an error)

**If you see a dollar value:** ✅ Success! Measures loaded correctly

**If you see an error:** ❌ See Troubleshooting section below

---

## Troubleshooting

### Error: "Measure references a column that doesn't exist"

**Cause:** Fact_InTrans or dim_Parts_LowMargin tables missing columns

**Fix:**
1. Verify Fact_InTrans has these calculated columns:
   - LowMarginFlag
   - IsLowMarginFlagged
   - StockOrderPrice
   - ListPriceManuf
   - OriginalMarginDollars
   - MarginDiscrepancyDollars

2. Verify dim_Parts_LowMargin has these columns:
   - OnHandQty (calculated)
   - InventoryCost
   - StockOrderPrice
   - SellPrice1
   - ListPrice
   - BulkBinQty

### Error: "The file is locked"

**Cause:** Power BI Desktop is still open

**Fix:**
1. Close ALL Power BI Desktop windows
2. Check Task Manager - end any `PBIDesktop.exe` processes
3. Try editing TMDL file again

### Error: "Syntax error in TMDL file"

**Cause:** Formatting issue in pasted measures

**Common issues:**
1. Missing TAB indentation
2. Missing backticks around multi-line formulas
3. Extra blank lines
4. Mixed tabs and spaces

**Fix:**
1. Compare your `_Measures.tmdl` to the sample below
2. Ensure all measures use TAB indentation (not spaces)
3. Check backticks on complex measures (Margin Color Code, % Difference, etc.)

### Error: Measures don't appear in Fields pane

**Cause:** Changes not saved or Power BI didn't reload

**Fix:**
1. Verify `_Measures.tmdl` file was saved
2. Close and reopen Power BI Desktop
3. Check Model view > right-click Tables > Refresh All

---

## Sample TMDL Structure (for reference)

Your `_Measures.tmdl` should look like this after pasting:

```tmdl
table _Measures
	lineageTag: 22e4b9e3-99b6-4634-9836-9ade5a5ea5a5

	measure 'Home - Header' = ```

			// Get user name
			VAR _User = USERPRINCIPALNAME()
			...
		```
		lineageTag: 49efea2a-3c06-4cab-8367-26b26caa141e

	// ========================================================================
	// TRANSACTION SALES MEASURES (Page 1: Parts Sales with Low Margins)
	// ========================================================================

	measure 'Sale $' = SUM(Fact_InTrans[SaleValue])
		formatString: "\$#,0.00;(\$#,0.00);\$#,0.00"
		lineageTag: sale-dollars-measure

	measure 'Cost $' = SUM(Fact_InTrans[CostValue])
		formatString: "\$#,0.00;(\$#,0.00);\$#,0.00"
		lineageTag: cost-dollars-measure

	... [more measures] ...

	column Value
		isHidden
		lineageTag: da2dfa23-0c4c-4e9d-8014-3cc5710e756b
		summarizeBy: none
		isNameInferred
		sourceColumn: [Value]

		annotation SummarizationSetBy = Automatic

	partition _Measures = calculated
		mode: import
		source = { "This table holds all measures for the Parts Reorder Monitoring report" }

	annotation PBI_Id = da82ad85df114f0dbe8c17ce73f079a8
```

**Key points:**
- `measure 'Home - Header'` stays at top (existing measure)
- New measures go AFTER 'Home - Header' measure
- New measures go BEFORE `column Value`
- All measures use TAB indentation
- Each measure has `formatString` and `lineageTag`

---

## Alternative: Manual Measure Creation

If TMDL method doesn't work for any reason, you can create measures manually:

1. Open Power BI Desktop
2. Switch to **Report** view
3. Right-click `_Measures` table > **New Measure**
4. Copy formula from `DAX-MEASURES-TMDL.txt`
5. Paste into formula bar
6. Press Enter
7. Right-click measure > **Format** > set format string
8. Repeat for all 25+ measures

**Time required:** 30-45 minutes

---

## Summary

**TMDL Method (Recommended):**
1. ✅ Close Power BI Desktop
2. ✅ Open `_Measures.tmdl` in text editor
3. ✅ Copy lines 10-254 from `DAX-MEASURES-TMDL.txt`
4. ✅ Paste ABOVE `column Value` line
5. ✅ Save file
6. ✅ Reopen Power BI Desktop
7. ✅ Verify measures appear in Fields pane
8. ✅ Test with a Card visual

**Time:** 2-3 minutes
**Error Rate:** Low (pre-written code)
**Recommended For:** Adding 10+ measures at once

---

**Questions?** See [IMPLEMENTATION-GUIDE-FINAL.md](IMPLEMENTATION-GUIDE-FINAL.md) for complete walkthrough.
