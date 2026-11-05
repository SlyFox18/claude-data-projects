// Builds "Non-JD Order Tool - Walkthrough.docx": hands-on steps through every page, each with what to do and what
// you should see. Brian works through it to test each release; it doubles as training for Ben, Shannon, Barry and
// Curt. It grows with each version: part 1 is the standing tour, part 2 has a section per version for what's new,
// part 3 holds release checks for Brian only.
// Examples are from Prod data of 2026-10-27 (Fact_NonJD_Reorder built 11:40 UTC); the 0.5.0 section's transfer and
// phase-in examples are from Dev data of 2026-10-28 (Gold built 14:12 UTC), because Prod has no round 2 data until the
// release. Re-check them against Prod after the first 0.5.0 publish. Refresh examples when a section is added.
// Labels follow nonjd-order-app 0.13.0 and the user guide (guide.js). The 0.6.0 section's examples are Prod data of
// 2026-10-28 (Gold built 18:08 UTC): MULTISEAL at 1 "Transfer 44 from 6", R134A "Redistribution 52 from 13".
// The 0.7.0 section's example is Brian's Prod TEST of 2026-10-29 (Plan G task G7): One-Time Order "TEST 0.7.0",
// branch 1, ET-3912-J (MM) 1 from branch 3, $32.00, saved then cancelled.
// The 0.8.0 section's counts are Prod data of 2026-10-30 (Gold built 11:40 UTC): branch 1 has 21 minimums with no
// demand; the order and transfer counts are rounded from the tour's.
// The 0.9.0 section's examples are Brian's Prod TEST of 2026-11-02 (Plan I task I12, v4 publish of that morning): rule
// "Scrap default" (All franchises, no sales 36 months, unit cost at least $0.10) found 49 AM parts; 6397 (BRKT) at 11,
// 2 x $239.62 = $479.24, last sold 2023-03, no demand elsewhere; 9447 (98-3/8" GANG BOLT) at 91, $490.48, demand at
// 8 (2), 13 (2), 96 (2), 94 (1), Transfer instead to 8. There were no return rules on Prod, so the return steps have the
// reader create one with the vendor's terms.
// The 0.10.0 section follows nonjd-order-app 0.10.0 (commit 9cc43f0: src/pages/oneTime/TemplateCard.tsx,
// src/pages/TemplatesPage.tsx). Prod had no templates (Brian's real test of 2026-11-02, "Test Template", was deleted
// with its history), so the steps have the reader make a TEST 0.10.0 template (branch 1, BS, Rolling 12, factor 1.5 → 2)
// and archive it.
// The 0.11.0 section follows nonjd-order-app 0.11.0 (commit e8c6a7e: src/pages/cleanup/*, src/cleanup/fields.ts and
// conditions.ts). Counts are Prod of 2026-11-02 (v5 publish, 199,706 parts, data as of 22:04 UTC): Minimums with no
// demand 3,592, Stock value with no quantity 415. RM-24V at 11 (on hand -126, cost $500, Equip value -$63,000) is from
// the plan's Prod survey of that day. The new check (On hand > 0, Sales 24 months = 0, Cost > 100) is Brian's real
// test "TEST Check", deleted afterwards; the steps have the reader make "TEST 0.11.0" and archive it.
// The 0.12.0 section follows nonjd-order-app 0.12.0 (commit 46812b4: src/pages/inventory/*, src/inventory/builtIns.ts,
// fields.ts and reportResults.ts). Counts are Prod of 2026-11-03 (v6 publish at 20:08 UTC, 250,867 JD parts at 27
// branches, data as of 19:42 UTC): MLPF Gaps 10,090. Brian's real test copy "Test of MLPF Gaps" (Corp demands >= 4)
// was switched off, archived and deleted; the steps have the reader make "TEST 0.12.0" and archive it.
// The 0.13.0 section follows nonjd-order-app 0.13.0 (commit 1319ca9: src/inventory/builtIns.ts, report.ts,
// src/pages/inventory/ReportEditorPage.tsx, src/pages/cleanup/GroupRowEditor.tsx). Counts are Prod of 2026-11-04
// (v7 publish at 16:11 UTC, 250,911 active and 643,034 idle JD part records, data as of 15:43 UTC): Border Stores
// 1,576, 2 & 4 Cotton 251, MLPF Gaps 10,135. Brian's real test copy "Test 0.13.0" (branch one of 7, 14, parts with
// no activity on, 1,027 parts) was deleted; the steps have the reader make "TEST 0.13.0" and archive it.
// The 0.13.1 section follows nonjd-order-app 0.13.1 (commit 0a0d6e6: Export (N) on the Transfer orders tab,
// src/transfers/bulkExport.ts, src/pages/transfers/TransferOrdersList.tsx); the steps use practice transfers.
// The 0.14.0 section follows nonjd-order-app 0.14.0 (commit 15ca00a: Corporate Stocking, src/inventory/partReport.ts,
// src/pages/inventory/PartReportResultsPage.tsx, PartRecordsPanel.tsx, ReportEditorPage.tsx, InventoryReportsPage.tsx).
// Counts are Prod of 2026-11-05: Corporate Stocking 1,815; Brian's real test copy "TEST Corporate Stocking 4+"
// (Branches with demand >= 4, 618 parts) was deleted; the steps have the reader make "TEST 0.14.0" and archive it.
// Run: npm install, then node walkthrough.js [output file]
const { build, CONTENT_W } = require('./lib');

const w = (...fr) => fr.map((f) => Math.round(CONTENT_W * f));
const BOX = '☐';
// A step table: [do this, you should see] pairs, numbered from 1 in each table.
const steps = (rows) => ({
  table: [['#', 'Do this', 'You should see', 'OK'], ...rows.map(([d, s], i) => [String(i + 1), d, s, BOX])],
  widths: w(0.05, 0.42, 0.45, 0.08),
});
const notes = { answer: 'Notes (anything different, slow or confusing):' };

