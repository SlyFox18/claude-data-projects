let

    // Incremental refresh parameters with fallbacks

    StartDate = try RangeStart otherwise #datetime(1900, 1, 1, 0, 0, 0),

    EndDate = try RangeEnd otherwise DateTime.LocalNow(),

    // Format dates for your database (confirmed working format)

    StartDateText = DateTime.ToText(StartDate, "yyyy-MM-dd HH:mm:ss"),

    EndDateText = DateTime.ToText(EndDate, "yyyy-MM-dd HH:mm:ss"),

    // Base query

    BaseQuery = "SELECT

        pi_Branch AS Branch,

        pi_Franchise AS Franchise,

        pi_Part_No AS PartNumber,

        pi_Source AS Source,

        pi_SLC AS SLC,

        pi_Dealer_Group_Code AS DealerGroupCode,

        pi_Description AS Description,

        pi_Commodity_Code AS CommodityCode,

        pi_Vendor_Code AS VendorCode,

        pi_Inventory_Cost AS InventoryCost,

        pi_Bin AS Bin,

        pi_Bin_Qty AS BinQty,

        pi_Bulk_Bin AS BulkBin,

        pi_On_Hand_Qty AS QuantityOnHand,

        pi_Back_Ord_Qty AS BackOrderQty,

        pi_Return_Indicator AS Returnable,

        pi_Sell_Price_1_Master_File AS SellPrice1,

        pi_Cost AS Cost,

        pi_current_12_mo_sales AS Current12MoSales,

        pi_current_12_dollars AS Current12MoDollars,

        pi_List_Price_Master_File AS ListPrice,

        pi_Date_Created AS DateCreated,

        pi_Date_Last_Request AS DateLastRequested,

        pi_Stocktake_Date AS StocktakeDate

    FROM jdis_Part_Information",

    // Add incremental filter when in incremental refresh mode

    FinalQuery = if (try RangeStart is null otherwise true) then

        BaseQuery  // Full refresh mode - get all records

    else

        BaseQuery & " WHERE pi_Date_Last_Request >= '" & StartDateText & "' AND pi_Date_Last_Request < '" & EndDateText & "'",

    Source = Odbc.Query("dsn=EquipRDB64", FinalQuery)

in

    Source