# Pipeline Documentation

This folder contains comprehensive documentation for the 4-phase pipeline architecture that powers the Inspections Report refresh process at South Plains Implement.

## 📚 Documentation Index

### Core Architecture
- **[Architecture Overview](./architecture-overview.md)** - Start here for the big picture
  - Executive summary of the complete pipeline system
  - Business problem and solution overview
  - Performance improvements and cost savings
  - Architecture diagrams and technology stack

### Phase-by-Phase Documentation
- **[Phase 1: Raw Data](./phase-1-raw-data.md)** - Source data refresh from ODBC
  - 21 parallel dataflow refreshes
  - Weekday-only scheduling logic
  - Connection management

- **[Phase 2: InTrans Incremental](./phase-2-intrans-incremental.md)** - Parts transaction incremental loading
  - Watermark-based incremental refresh strategy
  - 97% performance improvement (16-18 min → 1-2 min)
  - 90% reduction in CU usage

- **[Phase 3: Dimensions](./phase-3-dimensions.md)** - Dimension table refresh
  - Parallel dimension refreshes
  - Selective activation/deactivation strategy
  - Dimension management best practices

- **[Phase 4: Facts and Semantic Models](./phase-4-facts-semantic-models.md)** - Fact tables and report refresh
  - Three fact table refreshes in parallel
  - Universal semantic model refresh notebook
  - Power BI API integration

- **[Master Orchestrator](./master-orchestrator.md)** - Complete workflow coordination
  - Sequential phase execution
  - Error handling and notifications
  - Scheduling and monitoring

### Implementation Guides
- **[Scaling Guide](./scaling-guide.md)** - How to add more reports and expand the system
  - Adding new semantic models
  - Creating additional fact tables
  - Performance optimization strategies

- **[Migration Guide: InTrans](./migration-guide-intrans.md)** - Moving from old InTrans to InTrans_Incremental
  - Step-by-step migration process
  - Updating fact tables and measures
  - Validation and testing procedures

- **[Troubleshooting Guide](./troubleshooting-guide.md)** - Common issues and solutions
  - Pipeline failure scenarios
  - Performance issues
  - Data quality problems
  - Debugging techniques

## 🎯 Quick Start

**New to the system?** Start here:
1. Read [Architecture Overview](./architecture-overview.md) to understand the big picture
2. Review each phase documentation in order (Phase 1 → 2 → 3 → 4)
3. Study [Master Orchestrator](./master-orchestrator.md) to see how it all connects
4. Reference [Troubleshooting Guide](./troubleshooting-guide.md) when issues arise

**Looking to expand?**
- Read [Scaling Guide](./scaling-guide.md) for adding new reports
- Reference [Migration Guide](./migration-guide-intrans.md) for InTrans migration patterns

## 📊 System Performance Summary

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| InTrans Refresh | 16-18 min | 1-2 min | 97% faster |
| Total Report Refresh | 60-120 min | 30-35 min | 60-70% faster |
| CU Consumption (InTrans) | High | Low | 90% reduction |
| Data Freshness | 1-2x daily | 2x+ daily | More frequent updates |

## 🔧 Technologies Used

- **Microsoft Fabric**: Data Pipelines, Dataflow Gen2, Lakehouse, Notebooks, Semantic Models
- **Storage**: Delta Lake (Lakehouse)
- **Compute**: F4 Capacity
- **Integration**: ODBC connections to Dealer Management System
- **Notifications**: Office 365 Outlook (email alerts)
- **Language**: Power Query M, Python (PySpark), DAX

## 📝 Document Conventions

- **Pipeline names** are formatted as `Pipeline_Name`
- **Table names** are formatted as `TableName` or `Table_Name`
- **Code blocks** use appropriate syntax highlighting
- **Internal links** use relative paths for portability
- **External links** reference official Microsoft documentation

## 📅 Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-21 | Brian Fox | Initial documentation - Complete 4-phase architecture |

## 🤝 Contributing

When updating these documents:
1. Update the "Last Updated" date in the document header
2. Add an entry to the Version History section
3. Update the parent README.md if adding new documents
4. Keep code examples current with actual implementation
5. Test all internal links after changes

## 📞 Contact

**System Owner:** Brian Fox  
**Team:** Data Analytics  
**Organization:** South Plains Implement  
**Fabric Capacity:** F4  
**Environment:** Production

For questions or issues, reference the appropriate documentation file above.

---

*This documentation is maintained in the South Plains Implement DATA-PROJECTS repository under `projects\inspections-report\documentation\pipelines\`*