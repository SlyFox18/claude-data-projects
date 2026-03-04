let
    // Get the watermark datetime value
    WatermarkValue = if Value.Is(GetWatermark, type table) then GetWatermark{0}[LastLoadedDatetime] else GetWatermark,
    
    // Convert to SQL-friendly datetime string format
    WatermarkText = DateTime.ToText(WatermarkValue, "yyyy-MM-dd HH:mm:ss"),
    
    // Build the SQL query with ALL columns normalized
    SQL = "SELECT 
    Trans_Datetime AS TransDatetime,
    ModifiedDate AS ModifiedDate,
    CreationDate AS CreationDate,
    BRANCH AS Branch,
    REF_NO AS RONumber,
    TYPE AS Type,
    PART_NO AS PartNumber,
    DESCRIPTION AS Description,
    FRANCHISE AS Franchise,
    QTY AS Qty,
    customer_no AS CustomerNo,
    TRADE_TYPE AS TradeType,
    JOB_CODE AS JobCode,
    JOB_TYPE AS JobType,
    SALE_VAL AS SaleValue,
    COST_VAL AS CostValue,
    SELL_PRICE1 AS SellPrice1,
    LIST_PRICE AS ListPrice,
    Transfer_Branch AS TransferBranch,
    PIN_NO AS PinNo,
    Bill_to_Acc AS BillToAcc,
    SALE_TAX AS SaleTax,
    SALE_CLASS AS SaleClass,
    BACK_ORD_QTY AS BackOrdQty,
    ORIGINAL_INVOICE_NO AS OriginalInvoiceNo,
    NOTATION AS Notation,
    ORDER_DATE AS OrderDate,
    DELIVERY_DATE AS DeliveryDate,
    SPECIAL_INVOICE_IND AS SpecialInvoiceInd,
    COMMENTS AS Comments,
    MACHINE_ID AS MachineId,
    Tax_Cat AS TaxCat,
    Taxed_Ind AS TaxedInd,
    claimed_qty AS ClaimedQty,
    File_No AS FileNo,
    trans_id AS TransId,
    Salesman AS Salesman,
    Tax_Region AS TaxRegion,
    Import_Permit_Date AS ImportPermitDate,
    Import_Permit_No AS ImportPermitNo,
    Port_Of_Entry AS PortOfEntry,
    Remaining_Qty AS RemainingQty,
    Internal_Sal_Val AS InternalSalValue,
    Revenue_Indicator AS RevenueIndicator,
    STOCK_NO AS StockNo,
    Segment AS Segment,
    Online_Order AS OnlineOrder,
    Part_Line_Status AS PartLineStatus,
    Shipping_ID AS ShippingId,
    GUID_SO AS GuidSO,
    Order_Salesman AS OrderSalesman,
    Special_Inst AS SpecialInst,
    Transfer_Bo_Ind AS TransferBoInd,
    So_Ro_Ref AS SoRoRef,
    Bin_Location AS BinLocation,
    Order_Qty AS OrderQty,
    Shipped_Qty AS ShippedQty,
    Sub_Part_Received AS SubPartReceived,
    REF_NO_NEW AS RONumberNew,
    WKOTHSUB_GUID_SO AS WkothsubGuidSO,
    ECOMM_ORDER_NO AS EcommOrderNo,
    PART_PICKUPFLAG AS PartPickupFlag,
    Price_Level AS PriceLevel,
    EPC_DocID AS EpcDocId
FROM InTrans
WHERE Trans_Datetime > '" & WatermarkText & "'",
    
    // Execute the query
    Source = Odbc.Query("dsn=EquipRDB64", SQL),
    
    // Remove duplicates based on TransId (primary key)
    // Protects against watermark overlap from system failures, maintenance windows, or concurrent runs
    // NOTE: TransId is the true primary key — do NOT use a composite key here.
    // Using a composite key caused ~7x duplicate accumulation in Dec 2025 – Feb 2026 when
    // the watermark stopped advancing and each pipeline run re-appended the same rows.
    RemoveDuplicates = Table.Distinct(Source, {"TransId"})
in
    RemoveDuplicates
