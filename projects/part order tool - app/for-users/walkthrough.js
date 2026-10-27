// Builds "Non-JD Order Tool - Walkthrough.docx": hands-on steps through every page, each with what to do and what
// you should see. Brian works through it to test each release; it doubles as training for Ben, Shannon, Barry and
// Curt. It grows with each version: part 1 is the standing tour, part 2 has a section per version for what's new,
// part 3 holds release checks for Brian only.
// Examples are from Prod data of 2026-10-27 (Fact_NonJD_Reorder built 11:40 UTC); refresh them when a section is
// added. Labels follow nonjd-order-app 0.4.0 (3ca2dec) and the user guide (guide.js).
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
  subtitle: 'Hands-on steps through every page · Version 0.4.0 · October 27, 2026 · App: https://10.110.100.13:8443',
  footer: 'Non-JD Parts Order Tool: walkthrough (0.4.0)',
  blocks: [
    { p: 'This is a hands-on tour of the tool. Each step says what to do and what you should see. Tick **OK** when it matches. When it doesn’t, or something is slow or confusing, write it in the notes box under that section and send it to Brian.' },
    { bullets: [
      '**Part 1, the tour,** covers every page. Work through it once to learn the tool (about an hour). It stays the same from version to version, apart from small updates.',
      '**Part 2, what’s new,** has a short section for each version. When a new version comes out, only its section needs doing.',
      '**Part 3, release checks,** is for Brian when he puts a new version on the test server.',
    ] },
    { note: 'The examples use the data of October 27, 2026. The data is refreshed every morning, so your quantities and dollars will be a little different. Close is fine; what matters is that the steps behave as described.' },
    { note: 'Practising is safe if you follow the steps: anything you change is undone in the next step. Practice orders stay as **drafts** named **TEST**. Don’t export or mark them placed. Orders can’t be deleted in the app yet; Brian clears the TEST ones.' },

    { h1: 'Part 1: the tour' },

    { h2: '1. Getting in and Home' },
    steps([
      ['Open **https://10.110.100.13:8443** in Edge or Chrome. If the browser warns "Your connection isn’t private", click **Advanced**, then **Continue to 10.110.100.13**.', 'The sign-in page, or Home if you are already signed in.'],
      ['Sign in with your work Microsoft account.', '**Home**, with a greeting, your branch, and how many parts need ordering there and their cost.'],
      ['Look at the top right.', 'The date and time of the morning data. It is **amber** if the data is more than one business day old.'],
      ['In the greeting line, change the branch to **1**.', 'Branch 1 needs about **220** parts ordered (about $93,000), with a small line like "(21 more with minimums but no demand)".'],
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
      ['In the same details, look for **Excess at other branches** and **Inbound transfers**.', 'Other branches with stock above their target, if any, and any transfers on their way (they don’t reduce the order).'],
      ['Click the **part number** 124184.', 'The Part page opens on its **Detail** tab (next section).'],
    ]),
    notes,

    { h2: '4. Part Lookup and the Part page' },
    steps([
      ['Click **Part Lookup** in the menu. Choose **All branches** and search `PW-193NT`.', 'The Posi-Close Schlagel wheel at every branch that has it (about 12 of them need ordering today).'],
      ['Click the branch 1 result.', 'The Part page, **Detail** tab: stock, prices, the suggested order (about 14) and "Why this number".'],
      ['Scroll to **Other branches**.', 'Every branch with this part, this branch first and marked "(this branch)": On hand, Target, Excess and Sold 12 mo, with a **Total** row.'],
      ['Click the **History** tab. Switch between units sold and requests.', 'A chart of the last 12 full months, a 60-month table and totals.'],
      ['Click the **Settings** tab. Don’t change anything yet.', 'Min override, Manual order, Masked (with an expiry date), Notes, and the not-yet-used EOQ / pre-approved fields.'],
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
      ['Click **App Settings**.', 'Your default branch and franchise, and **About** with the version (**0.4.0**).'],
      ['Set your default branch, then open Recommended Reorder.', 'It opens on your default branch.'],
    ]),
    notes,

    { h1: 'Part 2: what’s new' },

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
