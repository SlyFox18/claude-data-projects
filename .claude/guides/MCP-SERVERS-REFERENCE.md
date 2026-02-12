# MCP Servers Reference - Your Available Servers

**Last Updated:** 2026-01-15

---

## 🔌 Currently Available MCP Servers

You have access to these MCP servers:

1. **Microsoft Docs MCP**
2. **fabric-mcp** ⭐ HIGH VALUE
3. **powerbi-desktop-mcp**
4. **powerbi-modeling-mcp** ⭐ HIGH VALUE
5. **GitHub MCP** (possibly)

---

## 1. Microsoft Docs MCP

**Purpose:** Search and retrieve Microsoft documentation

**Use Cases:**

```
"Search Microsoft Docs for the latest best practices on
Fabric dataflow incremental refresh in 2026"

"Find Microsoft documentation on Power Query query folding
optimization techniques"

"Look up the syntax for CALCULATE function in DAX with examples"

"Search for Fabric lakehouse performance tuning guidance"
```

**When to Use:**
- Need current Microsoft documentation
- Looking for official best practices
- Learning new features
- Troubleshooting with official guidance

---

## 2. fabric-mcp ⭐ HIGH VALUE

**Purpose:** Interact with Microsoft Fabric workspace

**Potential Capabilities:**

### **A. Monitor Dataflows**

```
"List all dataflows in my Fabric workspace"

"Show me the refresh history for df_Fact_WorkOrderParts"

"Which dataflows failed in the last 24 hours?"

"What's the current status of df_InTrans_Incremental?"
```

### **B. Trigger Refreshes**

```
"Trigger a refresh of df_Fact_WorkOrderParts"

"Refresh all dimension dataflows in parallel"

"Start the daily refresh pipeline"
```

### **C. Workspace Management**

```
"List all semantic models in my workspace"

"Show me capacity utilization for the last week"

"Which tables are consuming the most storage?"
```

### **D. Performance Monitoring**

```
"Show me refresh times for all dataflows over the last 7 days"

"Which dataflow has the longest refresh time?"

"Is the 7:30 AM pipeline still experiencing slowdowns?"
```

**Tomorrow's Test Cases:**

```
Try these to test fabric-mcp during migration:

1. "Using fabric-mcp, list all dataflows in my workspace"

2. "Using fabric-mcp, show me the last refresh status for
   df_Fact_[YourMigratedTable]"

3. "Using fabric-mcp, trigger a refresh of the dataflow
   I just created"

4. "Using fabric-mcp, show me capacity metrics during
   today's refresh operations"
```

---

## 3. powerbi-desktop-mcp

**Purpose:** Interact with Power BI Desktop files (.pbix)

**Potential Capabilities:**

### **A. Report Analysis**

```
"Read the data model from [report.pbix] and list all tables"

"What relationships exist in [report.pbix]?"

"List all DAX measures in [report.pbix]"

"Show me all visualizations in [report.pbix]"
```

### **B. Migration Support**

```
"Extract the Power Query code from all queries in
[old-report.pbix] and save to separate .pq files"

"Compare the data model in [old-report.pbix] with
[new-report.pbix] and show differences"

"List all calculated columns in [report.pbix] that
should be moved to Power Query"
```

### **C. Documentation**

```
"Generate documentation for [report.pbix] including
tables, relationships, measures, and visualizations"

"Extract all DAX measures from [report.pbix] and
format them for documentation"
```

**Tomorrow's Use Case:**

```
When you open the report to migrate:

"Using powerbi-desktop-mcp, read [old-report.pbix] and:
1. List all tables and their sources
2. Show all relationships
3. Extract all DAX measures
4. List any calculated columns
This will help me plan the migration."
```

---

## 4. powerbi-modeling-mcp ⭐ HIGH VALUE

**Purpose:** Validate and optimize Power BI data models

**Potential Capabilities:**

### **A. Model Validation**

```
"Check [report.pbix] for data modeling best practices violations"

"Identify any circular relationships in my data model"

"Find all many-to-many relationships and suggest alternatives"

"Check for missing relationships between fact and dimension tables"
```

### **B. Performance Analysis**

```
"Analyze [report.pbix] for performance issues"

"Identify calculated columns that should be moved to Power Query"

"Find DAX measures that could be optimized"

"Check for bi-directional relationships that aren't needed"
```

### **C. Documentation Generation**

```
"Generate a data model diagram for [report.pbix]"

"Create documentation showing all relationships and cardinality"

"List all dimension tables and their usage in facts"
```

**Tomorrow's Use Case:**

```
After creating new data model:

"Using powerbi-modeling-mcp, validate my new data model
in [migrated-report.pbix]. Check for:
- Missing relationships
- Performance anti-patterns
- Naming convention compliance
- Best practices violations"
```

---

## 5. GitHub MCP (Possibly Available)

**Purpose:** GitHub integration

**If Available, Use Cases:**

```
"Create a GitHub issue to track the [report name] migration"

"Commit these changes with message: 'Migrate [report] to new lakehouse'"

"Show me recent commits to the data-projects repo"

"Create a pull request for the migration work"
```

---

## 🎯 Priority MCP Servers to Add

### **1. SharePoint/M365 MCP** (High Priority)

**Why You Need It:**
- Price Matrix CSV automation
- Document sync to SharePoint
- Team collaboration

**How to Get It:**
Search for "SharePoint MCP server" or "Microsoft 365 MCP server"
- May be called: `@modelcontextprotocol/server-sharepoint`
- Or: `@microsoft/mcp-server-m365`

**Installation** (typical):
```bash
# Check Claude Code MCP server installation docs
# Usually involves adding to configuration file
```

