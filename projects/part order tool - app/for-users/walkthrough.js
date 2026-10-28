// Builds "Non-JD Order Tool - Walkthrough.docx": hands-on steps through every page, each with what to do and what
// you should see. Brian works through it to test each release; it doubles as training for Ben, Shannon, Barry and
// Curt. It grows with each version: part 1 is the standing tour, part 2 has a section per version for what's new,
// part 3 holds release checks for Brian only.
// Examples are from Prod data of 2026-10-27 (Fact_NonJD_Reorder built 11:40 UTC); the 0.5.0 section's transfer and
// phase-in examples are from Dev data of 2026-10-28 (Gold built 14:12 UTC), because Prod has no round 2 data until the
// release. Re-check them against Prod after the first 0.5.0 publish. Refresh examples when a section is added.
// Labels follow nonjd-order-app 0.5.1 (36e4c96) and the user guide (guide.js).
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
  title: 'Non-JD Parts Order Tool: walkthrough',
  subtitle: 'Hands-on steps through every page · Version 0.5.1 · October 28, 2026 · App: https://10.110.100.13:8443',
  footer: 'Non-JD Parts Order Tool: walkthrough (0.5.1)',
  blocks: [
    { p: 'This is a hands-on tour of the tool. Each step says what to do and what you should see. Tick **OK** when it matches. When it doesn’t, or something is slow or confusing, write it in the notes box under that section and send it to Brian.' },
    { bullets: [
      '**Part 1, the tour,** covers every page. Work through it once to learn the tool (about an hour). It stays the same from version to version, apart from small updates.',
      '**Part 2, what’s new,** has a short section for each version. When a new version comes out, only its section needs doing.',
      '**Part 3, release checks,** is for Brian when he puts a new version on the test server.',
    ] },
    { note: 'The examples use the data of October 27 and 28, 2026. The data is refreshed every morning, so your quantities and dollars will be a little different. Close is fine; what matters is that the steps behave as described.' },
    { note: 'Practising is safe if you follow the steps: anything you change is undone in the next step. Practice orders stay as **drafts** named **TEST**. Don’t export or mark them placed. Orders can’t be deleted in the app yet; Brian clears the TEST ones.' },

    { h1: 'Part 1: the tour' },

    { h2: '1. Getting in and Home' },
    steps([
      ['Open **https://10.110.100.13:8443** in Edge or Chrome. If the browser warns "Your connection isn’t private", click **Advanced**, then **Continue to 10.110.100.13**.', 'The sign-in page, or Home if you are already signed in.'],
      ['Sign in with your work Microsoft account.', '**Home**, with a greeting, your branch, and how many parts need ordering there and their cost.'],
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
      ['Click **One-Time Order**. Name it **TEST**, tick branch **1**, franchise **BW**, and choose **Rolling 12**.', 'Setup accepts it and moves to the review.'],
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

    { h2: '9. Cleanup and App Settings' },
    steps([
      ['Click **Cleanup**. Pick branch **6**.', 'The Equip minimums on parts with no demand and no sales; branch 6 has about 1,000. The largest is about $21,000 (part 145019, module rim, minimum 65).'],
      ['Click **App Settings**.', 'Your default branch and franchise, and **About** with the version (**0.5.1**).'],
      ['Set your default branch, then open Recommended Reorder.', 'It opens on your default branch.'],
    ]),
    notes,

    { h1: 'Part 2: what’s new' },

    { h2: 'Version 0.5.1 (October 28, 2026): export several orders as one CSV' },
    { p: 'New since 0.5.0: **Export together** (Barry’s request). Orders are still saved one per branch and franchise, but you can download several of them as one CSV, either one line per branch or a total per part, and one file per franchise or one for everything.' },
    { note: 'This makes practice orders: name them **TEST**. Exporting marks them Exported; Brian tidies them up afterwards.' },
    steps([
      ['On Recommended Reorder, click **Several branches…** and tick **1** and **92**. Tick `220018` at both branches (or any part both need) and one part from another franchise. Click **Create orders**, name it **TEST** and save.', 'You land on Orders, showing only the orders just made, all **ticked**. A panel above the list has **LINES** (One line per branch / Total per part), **FILES** (One file per franchise / One file for everything) and a button **Download one CSV for all (3 orders)**.'],
      ['Leave **One line per branch** and **One file per franchise**. Click **Download one CSV for all**.', 'One file per franchise, named like `Combined-RM-20261028-1530.csv`. Each starts with a **Branch** column and has every line of both branches. “Downloaded 2 files for 3 orders; each order is marked exported.” Every order now shows **Exported**.'],
      ['Click **Total per part** and **One file for everything**, then the button again.', 'One file, `Combined-All-….csv`, with a **Franchise** column first. `220018` is one line with both branches’ quantities added up, and the **Branches** column says how many each one ordered, e.g. “1 (2); 92 (3)”.'],
      ['Click **Show all orders**. Tick two older orders. Look at a **Placed** order’s box.', '**Export together (2 orders)** appears above the list. A placed order’s box can’t be ticked. Your LINES and FILES choices are as you left them.'],
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
      ['Click **Transfers** in the menu.', 'A grey **As of this morning** tag and a progress line while every branch loads (a few seconds), then a green **Live** tag: about **2,312 suggestions**, with the banner "Showing live suggestions. No part has changed since this morning."'],
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
      ['Open **Transfers** and wait for **Live**.', 'The banner now says "1 part has changed since this morning". Click **Why**: a part setting (… phase-in) changed. With franchise **BS** and To **1** you may also see a new GG100 line from a branch with a spare one (on the test data: 2 from branch 94). Phase-in parts can be filled by transfer.'],
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
