// Builds "Non-JD Order Tool - Questions.docx". Source text: ../CORP-PARTS-MANAGER-QUESTIONS.md
// (keep the two in step). Run: npm install, then node questions.js
const { build } = require('./lib');

const A = { answer: true };

build('Non-JD Order Tool - Questions.docx', {
  title: 'Non-JD Parts Order Tool: questions',
  subtitle: 'For Ben, with a section for Shannon · October 2026 · App: https://10.110.100.13:8443',
  footer: 'Non-JD Parts Order Tool: questions',
  blocks: [
    { p: 'The new web app is ready for you to try. While building it we had to make some choices, and some questions only you can answer. Each item says what the app does today and the alternatives. Most are quick to change, so "change it to B" is a fine answer. Write your answers in the spaces, or reply by email with the item numbers.' },
    { p: 'How the numbers are worked out is explained step by step in the **user guide** that came with this document.' },

    { h1: 'Part 1: confirm or change' },
    { p: 'The app already works this way.' },

    { h2: 'C1. The Default rule’s numbers' },
    { p: 'Every part uses the Default rule unless another rule fits it. Default looks at the last **12 full months** of units sold. A part needs sales in at least **3 of those months** for the rule to stock it. The rule then aims to keep about **6 weeks of cover**: the average monthly sales turned into 6 weeks’ worth, rounded up.' },
    { p: 'Are 12 / 3 / 6 the right starting numbers? You can change them yourself on the Rules page. Its **Try it** panel shows what a change would do to a branch before you save it.' },
    A,

    { h2: 'C2. Parts with little or no recent demand' },
    { bullets: [
      '**Sales in fewer than 3 of the last 12 months:** the rule itself suggests nothing. If Equip has a minimum on the part, the minimum still applies.',
      '**No sales at all in the 12 months:** the Equip minimum is ignored too, so long-inactive parts drop out of the suggestions. The minimums ignored this way are listed on the **Cleanup** page.',
    ] },
    { p: 'This replaces the old 60-month average and the "no activity" cutoff questions. You can change the months per rule on the Rules page, or set a part’s own minimum on its Settings tab.' },
    A,

    { h2: 'C3. Masking' },
    { p: 'A masked part gets no suggested order. With an expiry date, the mask lasts until the end of that day. With no date, it lasts until someone unmasks it.' },
    A,

    { h2: 'C4. One-Time Order: "Avg / mo"' },
    { p: '"Total" orders the whole period’s units sold. "Avg / mo" orders one month’s worth, multiplied by the factor, which is then labelled **Months of cover** (3 = three months’ worth), like PRISM’s "Use Monthly Average". On hand and on order are subtracted in both cases.' },
    { bullets: ['**Option B:** "Avg / mo" is only a display column, and the quantity always uses the total. This is how the old Power App worked.'] },
    A,

    { h2: 'C5. One-Time Order: minimum sales and minimum demands' },
    { p: 'Both compare the plain totals over the chosen months, before the factor. A part below either minimum is left off. Both start at 0 (no filter). What defaults would you like?' },
    { bullets: ['**Option B:** apply the factor before comparing.', '**Option C:** compare against the monthly average.'] },
    A,

    { h2: 'C6. One-Time Order: masked parts' },
    { p: 'Masked parts are listed and marked "Masked", but start **unticked**. "Select all" skips them, so each one has to be ticked by hand.' },
    { bullets: ['**Option B:** leave them off entirely.', '**Option C:** list them ticked like any other part.'] },
    A,

    { h2: 'C7. A target of 0 but negative stock' },
    { p: 'Found in testing. Today a part with a target of 0 still gets an order if Equip shows negative on hand or negative on order. Example: Branch 1, AM 9446, on order −1, so the tool suggests ordering 1 ($472.75) for a part with no recent demand.' },
    { p: '**Proposed:** a target of 0 always means order 0. Not changed yet.' },
    { bullets: ['**Option B:** keep it as it is (negative stock is "owed" and gets replaced).'] },
    A,

    { h2: 'C8. Orders' },
    { p: 'You tick parts on Recommended Reorder (or build a One-Time Order). The app saves **one order per franchise** and exports each one as a CSV file to use with that vendor’s ordering system. Direct submission can come later. Inbound transfers are shown on each part but don’t reduce the suggested quantity.' },
    A,

    { h1: 'Part 2: open questions' },

    { h2: 'Q1. Which branches belong in the tool?' },
    { p: 'Today every branch with non-JD parts is included.' },
    { bullets: [
      'Leave off Branch 12, the combine vault, which isn’t a physical store?',
      'Leave off Branches 5 and 97?',
      '4B and 93C are sub-branches. Show them on their own, or roll them into 4 and 93?',
    ] },
    A,

    { h2: 'Q2. Several branches at once' },
    { p: 'Today you work on one branch at a time, and an order is one branch and one franchise. Is it useful to see or order across several branches together (e.g. a region)? If so, how should orders be split?' },
    A,

    { h2: 'Q3. Transfers' },
    { bullets: [
      'A "Suggested transfers" page. Example: TY15949OZ needs reordering at one branch while another branch has surplus, so the tool could suggest moving it instead of buying it.',
      'Show pending transfers into the selected branch on Home.',
    ] },
    A,

    { h2: 'Q4. Deleting rules' },
    { p: 'Today a rule can only be switched off, so what was tried stays visible. Should users be able to delete rules?' },
    A,

    { h2: 'Q5. Equip minimums' },
    { p: 'The Cleanup page lists Equip minimums the tool ignores because the part had no demand. Are those minimums used in Equip or PRISM today? Who sets them, and should they be cleaned up in Equip?' },
    A,

    { h2: 'Q6. Trend and spiking' },
    { p: 'The app doesn’t adjust for trends or spikes yet. A part’s Settings tab has a "Force non-spiking" switch, which is saved but not used. How should a spiking part be recognised, and what should change for it? Is a trend adjustment (growing or shrinking sales) wanted?' },
    A,

    { h2: 'Q7. Pre-approved rule and EOQ' },
    { p: 'A part’s Settings tab can store a "Pre-approved rule" (free text for now) and an EOQ. The calculation uses neither. What are the real pre-approved rule choices, what should each one do, and should EOQ change the order quantity?' },
    A,

    { h2: 'Q8. Phase-in' },
    { p: 'PRISM’s One-Time Order has "Include Phase-In". Is it relevant to non-JD ordering?' },
    A,

    { h2: 'Q9. Reorder code filter' },
    { p: 'Should Recommended Reorder have a filter for reorder code (e.g. stocked "A" parts only)?' },
    A,

    { h2: 'Q10. Minimum order value' },
    { p: 'Should small suggestions be hidden, e.g. lines under $5?' },
    A,

    { h2: 'Q11. Low margin' },
    { p: 'Should non-JD parts get a low-margin flag, and what margin counts as low?' },
    A,

    { h2: 'Q12. History across branches' },
    { p: 'A part’s page shows stock at every branch (Other branches), but its sales history is for one branch only. Would a combined history across branches help?' },
    A,

    { h1: 'Part 3: for Shannon (order export)' },
    { h2: 'S1. The CSV file' },
    { p: 'Each order exports as a CSV file with the columns `PartNumber, Description, OrderQty, Cost, LineValue, Bin`, one file per order (per franchise).' },
    { bullets: [
      'Does each vendor’s ordering system accept a file like this, or does any need a different layout?',
      'The file starts with an invisible marker so Excel shows special characters correctly. Some import tools can’t read it, and it can be switched off.',
      'Part numbers are written exactly as stored. **Excel drops leading zeros** (00724214 shows as 724214) when it opens a CSV directly; the file itself keeps them. If that matters, the app could export an Excel file (.xlsx) instead.',
    ] },
    A,

    { h1: 'Anything else' },
    { p: 'Anything you expected to find and didn’t, wording that was confusing, or things that got in your way:', keepNext: true },
    { answer: 'Notes:', tall: true },
  ],
});
