# TMDL Fix - Round 2 (After Power BI Overwrite)

## What Happened

When Power BI Desktop was open during the first fix, it overwrote the corrected TMDL file when you closed it, reverting back to the broken formatting.

## The Key Issues Fixed (Again)

### Issue 1: Missing Quotes on formatString

**WRONG (causes errors):**
```tmdl
formatString: \$#,0.00;(\$#,0.00);\$#,0.00    ← No quotes!
formatString: #,##0                           ← No quotes!
formatString: 0                               ← No quotes!
```

**CORRECT:**
```tmdl
formatString: "\$#,0.00;(\$#,0.00);\$#,0.00"  ← Quotes added
formatString: "#,##0"                         ← Quotes added
formatString: "0"                             ← Quotes added
```

**Why it matters:** TMDL requires quotes around ALL formatString values. Without quotes, Power BI can't parse the format.

### Issue 2: Multi-line Measures Without Triple Backticks

**WRONG:**
```tmdl
measure 'Margin Value %' =
		DIVIDE(
		    [Actual Margin $],
		    [Sale $],
		    0
		)
		formatString: "0.00%;-0.00%;0.00%"
```

**CORRECT (Simple - collapsed to single line):**
```tmdl
measure 'Margin Value %' = DIVIDE([Actual Margin $], [Sale $], 0)
		formatString: "0.00%;-0.00%;0.00%"
```

**CORRECT (Complex - needs backticks):**
```tmdl
measure '% Difference' = ```
		DIVIDE(
		    ([MDP Value] - [Inventory Cost]),
		    ([MDP Value] + [Inventory Cost]) / 2,
		    0
		)
		```
		formatString: "0.0%;-0.0%;0.0%"
```

### Issue 3: Multi-line Measures Missing Opening Backticks

**WRONG:**
```tmdl
measure 'Margin Color Code' =
		SWITCH(
		    TRUE(),
		    [Margin Value %] < 0, 1,
		    BLANK()
		)
		formatString: 0
```

**CORRECT:**
```tmdl
measure 'Margin Color Code' = ```
		SWITCH(
		    TRUE(),
		    [Margin Value %] < 0, 1,
		    BLANK()
		)
		```
		formatString: "0"
```

### Issue 4: Inconsistent Line Breaks

**WRONG:**
```tmdl
measure 'Total SOH Qty' =
		SUM(dim_Parts_LowMargin[OnHandQty])
		formatString: "#,##0"
		lineageTag: total-soh-qty-measure
```

**CORRECT:**
```tmdl
measure 'Total SOH Qty' = SUM(dim_Parts_LowMargin[OnHandQty])
		formatString: "#,##0"
		lineageTag: total-soh-qty-measure
```

## All Measures Fixed (30 Total)

### ✅ Simple Measures (Single Line)
1. Home - Header (complex HTML, kept as-is)
2. Sale $
3. Cost $
4. Qty
5. Actual Margin $
6. Original Margin $
7. Margin Discrepancy $
8. **Margin Value %** (collapsed from multi-line)
9. **Original Margin %** (collapsed from multi-line)
10. Total SOH Qty
11. Inventory Cost
12. MDP Value
13. Sell Price
14. List Price
15. Stock Order Price
16. Sell Value
17. Desired Margin $
18. **Desired Margin %** (collapsed from multi-line)
19. Actual Margin $ (INV)
20. **Actual Margin % (INV)** (collapsed from multi-line)
21. Net Margin $ Discrepancy
22. Total Transactions

### ✅ Complex Measures (Triple Backticks)
23. **Margin Color Code** (added backticks)
24. **Margin $ Discrepancy Color Code** (added backticks)
25. **% Difference** (added backticks)
26. **% Diff Discr (Low) Color Code** (added backticks)
27. **Positive Margin $ Discrepancy** (added backticks)
28. **Negative Margin $ Discrepancy** (added backticks)
29. **Type Check** (added backticks)
30. **Margin Calc Check** (added backticks)

## Key Changes Made

| Issue | Count | Fix Applied |
|-------|-------|-------------|
| Missing quotes on formatString | ~25 | Added quotes to all formatString values |
| Multi-line simple DIVIDE() | 4 | Collapsed to single line |
| Missing triple backticks | 8 | Added ``` for complex measures |
| Unnecessary line breaks | ~15 | Removed line breaks for simple measures |

## IMPORTANT: How to Avoid This in the Future

**CRITICAL RULE:**
> **ALWAYS close Power BI Desktop BEFORE editing TMDL files!**

**Why?**
- Power BI Desktop maintains a lock on TMDL files
- When you close Power BI, it writes its in-memory model back to TMDL
- This OVERWRITES any manual changes you made to the TMDL files
- Even if you saved the TMDL file, Power BI will overwrite it on close

**Correct Workflow:**
1. ✅ Close Power BI Desktop completely
2. ✅ Edit TMDL files in text editor
3. ✅ Save TMDL files
4. ✅ Open Power BI Desktop
5. ✅ Power BI loads the updated TMDL files

**WRONG Workflow:**
1. ❌ Open Power BI Desktop
2. ❌ Edit TMDL files while Power BI is open
3. ❌ Save TMDL files
4. ❌ Close Power BI Desktop ← **THIS OVERWRITES YOUR CHANGES!**

## Verification Checklist

After opening Power BI Desktop with these fixes:

- [ ] All 30 measures appear in _Measures table
- [ ] No red error icons on any measures
- [ ] Simple measures (like Sale $, Cost $) calculate correctly
- [ ] Complex measures (like Margin Color Code) calculate correctly
- [ ] Format strings display correctly (currency shows $, percentages show %)
- [ ] Test a Card visual with 3-4 different measures

## What to Do If Errors Still Appear

If you still see errors after applying this fix:

1. **Close Power BI Desktop again**
2. **Check the TMDL file** - verify quotes are present on ALL formatString values
3. **Check for backticks** - complex measures need ``` at start and end
4. **Look for the specific error message** - it will tell you which measure and what's wrong
5. **Compare to working measure** - look at Home - Header measure (line 4-79) as a working example

## Files Modified

- ✅ `_Measures.tmdl` - All 30 measures fixed and formatted correctly

## Status

✅ **ALL MEASURES FIXED (ROUND 2)**
✅ **Power BI Desktop was CLOSED during edits**
✅ **Ready to open and test**

**Next Step:** Open Power BI Desktop and verify all measures load without errors.

---

**Lesson Learned:** Always close Power BI Desktop before editing TMDL files manually! Power BI will overwrite your changes on exit.
