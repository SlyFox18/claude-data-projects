# Migration Quick-Start Guide - Tomorrow's Session

**Date:** 2026-01-16 (Tomorrow)
**Goal:** Migrate one report from old lakehouse to new standardized structure
**Time Estimate:** 3-6 hours

---

## 🎯 Session Goals

By end of tomorrow's session, you should have:

1. ✅ One report successfully migrated to new structure
2. ✅ Fact tables created with proper documentation
3. ✅ Data validated and refresh working
4. ✅ Project documented using `/document-project` skill
5. ✅ Experience with MCP servers (fabric-mcp, powerbi-desktop-mcp)
6. ✅ Updated FACT-TABLES-SUMMARY.md
7. ✅ Confidence to migrate remaining 11 projects

---

## 📋 Pre-Session Preparation (5 minutes)

**Before starting, have ready:**

1. **The Report:**
   - [ ] .pbix file location known
   - [ ] Know the report name and purpose
   - [ ] Know who uses it and why

2. **Your Environment:**
   - [ ] Claude Code open
   - [ ] Power BI Desktop ready
   - [ ] This quick-start guide open
   - [ ] MIGRATION-WORKFLOW-GUIDE.md open as reference

---

## 🚀 Session Kickoff (Start Here!)

### **Step 1: Open Claude Code Session**

Use this prompt to start:

```
I'm ready to migrate a report from my old lakehouse to the new
standardized structure we've built. This will be my first migration
using the new templates, skills, and MCP servers.

Here's what I have ready:
- All documentation in .claude/ (raw tables, dimensions, facts)
- Templates in .claude/templates/
- /document-project skill created
- Migration workflow guide
- MCP servers: fabric-mcp, powerbi-desktop-mcp, powerbi-modeling-mcp

The report I'm migrating:
[Provide these details:]
- Name: [Report name]
- Purpose: [What it does]
- Department: [Which department uses it]
- Current source: [Old lakehouse details if known]

I'll start by analyzing the current report structure. Can you guide
me through the migration following the MIGRATION-WORKFLOW-GUIDE.md?

First step: Should I use powerbi-desktop-mcp to extract the report
components, or should I manually review the Power Query editor?
```

---

## 📊 Phase-by-Phase Checklist

### **Phase 1: Analysis (30-60 min)**

- [ ] Open .pbix file in Power BI Desktop
- [ ] Try: `"Using powerbi-desktop-mcp, analyze [report.pbix]"`
- [ ] If MCP works: Get complete inventory automatically
- [ ] If MCP doesn't work: Manually note tables, relationships, measures
- [ ] Ask Claude to map tables to new structure
- [ ] Identify which dimensions already exist (check DIMENSIONS-SUMMARY.md)
- [ ] Identify which raw tables exist (check RAW-TABLES-SUMMARY.md)
- [ ] Create migration plan in MIGRATION-NOTES.md

**Output:** Clear list of what needs to be created vs what exists

---

### **Phase 2: Create Structure (15-30 min)**

```bash
# Create project folder
cd c:\Users\bfox\Documents\Git-Projects\data-projects\projects
mkdir [report-name]
cd [report-name]
mkdir queries
cd queries
mkdir fact-tables
```

- [ ] Project folder created
- [ ] queries/fact-tables/ folder created
- [ ] MIGRATION-NOTES.md created with plan

---

### **Phase 3: Build Fact Tables (1-3 hours)**

**For Each Fact Table:**

