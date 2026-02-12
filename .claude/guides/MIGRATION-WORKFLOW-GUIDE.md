# Report Migration Workflow Guide

**Purpose:** Step-by-step guide for migrating reports from old lakehouse to new structure
**Last Updated:** 2026-01-15

---

## 📋 Migration Overview

**What We're Doing:**
Migrating a report from your old data lakehouse structure to the new standardized architecture with:
- Proper documentation
- Optimized refresh strategies
- Standardized naming conventions
- MCP server integration (where applicable)
- Skills automation

**Expected Benefits:**
- Better performance with optimized queries
- Complete documentation for future maintenance
- Standardized structure for team collaboration
- Automated validation and testing
- Integration with source database validation (if SQL Server MCP works)

---

## 🎯 Pre-Migration Checklist

Before starting tomorrow, gather this information:

### **About the Report:**
- [ ] Report name and .pbix file location
- [ ] Business purpose (what questions does it answer?)
- [ ] Department and business owner
- [ ] Current users and how they use it
- [ ] Current refresh schedule (if any)

### **About the Data:**
- [ ] What fact tables does it use?
- [ ] What dimensions does it use?
- [ ] What raw tables does it pull from?
- [ ] Any custom Power Query transformations?
- [ ] Any DAX measures you want to preserve?

### **Performance Questions:**
- [ ] How long does it currently take to refresh?
- [ ] How large is the dataset (row counts)?
- [ ] Any known performance issues?
- [ ] Does it need incremental refresh?

---

## 🔄 Migration Workflow

### **Phase 1: Analysis & Planning (30-60 minutes)**

**Step 1.1: Understand Current State**

```
Tasks:
1. Open the .pbix file in Power BI Desktop
2. Review Data Model:
   - What tables are in the model?
   - What relationships exist?
   - Are there any calculated columns? (should move to Power Query)
3. Review Queries (Power Query Editor):
   - Note all queries and their sources
   - Identify which are facts, dimensions, helpers
   - Check for hardcoded values or paths
4. Review Measures:
   - Note all DAX measures
   - Check for any that need optimization
5. Review Visualizations:
   - Note any special formatting or custom visuals
   - Check for any report-level filters
```

**Step 1.2: Map to New Structure**

Use this mapping template:

```markdown
## Migration Mapping

### Current Report: [Name]
**Location:** [Path to .pbix]
**Purpose:** [Business purpose]

### Tables Mapping:

| Old Table | Type | New Location | Notes |
|-----------|------|--------------|-------|
| [OldName] | Fact | .claude/queries/facts/ or project/queries/fact-tables/ | [Migration notes] |
| [OldName] | Dim | Check if exists in .claude/queries/dimensions/ | [Use existing or create?] |
| [OldName] | Raw | Check .claude/queries/raw-tables/ | [Already documented?] |

### Actions Needed:

**New Fact Tables to Create:**
- [ ] [FactName] - [Purpose]

**New Dimensions to Create:**
- [ ] [DimName] - [Purpose]

**Existing Dimensions to Use:**
- [ ] dim_DateTable
- [ ] dim_BranchLocation
- [ ] [Others]

**Raw Tables Status:**
- [ ] [RawTable] - Already documented in .claude
- [ ] [RawTable] - Needs documentation

**Measures to Preserve:**
- [ ] [MeasureName] - [What it calculates]
- [ ] [MeasureName] - [What it calculates]
```

**Step 1.3: Ask Claude for Help**

```
Prompt template:

"I'm migrating a report called [ReportName] from my old lakehouse structure
to the new standardized architecture. Here's what I know:

Purpose: [Business purpose]
Department: [Dept]

Current tables:
- [List tables from Power Query]

Questions:
1. Which of these tables already exist in .claude/queries/?
2. Which dimensions from DIMENSIONS-SUMMARY.md should I use?
3. Which raw tables from RAW-TABLES-SUMMARY.md does this likely need?
4. Do any fact tables in FACT-TABLES-SUMMARY.md look similar to what I need?
5. What's the recommended structure for this report?"
```

---

### **Phase 2: Create Project Structure (15-30 minutes)**

**Step 2.1: Create Project Folder**

```bash
# Create project folder structure
cd projects
mkdir [report-name]
cd [report-name]
mkdir queries
cd queries
mkdir fact-tables
mkdir dimensions   # Only if project-specific dimensions needed
mkdir raw-tables   # Only if project-specific raw tables needed
```

**Step 2.2: Document Initial Plan**

Create a quick planning document:

