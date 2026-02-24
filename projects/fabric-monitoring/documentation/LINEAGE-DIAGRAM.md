# Fabric Workspace Lineage Diagram

**Generated:** 2025-10-09 16:42:26

This diagram shows the relationships between your Fabric workspaces organized by category.

---

## Overview Diagram

```mermaid
graph TB
    subgraph DataPrep[" Data Preparation"]
        Data_Backup[Data_Backup<br/>9 items]
        LH___Financial_Data_Prep[LH - Financial_Data_Prep<br/>8 items]
        LH___Parts_Data_Prep[LH - Parts_Data_Prep<br/>12 items]
        LH___Service_Data_Prep[LH - Service_Data_Prep<br/>17 items]
        LH_Data_Prep[LH_Data_Prep<br/>15 items]
        LH_Master_Data[LH_Master_Data<br/>91 items]
    end

    subgraph Reporting[" Reporting"]
        RP___Financial_Reports[RP - Financial Reports<br/>2 items]
        RP___Parts_Reports[RP - Parts Reports<br/>17 items]
        RP___Service_Reports[RP - Service Reports<br/>8 items]
    end

    subgraph Development[" Development/Testing"]
        Microsoft_Fabric_Capacity_Metrics_5_15_2025_4_29_08_PM[Microsoft Fabric Capacity Metrics 5/15/2025 4:29:08 PM<br/>0 items]
        My_workspace[My workspace<br/>15 items]
        RP___Sandbox[RP - Sandbox<br/>24 items]
        RP___Service_Sandbox[RP - Service Sandbox<br/>0 items]
    end

    %% Data flow relationships
    LH___Financial_Data_Prep --> RP___Financial_Reports
    LH___Parts_Data_Prep --> RP___Parts_Reports
    LH___Service_Data_Prep --> RP___Service_Reports

    %% Styling
    classDef dataPrep fill:#e1f5ff,stroke:#0288d1,stroke-width:2px
    classDef reporting fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef development fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px

    class Data_Backup dataPrep
    class LH___Financial_Data_Prep dataPrep
    class LH___Parts_Data_Prep dataPrep
    class LH___Service_Data_Prep dataPrep
    class LH_Data_Prep dataPrep
    class LH_Master_Data dataPrep
    class RP___Financial_Reports reporting
    class RP___Parts_Reports reporting
    class RP___Service_Reports reporting
    class Microsoft_Fabric_Capacity_Metrics_5_15_2025_4_29_08_PM development
    class My_workspace development
    class RP___Sandbox development
    class RP___Service_Sandbox development
```

---

## Workspace Distribution

```mermaid
pie title Workspaces by Category
    "Data Preparation" : 6
    "Reporting" : 3
    "Development" : 4
```

---

## Items Distribution

```mermaid
pie title Items by Category
    "Data Prep" : 152
    "Reporting" : 27
    "Development" : 39
```

---

## Legend

- **Blue boxes**: Data Preparation workspaces
- **Orange boxes**: Reporting workspaces
- **Purple boxes**: Development/Testing workspaces
- **Arrows (â†’)**: Data flow relationships

---

## Workspace Details

| Workspace | Category | Items | Type |
|-----------|----------|-------|------|
| Data_Backup | DataPrep | 9 | Workspace |
| LH - Financial_Data_Prep | DataPrep | 8 | Workspace |
| LH - Parts_Data_Prep | DataPrep | 12 | Workspace |
| LH - Service_Data_Prep | DataPrep | 17 | Workspace |
| LH_Data_Prep | DataPrep | 15 | Workspace |
| LH_Master_Data | DataPrep | 91 | Workspace |
| Microsoft Fabric Capacity Metrics 5/15/2025 4:29:08 PM | Development | 0 | Workspace |
| My workspace | Development | 15 | Personal |
| RP - Financial Reports | Reporting | 2 | Workspace |
| RP - Parts Reports | Reporting | 17 | Workspace |
| RP - Sandbox | Development | 24 | Workspace |
| RP - Service Reports | Reporting | 8 | Workspace |
| RP - Service Sandbox | Development | 0 | Workspace |

---

## Statistics

- **Total Workspaces:** 13
- **Total Items:** 218
- **Average Items per Workspace:** 16.8

### By Category

- **Data Preparation:** 6 workspaces, 152 items
- **Reporting:** 3 workspaces, 27 items
- **Development:** 4 workspaces, 39 items

---

**Note:** This lineage diagram shows organizational structure. Actual data flow may vary.
For detailed item-level relationships, see individual workspace documentation.

