import duckdb, sys
sys.stdout.reconfigure(encoding="utf-8")
WS="4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"; LH="7348c3a6-8694-4d11-bc70-1bd55be84ea2"
p=lambda t:f"delta_scan('abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Tables/{t}')"
con=duckdb.connect()
con.sql("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
con.sql(f"""CREATE TEMP TABLE j AS SELECT a.ACC_NO, a.Creation_Date acc_created, ac.STATUS_CODE, ac.BILL_TO_ACC, a.In_House_Account_IND, c.*
 FROM {p('ArMaster')} a JOIN {p('ArMaster_Customer')} ac USING(contact_code) LEFT JOIN {p('contact')} c USING(contact_code)""")
print("accounts:", con.sql("select count(*), count(distinct ACC_NO) from j").fetchone())
cols=["company_name","surname","name","Doing_Business_As","Familiar_Name","Business_Individual","street","street_2","city","pcode","postal_street_1","postal_city","postal_pcode",
 "bus_phone","prv_phone","mob_phone","fax_no","BusinessPhone","PrivatePhone","MobilePhone","email_address","Email_Address_2",
 "BILL_TO_ACC","STATUS_CODE","Inactive_Indicator","Inactive_Effect_Date","acc_created","Creation_Date",
 "abn","company_acn","tax_file_no","tax_exempt_no","Social_Security_No"]
n=con.sql("select count(*) from j").fetchone()[0]
for c in cols:
    k=con.sql(f"select count(*) from j where nullif(trim(cast({c} as varchar)),'') is not null and trim(cast({c} as varchar)) not in ('0')").fetchone()[0]
    print(f"{c:22s} {k:7,}  {k/n:6.1%}")
print("bill_to differs from own acct:", con.sql("select count(*) from j where nullif(trim(cast(BILL_TO_ACC as varchar)),'') is not null and trim(cast(BILL_TO_ACC as varchar))<>trim(cast(ACC_NO as varchar))").fetchone())
print("status:", con.sql("select STATUS_CODE, count(*) from j group by 1 order by 2 desc").fetchall())
print("inactive ind:", con.sql("select Inactive_Indicator, count(*) from j group by 1 order by 2 desc").fetchall())
print("bus/indiv:", con.sql("select Business_Individual, count(*) from j group by 1 order by 2 desc").fetchall())
for c in ["abn","company_acn","tax_file_no","Social_Security_No"]:
    print(c,"len/shape:", con.sql(f"select length(trim({c})) l, regexp_matches(trim({c}),'^[0-9-]+$') num, count(*) from j where nullif(trim({c}),'') is not null group by 1,2 order by 3 desc limit 4").fetchall())
