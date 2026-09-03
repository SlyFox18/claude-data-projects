# Data Projects - Claude Code Context

## Project Overview

This repository contains Power BI reports built on Microsoft Fabric. Each project folder in `projects/` represents a separate Power BI report with its own semantic model, queries, and documentation.

**Owner:** Brian Fox
**Lakehouse:** `LH_Master_Data` in Fabric workspace
**ODBC Connection:** `dsn=EquipRDB64` (source system)

## Repository Structure

```
data-projects/
├── .claude/
│   ├── queries/              # Shared query library (gold-standard reference)
│   │   ├── raw-tables/       # Raw data ingestion queries (.pq files)
│   │   ├── dimensions/       # Dimension building queries (.pq files)
│   │   ├── facts/            # Fact table metadata (FACT-TABLES-SUMMARY.md)
│   │   └── README.md         # Query library conventions
│   ├── plans/                # Implementation plans from plan mode
│   └── projects/.../memory/  # Auto-memory files
├── projects/
│   ├── customer anatomy - report/      # Customer analysis (flagship report)
│   ├── inspections - report/           # Service inspections (well-documented)
│   ├── inventory analysis - report/    # Inventory analysis (10M+ rows)
│   ├── first pass fill - report/       # Inventory KPI
│   ├── unique parts customers - report/ # Special customer tracking
│   ├── parts adjustments - report/     # Inventory adjustments
│   ├── bin location - report/          # Part bin locations
│   ├── combine vault sales - reports/  # Branch 12 transfers
│   └── ... (20+ total projects)
└── CLAUDE.md                 # This file
```

## Fabric Architecture

### Data Flow
```
Source System (ODBC) → Raw Tables (Lakehouse) → Dimensions → Fact Tables → Semantic Models → Reports
```

### Dataflow Organization (in LH_Master_Data)
- `01 - Raw Sources` - Raw data ingestion from ODBC
- `03 - Dimensions` - Dimension tables and lookup tables
- `04 - Fact` - Fact table transformations

### Key Tables

**Dimensions (shared across reports):**
- `dim_CustomerList` - Primary customer dimension (has calculated columns: CSM, Route Day, EngagementLevel, UniqueCustomerGroup, IsUniqueCustomer)
- `dim_BranchLocation` - Branch/location dimension (used by 14+ projects)
- `dim_DateTable` - Universal date dimension (used by 14+ projects)
- `dim_Parts` - Parts dimension (used by 9+ projects)
- `dim_EngagedAcres` - Engagement data from external CSV
- `lookup_UniqueCustomers_Invoice` - 11 unique customer groups (no relationship, uses LOOKUPVALUE)

**Common Raw Tables:**
- `Invoice` - Sales invoices (columns: CustomerNumber, CustomerOrderNumber, InvoiceDate, InvoiceNumber, Branch, ModuleType)
- `InTrans_Incremental` - Parts transactions (10M+ rows, incremental refresh)
- `ArMaster_Customer` - Customer master data (has TradeType column)
- `jdis_Part_Information` - Parts master data (1M+ rows)

## Conventions

### Power Query
- All queries have comprehensive header comments (purpose, grain, source, business use)
- Lakehouse column names use **PascalCase** (normalized from raw source)
- Delta tables reject column names with spaces - always rename in dataflows
- Incremental refresh uses `RangeStart`/`RangeEnd` datetime parameters

