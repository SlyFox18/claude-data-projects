// Builds "Non-JD Order Tool - User Guide.docx" for Ben, Shannon, Barry and Curt.
// Facts come from the app (nonjd-order-app 0.2.0: src/engine, README) and ../REORDER-RULES.md.
// Worked examples: Dev Gold Fact_NonJD_Reorder built 2026-10-26 (window Oct 2025 - Sep 2026).
// Run: npm install, then node guide.js [output file]
const { build, CONTENT_W } = require('./lib');

const w = (...fr) => fr.map((f) => Math.round(CONTENT_W * f));

build(process.argv[2] || 'Non-JD Order Tool - User Guide.docx', {
  title: 'Non-JD Parts Order Tool: user guide',
  subtitle: 'For Ben, Shannon, Barry and Curt · Version 0.2.0 (round 1) · October 2026 (test version) · https://10.110.100.13:8443',
  footer: 'Non-JD Parts Order Tool: user guide (version 0.2.0)',
  blocks: [
    { p: '**In one sentence:** the tool shows each branch which non-John Deere parts to reorder and why, lets you tune the rules behind those suggestions, and turns the parts you pick into an order file for each vendor.' },
    { p: 'This guide covers getting in, what each page does, and exactly how every number is worked out. Version 0.2.0 includes the changes from Ben’s answers (round 1). They are listed in the separate **Round 1 changes** document.' },

    { h1: '1. Getting started' },
    { steps: [
      'Open **https://10.110.100.13:8443** in Edge or Chrome on your PC.',
      'The first time, the browser warns "Your connection isn’t private". This test server uses its own certificate. Click **Advanced**, then **Continue to 10.110.100.13**. You only need to do this once.',
      'Sign in with your normal Microsoft (work) account. Only Ben, Shannon, Barry, Curt and Brian have access during the test.',
    ] },
    { p: 'Sign-in is shared by all your tabs and normally lasts until you close the browser. The sign-out button is next to your name at the bottom left. The version number is under **App Settings → About**.' },
    { h3: 'How fresh is the data?' },
    { p: 'The tool works from a snapshot of Equip taken in the morning: stock, sales history, open purchase orders and transfers. The date at the top right of every page says when it was taken. It turns **amber** when the data is more than one business day old. During this test the snapshot may be refreshed less often than daily, so check the date.' },
    { p: 'Your **rule** and **part setting** changes are different: they apply in the tool immediately, for everyone. The morning snapshot picks them up the next day.' },
    { p: 'Branches **12, 5, 97, 4B and 93C** are left out of the tool, as Ben asked.' },

    { h1: '2. The pages' },
    { p: 'The menu on the left takes you to each page. The branch you’re looking at shows at the top right.' },

    { h2: 'Home' },
    { p: 'Shows how many parts need ordering at your branch and what they would cost, with a **Review now** link straight to that list, plus a card for each page. Pick a different branch in the greeting line to look at another branch.' },
    { p: 'The count leaves out lines that are only there because of an Equip minimum on a part with no demand (see "Min, no demand" below). A small line says how many were left out, for example "(21 more with minimums but no demand)".' },

    { h2: 'Recommended Reorder' },
    { p: 'The main page: every part at the branch with the suggested order quantity.' },
    { bullets: [
      '**Branch and Franchise** pickers at the top. The page remembers them in the address, so a bookmark or a refresh keeps your view.',
      '**Reorder needed only** (on by default) shows just the parts to order (Out of stock and Reorder). Turn it off to see every part.',
      '**Show minimums with no demand** (off by default): see "Min, no demand" below.',
      '**Search** by part number or description.',
      '**Sort** by clicking a column heading; click again to reverse.',
      'Click the **arrow** at the left of a row to see **why** that quantity was suggested, in plain English. It also shows the rule used, any inbound transfers, other branches with excess stock, and the **Part actions** (below).',
      'Click a **part number** to open its Part page.',
    ] },
    { h3: 'Min, no demand' },
    { p: 'An Equip minimum always applies, even on a part nobody has asked for in the rule’s history months. Those lines carry a **Min, no demand** tag. They are hidden until you turn on **Show minimums with no demand**, and even then they are only ordered if you tick them. Many of these minimums are old or mistyped in Equip, so check them before ordering.' },
    { p: 'Example: Branch 1, part **408DU** (4x8 cross hydraulic cylinder). No demand in the last 12 months, Equip minimum 2, none on hand, cost $245.02. The tool suggests 2 ($490.04), tagged Min, no demand, and hidden until you turn the switch on.' },
    { h3: 'Part actions: Mask and Manual order' },
    { p: 'In the row detail, **Mask…** stops the tool suggesting the part, with an optional expiry date. **Manual order** stops it until someone turns it off. On a part that is already masked or on Manual order, the buttons are **Unmask** and **Clear manual**. Each one asks before saving, and the row updates straight away. The same buttons are on each line of the order review, and masking a line there takes it out of the order.' },
    { h3: 'Making an order from the suggestions' },
    { steps: [
      'Tick the parts you want (the box in the heading ticks every part listed by the current filter, on every page).',
      'The bar at the bottom shows how many are ticked and their value at cost. Ticked parts stay ticked when you search or sort. Changing the branch or franchise asks first, because it clears them.',
      'Click **Create order**. A review lists one order per franchise and every ticked part. Parts hidden by your current search are marked "Hidden by filter", so nothing is ordered by surprise.',
      'Change any quantity. A quantity of 0 leaves the line out.',
      'Save. The tool creates the order(s) and opens them.',
    ], ref: 'steps' },

    { h2: 'Part Lookup and the Part page' },
    { p: 'Search one branch, or **All branches** to find a part anywhere. The Part page has three tabs:' },
    { bullets: [
      '**Detail:** stock, prices, the suggested order and "Why this number", plus **Other branches** (below).',
      '**History:** a chart of the last 12 full months (switch between units sold and requests), a 60-month table and totals.',
      '**Settings:** this part’s own minimum, Manual order, a mask, and notes (below). Saving applies straight away for everyone.',
    ] },
    { h3: 'Other branches' },
    { p: 'Every branch loads by itself when the page opens. This branch is listed first, marked "(this branch)". The columns are **On hand**, **Target**, **Excess** and **Sold 12 mo**, and a **Total** row at the bottom adds up every branch, this one included. While branches are still loading, the totals end with "+".' },
    { p: '**Excess** = on hand above that branch’s target. Example: a branch with 10 on hand and a target of 4 has an excess of 6. A branch whose target is 0 counts all its stock as excess.' },
    { h3: 'Part settings' },
    { table: [
      ['Setting', 'What it does'],
      ['Min override', 'This part’s own minimum. The target is never below it, and it replaces the Equip minimum. Whole numbers only; blank means none. A min override of 0 switches off an Equip minimum you don’t trust.'],
      ['Manual order', 'The tool never suggests this part until someone turns it off. For parts you always order by hand.'],
      ['Masked', 'Stops the tool suggesting this part (order 0). The mask ends at the **first** of: the end of the expiry date, if you give one; or the next time the part is asked for (a demand after the day it was masked). A mask with no expiry date lasts until the part is asked for again or someone unmasks it.'],
      ['Notes', 'Free text for anyone looking at the part.'],
      ['EOQ, Force non-spiking, Pre-approved rule', 'Saved, but not used by the calculation yet (planned for when John Deere parts join).'],
    ], widths: w(0.24, 0.76) },
    { p: 'Example of a mask ending: a part masked on October 5 with no expiry is asked for on October 9. From the next morning’s snapshot the mask has ended and the part is suggested again if it needs ordering. Its Settings tab then reads "the mask ended when the part was requested on 2026-10-09".' },

    { h2: 'Special statuses' },
    { p: 'One list of every part with a special setting: **Masked**, **Manual order**, a **Min override**, or a **mask that has ended** (so someone can tidy it). It shows the branch, part, description, on hand, status, who set it and when, the expiry and the notes. Filter by status and branch, click a part to open it, and **Export CSV** for a spreadsheet. Phase-in will join this page in round 2.' },

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
      '**Setup:** name the order, pick the branch, franchise and (optionally) a dealer group, and choose the months: Rolling 12/24/36, a full calendar year, or tick any months. Click a highlighted range again to clear it. Optionally set a **Min line value** and **Max line value** in dollars (section 5).',
      '**Review:** choose **Total** or **Avg / mo**, the factor (called **Months of supply** with Avg / mo), and optional minimum sales / minimum demands. The list updates as you change them. Untick anything you don’t want.',
      '**Create order:** the same review and save as above; the order is marked One-Time.',
    ], ref: 'steps2' },
    { p: 'Masked and Manual order parts are left off One-Time Orders completely. The review says how many were left off.' },

    { h2: 'Rules' },
    { p: 'The rules that drive every suggestion (how much history to look at, how much to stock). Anyone in the test group can change them, and the page shows who last changed each rule and when. Section 4 explains them.' },
    { p: '**Try it** lets you test a change before saving it: click **Edit** on a rule, change a number, and the panel shows a branch before and after: order lines, total value, status counts and the parts that change most. Nothing is saved until you click **Save rule**. If you leave with unsaved changes, it asks first.' },
    { p: '**Archive** hides a rule you no longer use, instead of deleting it. Archived rules are never used. They are hidden unless **Show archived** is on; then they show greyed out, and **Unarchive** brings one back.' },

    { h2: 'Cleanup' },
    { p: 'Equip minimums on parts with **no demand and no units sold** in the rule’s history months: the same lines that carry the Min, no demand tag. These minimums **do** apply to the order, so this is the list to fix. The list shows each one’s minimum, on hand, cost, the stock value the minimum commits (minimum × cost) and what it **would order** today. Export it to work through in Equip.' },

    { h2: 'App Settings' },
    { p: 'Your own default branch and franchise (saved in your browser only). Reorder, One-Time Order and Part Lookup open on them. **About** shows the version.' },

    { h1: '3. How the suggested order is worked out' },
    { p: 'For each part at each branch, every morning and again in the tool whenever you change a rule or setting:' },
    { steps: [
      '**Pick the rule** that applies to the part (section 4).',
      '**Count demands** over the rule’s **history months**. A demand is one transaction (one request for the part), however many units it was for. Full months only; the current month isn’t finished, so it’s left out.',
      '**Add up units sold** over the same months (or the number of requests, if the rule says so). Returns are netted off, and a total below 0 counts as 0.',
      '**Monthly rate** = units sold ÷ history months. A part that sold 12 in 12 months has a rate of 1 a month, whether the sales came in one month or twelve.',
      '**Supply in months.** The rule’s supply is in weeks or months. Weeks are turned into months: **weeks × 12 ÷ 52**. So 12 weeks = 2.77 months.',
      '**Rule target.** If the part had at least the rule’s **min demands**, the rule target is **monthly rate × months of supply, rounded up**. Otherwise the rule target is 0 (the rule doesn’t stock it).',
      '**Minimum.** The part’s own **min override** (Part page) applies if set. If not, the **Equip minimum** applies, always, even with no demand.',
      '**Target** = the larger of the rule target and the minimum (rounded up).',
      '**Order** = target − on hand − on order, never below 0. On hand and on order count whole units. **A target of 0 always means order 0**, even when Equip shows negative stock.',
      '**Line value limits** (only if the rule has them): if the line is worth more than the **max line value**, the quantity is cut back to fit under it. Then, if the line is worth less than the **min line value**, nothing is suggested.',
      '**Manual order or masked:** the order is 0.',
    ], ref: 'steps3' },

    { h3: 'Worked example' },
    { p: 'Branch 1, part **124184** (Mobil 1 0W20 motor oil), Default rule (12 months, 3 demands, 12 weeks of supply). Dev data of October 26, 2026; the 12 months are October 2025 to September 2026.' },
    { table: [
      ['Step', 'Working', 'Result'],
      ['Demands', '22 transactions in the 12 months. 22 is at least 3, so the rule stocks it', 'stocked'],
      ['Units sold', '170 sold in the 12 months', '170'],
      ['Monthly rate', '170 ÷ 12', '14.17 a month'],
      ['Supply in months', '12 weeks × 12 ÷ 52', '2.77 months'],
      ['Rule target', '14.17 × 2.77 = 39.2, rounded up', '40'],
      ['Minimum', 'none set', '–'],
      ['Order', '40 target − 1 on hand − 0 on order', '**39** ($464.10 at $11.90)'],
    ], widths: w(0.2, 0.55, 0.25), keep: true },
    { p: 'A shortcut that gives the same answer with 12 months of history: units sold in the year × weeks ÷ 52 = 170 × 12 ÷ 52 = 39.2, rounded up to 40.' },
    { p: '**The same part with supply in months.** If the rule said **3 months** of supply instead: 14.17 × 3 = 42.5, rounded up to a target of 43, so the order is 43 − 1 = **42**.' },
    { p: '**Line value limits on the same part** (a rule with a max line value of $300 and a min line value of $50):', keepNext: true },
    { bullets: [
      'The order of 39 is worth 39 × $11.90 = $464.10, more than $300. The quantity is cut back to what $300 buys: $300 ÷ $11.90 = 25.2, rounded down to **25** ($297.50). That is still above the $50 minimum, so 25 is suggested, with a **Max value** badge.',
      'If there were 37 on hand, the line would be 40 − 37 = 3, worth $35.70. That is under the $50 minimum, so nothing is suggested (status **Below min value**).',
      'The cap is applied first, then the minimum.',
    ] },
    { p: '**Too few demands.** Branch 1, part **1426W** (26" wide neck row crop sweep) sold 30 units, but in only 2 transactions. 2 is fewer than 3, so the rule doesn’t stock it (**Not stocked**).' },
    { p: '**A minimum at work.** Branch 91, the same 1426W: 39 sold in 3 demands, so the rule target is 3.25 a month × 2.77 = 9. The Equip minimum is 12, so the target is 12. With 2 on hand the order is **10**. And at Branch 1, part **09-1785273** sold 4 in 1 demand, so the rule alone doesn’t stock it; a min override of 5 on its Part page makes the target 5 and, with none on hand, the order 5.' },

    { h3: 'Status' },
    { p: 'Each part gets the first status in this list that fits it:', keepNext: true },
    { table: [
      ['Status', 'Meaning'],
      ['Manual order', 'Someone set Manual order on the part; it is never suggested until that is turned off.'],
      ['Masked', 'Someone masked it, and the mask hasn’t ended; no order.'],
      ['No recent activity', 'The target is 0 and the part had no demands and no units sold in the history months.'],
      ['Not stocked', 'The part had some activity, but the target came out 0 (usually fewer demands than the rule needs) and there is no minimum.'],
      ['Below min value', 'An order was due, but the line is worth less than the rule’s min line value, so nothing is suggested.'],
      ['Above max value', 'An order was due, but one unit costs more than the rule’s max line value, so nothing is suggested.'],
      ['Out of stock', 'An order is suggested and there is none on hand.'],
      ['Reorder', 'An order is suggested; some stock is on hand.'],
      ['Stocked', 'The part is stocked and there’s enough; no order needed.'],
    ], widths: w(0.22, 0.78), keep: true },
    { p: 'Two badges can appear next to the status: **Max value** (the quantity was cut back to fit the max line value) and **Min value** (the line was under the min line value). The **Min, no demand** tag marks a line that is there only because of an Equip minimum on a part with no activity.' },
    { h3: 'Other numbers you’ll see' },
    { bullets: [
      '**Excess** = on hand above that branch’s target. Shown under "Other branches" and in the row detail, so you can ask for a transfer instead of buying.',
      '**Inbound** = transfers on their way to this branch. Shown for information; they do **not** reduce the suggested order.',
      '**Est. value** = suggested order × cost. Example: 39 × $11.90 = $464.10.',
      '**"Changed"** marks a part whose number differs from this morning’s because someone changed a rule or a part setting since.',
    ] },

    { h1: '4. Rules' },
    { p: 'Each rule says how to work out the target for the parts it covers. A rule can be narrowed to a **franchise**, a **dealer group code** and/or a **branch** (blank means any), and limited to a **season** (start and end month; 11 to 2 means November to February). Only **active** rules that aren’t **archived** are used.' },
    { h3: 'Which rule a part uses' },
    { steps: [
      'Of the active, in-season rules that fit the part, the **highest priority** wins.',
      'On a tie, the **more specific** rule wins (more of franchise, dealer group and branch filled in).',
      'Then the lowest rule number.',
      'If none fits, the built-in default applies: 12 months, 3 demands, 12 weeks of supply, units sold, no line value limits.',
    ], ref: 'steps4' },
    { table: [
      ['Setting', 'What it does', 'Higher means…', 'Lower means…'],
      ['History months (1–59)', 'How far back demand is measured', 'Smoother; slow parts get more history', 'Reacts faster to recent changes'],
      ['Min demands (0–9999)', 'Demands (transactions) in the history months needed before the rule stocks a part', 'Fewer, steadier parts stocked', 'More occasional sellers stocked'],
      ['Supply and Supply unit', 'How much stock to hold: 0–104 weeks or 0–24 months', 'More stock (long lead times, busy season)', 'Less stock (quick resupply, off season)'],
      ['Min line value ($, optional)', 'A line worth less than this isn’t suggested', 'Fewer small lines', 'More small lines'],
      ['Max line value ($, optional)', 'A line is cut back to stay at or under this', 'Bigger lines allowed', 'Lines cut back sooner'],
      ['Demand basis', '**UnitsSold** counts quantities; **Requests** counts how often it was asked for', 'Use Requests when a few big sales would overstate demand', ''],
    ], widths: w(0.22, 0.3, 0.24, 0.24), keep: true },
    { p: '**Example: cotton.** Two example rules exist for dealer group COTTON, switched off: "Cotton - in season" (June–October, 10 weeks of supply, 2 demands) and "Cotton - off season" (November–May, 3 weeks of supply, 3 demands). Both have priority 10, so they beat Default for cotton parts. Try them in **Try it** before switching them on. Dealer group codes are set per branch in Equip, so a part may be COTTON at one branch and not another.' },
    { p: 'A rule with a missing or out-of-range setting is shown as **Skipped** with the reason, and isn’t used. A rule that is active but out of season shows **Not used this month**.' },

    { h1: '5. One-Time Order: the calculation' },
    { steps: [
      '**Units sold** are added up over the months you picked (a net total below 0 counts as 0).',
      '**Total:** anticipated = units sold × loading factor. **Avg / mo:** anticipated = (units sold ÷ number of months) × **months of supply**.',
      '**Order** = anticipated, rounded up, − on hand − on order, never below 0.',
      '**Line value limits**, if you set them: a line worth more than the max is cut back to fit under it, then a line worth less than the min is dropped. The same as in a rule.',
      'Parts below **minimum sales** (units sold) or **minimum demands** (requests), both over the chosen months, are left off. 0 means no filter.',
      'Only parts with an order above 0 are listed. Masked and Manual order parts are never listed.',
    ], ref: 'steps5' },
    { table: [
      ['Example', 'Working', 'Order'],
      ['Total, factor 1.5', '20 sold in 12 months × 1.5 = 30; 30 − 10 on hand', '**20**'],
      ['Avg / mo, 3 months of supply', '24 sold in 12 months = 2 a month × 3 = 6; 6 − 1 on hand', '**5**'],
      ['Total, factor 1.5, max line value $100, cost $8', 'The order of 20 is worth $160, over $100. $100 ÷ $8 = 12.5, rounded down', '**12** ($96)'],
    ], widths: w(0.28, 0.54, 0.18), keep: true },

    { h1: '6. Cleanup: the numbers' },
    { bullets: [
      '**Listed:** parts with an Equip minimum above 0, no min override, and **no demands and no units sold** in the rule’s history months, as of this morning’s snapshot.',
      '**Minimum value** = Equip minimum × cost: the stock value that minimum commits. Example: 408DU, minimum 2 × $245.02 = $490.04.',
      '**Would order** = Equip minimum (rounded up) − on hand − on order, never below 0, × cost: what the minimum makes the tool suggest today.',
    ] },
    { p: 'To take a listed part off the order, fix the minimum in Equip, or set a min override of 0 on its Part page. To keep it stocked, leave it, or set the min override you want.' },

    { h1: '7. During the test' },
    { bullets: [
      'This is a test copy on a test server; the address and the certificate warning will change for the real version.',
      'Orders and settings you save are real (they go into the SharePoint lists), but nothing is sent to a vendor; you download the CSV and use it yourself.',
      'Please note anything confusing, missing or wrong, even small wording, in the **Anything else** box of the questions document, or send me an email.',
    ] },
  ],
});
