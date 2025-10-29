# Naming Conventions

## Power BI Naming Standards

### Tables
- **Fact Tables:** `Fact_[BusinessEntity]` (e.g., `Fact_PhysicalInventory`)
- **Dimension Tables:** `dim_[Entity]` (e.g., `dim_BranchLocation`)
- **Staging/Raw Tables:** `Raw_[SourceSystem]_[Entity]` (e.g., `Raw_jdis_Part_Information`)

### Measures
- **Format:** [Business Name] (e.g., `Total Parts Counted`)
- **Use Spaces:** Yes, for readability
- **Avoid Abbreviations:** Use full words when possible

### Columns
- **PascalCase:** For calculated columns (e.g., `IsCurrentYear`)
- **Descriptive Names:** Clear purpose (e.g., `DateKey` not `DK`)

### Files
- **Lowercase with hyphens:** For project folders (e.g., `physical-inventory`)
- **No spaces:** In folder or file names

## Dataflow Naming

- **Format:** `[Layer]_[Purpose]`
  - Raw: `Raw_SourceSystem`
  - Dimension: `dim_EntityName`
  - Fact: `Fact_BusinessProcess`

## Git Commit Messages

- **Format:** `[Type]: Brief description`
- **Types:**
  - `feat:` New feature
  - `fix:` Bug fix
  - `docs:` Documentation
  - `refactor:` Code restructuring
  - `perf:` Performance improvement

**Example:** `feat: Add rolling period filters to dim_DateTable`
