# Non-JD Parts Order Tool: questions for Ben (and Shannon)

**Updated 2026-10-28 for round 2 (app version 0.5.0).** Ben answered Parts 1 and 2 on 2026-10-23 (his
words: `feedback/2026-10-23-ben-answers.md`) and the transfer questions (Part 5) on 2026-10-27
(`feedback/2026-10-27-ben-transfer-answers.md`). Each answered item below gives his answer in one line and what
we did. Still open: Part 3 (Shannon), N1–N3 and N5. The short summary of round 1 is the **Round 1 changes**
document (`for-users/round1.js`); what's new since is in the walkthrough's "What's new" part.

How the numbers are worked out is explained step by step in **How the order tool suggests quantities**
(REORDER-RULES.md) and the user guide.

---

## Part 1: confirm or change (answered)

**C1. The Default rule's numbers.** *Answered.*
- Ben: stock on demands (transactions), not active months; Default 3 demands in 12 months; say "weeks of
  supply"; Default 12 weeks.
- Done: rules have **Min demands**; Default is 12 months / 3 demands / 12 weeks of supply; "cover" is now
  "supply" everywhere.

**C2. Parts with little or no recent demand.** *Answered.*
- Ben: see C1.
- Done: fewer demands than the rule needs means the rule doesn't stock the part; an Equip minimum still
  applies (Q5).

**C3. Masking.** *Answered.*
- Ben: mask from the order; a mask ends at the next demand; add Manual Order; a page of special statuses.
- Done: Mask… and Manual order on each Recommended Reorder line and in the order review; a mask ends at its
  expiry or the next demand, whichever is first; new **Special statuses** page. Phase-in joined it in 0.5.0.

**C4. One-Time Order, "Avg / mo".** *Answered.*
- Ben: keep it, and put months of supply in the rules too.
- Done: the factor is labelled **Months of supply**; each rule's supply can be in weeks or months.

**C5. One-Time Order, minimum sales and minimum demands.** *Answered.*
- Ben: working correctly.
- No change.

**C6. One-Time Order, masked parts.** *Answered.*
- Ben: leave them off altogether.
- Done: masked and Manual order parts are left off One-Time Orders.

**C7. A target of 0 but negative stock.** *Answered.*
- Ben: go with the proposed.
- Done: a target of 0 always means order 0.

**C8. Orders.** *Answered.*
- Ben: good.
- No change.

---

## Part 2: open questions (answered)

**Q1. Which branches belong in the tool?** *Answered.*
- Ben: leave off 12, 5, 97, 4B and 93C; John Deere parts later.
- Done: those five are left out of every page. John Deere parts: later.

**Q2. Several branches at once.** *Answered.*
- Ben: a checkbox to pick several branches and franchises.
- Done: One-Time Order (0.3.0) and Recommended Reorder (0.4.0) take several branches and franchises; 0.5.0 adds
  several dealer groups. One order per branch and franchise.

**Q3. Transfers.** *Answered.*
- Ben: a transfer step before working the order, with its own rules page; two kinds, stock order transfers
  and redistribution.
- Partly done (0.5.0): both kinds are suggested every morning and shown on Home, Recommended Reorder and a new
  **Transfers** page, keyed into Equip by hand. Ticking and saving transfers, and a transfer rules page, come
  next. Ben's answers are in Part 5.

**Q4. Deleting rules.** *Answered.*
- Ben: archive instead, with a toggle to see archived rules.
- Done: Archive / Unarchive and a **Show archived** switch on the Rules page.

**Q5. Equip minimums.** *Answered.*
- Ben: the Equip minimum overrides the demand minimum; we will clean them up ourselves.
- Done: the Equip minimum always applies. Lines with no demand are tagged **Min, no demand** and hidden
  behind a switch, off by default (Part 4, N2). Cleanup lists them.

**Q6. Trend and spiking.** *Answered.*
- Ben: spiking applies to Deere parts; criteria to come.
- Later: with John Deere parts.

**Q7. Pre-approved rule and EOQ.** *Answered.*
- Ben: neither is used until Deere parts join.
- Later: with John Deere parts.

**Q8. Phase-in.** *Answered.*
- Ben: useful; the reverse of masking, with an end date (default 12 months) and a quantity.
- Done (0.5.0): **Phase in…** on the Settings tab and in the Recommended Reorder row detail. The target is at
  least the quantity until the end date, or until the part has the demands its rule needs. Listed on Special
  statuses.

**Q9. Reorder code filter.** *Answered.*
- Ben: no.
- No change.

