# Claude Code Skills & MCP Servers Guide

**Purpose:** Understanding and leveraging Claude Code's advanced capabilities
**Last Updated:** 2026-01-15

---

## 📚 Table of Contents

1. [Claude Code Skills Overview](#claude-code-skills-overview)
2. [Built-in Skills Reference](#built-in-skills-reference)
3. [Creating Custom Skills](#creating-custom-skills)
4. [MCP Servers Overview](#mcp-servers-overview)
5. [Available MCP Servers](#available-mcp-servers)
6. [Use Cases for Your Projects](#use-cases-for-your-projects)

---

## 🎯 Claude Code Skills Overview

**What Are Skills?**
Skills are specialized, reusable AI workflows that can be invoked with slash commands. They're like "mini-agents" that handle specific tasks end-to-end.

**Key Benefits:**
- **Consistency**: Same approach every time
- **Efficiency**: Pre-packaged workflows save time
- **Reusability**: Use across all projects
- **Automation**: Reduce manual, repetitive work

**How to Use:**
```bash
/skill-name [arguments]
```

Example:
```bash
/commit -m "Add incremental refresh to Fact_WorkOrderParts"
/review-pr 123
```

---

## 🔧 Built-in Skills Reference

### **Available Built-in Skills:**

While I don't see specific built-in skills loaded in this session, Claude Code typically supports skills like:

1. **/commit** - Create git commits with proper formatting
2. **/review-pr** - Review GitHub pull requests
3. **/explain** - Explain code or concepts
4. **/optimize** - Suggest optimizations
5. **/test** - Generate or run tests

**To See Your Available Skills:**
Type `/` in Claude Code and you'll see autocomplete suggestions for available skills.

**To Get Help:**
```bash
/help
```

---

## 🏗️ Creating Custom Skills

Custom skills are defined using JSON configuration files in your `.claude/skills/` directory.

### **Skill Configuration Structure:**

```json
{
  "name": "skill-name",
  "description": "Brief description of what this skill does",
  "version": "1.0.0",
  "prompt": "Detailed instructions for the AI agent...",
  "args": {
    "arg_name": {
      "type": "string",
      "description": "What this argument is for",
      "required": true
    }
  },
  "examples": [
    {
      "command": "/skill-name value",
      "description": "Example usage"
    }
  ]
}
```

### **Skill Types You Could Create:**

---

### **1. /document-project** - Auto-document a report project

**Use Case:** Generate comprehensive README for any project folder

```json
{
  "name": "document-project",
  "description": "Generate comprehensive documentation for a Power BI report project",
  "version": "1.0.0",
  "prompt": "You are documenting a Power BI report project. Follow these steps:\n\n1. Read the project folder structure\n2. Identify fact tables, dimensions, and raw tables used\n3. Find the report's .pbix file metadata if available\n4. Check FACT-TABLES-SUMMARY.md for project metadata\n5. Generate a comprehensive README.md using TEMPLATE-PROJECT-README.md\n6. Include:\n   - Business purpose and use cases\n   - Data model (facts, dimensions, relationships)\n   - Refresh schedule and dependencies\n   - Known issues and limitations\n   - Key measures and calculations\n   - Testing/validation procedures\n7. Save to project folder as README.md",
  "args": {
    "project_path": {
      "type": "string",
      "description": "Path to project folder (e.g., projects/parts-adjustments)",
      "required": true
    }
  },
  "examples": [
    {
      "command": "/document-project projects/parts-adjustments",
      "description": "Document the Parts Adjustments project"
    }
  ]
}
```

**Usage:**
```bash
/document-project projects/inspections-report
```

---

### **2. /optimize-refresh** - Analyze and optimize refresh performance

```json
{
  "name": "optimize-refresh",
  "description": "Analyze a dataflow/fact table and suggest performance optimizations",
  "version": "1.0.0",
  "prompt": "You are a Power Query and Fabric performance expert. Analyze the given query and:\n\n1. Identify performance bottlenecks\n2. Check for incremental refresh opportunities\n3. Review column selection efficiency\n4. Analyze query folding potential\n5. Suggest specific optimizations:\n   - Watermark-based incremental refresh (use InTrans_Incremental pattern)\n   - Strategic column selection\n   - Early filtering\n   - Data type optimization\n6. Estimate expected performance improvement\n7. Provide before/after comparison",
  "args": {
    "query_path": {
      "type": "string",
      "description": "Path to .pq file or dataflow name",
      "required": true
    }
  }
}
```

**Usage:**
```bash
/optimize-refresh queries/fact-tables/Fact_WorkOrderParts.pq
```

---

### **3. /validate-data-model** - Check data model for issues

```json
{
  "name": "validate-data-model",
  "description": "Validate data model for common issues and best practices",
  "version": "1.0.0",
  "prompt": "Validate a Power BI data model and check for:\n\n1. Missing relationships\n2. Circular relationships\n3. Many-to-many relationships (flag for review)\n4. Bi-directional filtering (warn if not needed)\n5. Missing date table relationships\n6. Orphaned records (facts without matching dimensions)\n7. Naming convention compliance\n8. Measure organization\n9. Performance red flags:\n   - Calculated columns (should be Power Query)\n   - Complex measures without variables\n   - Excessive row-level security\n10. Generate validation report with findings",
  "args": {
    "project_path": {
      "type": "string",
      "description": "Path to project folder",
      "required": true
    }
  }
}
```

---

### **4. /create-incremental-refresh** - Auto-implement incremental refresh

```json
{
  "name": "create-incremental-refresh",
  "description": "Convert a full-refresh table to incremental refresh using watermark pattern",
  "version": "1.0.0",
  "prompt": "Implement watermark-based incremental refresh following InTrans_Incremental gold standard:\n\n1. Read the existing query\n2. Identify the datetime column for watermark\n3. Create GetWatermark helper query\n4. Modify source query to:\n   - Add watermark parameter\n   - Filter by datetime > watermark\n   - Add duplicate protection on primary key\n5. Document the pattern\n6. Provide implementation checklist:\n   - Create GetWatermark helper\n   - Update main query\n   - Test with small watermark\n   - Schedule refresh\n   - Monitor for 48 hours\n7. Estimate performance improvement",
  "args": {
    "query_path": {
      "type": "string",
      "description": "Path to query file to convert",
      "required": true
    },
    "datetime_column": {
      "type": "string",
      "description": "Name of datetime column for watermark",
      "required": false
    }
  }
}
```

**Usage:**
```bash
/create-incremental-refresh queries/fact-tables/Fact_WorkOrderParts.pq ModifiedDate
```

---

### **5. /generate-test-queries** - Create validation SQL queries

```json
{
  "name": "generate-test-queries",
  "description": "Generate validation and testing queries for a fact/dimension table",
  "version": "1.0.0",
  "prompt": "Generate comprehensive testing queries:\n\n1. Row count validation\n2. Date range validation\n3. Null checks on critical columns\n4. Duplicate detection on grain\n5. Referential integrity checks\n6. Business rule validation\n7. Outlier detection\n8. Comparison with source system\n9. Historical trend validation\n10. Performance benchmarks\n\nProvide queries in SQL and DAX formats where applicable.",
  "args": {
    "table_name": {
      "type": "string",
      "description": "Fact or dimension table name",
      "required": true
    }
  }
}
```

---

### **6. /analyze-refresh-pipeline** - Optimize refresh pipeline

```json
{
  "name": "analyze-refresh-pipeline",
  "description": "Analyze refresh dependencies and suggest optimal pipeline structure",
  "version": "1.0.0",
  "prompt": "Analyze the refresh pipeline:\n\n1. Map dependencies (raw → dims → facts → semantic)\n2. Identify sequential vs parallel opportunities\n3. Find bottlenecks (like 7:30 AM pipeline)\n4. Suggest pipeline restructuring:\n   - Group independent refreshes in parallel\n   - Sequence dependent refreshes\n   - Time-shift to avoid contention\n5. Estimate total pipeline time improvement\n6. Generate Fabric pipeline YAML/JSON if requested",
  "args": {
    "scope": {
      "type": "string",
      "description": "Pipeline scope: all | daily | weekly | specific report",
      "required": false
    }
  }
}
```

---

### **Where to Store Custom Skills:**

Create a `.claude/skills/` directory and add JSON files:

```
.claude/
├── skills/
│   ├── document-project.json
│   ├── optimize-refresh.json
│   ├── validate-data-model.json
│   ├── create-incremental-refresh.json
│   ├── generate-test-queries.json
│   └── analyze-refresh-pipeline.json
```

**Skill File Naming:**
- Use kebab-case: `skill-name.json`
- Match the `"name"` field in the JSON
- Clear, action-oriented names

---

## 🌐 MCP Servers Overview

**What Are MCP Servers?**
Model Context Protocol (MCP) servers extend Claude Code's capabilities by connecting to external data sources, APIs, and services.

**Key Benefits:**
- **Live Data Access**: Query databases, APIs, web services in real-time
- **Extended Capabilities**: File systems, Git, cloud services, databases
- **Context Enrichment**: Pull in external context without manual copying
- **Automation**: Trigger external actions from Claude Code

**How MCP Works:**
```
Claude Code <──> MCP Server <──> External Service
              (Protocol)      (API/Database/etc.)
```

---

## 🔌 Available MCP Servers

### **Database MCP Servers:**

**1. PostgreSQL MCP Server**
- **Purpose:** Query PostgreSQL databases directly
- **Use Cases:**
  - Validate Power BI data against source database
  - Run ad-hoc SQL queries for analysis
  - Check data quality at source
  - Compare Fabric Lakehouse vs source database

**Example Usage:**
```
"Can you query the InTrans table in SQL Server to check
how many rows were added in the last 24 hours?"
```

**2. SQL Server MCP Server**
- Direct access to your SQL Server database
- Perfect for your `dsn=EquipRDB64` source
- Can validate refresh data at source

---

### **File System MCP Servers:**

**3. File System MCP Server**
- **Purpose:** Access local and network file systems
- **Use Cases:**
  - Read/write files outside working directory
  - Access network shares
  - Backup and archive management
  - Log file analysis

---

### **Cloud & API MCP Servers:**

**4. Microsoft 365 MCP Server**
- **Purpose:** Access SharePoint, OneDrive, Outlook
- **Use Cases:**
  - Read Price Matrix CSV from SharePoint (you have this!)
  - Access project documentation in SharePoint
  - Email reports or alerts
  - Sync documentation to SharePoint

**5. Azure MCP Server**
- **Purpose:** Interact with Azure services
- **Use Cases:**
  - Manage Fabric resources
  - Monitor pipeline runs
  - Access Azure DevOps for automation
  - Query Azure SQL

---

### **Development Tools MCP Servers:**

**6. GitHub MCP Server**
- **Purpose:** Enhanced GitHub integration
- **Use Cases:**
  - Create/manage issues
  - Review pull requests
  - Manage releases
  - Search code across repos

**7. Git MCP Server**
- **Purpose:** Advanced Git operations
- **Use Cases:**
  - Complex branching strategies
  - Git history analysis
  - Automated versioning
  - Repository management

---

### **Web & Data MCP Servers:**

**8. Web Search MCP Server**
- **Purpose:** Search the web for current information
- **Use Cases:**
  - Latest Power BI best practices
  - Current Microsoft Fabric documentation
  - Troubleshooting error messages
  - Finding code examples

**9. Web Scraper MCP Server**
- **Purpose:** Extract data from websites
- **Use Cases:**
  - Scrape vendor pricing
  - Monitor competitor data
  - Extract public data for enrichment

---

## 🎯 Use Cases for Your Projects

### **High-Value MCP Server Use Cases:**

---

### **1. SQL Server MCP + Your Database**

**Setup:**
Configure MCP server to connect to your `dsn=EquipRDB64` database

**Use Cases:**

**A. Pre-Refresh Validation**
```
Before refreshing Fact_WorkOrderParts, check source row count:

"Query the SQL Server InTrans table and tell me how many
transactions have Trans_Datetime > [last watermark].
Should match today's expected refresh volume."
```

**B. Data Quality Checks**
```
"Query InHist_PmManage and analyze the data distribution
for the last 30 days. Are there any anomalies?"
```

**C. Troubleshooting Missing Data**
```
"A user reports missing transactions for Branch 12 on
01/14/2026. Query the source InTrans table and verify
if the data exists there."
```

---

### **2. SharePoint MCP + Price Matrix**

**Setup:**
Connect to SharePoint where Price Matrix CSV lives

**Use Cases:**

**A. Automated Price Matrix Refresh**
```
"Check the Price Matrix CSV on SharePoint. Has it been
updated in the last 24 hours? If yes, trigger a refresh
of the Price Matrix report."
```

**B. Price Matrix Validation**
```
"Download the latest Price Matrix CSV from SharePoint
and validate its structure. Check for:
- Required columns present
- No duplicate part numbers
- Prices in expected ranges
- Branch coverage complete"
```

**C. Documentation Sync**
```
"Upload the newly created project documentation for
Parts Adjustments to the SharePoint project folder."
```

---

### **3. Azure MCP + Fabric**

**Setup:**
Connect to your Azure subscription with Fabric workspace

**Use Cases:**

**A. Pipeline Monitoring**
```
"Check the status of all dataflows in the 'South Plains
Analytics' workspace. Which ones failed in the last 24 hours?"
```

**B. Automated Refresh Triggers**
```
"Trigger a refresh of df_Fact_WorkOrderParts in Fabric
after I finish optimizing the query."
```

**C. Capacity Monitoring**
```
"Check the F4 capacity utilization for the last week.
Are we approaching CU limits during 7:30 AM pipeline?"
```

---

### **4. GitHub MCP + Version Control**

**Setup:**
Connect to your GitHub repo

**Use Cases:**

**A. Automated Issue Tracking**
```
"Create a GitHub issue for optimizing Fact_WorkOrderParts:
- Title: Optimize Fact_WorkOrderParts refresh time
- Description: Current 18-19 min, target 3-5 min
- Labels: performance, high-priority
- Assign to: bfox
- Link to InTrans_Incremental pattern"
```

**B. Release Notes Generation**
```
"Generate release notes for all changes made this week
to the data-projects repo. Group by:
- New features
- Performance improvements
- Bug fixes
- Documentation updates"
```

---

### **5. Web Search MCP + Latest Best Practices**

**Use Cases:**

**A. Current Documentation**
```
"Search for the latest Microsoft Fabric incremental
refresh best practices in 2026. Has the watermark
pattern changed?"
```

**B. Troubleshooting**
```
"Search for recent discussions about Power Query
performance in Fabric dataflows taking longer in
scheduled runs vs on-demand."
```

---

## 🚀 Getting Started with Skills & MCP

### **Step 1: Check Available MCP Servers**

```bash
# In Claude Code, check your MCP configuration
# Look in settings or configuration files for enabled MCP servers
```

### **Step 2: Enable Relevant MCP Servers**

For your use cases, prioritize:
1. **SQL Server MCP** (highest value - validate source data)
2. **SharePoint/Microsoft 365 MCP** (Price Matrix automation)
3. **Azure MCP** (Fabric management)
4. **GitHub MCP** (if using GitHub)

### **Step 3: Create Your First Custom Skill**

Start simple with `/document-project`:

1. Create `.claude/skills/` directory
2. Create `document-project.json` with the configuration above
3. Test it: `/document-project projects/parts-adjustments`
4. Iterate and improve based on results

### **Step 4: Combine Skills + MCP**

Create powerful workflows:

```bash
# Skill that uses MCP servers internally
/validate-refresh Fact_WorkOrderParts
  → Uses SQL Server MCP to check source row count
  → Validates against expected range
  → Reports discrepancies
```

---

## 📋 Recommended Skills for Your Environment

### **Tier 1: Create These First** (Highest Value)

1. **/document-project** - Auto-document the 12 undocumented projects
2. **/optimize-refresh** - Fix Fact_WorkOrderParts and others
3. **/create-incremental-refresh** - Replicate InTrans_Incremental pattern
4. **/validate-data-model** - Catch relationship issues early

### **Tier 2: High Value** (After Tier 1)

5. **/generate-test-queries** - Standardize validation
6. **/analyze-refresh-pipeline** - Fix 7:30 AM bottleneck
7. **/check-data-quality** - Automated quality checks
8. **/generate-documentation** - Auto-update docs

### **Tier 3: Nice to Have**

9. **/create-measure** - Generate DAX measures with best practices
10. **/optimize-dax** - Review and optimize existing measures
11. **/generate-report-template** - Standardize report structure
12. **/create-test-data** - Generate realistic test data

---

## 💡 Next Steps

**To maximize value immediately:**

1. **Enable SQL Server MCP**
   - Connect to your EquipRDB64 database
   - Test with simple query validation
   - Build confidence before complex automation

2. **Create `/document-project` skill**
   - Use it to document all 12 undocumented projects
   - Saves hours of manual documentation
   - Builds consistent project structure

3. **Create `/optimize-refresh` skill**
   - Apply to Fact_WorkOrderParts (18-19 min → 3-5 min target)
   - Template for other performance issues
   - Document the optimization process

4. **Enable SharePoint MCP**
   - Automate Price Matrix CSV monitoring
   - Sync documentation to SharePoint
   - Enable team collaboration

**Questions to Consider:**

- Which MCP servers do you currently have access to?
- Are there specific automation workflows you'd like to prioritize?
- Which of the 12 undocumented projects should we start with?
- Would you like me to create the skill JSON files for you?

---

## 📚 Additional Resources

**Claude Code Documentation:**
- Skills: [Claude Code documentation]
- MCP Servers: [Model Context Protocol documentation]
- Configuration: Check your `.claude/settings.json`

**Community Skills:**
- Search GitHub for "claude-code-skills"
- Share skills with your team
- Contribute back to community

**MCP Server Directory:**
- Official MCP servers: [MCP server registry]
- Custom MCP servers: Can be built for specialized needs