### DAX Patterns
- **Dimension flagging via lookup tables:** Use `LOOKUPVALUE` on calculated columns (no model relationship needed). Used for: EngagementLevel, UniqueCustomerGroup, IsUniqueCustomer
- **HTML visuals:** Inline CSS for KPI cards and badges (purple #818cf8 for Unique, gold #fbbf24 for Key Customer)
- **Multi-level fact tables:** Level 1 (aggregated), Level 2 (invoice detail), Level 3 (line items)

### Semantic Model Files (.tmdl)
- Located in `reports/current/{ReportName}.SemanticModel/definition/`
- Tables in `tables/` subfolder
- Measures typically in `_Measures.tmdl`
- Cultures in `cultures/` subfolder
- **TMDL does NOT support `//` comments** — never add `//` comment lines anywhere in a `.tmdl` file (they cause parse errors). DAX `//` comments inside backtick measure expressions are fine; TMDL-level comments are not.

### CSV Imports to Fabric
1. Upload CSV to Lakehouse Files section
2. Create Dataflow Gen2 to read from Files, transform, and output to Lakehouse table
3. Always rename columns to remove spaces in the dataflow (Delta compatibility)

## Refresh Pipeline

### Architecture
```
4:15 AM CST Mon-Fri → Pipeline_Master_Orchestrator
  Phase 1: Raw Data (26 DFs, parallel) → Phase 2: InTrans (incremental)
  → Phase 3: Dimensions (14+ DFs) → Phase 4: Facts (24 DFs, 5-wave batches)
  → Phase 5: Semantic Models (17 reports) → Phase 6: Tier 2 reports
  Total: ~80-95 min, complete by ~6:00 AM
```

### Key Constraints
- **F4 Capacity:** 4 CU sustained, keep concurrent DFs to 4-5 per wave
- **Source System:** ODBC performs well off-peak (3-6 AM), degrades during business hours
- **Dependencies:** Raw → InTrans → Dims → Facts → Semantic Models (strict order)

### Report Tiers
- **Tier 1 (12 reports):** Fresh by 8 AM daily - Customer Anatomy, Inspections, Inventory Analysis, 60+ Past Due, Open Work Orders, Open Parts Tickets, First Pass Fill, Negative On Hand, Parts Adjustments, Part Sales Low Margin, Parts Promo, Parts Not Re-Ordered
- **Tier 2 (5 reports):** Daily, can finish after 8 AM - Labor Performance, Unique Parts Customers, Combine Vault Sales, Pin Capture, Physical Inventory
- **Tier 3 (2 reports):** Weekly Monday 5 AM - Price Matrix, Bin Location

### Workspaces
- **Production:** RP - Parts Reports, RP - Service Reports, RP - Financial Reports
- **Sandbox:** RP - Sandbox (Customer Anatomy V2, Inventory Analysis V3, Parts Promo pending promotion)
- **Pipeline Home:** LH_Master_Data (all dataflows, pipelines, notebooks)

### Documentation
- Full pipeline docs: `projects/refresh-pipeline/`
- Schedule reference: `projects/refresh-pipeline/pipeline-schedule.md`
- Performance baselines: `.claude/queries/REFRESH-TIMES.md`

---

## Git Workflow

### Branch Strategy

| Branch | Purpose | Fabric Workspace |
|--------|---------|-----------------|
| `main` | Production — protected, PR required | RP - Parts Reports, RP - Service Reports, RP - Financial Reports |
| `dev` | Sandbox development and testing | RP - Sandbox |
| `feature/*` | Individual report/feature work (optional) | Local only |

**Same branching strategy applies to both repos:**
- `data-projects` (GitHub: SlyFox18/claude-data-projects) — queries, docs, TMDL files
- `fabric-workspace-docs` (GitHub: SlyFox18/fabric-workspace-docs) — Fabric Git Integration mirror

### Standard Workflow

**Two-repo architecture (critical distinction):**
- `data-projects` — local dev workspace (queries, docs, plans). NOT Fabric-integrated. Changes here do NOT affect Fabric.
- `fabric-workspace-docs` — Fabric Git Integration mirror. This IS what Fabric reads/writes. Changes here DO affect Fabric.

**Fabric Deployment Pipeline: "Dev Pipeline"**
- Stages: RP-Dev → RP-Sandbox (2 stages only)
- Reason: linear pipelines cannot branch to multiple production workspaces; each workspace can only belong to one pipeline
- Production promotion is done via Desktop publish directly to the target workspace

**Development → Production flow:**
```
1. Build in Power BI Desktop
2. Publish to RP-Dev → verify privately (Brian only)

For significant changes (new reports, data model changes):
3. Deploy RP-Dev → RP-Sandbox via "Dev Pipeline" → stakeholder validates

For minor changes (label fixes, formatting, job code updates):
3. Skip Sandbox — go directly to step 4

4. Desktop → Publish to the correct production workspace:
   - Parts reports  → RP - Parts Reports
   - Service reports → RP - Service Reports
   - Financial reports → RP - Financial Reports

5. In the Fabric workspace → Git integration → Commit
   → pushes changes to fabric-workspace-docs/dev branch

6. Open PR: dev → main in fabric-workspace-docs
7. Merge PR → production workspaces update via Git integration "Update all"
```

### Branch Protection

- `main` on `claude-data-projects`: **Protected** — requires PR, 0 approvers required (solo dev), enforced on admins
- `main` on `fabric-workspace-docs`: **Not enforceable** — GitHub Free plan limitation for private repos; Fabric access control serves as the gate
- Direct pushes to `main` should be avoided even on fabric-workspace-docs

### PR Templates

Located at `.github/PULL_REQUEST_TEMPLATE/dev_to_main.md` in both repos.
Covers: reports changed, data model changes, refresh pipeline impact, sandbox testing checklist, query library updates, deployment notes.

### Session Start Orientation (automated)

A `SessionStart` hook (`~/.claude/scripts/git-status-check.sh`, registered in `~/.claude/settings.json`) runs automatically at the start of every session and prints: `data-projects` git status, `fabric-workspace-docs` git status + dev/main divergence, and open High/Medium items from `C:/Users/bfox/todo.md`. This is hook-guaranteed, not a prompt instruction — if its output is missing from context at session start, the hook itself is broken (check for a stray `"async": true` on that SessionStart entry; SessionStart hooks must run synchronously to inject context).

`C:/Users/bfox/todo.html` (the browser-viewable dashboard rendering of `todo.md`) is regenerated automatically by `~/.claude/scripts/render_todo_html.py` — on every SessionStart, and via a PostToolUse hook (`~/.claude/scripts/todo-html-sync.sh`) whenever `todo.md` is edited. Never hand-edit `todo.html` directly or manually "re-render" it — edit `todo.md` only, the hook keeps the HTML in sync deterministically.

### When Claude Is Helping With Development

- **Always work on `dev` branch**, not `main`
- After completing work: commit to `dev`, push, then remind to validate in RP - Sandbox before merging to `main`
- Never commit directly to `main` unless it's a docs-only change with no Fabric impact
- After a PR merges to `main` on fabric-workspace-docs: remind to sync affected production workspaces in Fabric UI

---

## Related Repositories & Knowledge Bases

### Fabric Workspace (Production)
**Path:** `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs`
- Pure Fabric Git Integration mirror — workspace artifacts only (no scripts/logs/docs)
- 220+ items across 9 workspaces (LH_Master_Data, RP - Parts Reports, RP - Service Reports, etc.)
- 83 dataflows in LH_Master_Data, 531 .tmdl files, 122 mashup.pq files
- Contains the production Power Query (mashup.pq) for every dataflow
- Use this to verify what's actually deployed vs what's in development here

### Fabric Monitoring
**Path:** `projects/fabric-monitoring/` (in this repo)
- Windows Task Scheduler automation for post-pipeline monitoring (runs 6 AM Mon-Fri)
- `scripts/scheduled/` — Get-FreshToken.ps1, Run-PostPipeline-Monitoring.ps1, Register-ScheduledTasks.ps1
- `scripts/enhanced/` — 6 active monitoring scripts (Discover, Backfill, Freshness, CU, Changes, Dashboard)
- `scripts/Startup-AzureLogin.ps1` — Azure credential refresh (7 AM task)
- `logs/` — daily post-pipeline-YYYY-MM-DD.log files
- `documentation/` — auto-updated CSVs and markdown reports (committed to dev by the scheduled task)
- Teams notification: uses Microsoft.Graph module (`Connect-MgGraph -Scopes "ChannelMessage.Send"`), posts to Fabric Monitoring channel
- See `scripts/scheduled/README.md` for setup guide and troubleshooting

### Obsidian Knowledge Base
**Path:** `C:\Users\bfox\Documents\Obsidian Vault`
- **Awesome Vault** - 131 files: query library with versioned dimensions, facts, raw tables
- **Inspections Report Knowledge Base** - 20 files: project-level architecture, pipeline, data model docs
- When documenting completed features, update Obsidian vault too if asked

## Working With This Repo

### Before modifying any report:
1. Read the project's documentation (README.md, ARCHITECTURE.md, etc.) if it exists
2. Check `.claude/queries/` for existing query patterns
3. Check `FACT-TABLES-SUMMARY.md` for table metadata and relationships

### When creating new queries:
1. Follow the header comment convention from existing `.pq` files
2. Save a copy to `.claude/queries/` in the appropriate subfolder
3. Use PascalCase for Lakehouse column names

### When modifying DAX:
1. Read the relevant `.tmdl` file first
2. For cross-table flags, prefer LOOKUPVALUE on calculated columns over model relationships
3. Test with existing slicers and filters

### Documentation expectations:
- Update project-level docs when making significant changes
- Keep `.claude/queries/` files in sync with actual dataflow queries
- Update FACT-TABLES-SUMMARY.md when adding/modifying fact tables

---

## Known Issues & Gotchas

### Power Query / Dataflows
- **Delta column names:** Delta tables reject column names with spaces — always rename columns in the dataflow before loading to Lakehouse
- **InTrans join key:** `InTrans.REF_NO` = invoice number, NOT work order number. Using work order number produces ~186 rows instead of ~150K (caused the Inspections bug)
- **Incremental refresh parameters:** `RangeStart`/`RangeEnd` must be **datetime** type, not date. Using date type causes silent failures or incorrect filtering
- **Query folding:** Avoid operations that break query folding (type conversions on folded columns, unsupported functions). Breaking folding causes full data transfer from source
- **Fabric API for Gen2 dataflows:** `/v1/workspaces/{id}/dataflows/{id}/refreshes` returns 404 for Dataflow Gen2. Use `/v1/workspaces/{id}/items/{id}/jobs/instances?jobType=Refresh` instead. Field names are `startTimeUtc`/`endTimeUtc`, not `startTime`/`endTime`

### DAX / Semantic Models
- **Cross-table flags:** Always use `LOOKUPVALUE` on calculated columns — do NOT create model relationships for flag/lookup tables (`lookup_UniqueCustomers_Invoice`, `dim_EngagedAcres`). Relationships cause circular dependency issues
- **Bidirectional relationships:** Avoid `crossFilteringBehavior: bothDirections` — significant performance risk, causes ambiguous filter paths
- **Calculated columns and refresh order:** `dim_CustomerList` calculated columns (CSM, EngagementLevel, UniqueCustomerGroup, IsUniqueCustomer) depend on `lookup_UniqueCustomers_Invoice` being refreshed first. If the lookup table changes, re-run dim refresh

### Pipeline / Capacity
- **F4 CU limit:** Max 4-5 concurrent dataflows per wave. Exceeding this causes throttling and cascading failures. Phase 4 uses 5-wave batching for this reason
- **ODBC source hours:** `dsn=EquipRDB64` performs well 3–6 AM. Queries during business hours degrade significantly — avoid ad-hoc full refreshes during the day
- **Phase dependency:** Raw → InTrans → Dims → Facts → Semantic Models is a strict order. If a phase fails, all downstream phases produce stale data even if they "succeed"
- **Fact_WorkOrderParts bottleneck:** Consistently ~18.5 min, the pipeline's longest step. Do not add dependencies to it without considering impact on total runtime

### Customer Anatomy Specific
- **Unknown Customer in service data:** `Invoice.BillToAccount` does not match `dim_CustomerList.CustomerNumber` for service invoices (~$1.6M revenue unattributed). Parts work correctly. See `INVESTIGATION-PLAN-Unknown-Customers.md`
- **CustomerNumber 25227:** Matches multiple unique customer patterns — resolves to Manuel/MR Tractor by priority order in the lookup table

---

## CLI Tools Available

Three CLI tools are installed and available for use via Bash. Always add `$env:Path += ";C:\Users\bfox\.local\bin"` if running in a PowerShell session that doesn't recognize the commands (terminals opened before install). In Bash via Claude Code, use `export PATH="$HOME/.local/bin:$PATH"`.

### pbir (pbir.tools v0.9.5)
Report-layer tool — works on local PBIR files and Fabric workspace. No Desktop required.
- `pbir tree "Report.Report"` — full visual inventory (pages, visuals, types, filters)
- `pbir fields list "Report.Report"` — all fields/measures used across the report
- `pbir ls / pbir find` — browse pages and visuals
- `pbir set "Report/**/*.Visual.title.fontSize" --value 14 -f` — bulk formatting via glob
- `pbir download "Workspace.Workspace/Report.Report" --output ./path` — pull from Fabric
- `pbir publish "Report.Report" "Workspace.Workspace/Report.Report"` — push to Fabric
- `pbir validate "Report.Report" --all` — check for broken references, overlaps
- `pbir backup / pbir restore` — snapshot before risky changes
- Use skill: `pbir-cli`

### pbi (pbi-cli v1.0.6)
Semantic model tool — connects to a running Power BI Desktop instance via XMLA.
- **Requires Power BI Desktop open** with the target file
- Connection name pattern: `PBIDesktop-{ReportName}-{Port}` (e.g. `PBIDesktop-MD Invoices With No Freight-53960`)
- `pbi connect` — auto-detect Desktop port; use `-d localhost:{port} -n "{name}"` to set exact name
- `pbi measure list` / `pbi measure create` / `pbi measure update`
- `pbi dax execute "EVALUATE ..."` — run DAX against live model
- `pbi table list` / `pbi column list`
- `pbi relationship list`
- `pbi database export-tmdl ./folder` — export full TMDL to disk
- Use REPL for interactive sessions: `pbi repl`
- Use skills: `power-bi-dax`, `power-bi-modeling`, `power-bi-deployment`, `power-bi-security`

### fab (Microsoft Fabric CLI v1.5.0)
Fabric workspace tool — authenticated as bfox@spitractor.com.
- `fab ls` — list all workspaces
- `fab ls "RP - Sandbox.Workspace"` — list items in a workspace
- `fab get "Workspace.Workspace/Item.SemanticModel" -q "id"` — get item properties
- `fab export / fab import` — download/upload items (always use `-f` flag to avoid interactive prompts)
- `fab cp "Source.Workspace/Item" "Dest.Workspace"` — copy items between workspaces
- Always use `-f` flag on destructive/overwrite operations or agent will hang on confirmation prompts
- Use skill: `fabric-cli`

---

## Skills Available

| Skill | Command | Use When |
|-------|---------|----------|
| Check refresh status | `/check-refresh` | Morning check, investigating staleness |
| New report scaffold | `/new-report "Name"` | Starting a brand new report project |
| Promote to production | `/promote-sandbox "Name"` | Moving sandbox report to production |
| Add DAX measure | `/add-measure "report" "description"` | Adding a new measure to any report |
| Debug pipeline failure | `/debug-pipeline "problem"` | Pipeline failed or data is stale |
| Sync query library | `/sync-query` | After modifying a .pq dataflow query |
| Document report | `/document-report "report"` | Create stakeholder Obsidian docs for a report that doesn't have them yet |
| Wrap up session | `/wrap-up` | End of a work session |
