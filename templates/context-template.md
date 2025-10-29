# [Project Name] - AI Assistant Context

> **Purpose:** This file provides comprehensive context for AI assistants (Claude, GitHub Copilot, etc.) to understand this project deeply.

## ðŸŽ¯ Business Context

### What This Report Does
[Detailed explanation of the business purpose]

### Who Uses It
- **Primary Users:** [Department/Role]
- **Use Frequency:** [How often they use it]
- **Key Decisions Made:** [What business decisions are made with this data]

### Pain Points This Solves
1. [Problem it solves]
2. [Another problem]
3. [Another problem]

## ðŸ“Š Data Model

### Source Systems
- **System:** [Name of source system]
- **Connection Type:** [ODBC/API/Direct Lake/etc.]
- **Refresh Method:** [Full/Incremental]
- **Typical Volume:** [Number of rows]

### Fact Tables
```
Fact_[Name]
â”œâ”€â”€ Keys: [List key columns]
â”œâ”€â”€ Measures: [List measure columns]
â””â”€â”€ Dates: [Date columns for relationships]
```

### Dimension Tables
- **dim_[Name]:** [Purpose]
- **dim_[Name]:** [Purpose]

### Relationships
```
Fact_[Name][Column] --> dim_[Name][Column] (Many-to-One)
```

## ðŸ§® Key Calculations

### [Calculation Name]
**Purpose:** [What it calculates and why]  
**Logic:** [Business logic explanation]  
**DAX/M Code:**
```dax
[Your code here]
```

## ðŸ”„ Refresh Strategy

- **Frequency:** [How often]
- **Duration:** [Typical refresh time]
- **CU Usage:** [Estimated Fabric CUs]
- **Dependencies:** [What needs to refresh first]

## ðŸŽ¨ Report Design

### Pages
1. **[Page Name]:** [Purpose]
2. **[Page Name]:** [Purpose]

### Key Visuals
- **[Visual Type]:** [What it shows and why]

## âš ï¸ Important Notes for AI

### Business Rules
- [Critical business rule to remember]
- [Another critical rule]

### Data Quirks
- [Anything unusual about the data]
- [Known data quality issues]

### Common User Questions
1. **Q:** [Question]  
   **A:** [Answer]

## ðŸ“š Related Projects

- [Link to related report]
- [Link to related documentation]

## ðŸ”§ Maintenance Notes

### Regular Tasks
- [Maintenance task 1]
- [Maintenance task 2]

### Future Enhancements
- [ ] [Enhancement idea 1]
- [ ] [Enhancement idea 2]