build(process.argv[2] || 'Non-JD Order Tool - Walkthrough.docx', {
  title: 'SPI Parts Hub: walkthrough',
  subtitle: 'Formerly the Non-JD Parts Order Tool · Hands-on steps through every page · Version 0.14.0 · November 5, 2026 · App: https://10.110.100.13:8443',
  footer: 'SPI Parts Hub: walkthrough (0.14.0)',
  blocks: [
    { p: 'This is a hands-on tour of the tool. Each step says what to do and what you should see. Tick **OK** when it matches. When it doesn’t, or something is slow or confusing, write it in the notes box under that section and send it to Brian.' },
    { bullets: [
      '**Part 1, the tour,** covers every page. Work through it once to learn the tool (about an hour). It stays the same from version to version, apart from small updates.',
      '**Part 2, what’s new,** has a short section for each version. When a new version comes out, only its section needs doing.',
      '**Part 3, release checks,** is for Brian when he puts a new version on the test server.',
    ] },
    { note: 'The examples use the data of October 27 to November 5, 2026. The data is refreshed every morning, so your quantities and dollars will be a little different. Close is fine; what matters is that the steps behave as described.' },
    { note: 'Practising is safe if you follow the steps: anything you change is undone in the next step. Practice orders stay as **drafts** named **TEST**. Don’t export or mark them placed. Orders are never deleted: archive the TEST ones when you are done (0.5.2). A practice **transfer** is different: while it is saved it holds the sending branch’s stock for everyone, so **cancel it** straight after the step that made it.' },

    { h1: 'Part 1: the tour' },

    { h2: '1. Getting in, the launch page and Home' },
    steps([
      ['Open **https://10.110.100.13:8443** in Edge or Chrome. If the browser warns "Your connection isn’t private", click **Advanced**, then **Continue to 10.110.100.13**.', 'The sign-in page (the SPI logo, **SPI Parts Hub**, **Sign in with Microsoft**), or the launch page if you are already signed in.'],
      ['Sign in with your work Microsoft account.', 'The **launch page**: a greeting, your branch, and six cards: **Non-JD ordering**, **Cleanup**, **Returns & scrap** (Part 2, 0.9.0), **Part Lookup**, **Inventory management** (Part 2, 0.12.0), and greyed-out **JD ordering** (**Coming later**).'],
      ['Click the **Non-JD ordering** card.', '**Home**, with a greeting, your branch, and how many parts need ordering there and their cost. The left menu lists only Non-JD ordering’s pages, under **‹ All areas** and the **Area** select.'],
      ['Look at the top right.', 'The date and time of the morning data. It is **amber** if the data is more than one business day old.'],
      ['In the greeting line, change the branch to **1**.', 'Branch 1 needs about **220** parts ordered (about $93,000), with a small line like "(21 more with minimums but no demand)". Below it, a purple **transfers** card (Part 2, 0.5.0).'],
      ['Click **Review now**.', 'Recommended Reorder opens on branch 1.'],
    ]),
    notes,

    { h2: '2. Recommended Reorder, one branch' },
    steps([
      ['At the top, set **Branch** to 1 and **Franchise** to **All**.', 'About 220 lines. Each line shows the part, its status (Out of stock or Reorder), on hand, target, order and est. value.'],
      ['Set **Franchise** to **M**.', 'About 80 lines, all franchise M.'],
      ['Set **Franchise** back to **All**. Type `CE51` in the search box.', 'One line: **CE51**, 4’ CoverEdge Net Wrap, about 146 to order, about $47,700.'],
      ['Clear the search. Click the **Est. value** column heading, then click it again.', 'The list sorts by value, then reverses. CE51 is at the top when sorted largest first.'],
      ['Turn **Reorder needed only** off.', 'Every part at the branch is listed (about 14,000), including **Stocked**, **Not stocked** and **No recent activity**.'],
      ['Turn **Reorder needed only** back on. Turn **Show minimums with no demand** on.', 'About 21 more lines appear, each tagged **Min, no demand**.'],
      ['Turn **Show minimums with no demand** off again.', 'Back to about 220 lines.'],
    ]),
    notes,

    { h2: '3. Why this number' },
    { p: 'Every suggestion can explain itself. This uses part 124184 (Mobil 1 0W20 motor oil) at branch 1, the worked example in the user guide.' },
    steps([
      ['Search `124184`. Click the **arrow** at the left of its line.', 'The details open: "why" in plain English, the rule used (**Default**), 22 demands, 170 sold in 12 months, a target of 40, and an order of **39** (40 − 1 on hand − 0 on order).'],
      ['In the same details, look for **Above target at other branches** and **Inbound transfers in Equip**.', 'Other branches with stock above their own target, if any, and any Equip transfers on their way (they don’t reduce the order: Equip already counts them in on order). A part another branch could send shows a purple **Suggested transfers** box instead (Part 2, 0.5.0).'],
      ['Click the **part number** 124184.', 'The Part page opens on its **Detail** tab (next section).'],
    ]),
    notes,

    { h2: '4. Part Lookup and the Part page' },
    steps([
      ['Click **Part Lookup** in the menu. Choose **All branches** and search `PW-193NT`.', 'The Posi-Close Schlagel wheel at every branch that has it (about 12 of them need ordering today).'],
      ['Click the branch 1 result.', 'The Part page, **Detail** tab: stock, prices, the suggested order (about 14) and "Why this number".'],
      ['Scroll to **Other branches**.', 'Every branch with this part, this branch first and marked "(this branch)": On hand, Target, Above target, Excess, Months of supply and Sold 12 mo, with a **Total** row.'],
      ['Click the **History** tab. Switch between units sold and requests.', 'A chart of the last 12 full months, a 60-month table and totals.'],
      ['Click the **Settings** tab. Don’t change anything yet.', 'Min override, Manual order, Masked (with an expiry date), Phase in (quantity and end date), Notes, and the not-yet-used EOQ / pre-approved fields.'],
    ]),
    notes,

    { h2: '5. Part actions: mask, then undo' },
    { p: 'Masking stops the tool suggesting a part (for example, one you know is being discontinued). These steps mask a part and undo it straight away.' },
    steps([
      ['Go to **Recommended Reorder**, branch 1, and search `124184`. Open its details. Under **Part actions**, click **Mask…**, leave **Expires** blank and confirm.', 'The line shows **Masked** with an order of 0. A banner says part settings changed since this morning’s run.'],
      ['Go to **Special statuses** in the menu.', '124184 at branch 1 is listed as **Masked**, with your name and today’s date.'],
      ['Back on Recommended Reorder, open 124184 again and click **Unmask**.', 'The order of 39 comes back. It is gone from Special statuses.'],
      ['Optional: do the same with **Manual order** and **Clear manual**.', 'Manual order also shows an order of 0 and a Special statuses entry until cleared.'],
    ]),
    notes,

    { h2: '6. Making an order (practice)' },
    steps([
      ['On Recommended Reorder, branch 1, tick **CE51** and **124184**.', 'The bar at the bottom says 2 parts ticked and their value at cost.'],
      ['Search for something else, then clear the search.', 'Both parts are still ticked.'],
      ['Click **Create order**.', 'The review: one order per franchise (here 2: HW for CE51 and M for the oil), with every ticked line.'],
      ['Change CE51’s quantity to **1**. Name the order **TEST** and save.', 'The orders are saved and you land on them.'],
      ['Click **Orders** in the menu.', 'Your TEST orders at the top, status **Draft**, one per franchise. Don’t export or mark them placed.'],
      ['Open one. Change a quantity and press Enter.', 'The new quantity is saved. The line value updates.'],
    ]),
    notes,

    { h2: '7. One-Time Order (practice)' },
    { p: 'For a one-off order based on months you choose, for example stocking up before a season.' },
    steps([
      ['Click **One-Time Order**. Name it **TEST**, tick branch **1**, franchise **BW**, and choose **Rolling 12**.', 'The steps across the top read **Set up order → Transfers → Review & calculate**.'],
      ['Click **Continue to transfers**.', 'Every branch loads first (a few seconds the first time). Then either **Transfers into branch 1** (stock other branches can spare; Part 2, 0.7.0), or straight to the review with “No transfers suggested for this order.”'],
      ['If it shows transfers, don’t save any. Click **Continue to review ›**, and if it asks “Save the N ticked transfers first?”, click **Continue without them**.', 'The review, with the parts to order.'],
      ['Switch between **Total** and **Avg / mo**, and change the factor.', 'The list and its total update as you change them.'],
      ['Set a minimum demands of **3**.', 'Parts with fewer than 3 demands drop off.'],
      ['Leave without saving (or save it as a TEST draft).', 'If you leave with ticked parts, the app asks first.'],
    ]),
    notes,

    { h2: '8. Rules and Try it (don’t save)' },
    steps([
      ['Click **Rules**.', 'The rules list: Default and the others, with who last changed each and when. Archived rules are hidden unless **Show archived** is on.'],
      ['Click **Edit** on **Default**. Change its supply from 12 weeks to **16 weeks**. Don’t save.', 'The **Try it** panel shows branch 1 before and after: more order lines and a higher total, and the parts that change most.'],
      ['Click **Close**, then **Discard**.', 'Nothing is saved. Default still says 12 weeks.'],
    ]),
    notes,

    { h2: '9. Cleanup, Inventory and App Settings' },
    steps([
      ['In the left menu, change the **Area** select to **Cleanup**.', '**Cleanup checks**, with **Checks** the only item in the menu: the built-in checks **Minimums with no demand** and **Stock value with no quantity**, and any saved ones, each with a count over every branch (Part 2, 0.11.0).'],
      ['Click **Minimums with no demand**, then pick branch **6**.', 'The Equip minimums on parts with no demand and no sales, with **← Cleanup checks** at the top; branch 6 has about 1,000. The largest is about $21,000 (part 145019, module rim, minimum 65).'],
      ['Change the **Area** select to **Inventory management**.', '**Inventory reports**, with **Reports** the only item in the menu: the built-ins **MLPF Gaps**, **Border Stores**, **2 & 4 Cotton** and **Corporate Stocking** and any saved copies, each with a count over every JD branch (Part 2, 0.12.0 to 0.14.0).'],
      ['Click **App Settings**.', 'Your default branch and franchise, and **About** with the version (**0.14.0**).'],
      ['Set your default branch, then open Recommended Reorder.', 'It opens on your default branch.'],
    ]),
    notes,

    { h1: 'Part 2: what’s new' },

    { h2: 'Version 0.14.0 (November 5, 2026): Corporate Stocking, one row per part' },
    { p: 'New since 0.13.1: the SPI Corparate Stocking workbook as a built-in report, **Corporate Stocking**. It is the first report with **one row per part** instead of one per branch. Copies can change which records count, what they must be, where demand counts and the thresholds, and **New report** starts a report from scratch. The user guide, section 12, explains it in full.' },
    { note: 'Saving a copy is real: everyone sees it straight away. Name it **TEST 0.14.0**, and **archive it** at the end of these steps (Brian tidies up afterwards). The counts are from November 5 and change every morning; close is fine.' },
    { h3: 'Corporate Stocking, a copy, and a new report' },
    steps([
      ['Open **Inventory management**. Wait for the loading line to finish.', 'The built-ins end with **Corporate Stocking** (🔒 Built in), showing a **Count (loads more data)** button.'],
      ['Click **Count** on Corporate Stocking.', 'After a few seconds (it loads the parts with no activity, about 11 MB the first time), about **1,815** parts.'],
      ['Open **Corporate Stocking**.', 'No Branch column: Part number, Description, Cost, Source, SLC, Commodity code, Dealer group, On order, On hand, **R18 demands**, **Branches with demand**, **Locations with demand** (for example “1, 6, 7, 8, 11 …”). Every row has On order and On hand **0** and Branches with demand **3** or more, most first. Instead of Branch there is **Demand at branch**.'],
      ['Set **Demand at branch** to **93**, then back to **All branches**.', 'Only the parts with a demand at 93 (93 is in their Locations with demand), then all of them again.'],
      ['Click a part number.', 'A panel listing every branch’s record: On hand, On order, Super To, Corp demands, **Counted** (Yes, or “No: not in Records that count” for branches 2 and 4 and records failing the part rules) and a ✓ under **Demand counted** for each branch in Locations with demand. **Close** closes it.'],
      ['**Export CSV** and open it in Excel.', 'A file named like `Inventory-Corporate Stocking-20261105.csv` with the workbook’s headings, ending **R18 Demands**, **Count of Locations with Demands**, **Locations with Demands**. It lines up beside SPI Corparate Stocking.xlsx.'],
      ['Click **Copy as my own**. Name it **TEST 0.14.0**.', '**Copy report** with four cards: **Records that count** (Branch not one of 2, 4 and the four part rules), **Every counted record must** (On hand = 0, On order = 0, Super To is blank), **Demand counts where** (Branch not one of 2, 4) and **Parts to show** (Branches with demand ≥ 3).'],
      ['In **Parts to show**, change **3** to **4**.', '**Try it** updates after a moment with fewer parts (about 618 on November 5).'],
      ['Click **Save report**.', '“Report saved.”: **TEST 0.14.0**. Its **Export CSV** has the same workbook headings.'],
      ['Click **← Inventory reports**. On the TEST 0.14.0 row click **Switch off**, then **Switch off** again. Then **Archive**, then **Archive**.', 'The row greys with an **Off** tag, then leaves the list: “1 archived report is hidden.”'],
      ['Click **New report** (top right).', '**New report** with a **Report type** choice: **One row per branch** or **One row per part**. Choose **One row per part**: the first three cards are empty (“Every record counts.” and so on) and Parts to show starts with Branches with demand ≥ 1.'],
      ['Click **← Inventory reports** without saving.', 'It asks first; leave without saving.'],
    ]),
    { p: '**Your opinion:** does the panel explain a part clearly? Is **Demand at branch** what you’d want instead of a branch filter? Are the four cards easy to tell apart, and would you know which one to change to stop counting a branch?' },
    notes,

    { h2: 'Version 0.13.1 (November 4, 2026): export several transfer orders at once' },
    { p: 'New since 0.13.0: on the **Transfer orders** tab, tick several transfer orders and click **Export (N)** for one file with all their lines, instead of opening and exporting each one. Every transfer in the file is marked Exported, as if exported on its own. The user guide (Transfers, Transfer orders) explains it.' },
    { note: 'Exporting is real: practise on two transfers you make for the purpose, then cancel and archive them at the end of these steps. Don’t tick real transfers unless you mean to send them.' },
    { h3: 'Two practice transfers, one file' },
    steps([
      ['Click **Transfers**, then the **Suggestions** tab. Set **From** to a branch with a few suggestions and click **Save**. Do the same for a second **From** branch.', '“Saved 1 transfer order.” each time.'],
      ['Click the **Transfer orders** tab. Tick your two new transfers (the newest two, saved by you).', '**Export (2)** appears above the list.'],
      ['Tick an **Entered in Equip** or **Cancelled** transfer as well.', '**Export (3)** is greyed out: “Only Draft or Exported transfer orders that aren’t archived can be exported.” Untick it again.'],
      ['Click **Export (2)** and open the file in Notepad.', 'One file, `Transfer-orders-<today>.csv`, starting **Transfer, From, To**, then the usual line columns; your newer transfer’s lines first. The message reads “Exported 2 transfer orders (N lines).” and both rows show **Exported** with an export count of 1.'],
      ['Open each practice transfer, click **Cancel**, then **Cancel transfer**, then **Archive**.', 'Both show **Cancelled**, then leave the list (their stock is released for other suggestions).'],
    ]),
    { p: '**Your opinion:** is the combined file what you’d work from? Would a filter by **To** branch plus the heading tick box cover how you send transfers?' },
    notes,

    { h2: 'Version 0.13.0 (November 4, 2026): Border Stores and 2 & 4 Cotton' },
    { p: 'New since 0.12.0: two more Corp Parts workbooks as built-in reports, both comparing a part at one branch with the same part at the other branches. The user guide, section 11, explains them in full; this section opens both, makes a copy of Border Stores for other branches and tidies it away.' },
    { bullets: [
      '**Border Stores:** parts with a Corp demand at 95, 91 or 96 and nothing on hand there that 5 or more other branches (not 2 or 4) are selling, 10 or more Corp demands between them.',
      '**2 & 4 Cotton:** cotton, stripper and picker parts at 2 and 4 with no Corp demands there, by the same test, including parts 2 and 4 carry but have never stocked or sold (**parts with no activity**).',
      '**Two new columns**, **Other-branch demands** and **Other branches with demand**, the workbooks’ OtherBranchDemands and OtherLocationCount.',
      '**Copies** can say which other branches count (**Count other branches where**), use **‘any of’ groups**, and include parts with no activity. Cleanup checks get ‘any of’ groups too.',
    ] },
    { note: 'Saving a copy is real: everyone sees it straight away. Name it **TEST 0.13.0**, and **archive it** at the end of these steps (Brian tidies up afterwards). The counts are from November 4 and change every morning; close is fine.' },
    { h3: 'The two reports, then a copy for other branches' },
    steps([
      ['Open **Inventory management**. Wait for the loading line to finish.', 'Three built-ins marked **🔒 Built in**: **MLPF Gaps** (about **10,135** parts), **Border Stores** (about **1,576**) and **2 & 4 Cotton**, which shows a **Count (loads more data)** button instead of a number.'],
      ['Click **Count** on 2 & 4 Cotton.', 'After a few seconds (it loads the parts with no activity, about 11 MB the first time), about **251** parts.'],
      ['Open **Border Stores**.', 'Its conditions start “Branch is one of 95, 91, 96 and Corp demands ≥ 1 and Other-branch demands ≥ 10 and Other branches with demand ≥ 5 and On hand < 1 …”. The columns end **Corp demands**, **Other-branch demands**, **Other branches with demand**; every row is at 95, 91 or 96, with Other-branch demands 10 or more and Other branches with demand 5 or more.'],
      ['Click a part number.', 'The details panel shows **Other-branch demands** and **Other branches with demand** with the other fields.'],
      ['**Export CSV** and open it in Excel.', 'A file named like `Inventory-Border Stores-20261104.csv`; the last three headings are **Demands**, **OtherBranchDemands**, **OtherLocationCount**, as in Border Stores.xlsx.'],
      ['Go back and open **2 & 4 Cotton**.', '“Loading the parts with no activity this report needs…” if they aren’t loaded yet, then its parts: every row at 2 or 4, with Corp demands **0**. Many have nothing at all on hand, on order or sold there.'],
      ['Open **Border Stores** again and click **Copy as my own**. Name it **TEST 0.13.0**.', '**Copy report** with two condition cards: **Rows to show** (“All conditions must match.”) and **Count other branches where** (“Optional. Which of the part’s rows at other branches count …”), which starts “Branch not one of 2, 4” and the six part rules. Under them **Include parts with no activity**, off.'],
      ['In **Rows to show**, change the Branch condition to **one of 7, 14**. Turn on **Include parts with no activity**.', '**Try it** updates after a moment with parts at 7 and 14 (about 1,000 on November 4).'],
      ['Click **Add ‘any of’ group** in Rows to show.', 'A box **Any of these** (“At least one line must match.”) with two lines. Click **Remove** on one line: the box offers **Make it a plain condition**. Click **Remove group** to put the report back.'],
      ['Click **Save report**.', '“Report saved.”: **TEST 0.13.0**, its rows only at 7 and 14, with the two other-branch columns.'],
      ['Click **← Inventory reports**. On the TEST 0.13.0 row click **Switch off**, then **Switch off** again. Then **Archive**, then **Archive**.', 'The row greys with an **Off** tag, then leaves the list: “1 archived report is hidden.”'],
    ]),
    { p: '**Your opinion:** are **Rows to show** and **Count other branches where** easy to tell apart? Would you know which one to change to compare different branches? Does the Count button make sense?' },
    notes,

    { h2: 'Version 0.12.0 (November 3, 2026): Inventory reports' },
    { p: 'New since 0.11.0, from Ben’s wish to bring the Corp Parts workbooks into the tool: the **Inventory management** area, starting with **MLPF Gaps**. The user guide, section 10, explains it in full; this section opens MLPF Gaps, makes a copy of your own and tidies it away.' },
    { bullets: [
      '**Inventory reports:** the Inventory management area (its menu item is **Reports**) lists reports over every active JD part at every branch, each with how many parts it finds.',
      '**MLPF Gaps, built in:** the workbook’s rules and columns, so it lists the same parts as MLPF Gaps.xlsx on the same morning.',
      '**Open a report** to filter it by branch, search it, sort it, see a part’s details and **Export CSV** with the workbook’s headings.',
      '**Copy as my own** makes a version you can change, such as 2 or more demands. The built-in never changes. Copies are shared: anyone can edit, switch off or archive one.',
    ] },
    { note: 'Saving a copy is real: everyone sees it straight away. Name it **TEST 0.12.0**, and **archive it** at the end of these steps (Brian tidies up afterwards). The counts are from November 3 and change every morning; close is fine.' },
    { h3: 'MLPF Gaps, then a copy of your own' },
    steps([
      ['On the launch page, click the **Inventory management** card. Wait for the loading line to finish.', '**Inventory reports**: “The Corp Parts reports over the JD parts, every branch. Open one to filter it and export a CSV.”, “Loading JD parts: N of 27 branches…” for a few seconds, then **Data as of …**. **Reports** is the only item in the menu. The first row is **MLPF Gaps** marked **🔒 Built in**, about **10,090 parts**, with its conditions under it: “Branch is not 12 and Corp demands = 2 and On hand < 1 … and Super To is blank”.'],
      ['Click **MLPF Gaps**.', '**← Inventory reports** at the top, the name, the description, the conditions and **Data as of …**. **Branch** on **All branches**, a **Search** box, and about “10,090 parts · Total cost (1 each) $…”. Columns: Branch, Part number, Description, Cost, Source, SLC, Commodity code, Commodity group, Dealer group, On order, On hand, Corp demands. Every row has Corp demands **2**, On hand below 1 and On order **0**; no row is at branch 12.'],
      ['Set **Branch** to **1**. Type part of a part number in **Search**. Click the **Cost** heading, and again.', 'Only branch 1’s parts, then only those matching the search. The first click puts the dearest first; the second reverses it. The count and Total cost follow the filters.'],
      ['Click a part number.', 'A panel on the right with the part and its branch, and every field: Corp demands, On hand, On order, Cost, Package qty (1), Return indicator (R), Source, SLC, Super To (—), Commodity code and group, Dealer group, Equip minimum and maximum, Sales 12 and 24 months. **Close** (or Escape) closes it.'],
      ['Clear the search, set Branch back to **All branches**, then **Export CSV** and open the file in Excel.', 'A file named like `Inventory-MLPF Gaps-20261103.csv`, with the workbook’s headings: Branch, PartNumber, Description, Cost, Source, SLC, CommodityCode, CommodityGroup, DealerGroupCode, OnOrder, OnHandQty, Demands. It lines up beside MLPF Gaps.xlsx.'],
      ['Click **Copy as my own**.', '**Copy report**, with three cards: **Report** (“Nothing is saved until Save report.”, name “Copy of MLPF Gaps”, description “Based on MLPF Gaps.”), **Conditions** (“All conditions must match.”, the nine MLPF conditions) and **Try it**, with a count close to MLPF Gaps’.'],
      ['Name it **TEST 0.12.0**. On the **Corp demands** row, change **=** to **≥** (leave 2).', 'Under the rows: “… and Corp demands ≥ 2 and …”. Try it updates after a moment (“Recomputing…”) with more parts than MLPF Gaps and “The first 20 of N parts. Save the report to see them all.”'],
      ['Click **Save report**.', 'The copy’s page opens with “Report saved.”: **TEST 0.12.0** with **Copy as my own** and **Edit**. After the workbook’s columns it adds **Package qty**, **Return indicator** and **Super To**, the other fields its conditions use.'],
      ['Click **Edit**, change the value to **3** and click **Save report**.', '“Report updated.” and fewer parts than before.'],
      ['Click **← Inventory reports**. On the TEST 0.12.0 row click **Switch off**, then **Switch off** again. Then **Archive**, then **Archive**. Turn on **Show archived (1)**.', 'The row says **By** <your name> and its count. “Switch off TEST 0.12.0? It stays in the list, marked Off; Switch on brings it back.”: the row greys and gets an **Off** tag. “Archive TEST 0.12.0? It leaves the list; Show archived and Unarchive bring it back.”: the row goes and “1 archived report is hidden.” shows. With Show archived on: the row greyed with **Off** and **Archived** tags and **Unarchive**.'],
    ]),
    { p: '**Your opinion:** does MLPF Gaps read like the workbook? Is **Total cost (1 each)** a useful total? Is a JD field you’d expect missing from the field list?' },
    notes,

    { h2: 'Version 0.11.0 (November 2, 2026): Cleanup checks' },
    { p: 'New since 0.10.0, from Ben’s “value without quantity” idea and his wish for more things to fix in Equip: **Cleanup is now a list of checks**. The user guide, section 7, explains them in full; this section opens the built-in ones, builds a check of your own and tidies it away.' },
    { bullets: [
      '**Cleanup checks:** the Cleanup area (its menu item is **Checks**) lists checks, each a list of parts to fix in Equip, with how many parts it finds over every branch.',
      '**Two built in:** **Minimums with no demand** (the old Cleanup page, unchanged) and the new **Stock value with no quantity**: Equip shows a stock value of $1 or more, either way, but nothing or less than nothing on hand.',
      '**Open a check** to filter it by branch and franchise, sort it by any column and **Export CSV**.',
      '**Build your own** from conditions such as “On hand > 0” and “Sales 24 months = 0”, with **Try it** showing what it finds as you type. Saved checks are shared: anyone can edit, switch off or archive one.',
    ] },
    { note: 'Saving a check is real: everyone sees it straight away. Name it **TEST 0.11.0**, and **archive it** at the end of these steps (archiving hides it; Brian tidies up afterwards). The counts are from November 2 and change every morning; close is fine.' },
    { h3: 'The built-in checks, then a check of your own' },
    steps([
      ['On the launch page, click the **Cleanup** card. Wait for the progress bar to finish.', '**Cleanup checks**: “Lists of parts to fix in Equip, over every branch. Open one to filter it and export a CSV.”, a **New check** button, and **Checks** the only item in the menu. Two rows marked **Built in**: **Minimums with no demand**, about **3,592 parts**, and **Stock value with no quantity**, about **415 parts**, with its conditions under it: “Equip stock value (either way) ≥ $1.00 and On hand ≤ 0”. While branches load, each count says “in N of 19 branches”.'],
      ['Click **Stock value with no quantity**.', '**← Cleanup checks** at the top, the name, “Equip shows a stock value of $1 or more (either way) but nothing, or less than nothing, on hand.”, **Branch** and **Franchise** on **All**, about “415 parts” and a dollar total marked **Equip stock value**. Columns: Branch, Franchise, Part, Description, Bin, **On hand**, **Cost**, **Equip stock value**. Every On hand is 0 or less; every Equip stock value is $1.00 or more, or -$1.00 or less.'],
      ['Set **Branch** to **11**. Click the **Equip stock value** heading (and again to reverse). Click **Export CSV** and open the file in Excel.', 'Only branch 11’s parts. The first click sorts the largest value first; the second puts the most negative first. On November 2 one of them was **RM-24V**: -126 on hand at $500.00, **-$63,000.00**. The file is called like `Cleanup-Stock value with no quantity-20261102.csv`: Branch, Franchise, PartNumber, Description, Bin, OnHand, Cost, EquipStockValue, branch 11 only.'],
      ['Click **← Cleanup checks**, then **Minimums with no demand**.', 'The same page as before 0.11.0 (Equip min, On hand, Min × cost, Would order $ …), now with **← Cleanup checks** at the top. Go back to the list.'],
      ['Click **New check**. Name it **TEST 0.11.0**. Condition 1 says **On hand** **=** **0**: change the comparison to **>** (leave 0).', 'Three cards: **Check** (“Nothing is saved until Save check.”), **Conditions** (“All conditions must match.”) and **Try it**: “What this check finds today over every branch, from this morning’s data. Nothing is saved.”, with a count of parts and the first 20.'],
      ['Click **Add condition** and change its field to **Sales 24 months** (it says = 0). **Add condition** again: field **Cost**, comparison **>**, value **100**.', 'The new row starts on a field not used yet (On order, then Pending). Under the rows: “On hand > 0 and Sales 24 months = 0 and Cost > $100.00”. Try it updates after a moment (“Recomputing…”): parts with stock, no sales in two years and a cost over $100, and “The first 20 of N parts. Save the check to see them all.”'],
      ['Type `abc` in the Cost value, then put **100** back.', 'A red “Enter a number.” under the row, **Save check** greyed out and Try it saying “Fix the conditions’ problems to try it.”; with 100 back, the count returns.'],
      ['Click **Save check**.', 'The check’s results open with “Check saved.”: **TEST 0.11.0** with an **Edit** button, its conditions, and columns **On hand**, **Cost** and **Sales 24 months** after Bin. The total is marked **On-hand value (on hand × cost)**.'],
      ['Click **Edit**, change the Cost value to **200** and click **Save check**.', '“Check updated.” and fewer parts than before.'],
      ['Click **← Cleanup checks**. On the TEST 0.11.0 row click **Switch off**, then **Switch off** again. Then **Archive**, then **Archive**. Turn on **Show archived (1)**.', 'The row says **By** <your name> and its count. “Switch off TEST 0.11.0? It stays in the list, marked Off; Switch on brings it back.”: the row greys, gets an **Off** tag and moves under the checks that are on. “Archive TEST 0.11.0? It leaves the list; Show archived and Unarchive bring it back.”: the row goes and “1 archived check is hidden.” shows. With Show archived on: the row greyed with **Off** and **Archived** tags, **Unarchive** and no Open or Edit.'],
    ]),
    { p: '**Your opinion:** are the fields and comparisons easy to read? Is there a field you expected that isn’t in the list? Which checks would you build first?' },
    notes,

    { h2: 'Version 0.10.0 (November 2, 2026): One-Time templates' },
    { p: 'New since 0.9.1, from Ben’s idea of saving One-Time settings that get used all the time: **templates**. The user guide, section 9, explains them in full; this section makes one, uses it, changes it and archives it.' },
    { bullets: [
      '**A template** saves a One-Time Order’s Set up under a name: branches, franchises, dealer groups, the months, the Calculation and the line value limits. Not the order name, and not transfers.',
      '**Shared:** everyone sees the same templates, anyone can save, change or archive one, and every change is recorded with who and when. Nothing is deleted.',
      '**The Template card** at the top of One-Time Order’s Set up: **Use** one to fill in the Set up, **Save as template**, and once you’re using one, **Update template**, **Save as new template**, **History**, **Archive** and **Stop using**.',
      '**Periods stay current:** a Rolling 12 template always means the latest 12 months; a full year stays that year; picked months stay those months.',
      '**A Templates page** in the Non-JD ordering menu, right under One-Time Order: every template with **Start order**, **History** and **Archive** / **Unarchive**.',
      '**Orders say where they came from:** an order made from a template ends its calculation line with “· From template <name>”.',
    ] },
    { note: 'Saving a template is real: everyone sees it straight away. Name it **TEST 0.10.0**, and **archive it** at the end of these steps (archiving hides it; Brian tidies up afterwards). Don’t create the One-Time order itself. There were no templates on the test server on November 2, so these steps start by making one.' },
    { h3: 'Make a template, use it, change it, archive it' },
    steps([
      ['Click **One-Time Order**. Look at the **Template** card at the top of Set up.', '“Start from a saved set-up, or save this one for next time.”, an empty **Start from a template** list with “No templates yet. Set up an order and save it as a template.”, and **Save as template**, greyed out until a branch has loaded and a month is picked.'],
      ['Name the order **TEST 0.10.0**, tick branch **1** and franchise **BS**, choose **Rolling 12**, and under **Calculation** leave **Total** with a **Loading factor** of **1.5**.', '**Save as template** lights up.'],
      ['Click **Save as template**. The **Template name** already says TEST 0.10.0; type a **Description** such as “Walkthrough practice”. Click **Save**.', 'The card now says **From template TEST 0.10.0** with the description, and the buttons **Update template** (greyed: nothing to save), **Save as new template**, **History**, **Archive** and **Stop using**. **History** shows one line: the date and time · your name · **Created**.'],
      ['Reload the page (F5) to start a fresh order. Pick **TEST 0.10.0** under **Start from a template** and click **Use**.', 'For a moment “Starting from TEST 0.10.0. Waiting for the branches to load.”, then branch 1, BS, the last 12 months, Total and 1.5 are filled in, and the blank **Order name** becomes **TEST 0.10.0**. The card says **From template TEST 0.10.0**.'],
      ['Change the **Loading factor** to **2**. Then back to **1.5**, then to **2** again.', 'With 2: “Not saved to the template yet: loading factor 1.5 → 2” under the buttons, and **Update template** lights up. With 1.5 the line goes and the button greys out again.'],
      ['Click **Update template**, then **History**.', '“Template updated.” The history now has two lines, newest first: “… · <your name> · loading factor 1.5 → 2”, then **Created**.'],
      ['Click **Continue to transfers**, then **Continue to review ›** (answer **Continue without them** if it asks).', 'The line about the calculation at the top of Review ends with “· From template TEST 0.10.0”. Don’t create the order.'],
      ['Click **Templates** in the menu, right under One-Time Order.', '**One-Time templates**: a row **TEST 0.10.0** with “Walkthrough practice” under it, Set up “Branch 1 · BS · Rolling 12 · total units sold × 2”, Changed “<your name> · <date and time>”, and **Start order**, **History** and **Archive**. Click **History**: the same two lines as on the card.'],
      ['Click **Start order** on that row.', 'One-Time Order, with TEST 0.10.0 filled in as in step 4 (factor **2** now). Click **Templates** again to go back.'],
      ['Click **Archive** on the row, then **Archive** again. Turn on **Show archived (1)** and open **History**.', '“Archive TEST 0.10.0? It leaves One-Time Order’s template list; Unarchive brings it back.” The row goes, “1 archived template is hidden.” shows, and **Show archived (1)** appears. With it on: the row greyed, an **Archived** tag, **Unarchive** and no **Start order**; History starts with **Archived**. On One-Time Order, TEST 0.10.0 is no longer in the list.'],
    ]),
    { p: '**Your opinion:** is “Update template” versus “Save as new template” clear? Which of your One-Time orders would you save as templates?' },
    notes,

    { h2: 'Version 0.9.0 (November 2, 2026): Returns & scrap' },
    { p: 'New since 0.8.1: a **Returns & scrap** area, for sending slow parts back to the vendor for credit and scrapping parts that will never sell. The user guide, section 8, explains each job; this section tries them once.' },
    { bullets: [
      '**Return & scrap rules:** each franchise’s return terms (allowance, credit %, how long without sales) are kept as a rule, set up once with the vendor’s terms. Scrap rules say how old a part must be to scrap; one for **All franchises** covers every franchise without its own.',
      '**New return / New scrap list:** three steps, **Set up · Parts · Review & save**. The tool lists the parts that qualify at every branch at once. A return is pre-ticked up to the allowance, worst sellers first, with a meter.',
      '**Transfer instead:** a part another branch has asked for in the last 18 months can go there instead of back to the vendor or into the scrap. It starts on for scrap and off for returns.',
      '**Saved returns and scrap lists** with their own statuses: Draft → Exported → Sent to vendor → Credit received (scrap: → Scrapped), an RA number, Export CSV and Export by branch.',
      '**On return / On scrap tags** where a part on an open list shows (Recommended Reorder, transfer suggestions, the Part page). The stock is held in the app only; Equip isn’t changed.',
      '**0.9.1 (the same day):** on Return & scrap rules, **Franchise is a list** (with **All franchises** for a scrap rule) instead of a box to type in; and the footers that stay at the bottom of the window (on Reorder step 1, the transfer and One-Time steps and the new return and scrap steps) now sit right at the bottom, with no gap under them.',
    ] },
    { note: 'Saving a scrap list is real: while it is a Draft it holds the parts for everyone. Save **one practice line**, then **cancel and archive it** in the same sitting, as below. The examples are from Brian’s test of November 2: “Scrap default” found **49** AM parts that day. The counts change every day; if a part isn’t there on your day, use any line.' },
    { h3: 'A scrap list (practice, then cancel it)' },
    steps([
      ['On the launch page, click the **Returns & scrap** card (“Vendor returns and scrap, by franchise rule.”). Click **Return & scrap rules**, then the **Scrap rules** tab.', 'The left menu has **Returns**, **Scrap** and **Return & scrap rules**. The tab lists **Scrap default**: **All franchises**, “no sales 36 mo · unit cost ≥ $0.10”, **All year**, **Active**. (The **Return rules** tab said “No rules yet.” on November 2.)'],
      ['Click **Scrap**, then **New scrap list**. Pick franchise **AM**.', 'Steps across the top: **Set up · Parts · Review & save**. Under the franchise: “**Scrap default** (All franchises) · no sales 36 mo · unit cost ≥ $0.10 · Rules”. Every branch ticked, **Demand window (months)** 18, and a progress bar while every branch loads.'],
      ['When loading finishes, click **Choose parts**.', 'About **49 qualifying parts**, all ticked, no allowance meter (that is for returns). Lines another branch has asked for already have **Transfer instead** ticked. The footer at the bottom of the window gives the lines, value and how many go by transfer.'],
      ['Search `6397`.', 'Branch **11**, AM · BRKT, qty **2**, cost $239.62, value **$479.24**, last sold **2023-03**, Demand elsewhere **—** and no Transfer instead: no other branch wants it, so it is one to scrap.'],
      ['Search `9447`.', 'Branch **91**, 98-3/8" GANG BOLT, **$490.48**, Demand elsewhere “**8 (2), 13 (2), 96 (2), 94 (1)**”, Transfer instead ticked with **8 (2)** in the box (8, 13 and 96 tie; branch order picks 8). Open the box: only branches that asked for it and can receive it.'],
      ['Clear the search. Untick the box in the heading (every line unticks), then tick **6397** only. Click **Review**.', 'The footer read “1 line · $479.24”. Review: **AM scrap list**, “Rule: Scrap default. Saved as a Draft.”, Lines **1**, Value at cost **$479.24**, and **No transfers**.'],
      ['Click **Save scrap list**.', 'The scrap list opens: “Scrap list · AM”, **AM-SCR-** with today’s date and time, an amber **Draft** pill, Saved … by you, Rule Scrap default, Branches 11, and the one line. Buttons: **Export CSV**, **Cancel scrap list**, and **Archive** greyed out.'],
      ['Change the **Area** to **Non-JD ordering**, open **Recommended Reorder**, branch **11**, franchise **AM**, turn **Reorder needed only** off and search `6397`.', 'A grey tag **On scrap AM-SCR-… (2)** on the line. Click it: back to the scrap list.'],
      ['Click **Cancel scrap list**, then **Cancel scrap list** again. Then **Archive**, then **Archive**.', '“Cancel this scrap list? Its parts are no longer held and can go on another scrap list.” The pill turns grey **Cancelled**, then an **Archived** tag. On Scrap it is hidden unless **Show archived** is on.'],
    ]),
    notes,
    { h3: 'A return rule and a return (don’t save the return)' },
    { note: 'There are no return rules yet. Pick a franchise you return to its vendor, and use **that vendor’s terms**. Save the rule only if the terms are right; otherwise close it without saving.' },
    steps([
      ['**Return & scrap rules**, tab **Return rules**, **New return rule**. Name it (for example “MM annual return”), pick the **Franchise**, and fill in **No sales for**, **Allowance %**, **Based on** and **Credit %** from the vendor’s terms.', 'The **Try it** card loads every branch, then shows **Qualifying parts**, **Their value**, the **Allowance** and the **Expected credit**, a line “Pre-pick ticks N parts, $X of $Y.”, and the biggest parts. It changes as you type. **Save rule** if the terms are right; otherwise **Close**, then **Discard**.'],
      ['If you saved the rule: **Returns → New return**, pick that franchise, **Choose parts**.', 'A meter “$X of $Y allowance” above the list, with the pre-picked lines ticked: the longest unsold first, up to the allowance. The Credit column fills in.'],
      ['Tick a few more lines until the meter goes over. Then click **Returns** in the menu.', 'The meter turns red with “(over)”; Review is still allowed. Leaving asks “Leave this page? Your new return isn’t saved.”: click **Leave**. Nothing was saved.'],
    ]),
    { p: '**Your opinion:** do the rule fields match how your vendors word their terms? Should Transfer instead start on for returns too?' },
    notes,


    { h2: 'Version 0.8.0 (October 30, 2026): SPI Parts Hub and the launch page' },
    { p: 'New since 0.7.0, from Ben’s idea of a landing page above the tools:' },
    { bullets: [
      '**A new name and the SPI logo:** the tool is now **SPI Parts Hub**. The ordering itself works as before.',
      '**A launch page in front.** The app opens on a page where you pick where to go: **Non-JD ordering**, **Cleanup** or **Part Lookup**. **JD ordering** and **Inventory management** show greyed out as **Coming later**, so you can see where the tool is heading.',
      '**The cards say what is waiting** at the branch picked at the top: parts to order and their cost, how many could come by transfer, and how many Equip minimums have no demand.',
      '**One area at a time in the menu.** Inside an area the left menu lists only its pages, under **‹ All areas** (back to the launch page) and an **Area** select to jump to another area. It no longer grows with every new tool.',
      '**Links out:** **Parts Availability** and the **Parts reports** app, at the bottom of the launch page.',
      '**Home moved:** Non-JD ordering’s Home is at **/non-jd**. Every other address and bookmark still works.',
    ] },
    { h3: 'The launch page and the menu' },
    steps([
      ['Open the app (Ctrl+F5 the first time after the update).', 'The browser tab reads **SPI Parts Hub**. The launch page: the colour SPI logo, a greeting, “Where do you want to go?”, a **Branch** select and the data date. Five cards; **JD ordering** and **Inventory management** are greyed with **Coming later**.'],
      ['Set the branch to **1** and read the cards.', 'Non-JD ordering: about **220 parts to order** with their cost and, in purple, about **67 could come by transfer**. Cleanup: about **21 minimums with no demand at Branch 1**. Part Lookup has no count. The Coming later cards do nothing when clicked.'],
      ['Click the **Non-JD ordering** card.', 'Home, with the same numbers as the card. The left menu has **‹ All areas**, the **Area** select on Non-JD ordering, and only its pages: Home, Recommended Reorder, One-Time Order, Transfers, Orders, Rules, Transfer rules, Special statuses (and, since 0.10.0, Templates under One-Time Order).'],
      ['Open **Recommended Reorder** (continue to step 2 if it opens on transfers) and tick one part. Change the **Area** select to **Cleanup**.', '“Leave this page? 1 ticked part will be lost.” Click **Stay**: the tick is kept. Change the area again and click **Leave**: Cleanup, with only Cleanup in the menu.'],
      ['Click **‹ All areas**, then the **Part Lookup** card. Search a part and open it.', 'Part Lookup, with only Part Lookup in the menu; it stays there on the part page.'],
      ['Click **‹ All areas**. At the bottom, click **Parts Availability ↗**, then **Parts reports ↗**.', 'Each opens in a new tab: Parts Availability, and the Parts Reports app in Power BI. The launch page stays open.'],
      ['Open a bookmark or address you used before, for example **/reorder** or **/orders**.', 'It opens that page as before, with the menu on its area.'],
    ]),
    { p: '**Your opinion:** do the launch page cards read clearly at a glance, and should the Coming later cards stay visible?' },
    notes,

    { h2: 'Version 0.7.0 (October 29, 2026): transfers on One-Time Orders' },
    { p: 'New since 0.6.2, from Ben’s question “do the transfers apply to the One-Time Orders as well?”:' },
    { bullets: [
      '**One-Time Order has three steps:** **Set up order → Transfers → Review & calculate**. **Continue to transfers** loads every branch (a few seconds the first time), then lists stock other branches can spare for the order’s lines.',
      '**Instead of buying only.** These are **Conventional** transfers from other branches’ excess, and each sending branch’s own transfer rule decides what it can spare. There is no redistribution here. A branch that is buying the part in this order never sends it.',
      '**The same tick and save as Recommended Reorder step 1:** lines start ticked, a quantity is never above the suggestion, there is a search box, and the footer keeps its own **Save**. The **Order** column shows the line’s one-time quantity before → after, for example **1 → 0**.',
      '**Continue to review ›** with unsaved ticks asks “Save the N ticked transfers first?”. Review counts **saved** transfers only: a **Transfer in** column and “Includes 1 coming by transfer from branch 3”. A line saved transfers cover fully stays on the list with **0** and **Covered by transfers**. It can’t be ticked and is never ordered.',
      '**Nothing to transfer:** the Transfers step is skipped, and Review says “No transfers suggested for this order.”',
      '**Where a transfer came from:** a transfer order saved here says **From One-Time Order "<name>"** on its page.',
    ] },
    { note: 'Saving a transfer is real: until it is cancelled it holds the sending branch’s stock. Save **one practice transfer of quantity 1**, then **cancel and archive it** in the same sitting, as below. Don’t create the One-Time order itself. The example is from Brian’s test on October 29; if ET-3912-J isn’t offered on your day, use any one line.' },
    { h3: 'One-Time Order: the Transfers step' },
    steps([
      ['Click **One-Time Order**. Name it **TEST 0.7.0**, tick branch **1** and franchise **MM**, and choose **Rolling 12**.', 'Across the top: **Set up order → Transfers → Review & calculate**.'],
      ['Click **Continue to transfers**.', 'A progress bar while every branch loads, with “Every branch loads first, to find the stock other branches can spare.” and **Cancel** / **Load the rest**.'],
      ['Wait for it to finish.', '**Transfers into branch 1**: “Stock other branches can spare for this order. Tick the transfers to make instead of buying; Review counts the saved ones.” Every line is ticked, with a **Conventional** badge. On October 29 one was **ET-3912-J** (110 LUMEN FLASHLIGHT - RECHARGEABLE), **1 from branch 3**, $32.00, with the **Order** column at **1 → 0**.'],
      ['Type `ET-3912` in the **Search parts** box, then clear it.', 'Only that line, and the footer says how many ticked lines are shown (“1 of N ticked lines shown”). Clearing brings every line back, still ticked.'],
      ['Untick ET-3912-J.', 'Its Order is the same before and after (**1 → 1** on October 29): without the transfer, the order buys it.'],
      ['Untick every other line and tick ET-3912-J again (quantity 1). Click **Continue to review ›**.', '“Save the 1 ticked transfer first?” (“The order on Review counts only saved transfers.”) with **Stay**, **Continue without them** and **Save and continue**. Click **Stay**.'],
      ['Click **Save 1 transfer (1 transfer order)**.', '“Saved 1 transfer order.” and **Saved transfers**: “3 → 1 · 1 line · Draft · saved … by <your name>”.'],
      ['Click **Continue to review ›**.', 'No question this time. ET-3912-J stays on the list with **0**, **Covered by transfers** and a greyed-out tick box, **Transfer in** 1 and “Includes 1 coming by transfer from branch 3”. The subtitle adds “1 part covered by transfers”, and the totals don’t count it. (If a transfer covers only part of a line, its quantity is that much lower instead.)'],
      ['Click **Back to transfers** and open the transfer order from **Saved transfers**. (You leave the One-Time Order; that’s fine.)', 'The transfer order page: **From One-Time Order "TEST 0.7.0"** · data as of …, with ET-3912-J × 1.'],
      ['Click **Cancel**, then **Cancel transfer**, then **Archive**.', '**Cancelled** (a grey pill), then **Archived**. Its stock is released.'],
      ['Start the One-Time Order again (TEST, branch 1, MM, Rolling 12) and click **Continue to transfers**.', 'ET-3912-J is offered again: a cancelled transfer no longer counts.'],
      ['Click **Back to setup**, untick **MM** and tick a small franchise. Click **Continue to transfers** (answer **Continue anyway** if it asks).', 'If no other branch can spare anything for it: straight to Review with “No transfers suggested for this order.” and no **Back to transfers** button. Leave without creating the order.'],
    ]),
    { p: '**Your opinion:** is a Transfers step on One-Time Orders useful, and does a covered line on Review (0, “Covered by transfers”) read clearly?' },
    notes,

    { h2: 'Versions 0.6.0 to 0.6.2 (October 28 and 29, 2026): save transfers in the app' },
    { p: 'New since 0.5.3:' },
    { bullets: [
      '**Save transfers.** Recommended Reorder now has two steps, **1 Transfers → 2 Order**. Step 1 lists the transfers suggested into your branch, all ticked to start with. Untick what you don’t want, change a quantity, and **Save**. Each sending and receiving pair becomes one **transfer order**.',
      '**The order counts saved transfers.** On step 2 a line a saved transfer reduced says **Includes 44 coming by transfer from branch 6** (part of Inbound, not on top of it), and a line it covered fully drops out of “Reorder needed only”. **Continue to order** with unsaved ticks asks whether to save them first.',
      '**The Transfers page saves too,** for example to work one sending branch at a time, and has a **Saved today** view and a new **Transfer orders** tab.',
      '**Transfers opens on Transfer orders (0.6.2).** Clicking **Transfers** in the menu lands on **Transfer orders**, now the first tab. The suggestions are on the second tab, **Suggestions**. Home’s **Review transfers** and the links on Recommended Reorder still go to the suggestions.',
      '**Status pills (0.6.1).** On Transfer orders each status is a coloured pill: **Draft** amber, **Exported** blue, **Entered in Equip** green, **Cancelled** grey.',
      '**Step 1 is easier to work (0.6.1).** The part search box at the top of Recommended Reorder now filters step 1’s list too. It doesn’t change your ticks: the footer says “N of M ticked lines shown” when the search hides some. The footer (what the ticked lines cover) stays at the bottom of the window while you scroll, with its own **Save** button.',
      '**Transfer orders** have their own page: change quantities while it is a Draft (never above the suggested quantity), **Export CSV** for keying into Equip, then **Mark entered in Equip**. **Cancel** releases the stock. Entered or cancelled transfers can be archived.',
      '**Transfer rules page** next to Rules, with **Try it**: change the excess (12 months), the redistribution limit (6 months) or the minimum, for a franchise, branch or other criteria, and see the effect on every branch before saving.',
      '**Safety:** before saving, the app checks each sending branch still has the stock; if someone else took it, nothing is saved and it says what changed. If SharePoint is slow to show a saved transfer, the app still counts it and says so. If a different person signs in on the same browser, the app reloads so nobody sees the last person’s data.',
      '**Also (0.5.3):** a quantity change on an order is refused if someone else exported, placed or archived it meanwhile.',
    ] },
    { note: 'Saving a transfer is real: until it is cancelled it holds the sending branch’s stock, so other people see less excess and the receiving branch’s order goes down. In the steps below save **one practice transfer of quantity 1**, then **cancel and archive it** in the same sitting. Don’t export or mark a practice transfer entered.' },
    { h3: 'Recommended Reorder: step 1 and step 2' },
    steps([
      ['Go to **Home**, branch **1**. Click **Review transfers** on the purple card.', 'Recommended Reorder opens on **step 1** of **1 Transfers → 2 Order**: “Transfers into branch 1”, with “Tick the transfers to make instead of buying; the order on step 2 counts the saved ones.” While every branch loads, the table is marked “as of this morning” and can’t be ticked: “Loading every branch… you can save once it finishes”.'],
      ['When loading finishes, type `MULTISEAL` in the search box at the top of the page.', 'Only the MULTISEAL lines (franchise M). Ticked, with a **Conventional** badge, about **44 from 6**. The footer reads like “N transfers cover N order lines and $X you won’t buy.” and “2 of N ticked lines shown”: the lines the search hides stay ticked.'],
      ['Type **60** in MULTISEAL’s quantity box.', 'It goes back to the suggested quantity with “At most 44”: a transfer is never more than suggested.'],
      ['Clear the search. Scroll down the list.', 'Every line again. The footer, with its **Save** button, stays at the bottom of the window while you scroll.'],
      ['Untick every line except one cheap one and set its quantity to **1**. Note the part. Click **Save 1 transfer (1 transfer order)** (at the top, or in the footer).', '“Saved 1 transfer order.” and a **Saved transfers** list, for example “6 → 1 · 1 line · Draft · saved 3:10 PM by <your name>”, linking to the transfer order.'],
      ['Tick another line, then click **Continue to order ›**.', 'A question: “Save the 1 ticked transfer first?” with **Continue without them** and **Save and continue**. Click **Continue without them**.'],
      ['On step 2, find the part you saved.', 'Its order cell says **Includes 1 coming by transfer from branch …** and the order is 1 lower than before. If SharePoint hasn’t caught up yet, a banner says “Your saved transfers may take a moment to show here — Refresh”; the order already counts it.'],
      ['Open the transfer from the **Saved transfers** list (or click **Transfers**: it opens on Transfer orders). Click **Cancel**, then **Cancel transfer**, then **Archive**.', '“Cancel this transfer? Its stock is released for other suggestions.” It shows **Cancelled** (a grey pill), then **Archived**. Back on Reorder step 2 (Refresh if needed) the order is back to what it was.'],
    ]),
    notes,
    { h3: 'The Transfers page and transfer orders' },
    steps([
      ['Click **Transfers** in the menu.', 'It opens on **Transfer orders**, the first tab: every transfer order, newest first: From, To, Status, Lines, Value at the sending branch’s cost, Exported, Saved. Each status is a coloured pill: **Draft** amber, **Exported** blue, **Entered in Equip** green, **Cancelled** grey. A Draft more than a week old shows **Draft for N days**, and the tab says how many old drafts there are.'],
      ['Turn on **Show archived**.', 'Your cancelled practice transfer, greyed, with a grey **Cancelled** pill and an **Archived** tag. Only entered or cancelled transfers can be archived.'],
      ['Click the **Suggestions** tab. Set **From** to **13** and **To** to **1**.', 'Only lines from 13 into 1, for example **R134A**, **Redistribution** about **52 from 13**. The Save button counts only the ticked lines you can see.'],
      ['Set **Status** to **Saved today**.', 'Today’s saved transfer lines. A note says “Cancelled transfers aren’t listed here; see Transfer orders (Status: Cancelled).”: your cancelled practice transfer is there, not here. Kind is greyed out: saved lines are listed by transfer, not by kind.'],
    ]),
    notes,
    { h3: 'Transfer rules and Try it' },
    steps([
      ['Click **Transfer rules** in the menu.', 'The list starts with the read-only **Built-in default**: “excess above 12 months, receive up to 6 months, no minimum for redistribution”, and a sentence on how a rule is picked: the sending branch’s rule decides what counts as excess, and the receiving branch’s rule decides whether it takes transfers and how much redistribution.'],
      ['Click **New rule**. Name it **TEST**, Branch **6**, untick **AllowSend**. Don’t save.', 'A **Try it** card: Conventional lines, **Order $ avoided**, Redistribution lines and Redistribution $, before → after, and the parts that change most (MULTISEAL should be one). Nothing is saved.'],
      ['Set **ExcessSupply** to **99** (months).', 'A message instead of figures, naming the problem (“ExcessSupply must be 0-60 months”). Set it back.'],
      ['Click **Close**, then **Discard**.', 'No rule was saved; the list is as before.'],
    ]),
    { p: '**Your opinion:** is two steps on Recommended Reorder the right flow, or would you rather tick transfers on the order list itself?' },
    notes,

    { h2: 'Version 0.5.2 (October 28, 2026): archive orders' },
    { p: 'New since 0.5.1: **Archive** orders you no longer need to see, such as test orders or orders long since placed. Nothing is deleted: an archived order is hidden from the Orders list unless **Show archived** is on, and is read-only until you unarchive it. Archiving never changes an order’s status, export count or lines.' },
    steps([
      ['On **Orders**, tick the **TEST** orders you made. Click **Archive (N)**.', 'A question: “Archive N orders? They stay saved and can be shown again with Show archived.” Click **Archive**: “Archived N orders.” and the orders leave the list.'],
      ['Turn on **Show archived (N)**.', 'The archived orders come back, greyed, each with an **Archived** tag. The switch stays on next time you open Orders on this computer.'],
      ['Open one of the archived orders.', 'A banner: “This order is archived. Unarchive it to edit or export.” There is no Export, Mark placed or quantity editing.'],
      ['Click **Unarchive**. Go back to Orders.', 'The order is back to normal, with the same status and export count as before. Archive it again if it was a test.'],
    ]),
    { p: '**Your opinion:** would a quick way to archive every placed order older than a month be useful?' },
    notes,

    { h2: 'Version 0.5.1 (October 28, 2026): export several orders as one CSV' },
    { p: 'New since 0.5.0: **Export together** (Barry’s request). Orders are still saved one per branch and franchise, but you can download several of them as one CSV, either one line per branch or a total per part, and one file per franchise or one for everything.' },
    { note: 'This makes practice orders: name them **TEST**. Exporting marks them Exported; Brian tidies them up afterwards.' },
    steps([
      ['On Recommended Reorder, click **Several branches…** and tick **1** and **92**. Tick `220018` at both branches (or any part both need) and one part from another franchise. Click **Create orders**, name it **TEST** and save.', 'You land on Orders, showing only the orders just made, all **ticked**. A panel above the list has **LINES** (One line per branch / Total per part), **FILES** (One file per franchise / One file for everything) and a button **Download one CSV for all (3 orders)**.'],
      ['Leave **One line per branch** and **One file per franchise**. Click **Download one CSV for all**.', 'One file per franchise, named like `Combined-RM-20261028-1530.csv`. Each starts with a **Branch** column and has every line of both branches. “Downloaded 2 files for 3 orders; each order is marked exported.” Every order now shows **Exported**.'],
      ['Click **Total per part** and **One file for everything**, then the button again.', 'One file, `Combined-All-….csv`, with a **Franchise** column first. `220018` is one line with both branches’ quantities added up, and the **Branches** column says how many each one ordered, e.g. “1 (2); 92 (3)”.'],
      ['Click **Show all orders**. Tick two older orders, then a **Placed** one.', '**Export together (2 orders)** appears above the list, with “2 of 3 ticked orders can be exported (placed and archived orders are left out).” Since 0.5.2 a placed order can be ticked so it can be archived, but it is never exported again. Your LINES and FILES choices are as you left them.'],
    ]),
    { p: '**Your opinion:** which layout does each vendor want, one line per branch or a total per part?' },
    notes,

    { h2: 'Version 0.5.0 (October 28, 2026): transfer suggestions and phase-in' },
    { p: 'New since 0.4.0:' },
    { bullets: [
      '**Transfer suggestions** (Ben’s answers of October 27). Every morning the tool suggests stock another branch could send: **Conventional** (instead of buying) and **Redistribution** (extra stock to a branch that sells the part). They show in **purple** on Home and Recommended Reorder, and on a new **Transfers** page. In this version you key them into Equip by hand; ticking and saving transfers in the app comes next.',
      '**"Excess" now means stock a branch could send:** free stock above the larger of its target and 12 months of supply, as John Deere uses it. Round 1’s figure (on hand above target) is now called **Above target**. **Months of supply** is shown next to them.',
      '**Phase-in:** stock a new part before it has the demands its rule needs, with a quantity and an end date.',
      '**More rule criteria:** SLC, Source, Vendor code, Product group and Commodity code, as well as franchise, dealer group and branch.',
      '**Several dealer groups** at once on Recommended Reorder and One-Time Order (Barry’s request).',
      '**No more lost ticks:** leaving Recommended Reorder or One-Time Order with parts ticked now asks first.',
    ] },
    { note: 'The examples below are from the test data of October 28. Transfer suggestions change every morning, so expect different quantities; if a part has no suggestion on your day, pick any purple row instead.' },

    { h3: 'Transfers on Home and Recommended Reorder' },
    steps([
      ['Go to **Home** and set the branch to **1**.', 'A purple card under the order count: "Branch 1: about **67** parts could come by transfer instead of being bought", and under it about 2,300 lines for all branches (about $266,000): about 1,200 could replace a purchase (about $150,000) and about 1,100 are redistribution (about $116,000).'],
      ['Click **Review transfers**.', 'The Transfers page, with **To** set to branch 1. (More on this page below.)'],
      ['Open **Recommended Reorder**, branch 1, franchise **All**.', 'A purple banner above the list: "About 67 parts here could come by transfer instead of being bought", "about 34 more parts could take extra stock (redistribution)", and **See Transfers**. Some rows have a purple left edge.'],
      ['Search `MULTISEAL`.', 'One line (8oz pump of Bulk Multi Seal): order about **44**, with a purple pill **Transfer 44 from 6** before it.'],
      ['Open its details (the arrow).', 'A purple **Suggested transfers** box at the top: "Branch 6 can send 44 instead of buying (Conventional), and 61 more (Redistribution)", then "Until transfers can be saved here, key them into Equip and lower this order."'],
      ['Look at the order: it still says about 44.', 'Right for this version: the order doesn’t drop by itself yet. You would key the transfer into Equip and not buy these 44.'],
      ['Clear the search. Turn **Transfer suggested only** on.', 'About 100 rows, all purple: every part another branch could send, including the redistribution-only ones with an order of 0. **Reorder needed only** greys out while this switch is on (hover over it to see why).'],
      ['Search `R134A`.', 'Freon refrigerant with **Redistribution 40 from 13** and an order of 0.'],
      ['Turn **Transfer suggested only** off. Clear the search.', 'Back to about 220 lines, and **Reorder needed only** works again.'],
      ['Tick any two parts, then click **Home** in the menu on the left.', 'A bar at the top: "Leave this page? 2 ticked parts will be lost." with **Stay** and **Leave**. You are still on Recommended Reorder.'],
      ['Click **Stay**.', 'The bar goes and both parts are still ticked. Untick them (or click **Clear** at the bottom).'],
      ['Click **Dealer group** and tick two groups (any two in the list). Then tick **(none)** as well.', 'Only parts in those groups; **(none)** adds parts with no dealer group code. Click **Clear** (or untick them all) to see every group again.'],
    ]),
    { p: '**Your opinion:** do the purple marks make the transfers easy to spot? Is there anything else you’d want to see on a row before keying a transfer into Equip?' },
    notes,

    { h3: 'Above target, Excess and Months of supply' },
    steps([
      ['On Recommended Reorder, branch 1, search `MULTISEAL` and click the **part number**.', 'The Part page. Under **Other branches**, a **Suggested transfers** line once every branch has loaded: "Suggested: 44 from branch 6 (conventional); 61 from branch 6 (redistribution)".'],
      ['Find **branch 6** in the Other branches table.', 'On hand about 730, Above target about 659, **Excess about 426**, Months of supply about 28.8. Branch 6 keeps 12 months of supply (about 304), so only the rest is excess.'],
      ['Find **branch 93**.', 'About 1,150 **Above target**, but **Excess 0**: it has about 11 months of supply, less than the 12 it keeps.'],
      ['Hover over the **Above target**, **Excess** and **Months of supply** headings.', 'A short definition of each.'],
    ]),
    notes,

    { h3: 'The Transfers page' },
    steps([
      ['Click **Transfers** in the menu, then the **Suggestions** tab (since 0.6.2 it opens on Transfer orders).', 'A grey **As of this morning** tag and a progress line while every branch loads (a few seconds), then a green **Live** tag: about **2,312 suggestions**, with the banner "Showing live suggestions. No part has changed since this morning."'],
      ['Set **Kind** to **Conventional**, then **Redistribution**, then **All**.', 'About 1,219, then about 1,093. Every line has a **Conventional** or **Redistribution** badge. The line under the table totals each kind.'],
      ['Set **Franchise** to **M** and **To** to **1**.', 'Branch 1’s franchise M suggestions, including MULTISEAL (44 and 61 from 6). The From columns show "before → after", for example on hand 730 → 686.'],
      ['Set **From** to **13**, then everything back to **All**.', 'Only lines sent by branch 13 (lots of R134A), then the full list.'],
      ['Click **Export CSV** and open the file in Excel.', 'One row per suggestion: Kind, FromBranch, ToBranch, PartNumber, Franchise, Description, Qty, FromBin, ToBin, FromCost, Value. Only the filtered lines are in it.'],
      ['Open **Transfer rules in use** at the bottom.', '"0 active" and the built-in default: excess above 12 months, receive up to 6 months, no minimum for redistribution.'],
    ]),
    { p: '**Your opinion:** what would you need on this page to key a transfer into Equip quickly (columns, order, grouping by branch pair)?' },
    notes,

    { h3: 'Phase-in (practice, then clear it)' },
    { note: 'A phase-in is saved for everyone straight away. Clear it again at the end of these steps.' },
    steps([
      ['**Part Lookup**, branch **1**, search `GG100`, and open it.', 'BS **GG100**, 100PSI liquid fill gauge: none on hand, no sales, so no order (**No recent activity**).'],
      ['Click the **Settings** tab. Under **Phase in**, type a quantity of **2**.', 'The end date fills in 12 months from today.'],
      ['Change the end date to **yesterday**.', 'The message "That date has passed, so the phase-in would not apply. Pick today or later." Put the 12-months-from-today date back.'],
      ['Click **Save settings**.', '"Saved." A green badge next to **Phase in**: **Active until** that date, and a line saying it ends early once the part has 3 demands.'],
      ['Click the **Detail** tab.', 'Target **2**, order **2**. "Why this number" says the phase-in of 2 sets the target.'],
      ['Click **Special statuses**.', 'GG100 at branch 1 listed as **Phase-in**, "2 until" the date, with your name.'],
      ['**Recommended Reorder**, branch 1, search `GG100`.', 'Order 2, with a small green **Phase-in** tag by the part number.'],
      ['Open **Transfers**, click the **Suggestions** tab and wait for **Live**.', 'The banner now says "1 part has changed since this morning". Click **Why**: a part setting (… phase-in) changed. With franchise **BS** and To **1** you may also see a new GG100 line from a branch with a spare one (on the test data: 2 from branch 94). Phase-in parts can be filled by transfer.'],
      ['Back on GG100’s **Settings** tab, click **Clear phase-in**, then **Save settings**.', 'The badge is gone. The order is back to 0, and GG100 is off Special statuses.'],
    ]),
    notes,

    { h3: 'A phase-in that has ended (practice, then clear it)' },
    { p: 'A phase-in ends at its end date, or as soon as the part has the demands its rule needs. This shows the second case on a part that already sells well.' },
    steps([
      ['Open part **124184** (Mobil 1 oil) at branch 1, **Settings** tab. Set a phase-in quantity of **1** and **Save settings**.', 'An amber badge **Ended: reached 3 demands**: the part already has about 22 demands, so its rule stocks it and the phase-in has nothing to do.'],
      ['Click the **Detail** tab.', 'Target and order are unchanged (about 40 and 39). "Why this number" starts with "The phase-in ended because the part reached 3 demands."'],
      ['Open **Special statuses**.', '124184 listed as **Phase-in ended**, so someone can tidy it.'],
      ['Back on **Settings**, click **Clear phase-in** and **Save settings**.', 'The badge and the Special statuses entry are gone.'],
    ]),
    notes,

    { h3: 'New rule criteria and Try it (don’t save)' },
    steps([
      ['Click **Rules**, then **New rule**.', 'An empty rule with the new fields: **SLC**, **Source**, **Vendor code**, **Product group** and **Commodity code**, as well as Franchise, Dealer group code and Branch.'],
      ['Type **01058** in **Vendor code**.', 'A warning: the leading zero means it matches no part; use 1058.'],
      ['Change it to **1058**. Give the rule a name (**TEST**), priority **5**, supply **16 weeks**, and switch it **Active**.', 'The **Try it** panel on branch 1: more order lines and a higher total, and only vendor 1058’s parts among the parts that change.'],
      ['Click **Close**, then **Discard**.', 'Nothing is saved; the rules list is unchanged.'],
    ]),
    notes,

    { h3: 'About' },
    steps([
      ['**App Settings** → **About**.', 'Version **0.5.0** or later.'],
    ]),
    notes,

    { h2: 'Version 0.4.0 (October 27, 2026): several branches in Recommended Reorder' },
    { p: 'Recommended Reorder can now show several branches at once, so you can work several stores in one pass. One-Time Order got the same in 0.3.0, and both now load faster (all 19 branches in about 4 seconds instead of 10 to 12).' },
    steps([
      ['On Recommended Reorder (branch 1, franchise All), click **Several branches…**.', 'A list of branch checkboxes, with **Select all** and **Clear**.'],
      ['Tick branch **92** as well as **1**.', 'Branch 92 loads by itself. Lines are grouped by branch, with a **Branch** column. A **Totals by branch** table shows lines and value for each (branch 92: about 120 lines, about $207,000).'],
      ['Search `RM-24A`.', 'One line, at branch 92: Arctic bale wrap (yellow), about 194 to order. Searching works across every loaded branch.'],
      ['Clear the search. Use the **Show** picker to choose **92**, then **All branches** again.', 'Only branch 92’s lines, then both again.'],
      ['Open **Several branches…** again and click **Select all**. Time it roughly.', 'All 19 branches load in about 4 seconds. A progress line shows "x of 19 branches loaded" until it finishes.'],
      ['While all branches are loaded, search `PW-193NT`.', 'About 12 lines, one per branch that needs it, each with its own quantity.'],
      ['Turn **Reorder needed only** off. Type in the search box, tick a few parts, and click a column heading.', 'Typing and ticking feel instant. Sorting takes about a second.'],
      ['Turn **Reorder needed only** back on. Search `220018`, open the **branch 92** line, and click **Mask…** and confirm with no expiry.', 'Only branch 92’s line changes to Masked. Branch 1’s line for 220018 is unchanged. The banner names branch 92.'],
      ['Click **Unmask** on that line.', 'Branch 92’s order comes back.'],
      ['Optional: tick 220018 at branch 1 and at branch 92 and click **Create orders**. Name it **TEST** and save.', 'The review says one order per **branch and franchise**: 2 orders (branch 1 RM, branch 92 RM). After saving you land on a list of just those orders. Don’t export them.'],
      ['Tick a part, then open **Several branches…** and untick that part’s branch.', 'The app tells you how many ticked parts at that branch were unticked.'],
      ['Click **Clear** and tick only **1**.', 'Back to one branch: it looks exactly as before, with no Branch column.'],
    ]),
    { p: '**Your opinion:** is the **Several branches…** button the right way to pick branches, or would you rather see the branch checkboxes all the time?' },
    notes,

    { h1: 'Part 3: release checks (Brian)' },
    { p: 'Run these when a new version is deployed to the test server, after **Ctrl+F5** to load it.' },
    { h3: '0.14.0' },
    steps([
      ['App Settings → **About**.', '**Version 0.14.0 · commit 15ca00a**. (Done November 5.)'],
      ['Refresh SPI Corparate Stocking.xlsx and compare it with the app’s list.', 'Every difference is explained. (Done November 5 against Brian’s 8:01 am refresh: Gold matched the reference with 0 differences; 1,817 parts matched; 5 parts with an invoice at 94 after the 6:42 data time, 1 at the window start, 2 changed at branch 11 in Equip, 4 description spellings accepted by Brian. The app’s CSV then matched the reference exactly: 1,815.)'],
      ['With Claude: a real test copy of Corporate Stocking, then check SharePoint and delete the TEST row.', 'NonJD_InventoryReports holds the row as a one-row-per-part report with its four lists. (Done November 5: “TEST Corporate Stocking 4+”, Branches with demand ≥ 4; its 618 parts matched the reference in the same order; deleted, list empty. App only: no data or publish changes.)'],
    ]),
    { h3: '0.13.1' },
    steps([
      ['App Settings → **About**.', '**Version 0.13.1 · commit 0a0d6e6**. (Done November 4.)'],
      ['Transfer orders: tick two or more, **Export (N)**.', 'One combined CSV; each transfer shows Exported with its export count up by 1. (Done November 4 on mock, no issues; app only, no data or publish changes.)'],
    ]),
    { h3: '0.13.0' },
    steps([
      ['App Settings → **About**.', '**Version 0.13.0 · commit 1319ca9**.'],
      ['After the backend deploy, the Prod items run and the Gateway publish: Inventory management, **Count** on 2 & 4 Cotton.', 'The Gateway PC published contract 7 (the parts with no activity): a count, not “Parts with no activity aren’t in today’s data yet”. (Done November 4: v7 publish with --force at 16:11 UTC, jdParts 250,911, jdIdleParts 643,034; `corp_parts_check.py --tier prod` PASS, 0 differences on both tables.)'],
      ['Refresh Border Stores.xlsx and 2 & 4 Cotton & Stripper Parts.xlsx and compare them with the app’s lists.', 'Every difference is explained. (Done November 4 against Brian’s 5 pm refreshes of November 3: Border Stores 1,573 of 1,575 matched, 2 & 4 Cotton 248 of 248 plus 1; all evening orders or transfer receipts except 95/TCA24616, a lower-case part record, fixed. The app’s CSVs then matched the reference exactly: Border Stores 1,576, 2 & 4 Cotton 251.)'],
      ['With Claude: a real test copy of Border Stores with other branches, then check SharePoint and delete the TEST row.', 'NonJD_InventoryReports holds the row with its two lists and the no-activity switch. (Done November 4: “Test 0.13.0”, branch one of 7, 14, parts with no activity on; stored correctly, its 1,027 parts matched the reference; deleted, list empty.)'],
    ]),
    { h3: '0.12.0' },
    steps([
      ['App Settings → **About**.', '**Version 0.12.0 · commit 46812b4**.'],
      ['After the backend deploy and the Gateway publish: the data date at the top right, then **Inventory management**.', 'The Gateway PC published contract 6 (the JD parts): Inventory shows the reports, not “JD parts aren’t in today’s data yet”. (Done November 3: v6 publish at 20:08 UTC, 250,867 JD parts, data as of 19:42 UTC; `corp_parts_check.py --tier prod` PASS, MLPF Gaps 10,090; `nonjd_reorder_check.py --tier prod` PASS.)'],
      ['Refresh MLPF Gaps.xlsx and compare it with the app’s list.', 'Every difference is explained by today’s sales, receipts or orders. (Done November 3: Brian’s 9:41 AM refresh against the Prod data, 10,046 of 10,065 rows matched on every column, every difference explained; see INVENTORY-REPORTS.md.)'],
      ['With Claude: a real test copy on Prod (save, switch off, archive), then check SharePoint and delete the TEST row.', 'NonJD_InventoryReports holds the row with the right Conditions, Active and Archived, by you. (Done November 3: “Test of MLPF Gaps”, Corp demands ≥ 4; switched off, archived; correct in SharePoint, then deleted, list empty.)'],
    ]),
    notes,
    { h3: '0.11.0' },
    steps([
      ['App Settings → **About**.', '**Version 0.11.0 · commit e8c6a7e**.'],
      ['The morning after the backend deploy: the data date at the top right, then **Cleanup**.', 'The Gateway PC published contract 5 (Equip stock value): **Stock value with no quantity** shows a count, not “Not in today’s data yet”. (Done November 2: v5 publish, 199,706 parts, data as of 22:04 UTC; Minimums with no demand 3,592, Stock value with no quantity 415; `nonjd_reorder_check.py --tier prod` PASS.)'],
      ['With Claude: a real test check on Prod (save, edit, switch off, archive), then check SharePoint and delete the TEST row.', 'NonJD_CleanupChecks holds the row with the right Conditions, Active and Archived, by you. (Done November 2: “TEST Check”, On hand > 0, Sales 24 months = 0, Cost > 100; edited, switched off, archived; correct in SharePoint, then deleted, list empty.)'],
    ]),
    notes,
    { h3: '0.10.0' },
    steps([
      ['App Settings → **About**.', '**Version 0.10.0 · commit 9cc43f0**.'],
      ['With Claude: a real test template on Prod (save, update, archive), then check SharePoint and delete the TEST rows.', 'NonJD_OneTimeTemplates holds the row (Archived, Setup correct) and NonJD_TemplateChanges one entry per change, by you. (Done November 2: “Test Template”, branch 1, BS, Rolling 12, factor 1 → 2, min demands 10; entries Created, loading factor 1 → 2, Archived; the 4 rows deleted, both lists empty.)'],
      ['Non-JD ordering menu.', '**Templates** right under One-Time Order; it opens **One-Time templates** with “No templates yet. Save one from One-Time Order’s Set up.” while the list is empty.'],
    ]),
    notes,
    { h3: '0.9.0 and 0.9.1' },
    steps([
      ['App Settings → **About**.', '**Version 0.9.1 · commit 001e2e8**.'],
      ['The morning after a publish: the data date at the top right, then **Return & scrap rules** → **New return rule** with any franchise and Allowance based on **12-month purchases** (don’t save).', 'Today’s date (the Gateway PC publish ran). Try it shows an **Allowance** in dollars, not “Purchases arrive with the next morning data”, and **Not received for** has no note saying last received isn’t in the data yet.'],
      ['With Claude: a **TEST** scrap list on Prod (one line kept, one line Transfer instead), then check SharePoint and delete the TEST rows.', 'NonJD_Returns / NonJD_ReturnLines and the transfer order hold the right fields; the tags show and go when it is cancelled. (Done November 2: Scrap default, AM-SCR-20261102-1026 with 6397 × 2 at 11, transfer 91-8-20261102-1026 with 9447 × 1; the 4 rows deleted.)'],
      ['Return & scrap rules: open **Scrap default** and a new return rule.', '0.9.1: **Franchise** is a list: **All franchises** on the scrap rule, **Choose a franchise** on the return rule.'],
      ['Scroll a long list on Reorder step 1 and on New scrap list → Parts.', '0.9.1: the footer sits at the very bottom of the window, with no rows showing under it.'],
    ]),
    notes,
    { h3: '0.8.0' },
    steps([
      ['App Settings → **About**.', '**0.8.0** and the deployed commit (`ae6c1a6`).'],
      ['The launch page on branch 1, then the Non-JD ordering card.', 'The card’s parts to order and cost match Home’s; the Cleanup card’s count matches Cleanup filtered to branch 1.'],
      ['Ask Shannon or Barry to click **Parts reports ↗** on the launch page.', 'The Parts Reports app opens for them.'],
      ['Old addresses: `/reorder`, `/orders`, `/cleanup`, a part page.', 'Each opens as before, with the menu on its area.'],
    ]),
    notes,
    { h3: '0.7.0' },
    steps([
      ['App Settings → **About**.', '**0.7.0** and the deployed commit (`ff52dc3`).'],
      ['With Claude, after 10:15: a One-Time Order for one branch and franchise Claude names from that morning’s Prod data. On step 2 save one line, then cancel that transfer order from its page.', 'Claude confirms through Graph: Status Cancelled, Parameters `source: "One-Time"` and `orderName`. After Refresh the line is offered again. No order is created. (Done October 29: “TEST 0.7.0”, ET-3912-J 1 from 3 → 1, $32.00.)'],
      ['Recommended Reorder step 1 and the Transfers page.', 'As in 0.6.2: ticks, search, Save and the Transfer orders tab unchanged.'],
      ['The next morning: `/check-refresh prod` and the reference check, then delete the TEST transfer rows only with Brian’s OK.', 'The refresh and the check pass; the cancelled TEST transfer never counted.'],
    ]),
    notes,
    { h3: '0.6.1 and 0.6.2' },
    steps([
      ['App Settings → **About**.', '**0.6.2** and the deployed commit.'],
      ['Click **Transfers** in the menu.', 'It opens on **Transfer orders** (the first tab), with coloured status pills. **Suggestions** is the second tab.'],
      ['Home → **Review transfers**; then on Recommended Reorder click **See Transfers**.', 'Reorder step 1, then the Transfers page on its **Suggestions** tab with To set to the branch.'],
      ['On Reorder step 1, search a part, then clear the search. Scroll a long list.', '“N of M ticked lines shown” while searching; all ticks kept after. The footer and its Save stay at the bottom of the window.'],
    ]),
    notes,
    { h3: '0.6.0' },
    steps([
      ['App Settings → **About**.', '**0.6.0** and the deployed commit.'],
      ['With Claude, after 10:15 (after the publish window): save one TEST transfer (quantity 1) on Reorder step 1, export it and **Mark entered in Equip**; save a second and leave it as a Draft.', 'Both in SharePoint `NonJD_Transfers` / `NonJD_TransferLines`; the transfer order page shows Saved and Entered times correctly in Central time.'],
      ['Run the Dev pipeline (`mode=items`: `df_NonJD_Transfers_Raw` and `Build_Gold_NonJD_Reorder`), then Claude runs the reference check.', 'Gold’s transfers in / out include the saved transfers; the check passes.'],
      ['Cancel the Draft and archive both. Delete the TEST rows only with Claude, after the check.', 'The cancelled transfer stops counting; nothing else changed.'],
      ['Real-data timing: `python run_publish.py --out <folder>`, then Claude runs `parity-full --committed`. On Fedora, open Transfer rules → a rule → Try it.', 'The re-run is under about 300 ms; Try it shows figures within a couple of seconds and typing never stalls.'],
      ['Sign out and sign in as someone else on the same browser (or ask Shannon to try it on your PC).', 'Only their name and data; nothing of the previous person’s.'],
    ]),
    notes,
    { h3: '0.5.2' },
    steps([
      ['App Settings → **About**.', '**0.5.2** and the deployed commit.'],
      ['Orders: tick the TEST orders, **Archive (N)**, confirm. Turn on **Show archived**.', 'They leave the list, then come back greyed with an **Archived** tag; in SharePoint `NonJD_Orders` only **Archived** changed (Status and ExportCount as before).'],
      ['Open an archived order.', 'The archived banner; no Export or Mark placed.'],
    ]),
    notes,
    { h3: '0.5.1' },
    steps([
      ['App Settings → **About**.', '**0.5.1** and the deployed commit.'],
      ['Orders: tick two Draft TEST orders from different branches, **Export together**, open the CSV in Notepad.', 'Header `Branch,PartNumber,Description,OrderQty,Cost,LineValue,Bin`; both orders show Exported with an export count of 1.'],
    ]),
    notes,
    { h3: '0.5.0' },
    steps([
      ['App Settings → **About**.', '**0.5.0** and the deployed commit.'],
      ['The first morning after the 0.5.0 publish: re-check the Part 2 examples (MULTISEAL at 1 with 44 from 6; branch 6 and 93 on Other branches; R134A redistribution from 13; GG100 with no stock or sales at 1; 124184 at about 22 demands) against Prod.', 'Each still behaves as described; update the walkthrough where Prod differs before sending it out.'],
      ['Home, Recommended Reorder and Transfers with the Prod data.', 'Purple card, banner and pills show; Transfers goes **Live** with no red "disagree" banner.'],
      ['Open an old address with dealer groups: `/reorder?branch=1&dgc=COTTON`.', 'Recommended Reorder with COTTON ticked.'],
      ['Special statuses with all branches loaded.', 'Masks, Manual order, min overrides and any phase-ins; no errors.'],
    ]),
    { h3: '0.4.0' },
    steps([
      ['App Settings → **About**.', '**0.4.0 · 3ca2dec**.'],
      ['Open an old bookmark-style address: `/reorder?branch=1&franchise=M`.', 'Recommended Reorder on branch 1, franchise M, as before 0.4.0.'],
      ['All 19 branches loaded with Reorder needed only off: press F12 → **Memory** and note the heap size.', 'Write it down (below about 500 MB is fine). The page stays responsive.'],
      ['Click **Clear**, then **Select all**, and click **Cancel** while it loads; then click **Load the rest**.', 'Loading stops with "x of 19 branches loaded (stopped)", then finishes.'],
      ['One-Time Order with all branches and a franchise.', 'Loads in about the same time as Reorder (about 4 seconds).'],
      ['After a morning publish, reload a page left open from the day before.', 'The new data date shows; no error.'],
    ]),
    notes,
  ],
}).catch((e) => {
  console.error(e);
  process.exit(1);
});
