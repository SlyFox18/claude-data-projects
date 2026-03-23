---
name: document-report
description: Document a Power BI report — creates in-repo CLAUDE.md and PROJECT-SUMMARY.md, then an Obsidian stakeholder note. Use when the user asks to document a report, create report docs, or runs /document-report.
argument-hint: "[report name]"
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
---

You are documenting a Power BI report. The report to document is: **$ARGUMENTS**

This skill creates two types of documentation in priority order:
1. **In-repo docs (primary)** — files inside the project folder that help developers and Claude work with the report
2. **Obsidian note (secondary)** — a plain-English stakeholder overview in the vault

---

## Step 1 — Find the project folder

Search `projects/` for a folder matching the report name. The folder name may have dashes and "- report" suffix.

## Step 2 — Gather all available information

Read everything that exists. Use Glob to find files, then read:

**Existing project docs (if any):**
- `projects/[folder]/CLAUDE.md`
- `projects/[folder]/README.md`
- `projects/[folder]/ARCHITECTURE.md`
- `projects/[folder]/docs/` or `projects/[folder]/documentation/` — any .md files
- `projects/[folder]/queries/` — any .pq or .dax files for data model context

**Semantic model files (essential for accurate documentation):**
- `projects/[folder]/report/current/*/definition/tables/_Measures.tmdl` — all DAX measures
- `projects/[folder]/report/current/*/definition/tables/Fact_*.tmdl` — fact table columns
- `projects/[folder]/report/current/*/definition/model.tmdl` — relationships
- `projects/[folder]/report/current/*/definition/tables/dim_*.tmdl` — dimension tables (skim for key fields)

Read a well-documented report for reference if helpful:
- `projects/inspections - report/CLAUDE.md` — gold standard CLAUDE.md format
- `projects/parts on open orders - report/PROJECT-SUMMARY.md` — gold standard PROJECT-SUMMARY.md format (if it exists)

---

## Step 3 — Create CLAUDE.md in the project folder

**Audience:** Claude (future sessions) and you as a developer. Technical language is fine. This is the most important file.

Save to: `projects/[folder]/CLAUDE.md`

If one already exists, update it rather than overwrite it — preserve any existing content that's still accurate.

**Required sections:**

```markdown
# [Report Name] — Claude Context

## Report Overview
- **Business purpose:** [1-2 sentences on what business question this answers]
- **Primary users:** [who reads this report]
- **Workspace:** [RP - Parts Reports / RP - Service Reports / RP - Financial Reports / RP - Sandbox]
- **Refresh tier:** [Tier 1 / Tier 2 / Tier 3] — [schedule]
- **Status:** [Production / Sandbox / In Development]

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Row Count (approx) |
|-------|-------|------------|-------------------|
| Fact_XYZ | One row per [X] | Field1, Field2 | ~N rows |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| dim_XYZ | [Lakehouse table] | [FK → Fact join] |

### Key Measures
List the most important measures with a one-line description of what they calculate.
No DAX formulas here — just names and plain-English descriptions.

## Report Pages
| Page | Purpose | Key Visuals |
|------|---------|-------------|
| Page 1 | [what it shows] | [chart types, slicers] |

## Data Flow
[Source system tables] → [Lakehouse raw tables] → [Fact/dim tables] → [Report]
Note any non-standard patterns (e.g., SQL views, incremental refresh, LOOKUPVALUE instead of relationship).

## Known Issues & Gotchas
- Any bugs that were fixed and why (so they don't get re-introduced)
- Any data quality issues or gaps
- Any performance considerations
- Any non-obvious design decisions

## Refresh Pipeline Position
- Which pipeline phase refreshes the fact table(s)
- Dependencies (what must run before this)
- Approximate refresh time if known

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | [✅/❌] PROJECT-SUMMARY.md
- Obsidian stakeholder docs: [✅ Complete — path | ❌ Missing]
```

