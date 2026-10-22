# Non-JD Parts Order Tool: questions for Ben (and Shannon)

The new web app is ready for you to try. While building it we had to make some choices, and
some questions only you can answer. Each item says what the app does today and the
alternatives. Most are quick to change, so "change it to B" is a fine answer.

How the numbers are worked out is explained step by step in **How the order tool suggests
quantities** (REORDER-RULES.md) and the user guide.

---

## Part 1: confirm or change (the app already works this way)

**C1. The Default rule's numbers.** Every part uses the Default rule unless another rule
fits it. Default looks at the last **12 full months** of units sold. A part needs sales in
at least **3 of those months** for the rule to stock it. The rule then aims to keep about
**6 weeks of cover**: the average monthly sales turned into 6 weeks' worth, rounded up. Are 12 / 3 / 6 the right starting
numbers? You can change them yourself on the Rules page. Its **Try it** panel shows what a
change would do to a branch before you save it.

**C2. Parts with little or no recent demand.**
- **Sales in fewer than 3 of the last 12 months:** the rule itself suggests nothing. If
  Equip has a minimum on the part, the minimum still applies.
- **No sales at all in the 12 months:** the Equip minimum is ignored too, so long-inactive
  parts drop out of the suggestions. The minimums ignored this way are listed on the
  **Cleanup** page.

This replaces the old 60-month average and "no activity" cutoff questions.
- Change the number of months or active months per rule (Rules page), or set a part's own
  minimum on its Settings tab.

**C3. Masking.** A masked part gets no suggested order. With an expiry date, the mask lasts
until the end of that day. With no date, it lasts until someone unmasks it.

**C4. One-Time Order, "Avg / mo"** (old question 8). "Total" orders the whole period's
units sold. "Avg / mo" orders one month's worth, multiplied by the factor, which is then
labelled **Months of cover** (3 = three months' worth), like PRISM's "Use Monthly
Average". On hand and on order are subtracted in both cases.
- Option B: "Avg / mo" is only a display column, and the quantity always uses the total.
  This is how the old Power App worked.

**C5. One-Time Order, minimum sales and minimum demands** (old question 7). Both compare
the plain totals over the chosen months, before the factor. A part below either minimum is
left off. Both start at 0 (no filter). What defaults would you like?
- Option B: apply the factor before comparing.
- Option C: compare against the monthly average.

**C6. One-Time Order, masked parts** (old question 11). Masked parts are listed and marked
"Masked", but start **unticked**. "Select all" skips them, so each one has to be ticked by hand.
- Option B: leave them off entirely.
- Option C: list them ticked like any other part.

**C7. A target of 0 but negative stock** (found in testing). Today a part with a target of 0
still gets an order if Equip shows negative on hand or negative on order. Example: Branch 1,
AM 9446, on order −1, so the tool suggests ordering 1 ($472.75) for a part with no recent
demand. Proposed: a target of 0 always means order 0. Not changed yet.
- Option B: keep it (negative stock is "owed" and gets replaced).

**C8. Orders.** You tick parts on Recommended Reorder (or build a One-Time Order). The app
saves **one order per franchise** and exports each one as a CSV file to use with that
vendor's ordering system. Direct submission can come later. Inbound transfers are shown on
each part but don't reduce the suggested quantity.

---

## Part 2: open questions

**Q1. Which branches belong in the tool?** Today every branch with non-JD parts is included.
- Leave off Branch 12, the combine vault, which isn't a physical store?
- Leave off Branches 5 and 97?
- 4B and 93C are sub-branches. Show them on their own, or roll them into 4 and 93?

**Q2. Several branches at once.** Today you work on one branch at a time, and an order is
one branch and one franchise. Is it useful to see or order across several branches together
(e.g. a region)? If so, how should orders be split?

**Q3. Transfers.**
- A "Suggested transfers" page. Example: TY15949OZ needs reordering at one branch while
  another branch has surplus, so the tool could suggest moving it instead of buying it.
- Show pending transfers into the selected branch on Home.

**Q4. Deleting rules.** Today a rule can only be switched off, so what was tried stays
visible. Should users be able to delete rules?

**Q5. Equip minimums.** The Cleanup page lists Equip minimums the tool ignores because the
part had no demand. Are those minimums used in Equip or PRISM today? Who sets them, and
should they be cleaned up in Equip?

**Q6. Trend and spiking** (old questions 5, 6 and 9). The app doesn't adjust for trends or
spikes yet. A part's Settings tab has a "Force non-spiking" switch, which is saved but not
used. How should a spiking part be recognised, and what should change for it? Is a trend
adjustment (growing or shrinking sales) wanted?

**Q7. Pre-approved rule** (old question 12). A part's Settings tab can store a
"Pre-approved rule", as free text for now. The calculation doesn't use it, and the same goes
for EOQ. What are the real choices, and what should each one do?

**Q8. Phase-in** (old question 10). PRISM's One-Time Order has "Include Phase-In". Is it
relevant to non-JD ordering?

**Q9. Reorder code filter** (old question 14). Should Recommended Reorder have a filter
for reorder code (e.g. stocked "A" parts only)?

**Q10. Minimum order value** (old question 15). Should small suggestions be hidden, e.g.
lines under $5?

**Q11. Low margin** (old question 16). Should non-JD parts get a low-margin flag, and what
margin counts as low?

**Q12. History across branches** (old question 18). A part's page shows stock at every
branch (Other branches), but its sales history is for one branch only. Would a
combined history across branches help?

---

## Part 3: for Shannon (order export)

**S1. The CSV file.** Each order exports as a CSV with the columns
`PartNumber, Description, OrderQty, Cost, LineValue, Bin`, one file per order (per franchise).
- Does each vendor's ordering system accept a file like this, or does any need a different
  layout?
- The file starts with an invisible marker so Excel shows special characters correctly.
  Some import tools can't read it, and it can be switched off.
- Part numbers are written exactly as stored. **Excel drops leading zeros** (00724214
  shows as 724214) when it opens a CSV directly; the file itself keeps them. If that
  matters, the app could export an Excel file (.xlsx) instead.

---

*Rewritten 2026-10-22 for the web app walkthrough. The original June questions (1–18) for the
Power App are folded in above; question 4 ("Rule Level Minimum") is replaced by the rules list
and each part's own minimum.*
