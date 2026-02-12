let
  Source = Odbc.Query("dsn=EquipRDB64", "SELECT#(lf)    BRANCH,#(lf)  REF_NO,#(lf)  FRANCHISE,#(lf)    PART_NO,#(lf)    Trans_Datetime,#(lf)     customer_no,#(lf)    TYPE,#(lf)    REF_NO,#(lf)    QTY,#(lf)    SALE_VAL,#(lf)    COST_VAL,#(lf)    TRADE_TYPE,#(lf)    DESCRIPTION,#(lf)    LIST_PRICE,#(lf)    Salesman#(lf)FROM#(lf)    InTrans#(lf)WHERE#(lf)    Trans_Datetime >= DATEADD(YEAR, -2, GETDATE())#(lf)#(lf)")
in
  Source