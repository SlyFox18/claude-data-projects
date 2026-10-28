# Non-JD Parts Order Tool: future ideas

Ideas for later rounds, beyond the round 2 plan (transfers: phase 3 saving, phase 4). Most came from Ben, through
Brian, on 2026-10-28. Each entry gives the idea as described, what already exists that it could build on, and the
open questions to settle before it is designed. Nothing here is scheduled; pick from this list when planning the
next round.

| # | Idea | Rough size | Needs a design pass |
|---|---|---|---|
| F1 | More Cleanup checks | Small per check | No (list the checks) |
| F2 | A landing page above the tools ("parts hub") | Medium, grows with each tool | **Yes** |
| F3 | Specials and promotions | Medium-large | **Yes** |
| F4 | Inventory management (the Corp Parts Excel Reports) | Medium-large | **Yes** |
| F5 | Scheduled reminders | Medium | Yes (with F3) |
| F6 | One-Time returns and scrap | Medium | Light |
| F7 | Warn before losing ticked parts on Recommended Reorder | **Done in 0.5.0** | No |
| F8 | One-Time order templates | Small-medium | Light |
| F9 | Price change history (was N5) | Medium | Yes, later |

## F1. More Cleanup checks

**Idea (Ben).** Cleanup could surface more things to fix in Equip, not only the stale minimums. Example: a part
with an **on hand value but no on hand quantity** (an Equip quirk). Ben will look into what other quirks exist.

**Builds on.** The Cleanup page and its CSV (round 1: minimums with no demand, with the guard against
spreadsheet formulas in descriptions). Each new check is a filter over data the publish already carries, or one
more column in the publish.

**Open.** Ben's list of checks. For the value-without-quantity check: which Equip value field (InMaster stock
value or the cost × on hand), and whether the publish carries it today.

## F2. A landing page above the tools

**Idea (Ben's vision, as Brian reads it).** The non-JD ordering is one piece of a bigger tool. The app opens on a
new landing page with a way into each piece: non-JD ordering, JD ordering, Cleanup, Inventory management (F4),
and later others. Ben sees the tool becoming much more than non-JD ordering.

**Builds on.** The app already has a nav rail and a Home page; today's Home would become the non-JD section's
home. The sign-in, the SharePoint lists and the publish all carry over.

**Open.** Needs proper design before building:
- which pieces, in what order (JD ordering is a large round of its own);
- the app's name and URL (it is "Non-JD tool" today);
- whether the attention items from each piece (transfers, cleanup counts, reminders) show on the landing page;
- whether everyone sees every piece.

Worth settling **before** JD ordering or inventory management are built, so they slot in rather than being
bolted on.

## F3. Specials and promotions

**Idea (Ben).** Handle vendor specials and promotions in the tool. Needs more thought; to be discussed when we get
there. Check Ben's earlier answers (Part 1 and Part 2 of the questions doc) for anything already said.

**Open.** Where promo data comes from (vendor emails, files, typed in by Shannon); what a promo changes (order
earlier, order more, a different price); whether it ties to F5's reminders.

## F4. Inventory management

**Idea (Ben).** Fold the **Corp Parts Excel Reports** (the six SharePoint workbooks) into the tool somehow.

**Builds on.** Those workbooks' logic and the data-source decision still pending for them (memory:
`project_franchise_d_low_demand_parts`). The publish already ships every branch's non-JD parts with sales
history, so non-JD pieces could reuse it.

**Open.** Needs a design pass: which workbooks, which users, whether they cover JD parts too (then F2 and JD
ordering come first), and whether they replace the workbooks or sit beside them.

## F5. Scheduled reminders

**Idea (Ben).** Let Shannon (or whoever) schedule reminders. Example: a promo on certain shredder parts starts on
a known date; 60 days before, the tool reminds Shannon to look at ordering more shredder blades. May fold into F3.

**Builds on.** A new SharePoint list (reminder text, parts or a rule criterion, due date, lead days, who) and a
Home card, as the transfers card does today. An email could come later (the DP refresh already sends mail
through Graph).

**Open.** Reminders on a part, a dealer group, a franchise or free text; one-off or yearly; whether the reminder
opens a ready One-Time search.

## F6. One-Time returns and scrap

**Idea (Ben, Brian).** The opposite of One-Time Order. Example: a franchise lets us return 10% of parts not sold in
a set period. It works like One-Time: search with a few different criteria, list the parts that qualify, tick the
ones to return, export a CSV. Scrap is the same with criteria like no sales in 36 months. A toggle labels the CSV
as Return or Scrap.

**Builds on.** One-Time Order's search, ticking, multi-branch and export (0.3.0 / 0.4.0) and the Orders list with
its Parameters JSON. Mostly a new mode of an existing page.

**Open.**
- The criteria: months without sales, on hand > 0, franchise, dealer group, maybe age since last receipt.
- The return allowance: is the 10% of value or of quantity, and of what (purchases in a period, stock)? Should
  the tool stop at the allowance?
- What value goes on the CSV: cost, or the return credit.
- Whether returns and scrap are saved like orders (list, status) or only exported.

## F7. Warn before losing ticked parts on Recommended Reorder

**Done in 0.5.0** (app `88c7d59`, 2026-10-28, before the 0.5.0 release).

**Found by Brian in the 0.5.0 click-through.** Tick a few parts on Recommended Reorder, go to another page, and
the ticks were lost without a warning. The Create order review screen and the Rules editor already asked;
leaving Reorder (or One-Time's review step) with ticks did not.

**Built.** Recommended Reorder and One-Time Order's review step ask "Leave this page? N ticked parts will be
lost." with Stay / Leave, and the browser asks on close or reload. A switch, filter or branch change on the page,
Create order and a finished save never ask. Keeping ticks for the session instead was not built.

## F8. One-Time order templates

**Idea (Ben).** Save One-Time settings that get reused all the time. Example: franchise XYZ always uses the same
search settings; the user saves them as a template and recalls them with one click.

**Builds on.** One-Time's settings are already written into each saved order's Parameters JSON, so a template is
that same JSON with a name, in a new SharePoint list (or reused from a past order: "Start from this order").

**Open.** Shared templates or per user; who can edit them.

## F9. Price change history (was question N5)

**Idea (Brian, 2026-10-27).** Show a part's price change history, as DP already keeps for JD parts
(`Fact_PartPriceChange`, `Fact_JDNationalPriceChange`).

**Status.** Parked (2026-10-28). Ben finds it interesting but there is no standard way non-JD price changes are
entered; it differs by vendor. Brian wants to explore it later without taking focus from other features. Revisit
when JD parts join the tool (then the JD history is ready to show), and look then at whether Equip's own cost
changes (Part Master history, `Fact_PartMaster_History`) can give a non-JD history without vendor files.
