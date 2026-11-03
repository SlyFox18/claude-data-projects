"""John Deere University training workbook (Casey): per employee and store, what training is complete, what's in
progress, and the full training history.

Reads JD's data share and DP_Presentation via OneLake (DuckDB, `az login` credentials). See README.md.

Usage: python build_training.py [--tier prod|dev] [--out FILE.xlsx]
"""
import argparse
from datetime import date

import jdshare as j

ap = argparse.ArgumentParser(description="JD University training by employee and store.")
ap.add_argument("--tier", choices=j.DP, default="prod")
ap.add_argument("--out")
args = ap.parse_args()

con = j.connect()
j.load_branch_map(con, args.tier)
loaded = con.execute(f"SELECT max(lake_ingestion_ts) FROM {j.share('dealer_john_deere_university_training_activity')}").fetchone()[0]

con.execute(f"""CREATE TABLE emp AS
    SELECT e.user_id, trim(concat_ws(' ', initcap(trim(e.frst_nm)), initcap(trim(e.last_nm)))) EmpName, e.title_txt Title,
           e.active = 'Y' Active, e.user_start_dt, e.user_end_dt, lower(nullif(trim(e.email_txt), '')) Email,
           a.Store, a.BranchID, a.Division, e.acct_id
    FROM {j.share('dealer_employee')} e LEFT JOIN jd_acct a ON a.acct_id = e.acct_id""")
# Completed = passed, completed or given substitute credit (JD's Status values end in -PASSED, -COMPLETED,
# -SUBSTITUTE-CREDIT; PROGRAM-COMPLETED too).
DONE = "(t.Status LIKE '%PASSED' OR t.Status LIKE '%COMPLETED' OR t.Status LIKE '%SUBSTITUTE-CREDIT')"
con.execute(f"""CREATE TABLE act AS
    SELECT t.*, {j.jd_date('t.Completion_Date')} done_dt, {j.jd_date('t.Enrollment_Date')} enrl_dt,
           {j.jd_date('t.Assignment_Date')} asgn_dt, {DONE} done
    FROM {j.share('dealer_john_deere_university_training_activity')} t""")
con.execute(f"""CREATE TABLE paths AS
    SELECT p.Student_ID, p.Path_Title, p.Sub_Path_Title,
           count(DISTINCT p.Requirement_Group) req_groups,
           count(DISTINCT p.Requirement_Group) FILTER (WHERE p.Req_Group_Status = 'Y') req_met,
           count(DISTINCT p.Item_ID) FILTER (WHERE p.Item_Completion_Date <> '') items_done,
           bool_or(p.Path_Complete = 'Y') path_complete,
           max(TRY_CAST(p.Item_Completion_Date AS TIMESTAMP))::DATE last_item,
           p.Path_Title ILIKE '%retired%' retired
    FROM {j.share('dealer_john_deere_university_learning_path_progress')} p GROUP BY 1, 2, 3""")
con.execute(f"""CREATE TABLE done_paths AS
    SELECT Student_ID, Path_Title, max(Completion_Date) Completion_Date, Path_Title ILIKE '%retired%' retired
    FROM {j.share('dealer_john_deere_university_completed_learning_paths')} GROUP BY 1, 2""")

