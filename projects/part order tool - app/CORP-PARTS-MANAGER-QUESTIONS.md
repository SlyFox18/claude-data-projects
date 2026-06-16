# Corp Parts Manager — Questions for Review
# Non-JD Parts Order Tool

Questions compiled during Power Apps V1 build. Answers will drive Phase 2 data changes
and refinements to the One Time Order wizard and recommendation logic.

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

*Last updated: 2026-06-03*
