# Corp Parts Manager — Questions for Review
# Non-JD Parts Order Tool

Questions compiled during Power Apps V1 build. Answers will drive Phase 2 data changes
and refinements to the One Time Order wizard and recommendation logic.

---

## Web app: choices made for now (2026-10-21)

Ben was out, so these were decided to keep the build moving. Each is easy to change. For
each one, the alternatives are listed so Ben can pick.

**W1. One-Time Order, "Avg / mo".** Chosen: the method changes the order quantity.
"Total" orders the whole period's units sold; "Avg / mo" orders one month's worth (the
monthly average). Both are multiplied by the loading factor, then on hand and on order are
subtracted. With "Avg / mo" the factor is labelled "Months of cover" (3 = three months'
worth), like PRISM's "Use Monthly Average".
- **The one question for Ben:** with "Avg / mo", should the factor mean months of cover? If
  not, Option B applies.
- Option B: "Avg / mo" is only a display column, and the quantity always uses the total.
  This is how the old Power App worked.

**W2. One-Time Order, minimum sales and minimum demands.** Chosen: both compare the plain
totals over the chosen months, before the loading factor. A part below either minimum is
left off.
- Option B: apply the loading factor to the totals before comparing them. The old app did
  this for sales but not for demands.
- Option C: compare against the monthly average instead of the total.

**W3. One-Time Order, masked parts** (relates to question 11 below). Chosen: masked parts
are listed and marked "Masked", but start **unticked**, so they're only ordered if someone
ticks them. "Select all" skips masked parts too; each one has to be ticked by hand.
- Option B: leave masked parts off entirely.
- Option C: list them ticked like any other part.

**W4. Settings stored but not used yet.** EOQ, Force Non-Spiking and Pre-Approved Rule can
be saved on a part, but the calculation ignores them. Pre-Approved Rule is free text until
Ben gives the real choices (question 12 below).

**W6. Parts with no target but negative stock (found in testing 2026-10-22).** Today a part
whose target is 0 (no recent activity, or not stocked) still gets an order if Equip shows
negative on hand or negative on order. Example: Branch 1, AM 9446, on order −1, so the tool
suggests ordering 1 ($472.75) for a part with no recent demand. Proposed: a target of 0
always means order 0, and the part shows as no recent activity or not stocked, as it does
now. Not changed yet; waiting for Ben.
- Option B: keep it as is (negative stock is "owed" and gets replaced).

**W5. Order export (Shannon).** Each order exports as a CSV file. The file starts with an
invisible marker so Excel shows special characters correctly. Some vendor import tools
can't read that marker, and it can be switched off. Part numbers are written exactly as
stored. Excel drops leading zeros only when it opens a CSV directly.

---

## Stale Parts & Activity Thresholds

1. Parts with no activity for several years are still showing up in reorder recommendations
   because the system assigns a minimum stocking quantity of 1. What is the cutoff — how
   many months of no activity before a part should be excluded from recommendations?
   (e.g., no requests in last 24 months? 36 months?)

2. Should the exclusion be based on Date Last Requested, or on zero 12-month sales AND
   requests combined?

---

## ROP Calculation

3. The current calculation uses a 60-month demand average. For parts that had high volume
   3–5 years ago but are slow movers now, this inflates the recommendation significantly.
   Should a shorter window be used — and if so, how many months?

4. What is "Rule Level Minimum" in the JD system, and how is it calculated? Is it the
   matrix WarehouseMin, or something else?

5. What is "ROP Trend Effect" and how should it be applied to the recommendation?

6. How should "Spiking" be identified? When a part is flagged as spiking, what changes
   in the calculation?

---

## One Time Order Wizard

7. In the JD system, Step 1 has "Minimum Demands" and "Minimum Sales" filters. What
   thresholds make sense as defaults?

8. Should "Use Monthly Average" be available — meaning use the average of selected months
   rather than the sum? When would a parts manager use average vs. sum?

9. What does "Use Trending" mean operationally — when should it be applied and what does
   it change in the output?

10. What does "Include Phase-In" mean and is it relevant to your ordering process?

11. What Masking filter options are needed for One Time Orders?
    (All parts / Exclude masked / Masked only?)

---

## Settings Tab

12. What are the valid choices for the "Pre Approved Rule" dropdown, and what does each
    one mean operationally? (Currently set to "None" as a placeholder — needs real options.)

13. What does "Masking" mean in practice — does it completely hide a part from all
    recommendations, or just suppress it temporarily until the Masking Expiration date?

---

## Recommended Reorder Screen

14. Should there be a ReorderCode filter on the Recommended Reorder screen so managers
    can focus on stocked (A) vs. non-stocked parts separately?

15. Should there be a minimum order value threshold — for example, exclude recommended
    orders under $5 total estimated value?

---

## Low Margin Flag

16. Is there a plan to extend the Low Margin flag to non-JD parts? If so, what is the
    margin threshold that defines "low margin"?

---

## Export & Future Use

17. What format is needed for exporting the recommended reorder list — Excel download,
    or direct submission to the JD ordering system?

18. Would it be useful to see a part's history across all branches on the History tab,
    not just the currently selected branch?

---

*Last updated: 2026-10-21 (web app choices W1–W5 added)*