since = "current_date - INTERVAL 12 MONTH"
employees = con.execute(f"""
    SELECT e.EmpName, e.Store, e.BranchID, e.Title, CASE WHEN e.Active THEN 'Yes' ELSE 'No' END, e.user_start_dt,
           e.user_end_dt, e.user_id, e.Email,
           count(*) FILTER (WHERE a.done AND a.done_dt >= {since}),
           coalesce(sum(a.Credit_Hours) FILTER (WHERE a.done AND a.done_dt >= {since}), 0),
           count(*) FILTER (WHERE a.done), coalesce(sum(a.Credit_Hours) FILTER (WHERE a.done), 0),
           max(a.done_dt) FILTER (WHERE a.done),
           count(*) FILTER (WHERE a.Status IN ('Assigned', 'ENROLL', 'WAITLIST')),
           (SELECT count(*) FROM done_paths d WHERE d.Student_ID = e.user_id AND NOT d.retired),
           (SELECT string_agg(d.Path_Title, '; ' ORDER BY d.Completion_Date DESC) FROM done_paths d
            WHERE d.Student_ID = e.user_id AND NOT d.retired),
           (SELECT count(*) FROM paths p WHERE p.Student_ID = e.user_id AND NOT p.path_complete AND NOT p.retired)
    FROM emp e LEFT JOIN act a ON a.Student_ID = e.user_id
    GROUP BY e.user_id, e.EmpName, e.Store, e.BranchID, e.Title, e.Active, e.user_start_dt, e.user_end_dt, e.Email
    ORDER BY e.Active DESC, TRY_CAST(e.BranchID AS INT) NULLS LAST, e.EmpName""").fetchall()

by_store = con.execute(f"""
    SELECT coalesce(e.Store, 'Unknown'), e.BranchID, count(DISTINCT e.user_id) FILTER (WHERE e.Active),
           count(DISTINCT e.user_id) FILTER (WHERE e.Active AND a.done AND a.done_dt >= {since}),
           count(*) FILTER (WHERE e.Active AND a.done AND a.done_dt >= {since}),
           coalesce(sum(a.Credit_Hours) FILTER (WHERE e.Active AND a.done AND a.done_dt >= {since}), 0),
           count(*) FILTER (WHERE e.Active AND a.Status IN ('Assigned', 'ENROLL', 'WAITLIST'))
    FROM emp e LEFT JOIN act a ON a.Student_ID = e.user_id
    GROUP BY 1, 2 ORDER BY TRY_CAST(e.BranchID AS INT) NULLS LAST""").fetchall()

history = con.execute("""
    SELECT e.EmpName, e.Store, CASE WHEN e.Active THEN 'Yes' ELSE 'No' END, e.Title, a.Item_Title, a.Item_Type_ID, a.Item_ID,
           a.Status, CASE WHEN a.done THEN 'Yes' ELSE 'No' END, nullif(a.Passed, ''), a.asgn_dt, a.enrl_dt, a.done_dt,
           a.Credit_Hours, a.Contact_Hours, TRY_CAST(nullif(a.cost, '') AS DOUBLE), nullif(a.Location, ''), a.Student_ID
    FROM act a LEFT JOIN emp e ON e.user_id = a.Student_ID
    ORDER BY e.Active DESC, e.EmpName, a.done_dt DESC NULLS FIRST""").fetchall()

path_rows = con.execute("""
    SELECT e.EmpName, e.Store, CASE WHEN e.Active THEN 'Yes' ELSE 'No' END, e.Title, p.Path_Title, p.Sub_Path_Title,
           CASE WHEN d.Student_ID IS NOT NULL THEN 'Completed' WHEN p.path_complete THEN 'JD marks complete' ELSE 'In progress' END,
           d.Completion_Date, p.items_done, p.last_item, CASE WHEN p.retired THEN 'Yes' ELSE 'No' END,
           p.Student_ID
    FROM paths p LEFT JOIN emp e ON e.user_id = p.Student_ID
    LEFT JOIN done_paths d ON d.Student_ID = p.Student_ID AND d.Path_Title = p.Path_Title
    ORDER BY p.retired, e.Active DESC, e.EmpName, p.Path_Title, p.Sub_Path_Title""").fetchall()

wb = j.new_workbook()
sub = f"From John Deere's data share (JD University), loaded {loaded:%m/%d/%Y}."
j.data_sheet(wb, "By Store", "JD University Training by Store", sub + " Active employees only; last 12 months.", [
    ("Store", 16, None), ("Branch", 8, None), ("Active Employees", 11, "int"),
    ("Employees Trained (12 mo)", 12, "int"), ("Courses Completed (12 mo)", 12, "int"),
    ("Credit Hours (12 mo)", 11, "num"), ("Assigned / Enrolled, Not Done", 13, "int")], by_store)
