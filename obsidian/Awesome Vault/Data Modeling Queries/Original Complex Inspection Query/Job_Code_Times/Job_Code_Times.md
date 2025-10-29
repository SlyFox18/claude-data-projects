let

  Source = Odbc.Query("dsn=EquipRDB64", "SELECT #(lf)

    rof.branch AS 'Location', #(lf)

    rof.ro_number AS 'wo_number', #(lf)

    COALESCE(#(lf)

        (SELECT #(lf)

            CASE #(lf)

                WHEN TRIM(company_name) <> '' THEN company_name #(lf)

                ELSE STRING(surname, ', ', name) #(lf)

            END #(lf)

         FROM contact #(lf)

         INNER JOIN armaster ON contact.contact_code = armaster.contact_code  #(lf)

         WHERE armaster.acc_no = wir.CHARGE_ACCT), #(lf)

        CASE rod.type#(lf)

            WHEN 'e' THEN 'Excess'#(lf)

            WHEN 'f' THEN 'Fleet'#(lf)

            WHEN 'i' THEN 'Internal'#(lf)

            WHEN 'p' THEN 'Policy'#(lf)

            WHEN 'b' THEN 'Billing'#(lf)

            WHEN 'r' THEN 'Retail'#(lf)

            WHEN 's' THEN 'Misc'#(lf)

            WHEN 'w' THEN 'Warranty'#(lf)

            ELSE rod.type #(lf)

        END || COALESCE(NULLIF(wir.CHARGE_ACCT, ''), '')#(lf)

    ) AS Customer, #(lf)

    CASE rof.ro_progress_status#(lf)

        WHEN 'bi' THEN 'Booked-In'#(lf)

        WHEN 'va' THEN 'Equipment Arrived'#(lf)

        WHEN 'wip' THEN 'Work Commenced'#(lf)

        WHEN 'wf' THEN 'Work Finished'#(lf)

        WHEN 'iv' THEN 'Equipment Invoiced'#(lf)

        WHEN 'ca' THEN 'Customer Advised'#(lf)

        WHEN 'vp' THEN 'Equipment Picked-up'#(lf)

        ELSE rof.ro_progress_status #(lf)

    END AS status, #(lf)

    DATE(expected_datetime) AS WO_Created, #(lf)

    COALESCE(NULLIF(rof.reg, ''), STRING('Stk# ', rof.stock_no)) AS reg, #(lf)

    CASE rod.type#(lf)

        WHEN 'e' THEN 'Excess'#(lf)

        WHEN 'f' THEN 'Fleet'#(lf)

        WHEN 'i' THEN 'Internal'#(lf)

        WHEN 'p' THEN 'Policy'#(lf)

        WHEN 'b' THEN 'Billing'#(lf)

        WHEN 'r' THEN 'Retail'#(lf)

        WHEN 's' THEN 'Misc'#(lf)

        WHEN 'w' THEN 'Warranty'#(lf)

        ELSE rod.type #(lf)

    END AS wo_type, #(lf)

    COALESCE(vf.make, vhs.make) AS make, #(lf)

    COALESCE(vf.model, vhs.model) AS vehicle_model_1, #(lf)

    COALESCE(vf.VIN_NO, vhs.VIN_NO) AS PIN, #(lf)

    rod.job_code, #(lf)

    COALESCE(NULLIF(TRIM(rod.detail), ''), os.detail_line) AS Invoice_Details, #(lf)

    MAX(COALESCE(os.est_hours, 0)) AS hrs_est, #(lf)

    SUM(COALESCE(mw.hours_work, 0)) AS hrs_wrk, #(lf)

    SUM(COALESCE(mw.invoice_hrs, 0)) AS hrs_inv, #(lf)

    COALESCE(vf.model, vhs.model) AS 'Vehicle_Model_2', #(lf)

    rod.job_code AS 'Job_Code', #(lf)

    wir.CHARGE_ACCT AS account_number, #(lf)  -- newly added line

    CASE rod.type#(lf)

        WHEN 'e' THEN 'Excess'#(lf)

        WHEN 'f' THEN 'Fleet'#(lf)

        WHEN 'i' THEN 'Internal'#(lf)

        WHEN 'p' THEN 'Policy'#(lf)

        WHEN 'b' THEN 'Billing'#(lf)

        WHEN 'r' THEN 'Retail'#(lf)

        WHEN 's' THEN 'Misc'#(lf)

        WHEN 'w' THEN 'Warranty'#(lf)

        ELSE rod.type #(lf)

    END AS 'Job_Type',#(lf)

    STRING(mw.mechanic_code, '-', (SELECT STRING(name, ' ', surname) FROM contact WHERE mw.mechanic_code = contact.contact_code)) AS Tech,#(lf)

    CONVERT(DATE, mw.DATE_CLOCKED_IN, 2003) AS Tech_Day, #(lf)

    wscl.claim_no AS Submitted,#(lf)

    os.std_lab_ind AS Standard_Labor,#(lf)

    SUM(it.SALE_VAL) AS SALE_VAL,#(lf)

    os.invoice_no AS INVOICE_NO,#(lf)

    os.Inv_Lab_Val#(lf)

FROM #(lf)

    wkrofile rof #(lf)

LEFT OUTER JOIN #(lf)

    wkvehfl vf ON rof.reg = vf.reg#(lf)

LEFT OUTER JOIN #(lf)

    vhstock vhs ON rof.stock_no = vhs.no#(lf)

INNER JOIN #(lf)

    wkothsub os ON rof.branch = os.ro_branch AND rof.ro_number = os.ro_number#(lf)

INNER JOIN #(lf)

    WkInvReg wir ON os.invoice_no = wir.document_no#(lf)

INNER JOIN #(lf)

    wkrodesc rod ON rof.branch = rod.ro_branch AND rof.ro_number = rod.ro_number AND rod.job_code = os.job_code AND rod.type = os.type#(lf)

LEFT OUTER JOIN #(lf)

    wkmechwk mw ON os.ro_branch = mw.ro_branch AND os.ro_number = mw.ro_number AND os.job_code = mw.job_code AND os.type = mw.job_type AND rod.type = mw.job_type#(lf)

LEFT OUTER JOIN #(lf)

    WarSubCl_Labour wscl ON os.invoice_no = wscl.invoice_no AND wscl.sub_claim = os.claim_no #(lf)

LEFT OUTER JOIN #(lf)

    InTrans it ON os.ro_branch = it.BRANCH AND os.invoice_no = it.REF_NO AND os.job_code = it.JOB_CODE AND os.type = it.TYPE#(lf)

WHERE #(lf)

    rof.ro_progress_status <> '' #(lf)

    AND rod.line_no = 1 #(lf)

    AND COALESCE(wscl.sequence, 1) = 1 #(lf)

    AND DATE(expected_datetime) BETWEEN '2024-01-01' AND CURRENT DATE#(lf)

GROUP BY #(lf)

    rof.branch, rof.ro_number, status, WO_Created, rof.reg, rof.stock_no, wo_type, #(lf)

    vf.make, vhs.make, vehicle_model_1, rod.job_code, Invoice_Details, mw.mechanic_code, #(lf)

    Tech_Day, PIN, Customer, Submitted, Standard_Labor, os.invoice_no, os.Inv_Lab_Val, #(lf)

    wir.CHARGE_ACCT#(lf)

ORDER BY #(lf)

    rof.branch, rof.ro_number, tech_day DESC;")

in

  Source