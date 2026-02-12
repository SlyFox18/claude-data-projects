let
  Source = Odbc.Query(
        "dsn=EquipRDB64", 
        "SELECT #(lf) 
            BRANCH, #(lf) 
            FRANCHISE, #(lf) 
            customer_no, #(lf) 
            PART_NO, #(lf) 
            Trans_Datetime, #(lf)
            TYPE, #(lf) 
            QTY, #(lf)
            REF_NO, #(lf) 
            SALE_VAL, #(lf) 
            COST_VAL, #(lf)
            DESCRIPTION #(lf)  
        FROM #(lf) 
            InTrans #(lf) 
        WHERE #(lf) 
            Trans_Datetime >= '2023-01-01' #(lf) 
            AND Trans_Datetime <= CURRENT_TIMESTAMP #(lf)"
    )
in
  Source