```bash
# In project folder, create MIGRATION-NOTES.md
```

```markdown
# Migration Notes - [Report Name]

**Date:** [Today's date]
**Status:** In Progress

## Migration Plan:

### Fact Tables to Create:
1. [FactName] - [Brief purpose]
   - Source: [Raw tables]
   - Estimated rows: [X]
   - Refresh strategy: [Full/Incremental]

### Dimensions to Use:
- dim_DateTable (shared)
- dim_BranchLocation (shared)
- [Others]

### Raw Tables Needed:
- [RawTable] - Status: [Documented/Needs Doc]

### Measures to Recreate:
1. [Measure] - [Formula or description]

### Open Questions:
- [ ] Question 1
- [ ] Question 2

### Next Steps:
- [ ] Create fact tables
- [ ] Test refresh
- [ ] Recreate measures
- [ ] Validate data
- [ ] Document project
```

---

### **Phase 3: Create Queries (1-3 hours)**

**Step 3.1: Start with Fact Tables**

For each fact table needed:

1. **Use existing pattern as template:**
   - If similar to existing fact, copy and modify
   - Use Raw_InTrans_Incremental pattern if large (1M+ rows)
   - Use simple pattern if small (<100K rows)

2. **Create the query file:**
   ```
   File: projects/[report-name]/queries/fact-tables/Fact_[Name].pq
   ```

3. **Use header template:**
   - Copy from .claude/templates/TEMPLATE-POWER-QUERY-HEADER.md
   - Fill in all sections
   - Document grain, business purpose, columns

4. **Test incrementally:**
   ```
   Ask Claude:
   "I created Fact_[Name].pq. Can you review it for:
   - Query folding opportunities
   - Performance optimizations
   - Naming convention compliance
   - Missing documentation
   - Potential issues"
   ```

**Step 3.2: Reference Shared Dimensions**

Don't recreate dimensions that already exist in `.claude/queries/dimensions/`:

```powerquery
// In your fact table or dataflow, reference shared dimension
// Don't duplicate - use existing!

// Reference dim_DateTable
dim_DateTable = [Reference to shared dim_DateTable in Fabric]

// Reference dim_BranchLocation
dim_BranchLocation = [Reference to shared dim_BranchLocation in Fabric]
```

**Step 3.3: Create Project-Specific Dimensions (If Needed)**

Only create dimensions in project folder if they're truly unique to this report.

Examples of when to create project-specific dimensions:
- Custom customer lists for this report only
- Report-specific categorizations
- One-off reference tables

Ask yourself: "Will any other report ever need this dimension?"
- Yes → Consider adding to .claude/queries/dimensions/ (shared)
- No → Create in project/queries/dimensions/

---

### **Phase 4: Testing & Validation (30-60 minutes)**

**Step 4.1: Refresh Test**

