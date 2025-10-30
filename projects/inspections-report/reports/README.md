# Inspections Report - Power BI Reports

## 📊 Current Report

**Location:** `current/Inspections-Report.Report/`  
**Format:** PBIP (Power BI Project - text-based)  
**Status:** In Development - Phase 2

**Connection Details:**
- Workspace: [Your Fabric Workspace Name]
- Lakehouse: [Your Lakehouse Name]
- Fact Table: Fact_LaborJobSummary

**Report Pages:**
1. Summary Dashboard (KPIs + detail table)
2. Job Code Breakdown (financial analysis)
3. Pending Inspections (aging analysis)
4. Overview (totals + pending summary)
5. Location Analysis (bar chart)
6. Labor Goals Tracking (actual vs goal)

---

## 📦 Archive

**Location:** `archive/Inspections-Report-OLD.pbix`  
**Format:** PBIX (legacy binary format)  
**Status:** Reference only - DO NOT USE

**Purpose:** 
- Reference for original report design
- Compare metrics with new report
- Validate business logic

**Known Issues:**
- 60-120 minute refresh time
- Causes capacity throttling
- Complex inefficient query
- No incremental refresh

---

## 🔄 Version Control Strategy

### PBIP Format Benefits

**Why PBIP:**
- ✅ Text-based files (Git-friendly)
- ✅ See changes in Git diffs
- ✅ Edit DAX in VS Code
- ✅ Better collaboration
- ✅ Proper version history

### What Gets Committed

**Commit:**
- ✅ Report structure (definition.pbir)
- ✅ DAX measures (separate files)
- ✅ Report JSON (layout, visuals)
- ✅ Semantic model definition

**Don't Commit (.gitignore):**
- ❌ .pbi/localSettings.json (user-specific)
- ❌ Cache files
- ❌ Temp files

---

## 🚀 Working with PBIP

### Opening the Report

**Option 1: Power BI Desktop**
- File → Open → Browse
- Navigate to `current/`
- Select `Inspections-Report.pbip`

**Option 2: VS Code (View/Edit)**
- Open the `.Report/` folder
- View JSON files, edit DAX measures
- Changes sync when reopened in Power BI Desktop

### Saving Changes

1. Make changes in Power BI Desktop
2. File → Save
3. Changes saved to individual files
4. Commit via Git/GitHub Desktop

### Best Practices

**Commit Messages:**
- "Add Summary Dashboard page with KPIs"
- "Update Pending Inspections visual filters"
- "Fix Labor $ measure calculation"

**Branching:**
- Use branches for major changes
- `main` = production-ready report
- `feature/new-page` = experimental changes

---

## 📝 Change Log

### 2025-10-30
- Created reports folder structure
- Saved old report to archive for reference
- Set up PBIP format for version control

---

**Report Maintainer:** [Your Name]  
**Last Updated:** 2025-10-30