---
name: add-measure
description: Add a DAX measure to a live report's semantic model in fabric-workspace-docs/workspaces/RP - Dev. Reads the model's existing measures first, writes TMDL that follows the repo's conventions, and lists what to test. Use when Brian asks to add or write a measure, or runs /add-measure.
argument-hint: "[report name] [what the measure should calculate]"
allowed-tools: Read, Glob, Grep, Bash, Edit
---

Add a measure. Request: **$ARGUMENTS**

Live report definitions are in `C:/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/`, not in data-projects (`projects/*/reports/` folders are frozen pre-DP copies). The full report workflow is in that repo's `docs/REPORT-DEVELOPMENT.md`.

## 1. Preconditions
- fabric-workspace-docs is on `dev` (`git -C <repo> branch --show-current`).
- **Ask Brian to confirm Power BI Desktop is closed for this report.** Desktop overwrites TMDL edited while it is open.

## 2. Find the model and read it
- Model: `RP - Dev/<Report>.SemanticModel/definition/`. Measures usually live in `tables/_Measures.tmdl` (some models use `MeasuresTable.tmdl` or a themed measures table). Grep `^\tmeasure` if unsure.
- Read the whole measures file: naming style, `formatString`s, `displayFolder`s, recurring patterns.
- Grep the model for measures and columns the new one will reference. Confirm exact table and column names in `tables/*.tmdl`. Don't guess.
- If the meaning of a business term is unclear, check `fabric-workspace-docs/docs/BUSINESS-GLOSSARY.md` before asking.

## 3. Write the measure
~~~
	/// What the measure calculates, in one plain sentence
	measure 'Measure Name' = ```
			<DAX>
			```
		formatString: #,0
		displayFolder: Folder Name
~~~
- **Description = a `///` line directly above `measure`.** There is no `description:` property, and TMDL has no `//` comment lines (DAX `//` inside the expression is fine).
- Measure references take no inner quotes: `[Total Sales]`, never `['Total Sales']`.
- Format strings: `"$#,0.00"` currency, `"0.0%"` percent, `"#,0"` counts.
- Return `BLANK()`, not 0, where there's no data.
- Iterating aggregations: `SUMX(VALUES(...), CALCULATE(...))`.
- Cross-table flags: `LOOKUPVALUE` on a calculated column, not a new relationship. No bidirectional relationships.
- "Today-relative" date logic is report DAX off `'Data Refresh'[Date]` (dim_DateTable has no such columns).
- Keep the file UTF-8 **without BOM**, with its existing line endings and tab indentation.

## 4. Check
- The PostToolUse TMDL validator hook runs on save. Fix anything it reports.
- If Desktop or XMLA access is available, test the DAX with `pbi dax execute` before Brian opens the report.

## 5. Hand off
- Stage only the measures file: `git -C <fabric-workspace-docs> add "<path>"`. Commit to `dev` only when Brian asks.
- Tell Brian what to check in Desktop: the value for one branch against a known number, behaviour under the branch and date slicers, and blanks where there's no data.
- The release path (RP - Dev sync → Sandbox → production) is in `docs/REPORT-DEVELOPMENT.md`.
