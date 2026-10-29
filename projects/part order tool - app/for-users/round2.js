// Builds "Non-JD Order Tool - Round 2 changes.docx" for Ben, Shannon, Barry and Curt: one page summing up round 2
// (app 0.4.0 to 0.7.0, 2026-10-27 to 2026-10-29). Sources: nonjd-order-app README (Versions table), the round 2 spec
// (docs/superpowers/specs/2026-10-27-non-jd-parts-order-tool-round-2-design.md), Ben's transfer answers
// (../feedback/2026-10-27-ben-transfer-answers.md) and plans D to G. The detail is in the walkthrough (Part 2) and
// the user guide.
// Run: npm install, then node round2.js [output file]
const { build, CONTENT_W } = require('./lib');

const w = (...fr) => fr.map((f) => Math.round(CONTENT_W * f));

build(process.argv[2] || 'Non-JD Order Tool - Round 2 changes.docx', {
  title: 'Non-JD Parts Order Tool: round 2 changes',
  subtitle: 'For Ben, Shannon, Barry and Curt · Versions 0.4.0 to 0.7.0 · October 29, 2026 · App: https://10.110.100.13:8443',
  footer: 'Non-JD Parts Order Tool: round 2 changes',
  blocks: [
    { p: 'Round 2 built what Ben asked for in round 1 and in his transfer answers of October 27, plus a few requests from Barry and Brian. The **walkthrough** (Part 2) has hands-on steps for each version, and the **user guide** explains every page and number. Reply by email with anything that reads wrong or feels slow.' },

    { h1: 'What’s new' },
    { table: [
      ['What', 'Version', 'What it does'],
      ['Several branches at once', '0.4.0', '**Several branches…** on Recommended Reorder (One-Time Order had it in 0.3.0). A Branch column, **Totals by branch**, and one order per branch and franchise. Several dealer groups at once too (0.5.0, Barry).'],
      ['Phase-in', '0.5.0', 'Stock a new part before it has the demands its rule needs: a quantity and an end date on the part’s Settings tab. It ends at the end date, or once the part has the demands.'],
      ['Daily transfer suggestions', '0.5.0', 'Every morning the tool suggests stock another branch could send: **Conventional** (instead of buying) and **Redistribution** (extra stock to a branch that sells the part). They show in purple on Home and Recommended Reorder, and on a new **Transfers** page. **Excess** now means stock a branch could send (above the larger of its target and 12 months of supply); the old figure is **Above target**.'],
      ['Saving transfers and transfer orders', '0.6.0', 'Recommended Reorder is two steps, **1 Transfers → 2 Order**. Tick the transfers you want and **Save**: each sending and receiving pair becomes one **transfer order**, and the order on step 2 counts it. A transfer order is **Exported** as a CSV, keyed into Equip and marked **Entered in Equip**, or **Cancelled** to release the stock. The Transfers page saves too, and opens on **Transfer orders** (0.6.2, Ben).'],
      ['Transfer rules, with Try it', '0.6.0', 'A **Transfer rules** page next to Rules. Change what a branch keeps before stock is excess (12 months), whether it sends or receives, and how much redistribution it takes (6 months), for a franchise, branch or other criteria. **Try it** shows the effect on every branch before you save. See **TRANSFER-RULES.md**.'],
      ['One-Time Order transfers', '0.7.0', 'Ben’s question: “do the transfers apply to the One-Time Orders as well?” Now they do. One-Time Order is **Set up order → Transfers → Review & calculate**. The Transfers step suggests conventional transfers from other branches’ spare stock for the order’s lines; saved ones come off the quantity, and a line they cover fully is never ordered.'],
    ], widths: w(0.22, 0.1, 0.68) },

    { h2: 'Smaller things' },
    { bullets: [
      '**Archive orders** (0.5.2): hide test orders or ones placed long ago. Nothing is deleted; **Show archived** brings them back.',
      '**Export together** (0.5.1, Barry): download several orders as one CSV, one line per branch or a total per part, one file per franchise or one for everything.',
      '**Search on the transfer step and a footer that stays put** (0.6.1): the part search filters the transfers too, and the footer with its **Save** stays at the bottom of the window.',
      '**Coloured status pills** on Transfer orders (0.6.1): Draft amber, Exported blue, Entered in Equip green, Cancelled grey.',
      '**More rule criteria** (0.5.0): SLC, Source, Vendor code, Product group and Commodity code, for order rules and transfer rules.',
      '**No lost ticks** (0.5.0): leaving a page with ticked parts or unsaved transfers asks first.',
    ] },

    { h2: 'Questions' },
    { p: 'Nothing is open. **N2** (the “Show minimums with no demand” switch) stays **off** by default for now (Brian, October 29). **S1** (the CSV layout per vendor) and **N5** (non-JD price changes) are parked for later. Other ideas are on the future ideas list.' },

  ],
}).catch((e) => {
  console.error(e);
  process.exit(1);
});