1. - [ ] Ask Claude: `"Which existing pattern should I use as template?"`
2. - [ ] Create `Fact_[Name].pq` file
3. - [ ] Copy appropriate header template
4. - [ ] Write Power Query code:
   - [ ] Reference raw tables from .claude or lakehouse
   - [ ] Reference shared dimensions (don't duplicate!)
   - [ ] Apply filters and transformations
   - [ ] Add surrogate keys for relationships
5. - [ ] Ask Claude to review:
   ```
   "Review this query for:
   - Performance optimization
   - Query folding
   - Naming conventions
   - Missing documentation
   - Potential issues"
   ```
6. - [ ] Create dataflow in Fabric
7. - [ ] Test refresh on-demand
8. - [ ] Try: `"Using fabric-mcp, trigger refresh of df_Fact_[Name]"`
9. - [ ] Validate row counts

**Key Reminders:**
- Use InTrans_Incremental watermark pattern if large (1M+ rows)
- Filter early in SQL query (query folding)
- Select only needed columns
- Reference existing dimensions, don't recreate

---

### **Phase 4: Validation (30-60 min)**

**Create Validation Queries:**

```sql
-- Save in project/docs/validation-queries.sql

-- 1. Row Count
SELECT COUNT(*) as RowCount
FROM Fact_[Name]

-- 2. Date Range
SELECT MIN([DateColumn]), MAX([DateColumn])
FROM Fact_[Name]

-- 3. Sample Data
SELECT TOP 100 *
FROM Fact_[Name]
ORDER BY [DateColumn] DESC

-- 4. Null Checks
SELECT
    COUNT(*) as TotalRows,
    SUM(CASE WHEN [CriticalCol1] IS NULL THEN 1 ELSE 0 END) as NullCount1,
    SUM(CASE WHEN [CriticalCol2] IS NULL THEN 1 ELSE 0 END) as NullCount2
FROM Fact_[Name]

-- 5. Duplicates Check
SELECT [GrainCol1], [GrainCol2], COUNT(*) as Cnt
FROM Fact_[Name]
GROUP BY [GrainCol1], [GrainCol2]
HAVING COUNT(*) > 1
```

- [ ] All validation queries pass
- [ ] Row counts match expectations
- [ ] No unexpected nulls
- [ ] No duplicates on grain
- [ ] Date ranges correct

---

### **Phase 5: Data Model & Measures (30-60 min)**

**In Power BI Desktop:**

1. - [ ] Connect to Fabric lakehouse
2. - [ ] Add fact table(s)
3. - [ ] Add shared dimensions (from .claude/queries/dimensions/)
4. - [ ] Create relationships:
   - [ ] Fact[DateKey] → dim_DateTable[DateKey]
   - [ ] Fact[BranchKey] → dim_BranchLocation[BranchKey]
   - [ ] [Other relationships]
5. - [ ] Verify all relationships are Many-to-One, Single direction
6. - [ ] Try: `"Using powerbi-modeling-mcp, validate my data model"`
7. - [ ] Recreate DAX measures from old report
8. - [ ] Organize measures in display folders
9. - [ ] Test measures with sample data

---

### **Phase 6: Documentation (30-45 min)**

**Use the Skill:**

```bash
# In Claude Code
/document-project projects/[report-name]
```

- [ ] Skill generated README.md
- [ ] Review and enhance with specifics:
  - [ ] Add business context
  - [ ] Add actual performance numbers
  - [ ] Add validation queries
  - [ ] Add known issues if any
- [ ] Update `.claude/queries/facts/FACT-TABLES-SUMMARY.md`:
  - [ ] Add project section
  - [ ] List fact tables with metadata
  - [ ] Mark status as "Fully documented"

---

### **Phase 7: Deployment (15-30 min)**

- [ ] Schedule dataflow refresh (avoid 7:30 AM!)
- [ ] Publish report to Power BI Service
- [ ] Set up report refresh schedule
- [ ] Test refresh in service
- [ ] Verify report loads correctly

---

## 🧪 MCP Server Testing

**During migration, try these:**

### **fabric-mcp Tests:**

```
"Using fabric-mcp, list all dataflows in my workspace"

"Using fabric-mcp, show me the refresh history for
df_InTrans_Incremental"

"Using fabric-mcp, trigger a refresh of df_Fact_[YourNewTable]"

"Using fabric-mcp, what's the current status of today's
refresh operations?"
```

**Document Results:**
- [ ] What worked?
- [ ] What didn't work?
- [ ] What needs configuration?

---

### **powerbi-desktop-mcp Tests:**

```
"Using powerbi-desktop-mcp, analyze [old-report.pbix] and
extract all table sources, relationships, and measures"

"Using powerbi-desktop-mcp, compare [old-report.pbix] with
[new-report.pbix] and show differences"
```

**Document Results:**
- [ ] Did it extract components correctly?
- [ ] Did it save time vs manual analysis?
- [ ] Any limitations discovered?

---

### **powerbi-modeling-mcp Tests:**

```
"Using powerbi-modeling-mcp, validate [new-report.pbix]
for best practices compliance"

"Using powerbi-modeling-mcp, check for performance issues
in my data model"
```

**Document Results:**
- [ ] What validation checks did it perform?
- [ ] Any issues flagged?
- [ ] Useful for future migrations?

---

## 💡 Tips & Troubleshooting

### **If Stuck on Query Performance:**

```
Ask Claude:
"This query is taking [X] minutes to refresh. Here's the code:
[paste code]

Based on the InTrans_Incremental gold standard pattern,
what optimizations should I apply?"
```

### **If Unsure About Pattern:**

```
Ask Claude:
"I need to create a fact table with [describe characteristics].
Which pattern from COMMON-PATTERNS-BEST-PRACTICES.md should I use?
Should this be full refresh or incremental?"
```

### **If Data Doesn't Match:**

```
Ask Claude:
"I'm seeing [X] rows in Fabric but expected [Y] rows.
What validation queries should I run to identify the issue?"

If SQL Server MCP worked:
"Query the source database and compare row counts with my
Fabric lakehouse for [date range]"
```

### **If MCP Server Doesn't Respond:**

```
Ask Claude:
"The fabric-mcp server isn't responding when I try [command].
Can you help troubleshoot:
1. Is the syntax correct?
2. Do I need to configure something?
3. Are there permission issues?
4. Is there an alternative approach?"
```

---

## 📝 End-of-Session Checklist

Before finishing tomorrow:

- [ ] Fact table(s) created and tested
- [ ] Refresh working and scheduled
- [ ] Data validated (row counts, nulls, duplicates)
- [ ] Measures recreated and tested
- [ ] Report functional in Power BI Service
- [ ] README.md generated with `/document-project`
- [ ] FACT-TABLES-SUMMARY.md updated
- [ ] Git commit created (if using git)
- [ ] MCP server results documented
- [ ] Notes on what worked well / what to improve

---

## 🎯 Success Criteria

**Minimum Success:**
- One fact table working with proper refresh
- Basic documentation in place
- Understanding of migration workflow

**Good Success:**
- All fact tables for report working
- Complete documentation
- Validation queries created
- MCP servers tested

**Excellent Success:**
- Report fully functional in Power BI Service
- Comprehensive documentation
- Performance optimized
- MCP servers working and saving time
- Lessons learned documented for next migration

---

## 📚 Quick Reference Links

**Keep These Open:**

1. [MIGRATION-WORKFLOW-GUIDE.md](.claude/guides/MIGRATION-WORKFLOW-GUIDE.md) - Detailed step-by-step
2. [MCP-SERVERS-REFERENCE.md](.claude/guides/MCP-SERVERS-REFERENCE.md) - MCP server commands
3. [COMMON-PATTERNS-BEST-PRACTICES.md](.claude/guides/COMMON-PATTERNS-BEST-PRACTICES.md) - Patterns and templates
4. [TEMPLATE-POWER-QUERY-HEADER.md](.claude/templates/TEMPLATE-POWER-QUERY-HEADER.md) - Query documentation
5. [FACT-TABLES-SUMMARY.md](.claude/queries/facts/FACT-TABLES-SUMMARY.md) - Fact table registry
6. [DIMENSIONS-SUMMARY.md](.claude/queries/dimensions/DIMENSIONS-SUMMARY.md) - Available dimensions
7. [RAW-TABLES-SUMMARY.md](.claude/queries/RAW-TABLES-SUMMARY.md) - Available raw tables

---

## 💬 Example Starting Conversation

```
Me: I'm ready to migrate the [Report Name] report. It's a [Department]
report that tracks [business purpose]. Let me start by analyzing the
current structure.

Using powerbi-desktop-mcp, analyze [path/to/report.pbix] and show me:
1. All tables and their sources
2. All relationships
3. All DAX measures
4. Any calculated columns

Claude: [Analyzes report and provides inventory]

Me: Based on this analysis and looking at my DIMENSIONS-SUMMARY.md
and RAW-TABLES-SUMMARY.md, which existing components can I reuse
and what do I need to create?

Claude: [Provides migration plan]

Me: Great! Let's start with creating the fact table. Which pattern
should I use as a template?

[Continue conversation through migration phases...]
```

---

## 🎉 You're Ready!

**You have everything you need:**
- ✅ Complete context in .claude/
- ✅ Templates ready to use
- ✅ Skills created
- ✅ MCP servers to test
- ✅ Workflow guide
- ✅ This quick-start checklist

**Tomorrow's goal is to learn by doing:**
- Don't try to be perfect
- Ask Claude for help liberally
- Document what you learn
- Iterate and improve

**Remember:** This first migration will teach you the process. Each
subsequent migration will be faster and smoother!

**Good luck! 🚀**