**Q10. Minimum order value.** *Answered.*
- Ben: min and max value in the rules and in One-Time Order setup.
- Done: **Min line value** and **Max line value**, per line (quantity × cost), in rules and One-Time Order.

**Q11. Low margin.** *Answered.*
- Ben: not needed here; the Low Margin report will cover it.
- No change.

**Q12. History across branches.** *Answered.*
- Ben: show all branches by default with a totals line; say "Excess", not "Surplus".
- Done: Other branches loads every branch, this one included, with a Total row; "Excess" everywhere.

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

## Part 4: new questions after round 1

**N1. Units sold with no demand recorded.** 973 parts show units sold in the last 12 months but no demands
recorded in Equip. Example: Branch 1, part 11234 (single tine bearing) sold 6 with 0 demands, so the Default
rule (3 demands) doesn't stock it. Why would Equip record a sale with no demand? Should those sales count as
demands?

**N2. The "Show minimums with no demand" switch.** It is off when Recommended Reorder opens, so lines that are
there only because of an Equip minimum on a part with no activity are hidden, and Home doesn't count them
(Branch 1 on 2026-10-26: 220 parts to order, plus 21 hidden). Is off the right starting point?

**N3. Sub-branches.** 11S, 13I, 13S, 14S, 15I, 15S, 16S, 1I, 1S, 2C, 3C, 3S, 4C, 4I, 4S, 6C, 6I, 7C, 8C, 8I, 8S,
91I and 95I stay in the tool. None has a non-JD part with a cost today. Should any be left out like 4B and 93C?

**N4. For round 2.** *Answered.*
- Transfers: Ben confirmed 12 months and 6 months (Part 5, T1 and T4).
- Several branches: built as one order per branch and franchise (0.4.0). Tell us if that's wrong.
- Phase-in: Ben confirmed (T7); built as asked.

**N5. Non-JD price changes (for a later round).** How do non-JD part prices change today? Who updates cost and
sell price in Equip, how often, and does each vendor send a price file? When JD parts join the tool, we'd like to
show a part's price change history (we already keep it for JD parts). Would the same be useful for non-JD parts,
and is there a source we could read it from?

---

## Part 5: transfers and phase-in (answered)

Brian emailed Ben seven questions on 2026-10-27, each with the default we planned to build. Ben's words are in
`feedback/2026-10-27-ben-transfer-answers.md`. Built in 0.5.0 (suggestions shown; saving transfers comes next).

**T1. Extra stock.** *Answered.*
- Ben: correct (above 12 months of supply is extra; stock with no sales is all extra unless it has a minimum;
  committed stock never moves), and it must be a field the rules can change.
- Done: **ExcessSupply** on each transfer rule, default 12 months.

**T2. Transfer before buying.** *Answered.*
- Ben: correct (minimums with no sales don't pull transfers); if we decide not to transfer, the order goes back
  to the recommended quantity.
- Done: Min, no demand lines never pull a transfer (unless the part has an active phase-in). Unticking a
  transfer putting the order back comes with saving transfers.

**T3. Order of filling.** *Answered.*
- Ben: the branch with the greatest months of supply sends first; the one with the lowest receives first. No
  branch-pair rules; special cases are done by hand.
- Done: that order, re-picked after every line; no branch-pair rules.

**T4. Redistribution.** *Answered.*
- Ben: 6 months is good for now; no minimum dollar amount, but it must be a field the rules can change.
- Done: receive up to 6 months (**RedistMax**); **RedistMinValue** defaults to $0.

**T5. Saving.** *Answered.*
- Ben: keep sending and receiving branch pairs together; all franchises together with a franchise filter at
  the top; export and key into Equip by hand; both kinds start ticked, with an indicator of the kind.
- Done in 0.5.0: the Transfers page with a franchise filter and a **Conventional / Redistribution** badge on
  every line, CSV export. Next version: one saved transfer per branch pair, both kinds ticked.

**T6. Wording.** *Answered.*
- Ben: keep "Excess", meaning months of supply over the threshold in T1, to match John Deere.
- Done: **Excess** has that meaning; round 1's figure is now **Above target**. Excess shows in units and months.

**T7. Phase-in.** *Answered.*
- Ben: correct.
- Done: see Q8.

---

*Rewritten 2026-10-22 for the web app walkthrough; updated 2026-10-26 with Ben's round 1 answers and 2026-10-28 with his transfer answers. The
original June questions (1–18) for the Power App are folded in above.*
