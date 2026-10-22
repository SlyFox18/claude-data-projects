// Builds "Non-JD Order Tool - User Guide.docx" for Ben, Shannon, Barry and Curt.
// Facts come from the app (nonjd-order-app: src/engine, README) and ../REORDER-RULES.md.
// Run: npm install, then node guide.js
const { build, CONTENT_W } = require('./lib');

const w = (...fr) => fr.map((f) => Math.round(CONTENT_W * f));

build('Non-JD Order Tool - User Guide.docx', {
  title: 'Non-JD Parts Order Tool: user guide',
  subtitle: 'For Ben, Shannon, Barry and Curt · October 2026 (test version) · https://10.110.100.13:8443',
  footer: 'Non-JD Parts Order Tool: user guide',
  blocks: [
    { p: '**In one sentence:** the tool shows each branch which non-John Deere parts to reorder and why, lets you tune the rules behind those suggestions, and turns the parts you pick into an order file for each vendor.' },
    { p: 'This guide covers getting in, what each page does, and exactly how every number is worked out. The questions we need you to answer are in the separate **questions** document.' },

    { h1: '1. Getting started' },
    { steps: [
      'Open **https://10.110.100.13:8443** in Edge or Chrome on your PC.',
      'The first time, the browser warns "Your connection isn’t private". This test server uses its own certificate. Click **Advanced**, then **Continue to 10.110.100.13**. You only need to do this once.',
      'Sign in with your normal Microsoft (work) account. Only Ben, Shannon, Barry, Curt and Brian have access during the test.',
    ] },
    { p: 'Sign-in is shared by all your tabs and normally lasts until you close the browser. The sign-out button is next to your name at the bottom left.' },
    { h3: 'How fresh is the data?' },
    { p: 'The tool works from a snapshot of Equip taken in the morning: stock, sales history, open purchase orders and transfers. The date at the top right of every page says when it was taken. It turns **amber** when the data is more than one business day old. During this test the snapshot may be refreshed less often than daily, so check the date.' },
    { p: 'Your **rule** and **part setting** changes are different: they apply in the tool immediately, for everyone. The morning snapshot picks them up the next day.' },

    { h1: '2. The pages' },
    { p: 'The menu on the left takes you to each page. The branch you’re looking at shows at the top right.' },

    { h2: 'Home' },
    { p: 'Shows how many parts need ordering at your branch and what they would cost, with a **Review now** link straight to that list, plus a card for each page. Pick a different branch in the greeting line to look at another branch.' },

    { h2: 'Recommended Reorder' },
    { p: 'The main page: every part at the branch with the suggested order quantity.' },
    { bullets: [
      '**Branch and Franchise** pickers at the top. The page remembers them in the address, so a bookmark or a refresh keeps your view.',
      '**Reorder needed only** (on by default) shows just the parts to order (Out of stock and Reorder). Turn it off to see every part.',
      '**Search** by part number or description.',
      '**Sort** by clicking a column heading; click again to reverse.',
      'Click the **arrow** at the left of a row to see **why** that quantity was suggested, in plain English, with the rule used, any inbound transfers and other branches with surplus.',
      'Click a **part number** to open its Part page.',
    ] },
    { h3: 'Making an order from the suggestions' },
    { steps: [
      'Tick the parts you want (the box in the heading ticks every part in the current filter, on every page).',
      'The bar at the bottom shows how many are ticked and their value at cost. Ticked parts stay ticked when you search or sort. Changing the branch or franchise asks first, because it clears them.',
      'Click **Create order**. A review lists one order per franchise and every ticked part. Parts hidden by your current search are marked "Hidden by filter", so nothing is ordered by surprise.',
      'Change any quantity. A quantity of 0 leaves the line out.',
      'Save. The tool creates the order(s) and opens them.',
    ], ref: 'steps' },

    { h2: 'Part Lookup and the Part page' },
    { p: 'Search one branch, or **All branches** to find a part anywhere. The Part page has three tabs:' },
    { bullets: [
      '**Detail:** stock, prices, the suggested order and "Why this number", plus **Other branches**: what each branch holds and any surplus.',
      '**History:** a chart of the last 12 full months (switch between units sold and requests), a 60-month table and totals.',
      '**Settings:** this part’s own minimum, a mask, and notes (see below). Saving applies straight away for everyone.',
    ] },
    { h3: 'Part settings' },
    { table: [
      ['Setting', 'What it does'],
      ['Min override', 'This part’s own minimum. The suggested target is never below it. Whole numbers only; blank means none.'],
      ['Masked', 'Stops the tool suggesting this part (order 0). Give an expiry date and the mask lasts until the end of that day; leave it blank and it lasts until someone unmasks it.'],
      ['Notes', 'Free text for anyone looking at the part.'],
      ['EOQ, Force non-spiking, Pre-approved rule', 'Saved, but not used by the calculation yet (see the questions document).'],
    ], widths: w(0.28, 0.72) },

    { h2: 'Orders' },
    { p: 'Every saved order, newest first, with filters for branch and status. An order is for **one branch and one franchise**.' },
    { table: [
      ['Status', 'What you can do'],
      ['Draft', 'Change quantities (press Enter or click away to save each one) and remove lines. Export when ready.'],
      ['Exported', '**Export CSV** downloads the file for the vendor and locks the lines, because the file has gone out. You can export it again (the count goes up).'],
      ['Placed', '**Mark placed** once the order is with the vendor. The order is then read-only.'],
    ], widths: w(0.18, 0.82) },
    { p: 'The CSV file has one line per part: `PartNumber, Description, OrderQty, Cost, LineValue, Bin`. Description and bin are saved with the order, so a file exported later still matches what was ordered. Tip: open it in Notepad to see it exactly; Excel drops leading zeros from part numbers on screen.' },

    { h2: 'One-Time Order' },
    { p: 'For a one-off order based on sales over months you choose, e.g. stocking up before a season.' },
    { steps: [
      '**Setup:** name the order, pick the branch, franchise and (optionally) a dealer group, and choose the months: Rolling 12/24/36, a full calendar year, or tick any months. Click a highlighted range again to clear it.',
      '**Review:** choose **Total** or **Avg / mo**, the factor, and optional minimum sales / minimum demands. The list updates as you change them. Untick anything you don’t want.',
      '**Create order:** the same review and save as above; the order is marked One-Time.',
    ], ref: 'steps2' },

    { h2: 'Rules' },
    { p: 'The rules that drive every suggestion (how much history to look at, how much to stock). Anyone in the test group can change them, and the page shows who last changed each rule and when. Section 4 explains them.' },
    { p: '**Try it** lets you test a change before saving it: click **Edit** on a rule, change a number, and the panel shows a branch before and after: order lines, total value, status counts and the parts that change most. Nothing is saved until you click **Save rule**. If you leave with unsaved changes, it asks first.' },

    { h2: 'Cleanup' },
    { p: 'Parts with an **Equip minimum that the tool is ignoring** because the part had no sales in the rule’s history window. These minimums would otherwise tie up stock in parts nobody buys. The list shows each one’s minimum, on hand, cost, the stock value the minimum would commit (minimum × cost) and what it **would order** today. Export it to work through in Equip.' },

    { h2: 'App Settings' },
    { p: 'Your own default branch and franchise (saved in your browser only). Reorder, One-Time Order and Part Lookup open on them.' },

    { h1: '3. How the suggested order is worked out' },
    { p: 'For each part at each branch, every morning and again in the tool whenever you change a rule or setting:' },
    { steps: [
      '**Pick the rule** that applies to the part (section 4).',
      '**Add up demand** over the rule’s **history months**: units sold, or the number of requests if the rule says so. Full months only; the current month isn’t finished, so it’s left out. Returns are netted off, and a total below 0 counts as 0.',
      '**Count active months:** how many of those months had any demand.',
      '**Monthly rate** = total demand ÷ history months. A part that sold 12 in 12 months has a rate of 1 a month, whether the sales came in one month or twelve.',
      '**Rule target.** If the part had demand in at least the rule’s **min active months**, the target is the monthly rate turned into the rule’s **weeks of cover**, rounded up: **rate × weeks × 12 ÷ 52**. Otherwise the rule target is 0 (the rule doesn’t stock it).',
      '**Minimum.** The part’s own **min override** (Part page) always applies. If there isn’t one, the **Equip minimum** applies, but only if the part had some demand in the history window; with no demand at all it is ignored and listed on Cleanup.',
      '**Target** = the larger of the rule target and the minimum (rounded up).',
      '**Suggested order** = target − on hand − on order, never below 0. On hand and on order count whole units. A masked part always gets 0.',
    ], ref: 'steps3' },
    { h3: 'Worked example' },
    { p: 'Branch 1, part **124184** (Mobil 1 0W20 motor oil), Default rule (12 months, 3 active months, 6 weeks):' },
    { table: [
      ['Step', 'Working', 'Result'],
      ['Demand', '170 sold in the last 12 full months, in 8 different months', '170'],
      ['Monthly rate', '170 ÷ 12', '14.17 a month'],
      ['Active months', '8 is at least 3, so the rule stocks it', 'stocked'],
      ['Rule target', '14.17 × 6 × 12 ÷ 52 = 19.6, rounded up', '20'],
      ['Minimum', 'none set', '–'],
      ['Order', '20 target − 1 on hand − 0 on order', '**19**'],
    ], widths: w(0.2, 0.6, 0.2) },
    { p: 'And a minimum at work: Branch 1, part **09-1785273** sold 4, all in one month, so the rule alone doesn’t stock it (1 active month is fewer than 3). With a min override of 5 set on its Part page, the target is 5 and, with none on hand, the order is 5.' },

    { h3: 'Status' },
    { table: [
      ['Status', 'Meaning'],
      ['Out of stock', 'An order is suggested and there is none on hand.'],
      ['Reorder', 'An order is suggested; some stock is on hand.'],
      ['Stocked', 'The part is stocked and there’s enough; no order needed.'],
      ['Not stocked', 'It had some demand, but not enough active months for the rule, and no minimum.'],
      ['No recent activity', 'No demand at all in the history window.'],
      ['Masked', 'Someone masked it on its Part page; no order.'],
    ], widths: w(0.25, 0.75) },
    { h3: 'Other numbers you’ll see' },
    { bullets: [
      '**Surplus** = on hand above that branch’s target. Shown under "Other branches" and in the row detail, so you can ask for a transfer instead of buying.',
      '**Inbound** = transfers on their way to this branch. Shown for information; they do **not** reduce the suggested order.',
      '**Est. value** = suggested order × cost.',
      '**"Changed"** marks a part whose number differs from this morning’s because someone changed a rule or a part setting since.',
    ] },

    { h1: '4. Rules' },
    { p: 'Each rule says how to work out the target for the parts it covers. A rule can be narrowed to a **franchise**, a **dealer group code** and/or a **branch** (blank means any), and limited to a **season** (start and end month; 11 to 2 means November to February). Only **active** rules are used.' },
    { h3: 'Which rule a part uses' },
    { steps: [
      'Of the active, in-season rules that fit the part, the **highest priority** wins.',
      'On a tie, the **more specific** rule wins (more of franchise, dealer group and branch filled in).',
      'Then the lowest rule number.',
      'If none fits, the built-in default applies: 12 months, 3 active months, 6 weeks, units sold.',
    ], ref: 'steps4' },
    { table: [
      ['Setting', 'What it does', 'Higher means…', 'Lower means…'],
      ['History months (1–59)', 'How far back demand is measured', 'Smoother; slow parts get more history', 'Reacts faster to recent changes'],
      ['Min active months (0–59)', 'Months with demand needed before the rule stocks a part', 'Fewer, steadier parts stocked', 'More occasional sellers stocked'],
      ['Weeks of cover (0–104)', 'How much stock to hold', 'More stock (long lead times, busy season)', 'Less stock (quick resupply, off season)'],
      ['Demand basis', '**UnitsSold** counts quantities; **Requests** counts how often it was asked for', 'Use Requests when a few big sales would overstate demand', ''],
    ], widths: w(0.22, 0.3, 0.24, 0.24) },
    { p: '**Example: cotton.** Two example rules exist for dealer group COTTON, switched off: "Cotton - in season" (June–October, 10 weeks of cover, 2 active months) and "Cotton - off season" (November–May, 3 weeks). Both have priority 10, so they beat Default for cotton parts. Try them in **Try it** before switching them on. Dealer group codes are set per branch in Equip, so a part may be COTTON at one branch and not another.' },
    { p: 'A rule with a missing or out-of-range setting is shown as **Skipped** with the reason, and isn’t used. A rule that is active but out of season shows **Not used this month**.' },

    { h1: '5. One-Time Order: the calculation' },
    { steps: [
      '**Units sold** are added up over the months you picked (a net total below 0 counts as 0).',
      '**Total:** anticipated = units sold × loading factor. **Avg / mo:** anticipated = (units sold ÷ number of months) × months of cover. (With Avg / mo the factor is labelled **Months of cover**.)',
      '**Order** = anticipated, rounded up, − on hand − on order, never below 0.',
      'Parts below **minimum sales** (units sold) or **minimum demands** (requests), both over the chosen months, are left off. 0 means no filter.',
      'Only parts with an order above 0 are listed. Masked parts are listed but start unticked; tick them yourself if you want them.',
    ], ref: 'steps5' },
    { table: [
      ['Example', 'Working', 'Order'],
      ['Total, factor 1.5', '20 sold in 12 months × 1.5 = 30; 30 − 10 on hand', '**20**'],
      ['Avg / mo, 3 months of cover', '24 sold in 12 months = 2 a month × 3 = 6; 6 − 1 on hand', '**5**'],
    ], widths: w(0.28, 0.54, 0.18) },

    { h1: '6. Cleanup: the numbers' },
    { bullets: [
      '**Listed:** parts with an Equip minimum above 0, no min override, and **no demand at all** in the rule’s history window, as of this morning’s snapshot.',
      '**Minimum value** = Equip minimum × cost: the stock value that minimum would commit.',
      '**Would order** = Equip minimum (rounded up) − on hand − on order, never below 0, × cost: what the minimum would make you buy today if it were used.',
    ] },
    { p: 'To keep a listed part stocked anyway, set a min override on its Part page. To stop it appearing, clean up the minimum in Equip.' },

    { h1: '7. During the test' },
    { bullets: [
      'This is a test copy on a test server; the address and the certificate warning will change for the real version.',
      'Orders and settings you save are real (they go into the SharePoint lists), but nothing is sent to a vendor; you download the CSV and use it yourself.',
      'Please note anything confusing, missing or wrong, even small wording, in the **Anything else** box of the questions document, or email Brian.',
    ] },
  ],
});
