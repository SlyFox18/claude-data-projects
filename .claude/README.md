# Claude Context for Power BI Projects

This directory contains standardized context, templates, and workflows for all Power BI report projects in this repository.

## Purpose

Provide Claude with consistent context across all projects to:
- Maintain documentation standards
- Follow naming conventions
- Apply DAX best practices
- Optimize for F4 capacity CU consumption
- Ensure consistent report branding and layout

## Directory Structure

```
.claude/
├── context/              # Background information about your environment
│   ├── fabric-architecture.md     # Lakehouse structure and dataflow organization
│   ├── naming-conventions.md      # Standard naming patterns
│   ├── common-dimensions.md       # Reusable dimensions across reports
│   ├── dax-best-practices.md      # DAX coding standards
│   └── cu-optimization.md         # F4 capacity optimization guidelines
│
├── templates/            # Documentation templates for consistency
│   ├── project-readme-template.md
│   ├── fix-documentation-template.md
│   └── discovery-template.md
│
└── skills/               # Custom Claude Code skills (slash commands)
    └── (to be created)
```

## How to Use

### For Claude

When working on any Power BI project in this repository:
1. Read relevant context files from `.claude/context/`
2. Apply naming conventions and best practices
3. Use templates from `.claude/templates/` for documentation
4. Follow the patterns established in this context

### For User

- Update context files when architecture or standards change
- Create new templates as needed
- Invoke skills with slash commands (e.g., `/new-report`, `/document`)

## Key Priorities

1. **CU Optimization** - F4 capacity management is critical
2. **Consistent Documentation** - All projects should follow the same structure
3. **Naming Standards** - Dataflows, dimensions, and facts follow established patterns
4. **Version Control** - Track changes to reports, queries, and configurations
5. **Reusability** - Build dimensions and measures that work across projects

---

**Environment:** Microsoft Fabric (F4 Capacity)
**Primary Lakehouse:** LH_Master_Data
**Source System:** SQL Anywhere (ODBC connection)
**Departments:** Parts, Service, Financial (expanding to Sales)