j.data_sheet(wb, "Employees", "Training by Employee", sub + " One row per JD University user at our stores.", [
    ("Employee", 24, None), ("Store", 14, None), ("Branch", 7, None), ("JD Title", 22, None), ("Active", 7, None),
    ("Start", 11, "date"), ("End", 11, "date"), ("JD User ID", 10, None), ("Email", 26, None),
    ("Courses Completed (12 mo)", 11, "int"), ("Credit Hours (12 mo)", 10, "num"), ("Courses Completed (all)", 11, "int"),
    ("Credit Hours (all)", 10, "num"), ("Last Completion", 11, "date"), ("Assigned / Enrolled, Not Done", 12, "int"),
    ("Learning Paths Completed", 11, "int"), ("Completed Paths (current)", 60, None),
    ("Paths In Progress (current)", 11, "int")], employees, freeze_col=1)
j.data_sheet(wb, "Learning Paths", "Learning Path Progress", sub + " One row per employee x learning path. "
             "Filter Retired = No for current paths.", [
    ("Employee", 24, None), ("Store", 14, None), ("Active", 7, None), ("JD Title", 22, None), ("Learning Path", 55, None),
    ("Sub-Path", 50, None), ("Status", 16, None), ("Completed On", 11, "date"),
    ("Items Completed", 10, "int"), ("Last Item Completed", 11, "date"),
    ("Retired Path", 8, None), ("JD User ID", 10, None)], path_rows, freeze_col=1)
j.data_sheet(wb, "Training History", "Training History", sub + " Every course enrollment, assignment and completion.", [
    ("Employee", 24, None), ("Store", 14, None), ("Active", 7, None), ("JD Title", 22, None), ("Course", 55, None),
    ("Type", 12, None), ("Course ID", 16, None), ("JD Status", 22, None), ("Completed", 9, None), ("Passed", 7, None),
    ("Assigned", 11, "date"), ("Enrolled", 11, "date"), ("Completed On", 11, "date"), ("Credit Hours", 8, "num"),
    ("Contact Hours", 8, "num"), ("Cost", 9, "money"), ("Location", 20, None), ("JD User ID", 10, None)],
    history, freeze_col=1)
j.notes_sheet(wb, "JD University Training - Notes", [
    ("Prepared", f"{date.today():%m/%d/%Y} from John Deere's dealer data share (JD University tables, loaded "
                 f"{loaded:%m/%d/%Y}). A snapshot: JD replaces this data every day."),
    ("Employees", "Everyone JD has a user ID for at our stores (dealer_employee). Active = JD shows them active. "
                  "Store comes from the JD account they're assigned to. Some people have more than one JD user ID "
                  "(e.g. a second ID for another role); each ID is its own row and its training is counted on it."),
    ("Completed", "A course counts as completed when JD's status ends in PASSED, COMPLETED or SUBSTITUTE-CREDIT. "
                  "Failed, cancelled, no-show and incomplete don't count. 'Assigned / Enrolled, Not Done' = status "
                  "Assigned, ENROLL or WAITLIST."),
    ("12 mo", "Completed on or after the same date last year."),
    ("Learning paths", "JD's certification tracks (e.g. Service Technician). 'Completed' = on JD's completed "
                       "learning paths list. 'JD marks complete' = JD's progress data flags it complete but it isn't on "
                       "that list. Items Completed = courses in the path the employee has finished. Paths JD has "
                       "retired are marked; 'current' counts leave them out."),
    ("Assigned / Enrolled, Not Done", "Includes old assignments JD still lists, so a large number can mean stale "
                                      "assignments rather than current work."),
    ("Type", "WBT = web-based training, CLASSROOM, VILT = virtual instructor-led, DLC, IDT, ASSESSMENT, WEBINAR, "
             "ELECTRONIC-MEDIA."),
    ("Questions", "Brian Fox. How the data works: fabric-workspace-docs/docs/JD-DATA-SHARE.md."),
])
j.save(wb, "JD_University_Training", args.out, loaded.date())
print(f"employees={len(employees)} history={len(history)} paths={len(path_rows)} stores={len(by_store)}")
