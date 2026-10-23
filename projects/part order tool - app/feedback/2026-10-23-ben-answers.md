# Ben's answers to the questions document (2026-10-23)

Received by Brian on 2026-10-23 after Ben tried the test app. Item numbers match `for-users/Non-JD Order Tool - Questions.docx`. Ben's words are kept as written; the **Reading** lines are our interpretation, to confirm where marked.

> This is really good. The core of this is very close already. I wrote a lot down. Most is not because of what needs to be changed but what needs to be added. Some for now, some for future functionality, and some as a dream of what it could turn into down the road. — Ben

## C1. The Default rule's numbers
- Instead of "A part needs sales in at least 3 of those months for the rule to stock it." We need to go off of demands. Demands is the number of transactions that happen on a part number independent of how many are sold at that time. A rule needs to be able to be changed based on a minimum of demands in the number of history months selected. Is that "requests" in the Demand Basis field? Default should be 3 demands in the 12 full months.
- Can you change the language from "weeks of cover" to "weeks of supply" so it aligns with John Deere language?
- Default weeks of supply should be 12 weeks.

**Reading:** yes, demands = `RequestCount` in the sales history (transactions per month, independent of quantity). Replace "min active months" (months with any demand) with "minimum demands" (total transactions in the window), default 3 in 12 months. Rename "weeks of cover" to "weeks of supply" everywhere. Default rule to 12 weeks.

## C2. Parts with little or no recent demand
See demand criteria on question C1.

## C3. Masking
I don't see where to mask a part on the order. The first two sentences is how masking should work. The only difference is masking will fall off of a part if it has a demand after it has been masked and then would showing up on the suggested order again. A part that has been put on "Manual Order" would work like you were saying where it would never show up on order until someone changes it from Manual Order. Also, it would be good to see a report of all of the parts that are Masked, Phase In, Manual Order, etc. on the menu bar.

**Reading:** (1) mask a part from Recommended Reorder / the order review, not only its Part page; (2) a mask ends at its expiry date **or** at the first demand after it was set; (3) new "Manual Order" status: never suggested until someone changes it; (4) a menu page listing every part with a special status (Masked, Phase-In, Manual Order).

## C4. One-Time Order: "Avg / mo"
The factor should be included in the Recommended Reorder Rules also. That is how Months of Supply should work.

**Reading (to confirm):** rules can express supply in months as well as weeks ("months of supply" = monthly rate × N), like the One-Time Order's months of cover.

## C5. One-Time Order: minimum sales and minimum demands
The factor would be applied to the Sales that the report generates. I think it is currently working correctly.

**Reading:** keep as built.

## C6. One-Time Order: masked parts
I don't see the masked but I think it would be best to leave them off altogether.

**Reading:** leave masked (and Manual Order) parts off One-Time Orders.

## C7. A target of 0 but negative stock
Go with the proposed. The negative on order is something I have written down for a future query in our new shared report folder.

**Reading:** a target of 0 always means order 0 (Gold, the reference check and the app together).

## C8. Orders
I think that's good.

## Q1. Which branches belong in the tool?
- Leave off Branch 12, 5, 97, 4b, and 93c.
- We will include John Deere parts once we've refined the Parts Order tool and have used it for a bit. There will be more fields needed in the rules for Deere as well as more advanced calculations.

## Q2. Several branches at once
It would be nice to be able to have a checkbox where you could select multiple individual branches and franchises.

## Q3. Transfers
That is how it should work. The transfers, however, need to be a step in the Recommended Reorder and One Time Order Wizard before you work the recommended order. This is so that you can select the desired transfers and the recommended order would recalculate. We need a separate rules page for transfer rules. These rules should still have the ability to set by different descriptive criteria such as Franchise, Group Code, SLC, Source, Commodity Code, etc. The numeric rules would need to be set by Months or Weeks of Supply. These rules need to address 2 different kinds of transfers. In a conventional stock order transfer, a location has a part that hits recommended order criteria. At this point it will look to see if another store has Excess inventory and will try to fulfill all or part of its stocking requirements. Default excess inventory is greater than 12 month supply but is a transfer rule that we need to be able to change. The second type of transfer is Redistribution. Redistribution Transfers are proactively moving inventory around even when there is not a part that needs a stocking requirement fulfilled. This will still go off of the same Excess Inventory Rules for the sending location. The difference is that the receiving location will have a rule that can be set where it will only receive up to a certain number of Months of Supply. Another way of describing this is, a Redistribution Transfer is initiated by the sending store when their months of supply gets to high to a receiving store that could stock more even though it is higher than their normal month of supply requirements. Both transfers are recommended daily with the Recommended Order.

## Q4. Deleting rules
Maybe be able to hide or archive rules instead of delete rules with a toggle that allows you to see hidden rules/archived rules or not.

## Q5. Equip minimums
We will have to cleanup Equip minimums ourselves. The minimum should override the demand minimum. We will catch it when working the orders.

**Reading (to confirm the size of it):** the Equip minimum applies even when the part had no demand (reverts the 2026-10-21 change). Cleanup stays as the list of minimums on parts with no demand.

## Q6. Trend and spiking
Non-Spiking will probably only apply to Deere parts because of the nature of how and when we have to place non-deere parts orders. I will get you the criteria for spiking parts but the idea of it is for parts that the majority of the R12 sales happen within a small time period. For Example: 75% of sales in 3 months of the year. It would, therefore, not recommend as many of those parts in the off months when the majority of the demands are not occurring. And it would recommend a larger amount than normal during those higher months. The other part of spiking parts is there is a ramp up period. For Example: if 75% of demands is happing in the months of August, September, and October the system will recommend to order in July to make sure you have enough time before your demands occur.

## Q7. Pre-approved rule and EOQ
- Pre-Approved will probably not be used at all for order generation in this Parts Order Tool. It is designed in Prism where if a part meets a set of demand and sales rules, it will automatically place an order for these parts without us seeing them at all on our order. As we get closer to making a more robust Parts Ordering Tool that includes John Deere parts, I could see Pre-Approved being an interesting report to make sure John Deere's rules are working correctly in Prism.
- EOQ stands for Economic Order Qty. This will only be used once we add Deere parts to the Parts Order Tool. An EOQ demand threshold can be set. If a part meets this threshold, the EOQ will try to stock 12 weeks of supply than the default 4 weeks of supply set in Prism. This would then raise the recommended order quantity. This is designed for fast moving parts with a lot of demand history.

## Q8. Phase-in
This is something that could be useful for both. Phase-In is just the reverse of masking. It is when we don't have enough history on a part but want to start bringing it in. A date can be set for when the Phase-In falls off. The default date is 12 months. A Phase in qty must also be set. If a part has enough history to meet normal stocking criteria while the Phase-In is active, the Phase-In will fall off and the normal stocking criteria will apply.

## Q9. Reorder code filter
I don't think so.

## Q10. Minimum order value
Minimum Value and Maximum value should be option available in the Rules and in the One-Time Order set up.

**Reading (to confirm):** per line (suggested qty × cost), not per order.

## Q11. Low margin
This is an interesting idea. I think with some changes we would eventually like to make in our Low Margin report, we would not need this as a part of the Parts Order Tool.

## Q12. History across branches
I think all branches should show by default on "Other Branches" instead of having to click "Check Every Branch". Then the combined totals/history could be added on a line at the bottom. Can you change "Surplus" to "Excess" to match Deere terminology?