**Rules for CLAUDE.md:**
- Be specific and technical — this is for developers and Claude, not end users
- Include table names, column names, measure names
- If you found bugs or non-obvious patterns in the TMDL files, document them
- If the refresh schedule is unknown, say so rather than guessing

---

## Step 4 — Create PROJECT-SUMMARY.md in the project folder

**Audience:** Anyone who opens the project folder for the first time. Mix of technical and plain English.

Save to: `projects/[folder]/PROJECT-SUMMARY.md`

If one already exists at a different path (e.g., `docs/01-getting-started/`), note its location in CLAUDE.md instead of creating a duplicate.

**Required sections:**

```markdown
# [Report Name] — Project Summary

## Overview
[2-3 sentences: what does this report do and who uses it?]

**Status:** [Production / Sandbox / In Development]
**Workspace:** [workspace name]
**Refreshed:** [schedule]

## Report Pages

| Page | Purpose |
|------|---------|
| [Page Name] | [What it shows and who uses it] |

## Data Model

### Tables
| Table | Type | Source | Description |
|-------|------|--------|-------------|
| Fact_XYZ | Fact | [dataflow / SQL view] | [what it contains] |
| dim_XYZ | Dimension | [shared / dedicated] | [what it contains] |

### Relationships
[Brief description of how tables connect, or a simple diagram]

## Key Measures
| Measure | Description |
|---------|-------------|
| [Measure Name] | [Plain English: what does it calculate?] |

## Source System Tables
List the ERP/ODBC source tables this report draws from.

## Notes
Any important context, migration history, or decisions worth preserving.
```

---

## Step 5 — Create the Obsidian stakeholder note

**Audience:** Non-technical business users — branch managers, CSMs, executives.

**Language rules:**
- No technical jargon: no Power Query, DAX, TMDL, LOOKUPVALUE, etc.
- No code blocks or formulas
- Avoid internal table names in prose (say "parts transaction data" not "Fact_InTrans")
- Exception: the Data Sources table may use table names since it's developer-adjacent

**Structure:**
1. Header block — what it answers (one sentence), update schedule, workspace, users
2. What This Report Shows — 2–3 plain-English sentences per major section/page
3. Key Metrics table — plain-English definitions, no formulas
4. Report Pages table — page, audience, purpose
5. Data Sources — Mermaid flowchart + table with `[[wikilinks]]`
6. Architecture Notes — only if there are non-obvious decisions worth preserving for developers (keep brief)
7. Related Reports — wikilinks to related reports
8. Status line — Production ✅ / Sandbox / Development + docs date

**Mermaid diagram format:**
```
flowchart LR
    ERP[("EquipRDB\nSource System")] --> T1["Source Table"]
    T1 --> R["Report Name"]
```

Check existing data source notes:
- `C:/Users/bfox/Documents/Obsidian Vault/Data Projects/Data Sources/` — use `[[wikilinks]]` for ones that exist

Save to: `C:/Users/bfox/Documents/Obsidian Vault/Data Projects/Reports/[Clean Display Name].md`

## Step 6 — Create any missing data source stubs in Obsidian

If the report uses data sources not yet in `Data Sources/`, create a stub:

```markdown
# [Source Name]

**What it is:** [One sentence]

[2-3 sentences on what it contains and which reports use it]

*Source: [[Source System (EquipRDB)]]*
```

## Step 7 — Update Obsidian Home.md

Read `C:/Users/bfox/Documents/Obsidian Vault/Data Projects/Home.md`. Change `❌` to `✅` for this report and add a `[[wikilink]]` around the report name if it doesn't have one. If the report isn't in the table yet, add it in alphabetical order.

## Step 8 — Confirm

Tell the user what was created:
- In-repo: paths to CLAUDE.md and PROJECT-SUMMARY.md
- Obsidian: path to the report note
- Any gaps: things you couldn't fill from available sources (unknown refresh tier, missing page names, etc.) — be specific so the user knows what to manually fill in
