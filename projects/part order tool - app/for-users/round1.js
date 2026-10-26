// Builds "Non-JD Order Tool - Round 1 changes.docx" for Ben: what changed from his answers of 2026-10-23.
// Sources: ../feedback/2026-10-23-ben-answers.md, ../feedback/2026-10-26-round1-impact.md,
// data-projects docs/superpowers/plans/2026-10-26-non-jd-parts-order-tool-round-1.md (D1-D14).
// Run: npm install, then node round1.js [output file]
const { build, CONTENT_W } = require('./lib');

const w = (...fr) => fr.map((f) => Math.round(CONTENT_W * f));
const DONE = '**Done.** ';
const R2 = '**Not yet: planned for round 2.** ';
const JD = '**Later: with John Deere parts.** ';
const SAME = '**No change.** ';

build(process.argv[2] || 'Non-JD Order Tool - Round 1 changes.docx', {
  title: 'Non-JD Parts Order Tool: round 1 changes',
  subtitle: 'For Ben (copy to Shannon, Barry and Curt) · Version 0.2.0 · October 26, 2026 · App: https://10.110.100.13:8443',
  footer: 'Non-JD Parts Order Tool: round 1 changes',
  blocks: [
    { p: 'Ben, thank you for the detailed answers. This page says what we did with each one. The user guide (version 0.2.0) explains every page and number in full, with worked examples.' },

    { h1: 'What changed from your answers' },
    { table: [
      ['Item', 'What you said', 'What we did'],
      ['C1', 'Stock on demands, not active months. Default 3 demands in 12 months. Say "weeks of supply". Default 12 weeks.', DONE + 'Rules now have **Min demands** (demands = transactions, however many units). Default: 3 demands in the last 12 full months, 12 weeks of supply. "Cover" is now "supply" everywhere.'],
      ['C2', 'See C1.', DONE + 'A part with fewer demands than the rule needs isn’t stocked by the rule. An Equip minimum still applies (Q5).'],
      ['C3', 'Mask from the order. A mask ends at the next demand. Add Manual Order. A page listing special statuses.', DONE + '**Mask…** and **Manual order** buttons on each Recommended Reorder line and in the order review. A mask ends at its expiry date or the next demand, whichever comes first. New **Special statuses** page (Phase-in joins it in round 2).'],
      ['C4', 'Months of supply in the rules too.', DONE + 'Each rule’s supply can be in **weeks or months**.'],
      ['C5', 'Working correctly.', SAME],
      ['C6', 'Leave masked parts off One-Time Orders.', DONE + 'Masked and Manual order parts are left off.'],
      ['C7', 'A target of 0 means order 0.', DONE],
      ['C8', 'Orders are good.', SAME],
      ['Q1', 'Leave off 12, 5, 97, 4B, 93C. John Deere parts later.', DONE + 'Those five branches are gone from every page. ' + JD],
      ['Q2', 'Pick several branches and franchises.', R2],
      ['Q3', 'Transfers as a step before the order, with their own rules (stock order and redistribution).', R2 + 'Your description is the starting point.'],
      ['Q4', 'Archive rules instead of deleting.', DONE + '**Archive** button and a **Show archived** switch on the Rules page.'],
      ['Q5', 'The Equip minimum overrides the demand minimum. We’ll clean them up.', DONE + 'The Equip minimum always applies. Those lines get a **Min, no demand** tag and are hidden until you turn on a switch (see the open questions). Cleanup lists them.'],
      ['Q6', 'Spiking is for Deere parts; criteria to come.', JD],
      ['Q7', 'Pre-approved and EOQ only with Deere parts.', JD],
      ['Q8', 'Phase-in is useful (reverse of masking).', R2],
      ['Q9', 'No reorder code filter.', SAME],
      ['Q10', 'Min and max value in rules and One-Time Order.', DONE + '**Min line value** and **Max line value**, per line, in rules and One-Time Order setup.'],
      ['Q11', 'Not needed (Low Margin report).', SAME],
      ['Q12', 'All branches on Other branches, with totals. Say "Excess".', DONE + 'Every branch loads by itself, this one included, with a **Total** row. "Surplus" is now **Excess**.'],
    ], widths: w(0.07, 0.36, 0.57) },

    { h1: 'What the changes do to the order' },
    { p: 'We recalculated the suggested order for every branch on the same day’s data (October 23), switching your changes on one at a time. Each step keeps the ones before it. **Lines** are parts with a suggested order; **$** is quantity × cost.' },
    { table: [
      ['Step', 'Lines', '$', 'Change'],
      ['1. The tool before round 1', '1,775', '$491,167', ''],
      ['2. Leave out 12, 5, 97, 4B, 93C', '1,775', '$491,167', 'none yet'],
      ['3. 3 demands instead of 3 active months', '2,336', '$604,904', '+561 lines, +$113,737'],
      ['4. A target of 0 means order 0', '2,171', '$587,923', '−165 lines, −$16,981'],
      ['5. Equip minimum always applies', '5,309', '$4,860,660', '+3,138 lines, +$4,272,737'],
      ['6. Default at 12 weeks of supply', '5,775', '$5,355,625', '+466 lines, +$494,965'],
    ], widths: w(0.4, 0.12, 0.18, 0.3), keep: true },
    { p: 'Step 5 is the big jump. Almost all of it is Equip minimums on parts with no activity in the 12 months: 3,120 lines worth $4,267,865. These are the **Min, no demand** lines. They are hidden on Recommended Reorder unless you turn the switch on, and never ordered unless ticked.' },
    { p: 'Six of them make up about $3.8 million of that $4.27 million. Several look like typing errors in Equip (a minimum far above anything the branch sells, or the price typed into the minimum). Fixing them in Equip, or a min override of 0 in the tool, takes the line off:' },
    { table: [
      ['Branch', 'Part', 'Description', 'Equip min', 'Cost', '$'],
      ['95', '990900100420702', '#2-2" FILL CAP', '50,241', '$41.82', '$2,101,079'],
      ['8', '00767891', 'COUPLING FLEX', '1,105', '$738.19', '$815,700'],
      ['4', 'WR-AR82561', 'ISO SELECTIVE CONTROL VALVE COMPLETE REM', '777', '$777.75', '$604,312'],
      ['3', '100025', 'ROTOR, LEFT 30\'/32 HEADER PICKUP', '78', '$1,499.90', '$116,992'],
      ['16', 'CTV-0505B', 'BLACK HOSE', '336', '$336.00', '$112,896'],
      ['4', 'VAWISO32', 'ISO 32 ANTI WARE FOR 9800 KP', '726', '$72.60', '$52,708'],
    ], widths: w(0.08, 0.18, 0.4, 0.1, 0.11, 0.13) },
    { p: '**$** = Equip minimum × cost, since none of them is on hand or on order. Example: 50,241 × $41.82 = $2,101,079. The full list is on the **Cleanup** page, with an export.' },

    { h1: 'Questions still open' },
    { h3: '1. Units sold with no demand recorded' },
    { p: '973 parts show units sold in the last 12 months but **no demands** recorded in Equip. Example: Branch 1, part 11234 (single tine bearing) sold 6 with 0 demands, so with 3 demands needed the Default rule doesn’t stock it. Why would Equip record a sale with no demand? Should those sales count as demands?' },
    { h3: '2. The "Show minimums with no demand" switch' },
    { p: 'It is **off** when you open Recommended Reorder, so the Min, no demand lines are hidden and Home doesn’t count them (Branch 1 today: 220 parts to order, plus 21 hidden). Is off the right starting point, or would you rather see them every time?' },
    { h3: '3. Sub-branches' },
    { p: 'These sub-branches stay in the tool: 11S, 13I, 13S, 14S, 15I, 15S, 16S, 1I, 1S, 2C, 3C, 3S, 4C, 4I, 4S, 6C, 6I, 7C, 8C, 8I, 8S, 91I and 95I. None has a non-JD part with a cost today, so they add nothing yet. Should any be left out like 4B and 93C?' },
    { h3: '4. For round 2' },
    { bullets: [
      '**Transfers:** is "excess = more than 12 months of supply at the sending branch" the right default? For redistribution, what should a receiving branch’s default limit be (in months of supply)?',
      '**Several branches:** when you pick several branches, should the order still be one per branch and franchise?',
      '**Phase-in:** set on the part’s Settings tab with a quantity and an end date (default 12 months from today). Is that right?',
    ] },

    { h1: 'How to give feedback' },
    { bullets: [
      'Reply by email with the item or question numbers, or write on the updated questions document.',
      'Small things count too: wording that reads wrong, a number you can’t explain, or a part you expected to see. The user guide shows where each change is in the app.',
    ] },
  ],
});
