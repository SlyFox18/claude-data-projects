Odbc.Query("dsn=EquipRDB64",

"SELECT #(lf)

    RO_BRANCH AS Branch, #(lf)

    RO_NUMBER AS WorkOrder, #(lf)

    JOB_CODE AS JobCode, #(lf)

    TYPE AS JobType, #(lf)

    LINE_NO AS LineNumber, #(lf)

    VALUE AS JobValue #(lf)

FROM wkrodesc #(lf)

WHERE LINE_NO = 1")