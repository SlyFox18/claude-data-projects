/*
============================================================================
RAW_WKCDESC - JOB CODE DESCRIPTIONS DATA SOURCE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract job code detailed descriptions from operational database
Grain: One row per job code line (multi-line descriptions supported)
Refresh Strategy: Full refresh with normalized column names only
Integration: Provides detailed descriptions for dim_JobCode enhancement

🎯 BUSINESS PURPOSE:
• Job Code Documentation: Detailed work descriptions for technician guidance
• Service Standardization: Consistent job procedures and quality standards
• Training Materials: Detailed work instructions for new technicians
• Customer Communications: Professional service descriptions for work orders

📊 KEY FIELDS PROVIDED:
• JobCode: Links to dim_JobCode for relationship building
• LineNumber: Multi-line description support for complex procedures
• JobDescription: Detailed work instructions and procedures
• JobValue: Associated value or cost information
• ChargeType: Billing classification for financial integration

============================================================================
*/

let
    SQL = "
        SELECT 
            JOB_CODE AS JobCode,
            LINE_NO AS LineNumber,
            DETAIL AS JobDescription,
            VALUE AS JobValue,
            CHARGE_TYPE AS ChargeType
        FROM WkCdDesc
        ORDER BY JOB_CODE, LINE_NO
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source