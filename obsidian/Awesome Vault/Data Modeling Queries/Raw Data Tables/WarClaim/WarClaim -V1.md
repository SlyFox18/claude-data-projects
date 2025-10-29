// Raw_WarClaim - Warranty Claims Header Data

// Purpose: Extract warranty claim headers with incremental refresh capability

  

let

    // Define incremental refresh parameters (3 years lookback)

    RangeStart = #datetime(2022, 1, 1, 0, 0, 0),

    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL string format for the query

    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",

    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // Build SQL query with normalized field names and incremental filter

    SQL =

    "SELECT #(lf)

        INVOICE_NO AS InvoiceNumber, #(lf)

        REPAIR_DATE AS RepairDate, #(lf)

        RO_NUMBER AS WorkOrderNumber, #(lf)

        RO_BRANCH AS WorkOrderBranch, #(lf)

        FRANCHISE AS Franchise, #(lf)

        CLAIM_NO AS ClaimNumber, #(lf)

        STATUS AS ClaimStatus, #(lf)

        DRIVER AS DriverName, #(lf)

        OWNER AS OwnerName, #(lf)

        PART_INVOICE_VAL AS PartsInvoiceValue, #(lf)

        LAB_INVOICE_VAL AS LaborInvoiceValue, #(lf)

        SUB_INVOICE_VAL AS SubletInvoiceValue, #(lf)

        OTH_INVOICE_VAL AS OtherInvoiceValue, #(lf)

        WARRANTY_WRITE_OFF AS WarrantyWriteOff, #(lf)

        WARRANTY_REJECTION AS WarrantyRejection, #(lf)

        GST_VALUE AS GSTValue, #(lf)

        Owner_Status_Code AS OwnerStatusCode, #(lf)

        Model_Serial_No AS ModelSerialNumber, #(lf)

        LAST_UPDATE_TS AS ModifiedDate #(lf)

    FROM WarClaim #(lf)

    WHERE REPAIR_DATE >= " & StartStr & " #(lf)

      AND REPAIR_DATE < " & EndStr & " #(lf)

      AND INVOICE_NO IS NOT NULL #(lf)

      AND CLAIM_NO IS NOT NULL",

    // Execute the query

    Source = Odbc.Query("dsn=EquipRDB64", SQL)

in

    Source

  

/*

FIELD MAPPINGS & EXPLANATIONS:

  

IDENTIFIERS:

- InvoiceNumber: Links to invoice system

- WorkOrderNumber + WorkOrderBranch: Links to work order system  

- ClaimNumber: Primary warranty claim identifier

- ModelSerialNumber: Equipment serial number

  

FINANCIAL VALUES:

- PartsInvoiceValue: Parts cost on warranty claim

- LaborInvoiceValue: Labor cost on warranty claim  

- SubletInvoiceValue: Subcontracted work cost

- OtherInvoiceValue: Other miscellaneous costs

- WarrantyWriteOff: Amount written off by manufacturer

- WarrantyRejection: Amount rejected by manufacturer

- GSTValue: Tax/GST amount

  

OPERATIONAL DATA:

- RepairDate: When warranty repair was performed

- ClaimStatus: Status of warranty claim (O=Open, etc.)

- Franchise: Equipment brand (John Deere, Case, etc.)

- DriverName/OwnerName: Equipment operator/owner

- OwnerStatusCode: Classification of owner type

  

AUDIT:

- ModifiedDate: For incremental refresh tracking

  

INCREMENTAL REFRESH:

- Filters on REPAIR_DATE for 3-year window

- Uses ModifiedDate for change tracking

- Excludes records with missing key identifiers

  

PERFORMANCE OPTIMIZATIONS:

- Essential fields only in SELECT

- Early filtering in WHERE clause

- Proper date range limiting

- NULL checks for data quality

  

NEXT STEPS:

1. Test this query for data volume and performance

2. Build Fact_WarrantyClaims using this as source

3. Optionally add WarSubCl_Labour detail later for line-item analysis

*/