1. **Create dataflows in Fabric:**
   - One for each fact table
   - Reference shared dimensions (don't duplicate)

2. **Test refresh:**
   ```
   First test:
   - Run on-demand refresh
   - Time the refresh
   - Check row counts
   - Verify data quality

   If using MCP servers:
   - Use SQL Server MCP to validate source row counts
   - Compare Fabric vs source database
   ```

3. **Validate with queries:**
   ```sql
   -- Row count check
   SELECT COUNT(*) FROM Fact_[Name]
   -- Should match expected range

   -- Date range check
   SELECT MIN(Date), MAX(Date) FROM Fact_[Name]
   -- Should match business requirements

   -- Sample data check
   SELECT TOP 100 * FROM Fact_[Name]
   ORDER BY Date DESC
   -- Review for data quality issues
   ```

**Step 4.2: Create Validation Queries**

Use templates from COMMON-PATTERNS-BEST-PRACTICES.md:

```sql
-- Save in project/docs/validation-queries.sql

-- 1. Row Count Validation
SELECT COUNT(*) as RowCount
FROM Fact_[Name]
WHERE Date >= DATEADD(day, -7, GETDATE())
-- Expected: [X-Y rows]

-- 2. Duplicate Detection
SELECT [GrainColumn1], [GrainColumn2], COUNT(*) as Duplicates
FROM Fact_[Name]
GROUP BY [GrainColumn1], [GrainColumn2]
HAVING COUNT(*) > 1
-- Expected: 0 rows

-- 3. Null Checks
SELECT COUNT(*) as NullCount
FROM Fact_[Name]
WHERE [CriticalColumn] IS NULL
-- Expected: 0 rows

-- 4. Business Rule Validation
-- [Add your specific business rules]
```

---

### **Phase 5: Data Model & Measures (30-60 minutes)**

**Step 5.1: Create Relationships**

In Power BI Desktop:

```
Standard relationships:
Fact[DateKey] → dim_DateTable[DateKey] (Many-to-One, Single)
Fact[BranchKey] → dim_BranchLocation[BranchKey] (Many-to-One, Single)
[Add others based on your model]

Verify:
- All relationships are Many-to-One
- Single direction (not bi-directional unless absolutely necessary)
- No circular relationships
- All dimension keys have matching fact keys
```

**Step 5.2: Recreate Measures**

1. **Organize measures in display folders:**
   ```
   Revenue Metrics/
     Total Revenue
     Revenue YTD
     Revenue vs LY

   Cost Metrics/
     Total Cost
     Cost YTD

   Margin Metrics/
     Gross Margin
     Margin %
   ```

2. **Use DAX best practices:**
   ```dax
   // Use variables for readability and performance
   Total Revenue =
   VAR SalesAmount = SUM(Fact_Sales[Revenue])
   VAR TaxAmount = SUM(Fact_Sales[Tax])
   RETURN
       SalesAmount + TaxAmount

   // Use DIVIDE for safe division
   Margin % =
   DIVIDE(
       [Total Revenue] - [Total Cost],
       [Total Revenue],
       0
   )

   // Use time intelligence with dim_DateTable
   Revenue YTD =
   CALCULATE(
       [Total Revenue],
       DATESYTD(dim_DateTable[Date])
   )
   ```

---

### **Phase 6: Documentation (30-45 minutes)**

**Step 6.1: Use /document-project Skill**

```bash
# In Claude Code
/document-project projects/[report-name]

# The skill will:
# - Read your project structure
# - Check FACT-TABLES-SUMMARY.md for metadata
# - Use TEMPLATE-PROJECT-README.md structure
# - Generate comprehensive README.md
```

**Step 6.2: Review and Enhance**

The skill generates a good starting point. Enhance it with:

1. **Add specific business context:**
   - Who requested this report and why?
   - What decisions does it enable?
   - Success criteria

2. **Add actual performance numbers:**
   - Refresh times you observed
   - Row counts from testing
   - Any optimization notes

3. **Add known issues or limitations:**
   - Any data quality issues discovered
   - Any business rules that need clarification
   - Any future enhancements planned

**Step 6.3: Update Central Documentation**

Update `.claude/queries/facts/FACT-TABLES-SUMMARY.md`:

```markdown
### **Project: [Report Name]**
**Location:** `projects/[report-name]/queries/fact-tables/`
**Department:** [Dept]
**Created:** [MM/DD/YYYY] | **Modified:** [MM/DD/YYYY]

| Fact Table | Dataflow | Rows | Refresh Time | Schedule | Purpose |
|------------|----------|------|--------------|----------|---------|
| Fact_[Name] | df_Fact_[Name] | [X] | [X min] | [Schedule] | [Purpose] |

**Raw Tables:** [List]

**Dimensions:** [List]

**Business Context:** [Brief description]

**Status:** ✅ Fully documented

**Notes:** [Any special notes about migration, optimization, etc.]
```

---

### **Phase 7: Deployment & Monitoring (15-30 minutes)**

**Step 7.1: Schedule Refresh**

Based on refresh times and dependencies:

```
Recommended schedule:
- If <100K rows and daily changes: Daily 8:00 AM (after raw tables)
- If 100K-1M rows: Daily 8:30 AM (after dims refresh)
- If 1M+ rows: Consider incremental refresh

AVOID 7:30 AM pipeline (documented bottleneck!)
```

**Step 7.2: Create Monitoring**

Set up basic monitoring:

```markdown
## Monitoring Checklist

**Daily Checks (First Week):**
- [ ] Refresh completed successfully
- [ ] Refresh time within expected range
- [ ] Row count within expected range
- [ ] No data quality issues
- [ ] Report loads in Power BI Service

**Weekly Checks (Ongoing):**
- [ ] Performance trends (is it getting slower?)
- [ ] Data quality validation queries
- [ ] User feedback
- [ ] Any errors in refresh history

**If using MCP:**
Ask Claude: "Check the Fabric workspace for any failed refreshes
in the last 24 hours for [report name]"
```

---

## 🎓 Tips for Tomorrow's Migration

### **Start Small:**
- Focus on getting ONE fact table working first
- Test thoroughly before moving to next component
- Build confidence with small wins

### **Use Claude Effectively:**

**Good prompts:**
```
"I'm migrating [ReportName]. Here's the current Power Query code:
[paste code]. How should I restructure this for the new lakehouse?"

"I created Fact_[Name]. Can you check if it follows the patterns
documented in COMMON-PATTERNS-BEST-PRACTICES.md?"

"This query is taking 10 minutes to refresh. Can you suggest
optimizations based on the InTrans_Incremental pattern?"
```

**If SQL Server MCP works:**
```
"Query the source database and tell me how many rows exist in
[SourceTable] for the last 7 days. I'll compare with my Fabric
lakehouse to validate the migration."
```

### **Test Incrementally:**

Don't wait until everything is built to test:
1. Test each query individually first
2. Test fact + dimensions together
3. Test measures with small dataset
4. Test full refresh
5. Test report performance

### **Document as You Go:**

Don't wait until the end to document:
- Add comments to Power Query as you write it
- Note any issues or decisions in MIGRATION-NOTES.md
- Update estimates (row counts, refresh times) as you learn
- Save validation queries you use for testing

### **Don't Hesitate to Ask:**

If something doesn't make sense or you're stuck:
```
"I'm seeing [unexpected behavior]. Here's what I tried: [description].
What should I check next?"

"Is this the right pattern for [scenario]? I'm torn between
approach A and approach B."

"This seems inefficient. Is there a better way based on
existing patterns?"
```

---

## 📋 Tomorrow's Session Kickoff Template

When you start tomorrow, use this prompt to get oriented:

```
I'm ready to migrate [ReportName] from my old lakehouse to the new
structure. Here's what I know about the report:

**Report Info:**
- Name: [Name]
- Purpose: [What it does]
- Department: [Dept]
- Current tables: [List from Power Query]

**What I need help with:**
1. Confirming which existing dimensions to use
2. Structuring the fact table(s) efficiently
3. Applying the right refresh pattern (full vs incremental)
4. Testing and validating the migration
5. Using the /document-project skill when done

**Questions:**
1. [Any specific questions you have]

Let's start by analyzing the current structure and creating
a migration plan. Should I share the current Power Query code first?
```

---

## 🔧 MCP Server Setup Notes

### **SQL Server MCP (To Try):**

**Your Database:** SQL Anywhere (via ODBC dsn=EquipRDB64)

**Question:** Will SQL Server MCP work with SQL Anywhere?
- Likely NO - SQL Server MCP is for Microsoft SQL Server
- SQL Anywhere uses different protocol
- But ODBC connection works in Power Query

**Alternative:**
- Continue using ODBC in Power Query
- Validate manually or with Power Query queries
- If SQL Anywhere MCP exists, we can explore

### **SharePoint MCP (Future):**

**Use Case:** Price Matrix CSV automation
**Setup:** Will need SharePoint site URL and credentials
**Priority:** Medium (can wait until after first migration)

### **Fabric MCP:**

**Already Available:** `fabric-mcp` in your list!

**Potential Uses:**
```
"Using fabric-mcp, check the status of df_Fact_[Name]
dataflow in my workspace"

"Using fabric-mcp, trigger a refresh of [dataflow name]
after I finish making changes"

"Using fabric-mcp, show me all dataflows that failed
in the last 24 hours"
```

**Let's test this tomorrow!**

---

## ✅ Pre-Migration Setup Completed

You now have:
- [x] `/document-project` skill created in `.claude/skills/`
- [x] Migration workflow guide
- [x] Templates ready to use
- [x] All context documentation in place
- [x] MCP server list documented
- [x] Plan for tomorrow's session

---

## 🚀 Tomorrow's Rough Timeline

**Suggested flow (adjust as needed):**

**9:00-9:30 AM: Analysis**
- Open report, review structure
- Map tables to new structure
- Create migration plan with Claude

**9:30-10:30 AM: Create Queries**
- Build fact table(s)
- Reference shared dimensions
- Test refresh

**10:30-11:00 AM: Testing**
- Validate data quality
- Check row counts
- Run validation queries
- Try fabric-mcp if possible

**11:00-11:30 AM: Data Model**
- Create relationships
- Recreate measures
- Test report functionality

**11:30-12:00 PM: Documentation**
- Run `/document-project` skill
- Review and enhance README
- Update FACT-TABLES-SUMMARY.md
- Commit changes to git

**Afternoon (if needed):**
- Performance optimization
- Additional testing
- Deploy to Power BI Service
- Schedule refresh

---

**Good luck tomorrow! This will be a great test of the new structure and workflows!** 🎉