### **2. SQL Database MCP** (Investigate)

**Your Situation:**
- Source database: SQL Anywhere (via ODBC dsn=EquipRDB64)
- Question: Is there a SQL Anywhere MCP server?

**Investigation Needed:**
1. Check if SQL Anywhere MCP server exists
2. If not, could a generic ODBC MCP server work?
3. Alternative: Continue using Power Query ODBC connections

**Potential Value if Available:**
```
"Query SQL Anywhere database and show row count for
InTrans table where Trans_Datetime > [yesterday]"

"Validate that Fabric lakehouse matches source database
for [specific date range]"

"Run data quality check on source InHist_PmManage table"
```

---

## 🧪 Testing Your MCP Servers Tomorrow

### **Test Plan:**

**1. fabric-mcp** (Test First - Highest Value)

```bash
# Try these commands during migration:

"Using fabric-mcp, list all dataflows in my workspace"

"Using fabric-mcp, what's the last refresh status of
df_InTrans_Incremental?"

"Using fabric-mcp, show me today's refresh history"
```

**Expected Output:**
- List of dataflows with status
- Refresh timestamps
- Success/failure status

**If It Works:**
- HUGE value for automation
- Can monitor refreshes in real-time
- Can trigger refreshes programmatically

**If It Doesn't Work:**
- May need configuration
- May need workspace permissions
- Can still proceed with manual monitoring

---

**2. powerbi-desktop-mcp** (Test During Analysis)

```bash
# When you open the old report:

"Using powerbi-desktop-mcp, analyze [path/to/old-report.pbix]
and extract:
1. All table names and sources
2. All relationships
3. All DAX measures
4. Any calculated columns"
```

**Expected Output:**
- Complete inventory of report components
- Makes migration planning much easier

---

**3. powerbi-modeling-mcp** (Test After Building New Model)

```bash
# After creating new data model:

"Using powerbi-modeling-mcp, validate my data model in
[path/to/new-report.pbix]. Check for best practices."
```

**Expected Output:**
- Validation report
- Performance recommendations
- Best practices compliance

---

## 📝 MCP Server Configuration

**To Check Your MCP Configuration:**

Look for Claude Code settings file (usually in):
- `.claude/settings.json`
- `~/.config/claude-code/settings.json`
- Or VSCode settings if using VSCode extension

**Typical MCP Configuration:**

```json
{
  "mcpServers": {
    "microsoft-docs": {
      "enabled": true,
      "config": { ... }
    },
    "fabric-mcp": {
      "enabled": true,
      "config": {
        "workspaceId": "your-workspace-id",
        "credentials": { ... }
      }
    },
    "powerbi-desktop-mcp": {
      "enabled": true
    },
    "powerbi-modeling-mcp": {
      "enabled": true
    }
  }
}
```

**If MCP Servers Don't Work:**

Ask Claude:
```
"My MCP servers aren't responding. Can you help me:
1. Check if they're properly configured
2. Verify permissions
3. Test connectivity
4. Troubleshoot any errors"
```

---

## 💡 MCP Server Best Practices

### **1. Always Specify Which MCP Server**

**Good:**
```
"Using fabric-mcp, show me dataflow status"
```

**Bad:**
```
"Show me dataflow status"
(Claude might not know to use MCP)
```

### **2. Start Simple, Build Complexity**

**First Test:**
```
"Using fabric-mcp, list workspaces"
```

**Once Working:**
```
"Using fabric-mcp, analyze refresh patterns over the last
week and identify bottlenecks"
```

### **3. Combine MCP with Context**

**Good:**
```
"Using fabric-mcp, check the status of df_InTrans_Incremental.
According to REFRESH-TIMES.md, it should take 2-3 minutes.
Is today's refresh within that range?"
```

### **4. Use for Validation**

```
"I just created df_Fact_NewTable. Using fabric-mcp:
1. Trigger a test refresh
2. Monitor the refresh time
3. Report any errors
4. Show final row count"
```

---

## 🔮 Future MCP Server Possibilities

**If These Become Available:**

### **Email/Notification MCP:**
```
"Send email alert if any dataflow refresh fails"
"Notify team when daily refresh pipeline completes"
```

### **Azure DevOps MCP:**
```
"Create work item for Fact_WorkOrderParts optimization"
"Track time spent on migration tasks"
```

### **Custom MCP for SQL Anywhere:**
```
"Query source database and compare with Fabric lakehouse"
"Run data quality checks on source tables"
```

---

## ✅ Tomorrow's MCP Checklist

During migration, try to test:

- [ ] **fabric-mcp**: List dataflows
- [ ] **fabric-mcp**: Check refresh status
- [ ] **fabric-mcp**: Trigger refresh (if creating new dataflow)
- [ ] **powerbi-desktop-mcp**: Extract report components
- [ ] **powerbi-modeling-mcp**: Validate new model
- [ ] **Microsoft Docs MCP**: Search for any needed documentation

**Document what works and what doesn't so we can optimize usage going forward!**

---

## 📚 Quick Reference

**Your MCP Servers:**
1. ✅ Microsoft Docs - Documentation search
2. ⭐ fabric-mcp - Fabric workspace management
3. ✅ powerbi-desktop-mcp - .pbix file analysis
4. ⭐ powerbi-modeling-mcp - Model validation
5. ❓ GitHub MCP - Version control (if available)

**Priority to Add:**
1. 🎯 SharePoint/M365 MCP - Price Matrix automation
2. 🔍 SQL Database MCP - Source validation (investigate options)

**Test Tomorrow:**
Focus on fabric-mcp and powerbi-desktop-mcp for migration workflow.
