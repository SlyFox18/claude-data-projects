# Non-JD Parts Order Tool: questions for Ben (and Shannon)

**Updated 2026-10-26 after Ben's answers (round 1, app version 0.2.0).** Ben answered Parts 1 and 2 on
2026-10-23 (his words: `feedback/2026-10-23-ben-answers.md`). Each answered item below gives his answer in one
line and what we did. Part 3 (Shannon) is still open, and Part 4 holds the new questions that came out of
round 1. The short summary for Ben is the **Round 1 changes** document (`for-users/round1.js`).

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
  expiry or the next demand, whichever is first; new **Special statuses** page. Phase-in joins it in round 2.

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
- Not yet: planned for round 2.

**Q3. Transfers.** *Answered.*
- Ben: a transfer step before working the order, with its own rules page; two kinds, stock order transfers
  and redistribution.
- Not yet: planned for round 2 (questions in Part 4).

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
- Not yet: planned for round 2.

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

**N4. For round 2.**
- Transfers: is "excess = more than 12 months of supply at the sending branch" the right default? For
  redistribution, what should a receiving branch's default limit be (months of supply)?
- Several branches: when several branches are picked, is the order still one per branch and franchise?
- Phase-in: set on the part's Settings tab with a quantity and an end date (default 12 months from today)?

---

*Rewritten 2026-10-22 for the web app walkthrough; updated 2026-10-26 with Ben's round 1 answers. The
original June questions (1–18) for the Power App are folded in above.*
