# Non-JD Parts Order Tool: future ideas

Ideas for later rounds, beyond the round 2 plan (transfers: phase 3 saving, phase 4). Most came from Ben, through
Brian, on 2026-10-28. Each entry gives the idea as described, what already exists that it could build on, and the
open questions to settle before it is designed. Nothing here is scheduled; pick from this list when planning the
next round.

Round 2 is complete (0.7.0, phase 4 One-Time transfers). F2 is done in 0.8.0 (2026-10-30), F6 in 0.9.0, F8 in 0.10.0 and F1 in 0.11.0 (all 2026-11-02), F4's first report in 0.12.0 (2026-11-03), Border Stores and 2 & 4 Cotton in 0.13.0 (2026-11-04), a bulk transfer export (Brian's request, 2026-11-04: Export (N) on Transfer orders, one combined CSV) in 0.13.1, Corporate Stocking (the first one-row-per-part report) in 0.14.0, F10 Stock on superseded parts in 0.15.0 and F11 the part details panel in 0.15.1 (all 2026-11-05), and Pieces In Set in 0.16.0 (2026-11-06). Next: the F12 reason-code design (Brian is asking Ben the open questions meanwhile).

| # | Idea | Rough size | Needs a design pass |
|---|---|---|---|
| F1 | More Cleanup checks | **Done in 0.11.0** | No |
| F2 | A landing page above the tools ("parts hub") | **Done in 0.8.0** | No |
| F3 | Specials and promotions | Medium-large | **Yes** |
| F4 | Inventory management (the Corp Parts Excel Reports) | **MLPF Gaps (0.12.0), Border Stores and 2 & 4 Cotton (0.13.0), Corporate Stocking (0.14.0), Pieces In Set (0.16.0) done**; Scrap and COTTON Trouble Parts placed later | No (one release per workbook) |
| F5 | Scheduled reminders | Medium | Yes (with F3) |
| F6 | One-Time returns and scrap | **Done in 0.9.0** | No |
| F7 | Warn before losing ticked parts on Recommended Reorder | **Done in 0.5.0** | No |
| F8 | One-Time order templates | **Done in 0.10.0** | No |
| F9 | Price change history (was N5) | Medium | Yes, later |
| F10 | Stock on superseded parts (JD + non-JD built-ins) | **Done in 0.15.0** | No |
| F11 | Part details panel (see a part without leaving an order) | **Done in 0.15.1** | No |
| F12 | Reason codes: report and check rules suggest parts on orders | Large | **Yes**; **next** |

## F1. More Cleanup checks

**Idea (Ben).** Cleanup could surface more things to fix in Equip, not only the stale minimums. Example: a part
with an **on hand value but no on hand quantity** (an Equip quirk). Ben will look into what other quirks exist.

**Builds on.** The Cleanup page and its CSV (round 1: minimums with no demand, with the guard against
spreadsheet formulas in descriptions). Each new check is a filter over data the publish already carries, or one
more column in the publish.

**Done in 0.11.0 (2026-11-02)** as **Cleanup checks**: Cleanup is a list of checks over every branch, each with a
count, a results page (branch and franchise filters, sort, Export CSV) and an editor. Two are built in: **Minimums
with no demand** (the old page) and **Stock value with no quantity** (Equip stock value of $1 or more either way, on
hand 0 or less; Prod had 415 on 2026-11-02). Anyone can save a check from conditions (field · comparison · value, all
must match) over 22 fields, with a live Try it; saved checks are shared and can be edited, switched off and archived.
The value is Equip's own (ON_HAND_VAL, `Silver_PartInformation.InventoryCost`), added to Gold and the publish
(contract 5). Spec `docs/superpowers/specs/2026-10-30-spi-parts-hub-round-3-design.md` (phase 3), plan
`docs/superpowers/plans/2026-11-02-spi-parts-hub-cleanup-checks.md` (decisions K-D1–K-D11), user guide section 7,
`CLEANUP-CHECKS.md`.

**Follow-ups:**
- **Or** between conditions (today every condition must match; "A or B" needs two checks).
- **Last sold** as a field: needs every branch's monthly history, too heavy for a list over every branch today.
- **Checks per person:** today every saved check is shared; a personal vs shared choice (and "my checks" first).
- **The "value without quantity" threshold** is fixed at $1 in the built-in; make it a setting.

**Was open:** Ben's list of checks (any check can now be built without a release); which Equip value field (Equip's
own stock value, not cost × on hand) and whether the publish carried it (it does since contract 5).

## F2. A landing page above the tools

**Idea (Ben's vision, as Brian reads it).** The non-JD ordering is one piece of a bigger tool. The app opens on a
new landing page with a way into each piece: non-JD ordering, JD ordering, Cleanup, Inventory management (F4),
and later others. Ben sees the tool becoming much more than non-JD ordering.

**Builds on.** The app already has a nav rail and a Home page; today's Home would become the non-JD section's
home. The sign-in, the SharePoint lists and the publish all carry over.

**Done in 0.8.0 (2026-10-30)** as **SPI Parts Hub**: a launch page with a card per area (Non-JD ordering, Cleanup,
Part Lookup; JD ordering and Inventory management as "Coming later"), counts of what is waiting on each card, and a
left nav that shows one area at a time. The questions below are answered in the spec
`docs/superpowers/specs/2026-10-29-spi-parts-hub-launch-page-design.md` (decisions H1–H7); the URL changes with the
production move (1.0.0), and limiting areas by person waits until JD ordering exists.

**Was open:**
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

**MLPF Gaps done in 0.12.0 (2026-11-03)** as the **Inventory management** area: reports over every active JD part
at every branch (a new Gold table `Fact_CorpParts_JD` with the Corp demand count, shipped in the publish as contract
6). The built-in **MLPF Gaps** uses the workbook's rules and columns; **Copy as my own** saves an editable copy
(SharePoint list NonJD_InventoryReports) on the Cleanup checks engine, with new **starts with / doesn't start with**
comparisons. Results have a branch filter, search, sort, Total cost (1 each), a part details panel and a CSV with the
workbook's headings. The Excel comparison of 2026-11-03 matched 10,046 of 10,065 rows on every column, every
difference explained. Spec `docs/superpowers/specs/2026-11-03-spi-parts-hub-inventory-reports-design.md`, plan
`docs/superpowers/plans/2026-11-03-spi-parts-hub-inventory-reports.md` (decisions L-D9–L-D22), user guide section 10,
`INVENTORY-REPORTS.md`.

**Border Stores and 2 & 4 Cotton done in 0.13.0 (2026-11-04).** The engine learnt "other branches": a report's second
list **Count other branches where** feeds two fields, Other-branch demands and Other branches with demand, so copies
can change the branches compared and counted. Also "any of" groups (Cleanup too), "not one of", **Dealer group at any
branch**, and **parts with no activity** (Gold `Fact_CorpParts_JD_Idle`, about 643,000 records, publish contract 7,
loaded only by reports that need them). The Excel comparison matched Border Stores 1,573 of 1,575 and 2 & 4 Cotton
248 of 248 (plus 1), every difference evening Equip activity except a lower-case part record, fixed. Spec
`docs/superpowers/specs/2026-11-03-spi-parts-hub-cross-branch-reports-design.md`, plan
`docs/superpowers/plans/2026-11-03-spi-parts-hub-cross-branch-reports.md`, user guide section 11.

**Corporate Stocking done in 0.14.0 (2026-11-05).** The engine learnt **one row per part**: four lists (Records that
count, Every counted record must, Demand counts where, Parts to show) over a part's active and idle records at every
branch, with part fields R18 demands, Branches with demand and Locations with demand. Results filter by **Demand at
branch**; a part's panel shows how each branch's record was treated. **New report** starts from scratch with a Report
type choice. The Excel comparison matched 1,817 parts, every difference explained (window edges, two Equip changes,
four description spellings accepted). Spec `docs/superpowers/specs/2026-11-04-spi-parts-hub-corporate-stocking-design.md`,
plan `docs/superpowers/plans/2026-11-04-spi-parts-hub-corporate-stocking.md`, user guide section 12.

**Pieces In Set done in 0.16.0 (2026-11-06).** Three built-ins (the main list, 3 Months or Less, Review) with new fields
from seven Gold columns on `Fact_CorpParts_JD` and `Silver_InMaster.PiecesInSet`, publish contract 8. The stock is Bin Qty,
not On hand (Ben). Reports only; nothing on the order screens. The Buy List is a copy. The app's CSVs matched the reference
with 0 differences (3,316, 680, 121), and every workbook difference is listed (18 other-franchise rows, 8 stock moves not
proven). Spec `docs/superpowers/specs/2026-11-05-spi-parts-hub-pieces-in-set-design.md`, plan
`docs/superpowers/plans/2026-11-05-spi-parts-hub-pieces-in-set.md`, user guide section 15.

**Later:** Scrap and COTTON Trouble Parts are placed later. **F12, Reason Codes,** is next.

**Follow-ups:**
- **A JD Part page:** today a report row opens a details panel (the Part page is non-JD only).
- **Actions from a row:** order, transfer or set a minimum straight from a report.
- **Intraday data:** reports use the morning data; the workbooks read Equip live. DP's `intraday` mode could refresh
  the JD parts during the day.
- **The franchise-case issue elsewhere:** `Build_Silver_PartInformation` lost InManuf fields on parts stored with a
  lower-case franchise (fixed in Plan L, L2b). Other notebooks that join Equip sources on franchise as stored may
  have the same issue.

**Was open:** which workbooks (all of them, MLPF Gaps first), which users (everyone), whether they cover JD parts (yes,
the JD parts only, without waiting for JD ordering), and whether they replace the workbooks (they sit beside them
until Ben is happy to retire them).

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

**Done in 0.9.0 (2026-11-02)** (0.9.1 the same day) as the **Returns & scrap** area: return and scrap rules per
franchise (a scrap rule can cover all franchises), New return / New scrap list (company-wide, pre-picked up to the
allowance for a return, **Transfer instead** to a branch with demand), saved documents with their own statuses and
CSV, and holds shown as "On return / On scrap" tags. Spec `docs/superpowers/specs/2026-10-30-spi-parts-hub-round-3-design.md`
(decisions R1–R16), plan `docs/superpowers/plans/2026-10-30-spi-parts-hub-returns-and-scrap.md`, reference for Ben
`RETURNS-AND-SCRAP.md`. The answers: the criteria are rule fields (no sales, not received, min line value / unit
cost, leave out Manual order / minimums, season); the allowance is a % of 12-month purchases, stock value or the
qualifying value, chosen per rule, and the tool warns but doesn't stop at it; the CSV has cost, credit % and credit
value; returns and scrap are saved documents with statuses.

**Follow-ups (small, found while building it):**
- The Returns and Scrap lists read every document's lines to show its lines, value and branches, so they get slower
  as history builds up. Store a line count and total on the document instead.
- A Draft whose lines were all removed isn't counted on the launch card ("N open returns"), though it is still open.
- Transfer instead goes by requests only: it doesn't check whether the receiving branch already has plenty.

**Was open:**
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

**Done in 0.10.0 (2026-11-02)** as **One-Time templates**: a Template card on One-Time Order's Set up (Use, Save as
template, Update template / Save as new template, History, Archive, Stop using) and a Templates page under One-Time
Order (Start order, History, Archive / Unarchive). Templates are shared and anyone can change them; every change is
recorded with who and when; periods are kept relative (Rolling N, a full year, or fixed months); a template whose
values aren't in today's data fills what exists and says what it left out; orders record "From template X". Spec
`docs/superpowers/specs/2026-10-30-spi-parts-hub-round-3-design.md` (phase 2), plan
`docs/superpowers/plans/2026-11-02-spi-parts-hub-one-time-templates.md` (decisions J-D1–J-D10), user guide section 9.

**Follow-ups (low, found while building it):**
- Archive / Unarchive count as a change for "Changed by": they move the template's last-changed time, so after someone
  archives and unarchives a template, the next person starting from it sees "Changed by X on …" though the Set up is
  the same.
- Orders keep "From template X" even if the Set up was changed after starting from the template (the order's own
  parameters say what was really used).
- "Create orders (N)" on One-Time Review counts lines, not orders.

**Was open:** shared templates or per user; who can edit them. (Shared; anyone can edit.)

## F9. Price change history (was question N5)

**Idea (Brian, 2026-10-27).** Show a part's price change history, as DP already keeps for JD parts
(`Fact_PartPriceChange`, `Fact_JDNationalPriceChange`).

**Status.** Parked (2026-10-28). Ben finds it interesting but there is no standard way non-JD price changes are
entered; it differs by vendor. Brian wants to explore it later without taking focus from other features. Revisit
when JD parts join the tool (then the JD history is ready to show), and look then at whether Equip's own cost
changes (Part Master history, `Fact_PartMaster_History`) can give a non-JD history without vendor files.

## F10. Stock on superseded parts

**Done in 0.15.0 (2026-11-05).** Ben's idea: parts with on hand > 0 and a Super To, for JD and non-JD. A built-in
Inventory report and a built-in Cleanup check; Super To is a new Cleanup field. Spec:
`docs/superpowers/specs/2026-11-05-spi-parts-hub-superseded-stock-design.md` (Plan P).

## F11. Part details panel

**Idea (Ben, 2026-11-05).** On an order in progress, check a part's details and come back without losing the work
(today the part link asks "Leave this page?"). Designed: `docs/superpowers/specs/2026-11-05-spi-parts-hub-part-details-panel-design.md`
(Plan Q). **Done in 0.15.1 (2026-11-05):** a part number opens a look-only panel over the page. When JD ordering is
built it will need a JD version: JD parts have no part page.

## F12. Reason codes: rules that suggest parts on orders

**Idea (Ben, 2026-11-05).** On an order (e.g. Seminole's Recommended Reorder, Order step), parts that meet the
Corporate Stocking rules are suggested too, each labelled with why, as JD Prism's "Reason Codes" do. Must work for
non-JD ordering now and JD ordering once that is built (planned).

**Direction (Brian, 2026-11-06): tags on the reorder rules. This replaces approach A below.** Add to the existing Rules
screen instead of a Suggest on orders setting on reports. Build after JD ordering.
- A rule gets a **tag**: pick one already in use or type a new one (no SharePoint list change to add a tag). The tag
  shows on the Recommended Reorder and One-Time Order screens.
- A rule either **replaces** (as today, one rule per part; Cotton stays this way) or **adds parts**: the normal rule
  runs first, then the add-on rule also checks the part, and a part it recommends appears with the tag.
- A part both rules order takes the **larger** quantity; the user can change it on the order.
- Tagged parts **start ticked**, like other lines: the user checks every line of an order and unticks what they don't
  want.
- Rules can't express Corporate Stocking today: they look at one branch and it looks across all branches (nothing on
  hand or on order anywhere, demand at 3+ branches), and it is JD only. It becomes a real rule with JD ordering, with
  those conditions added. Package qty, Super To and the like are added as people ask.
- Both the morning run and the app calculate rules, so both change and must still agree.

**Earlier direction, superseded (Brian, 2026-11-05: approach A).** Not a separate rules area: any Inventory report (JD) or Cleanup check
(non-JD), built-in or saved, gets a **Suggest on orders** setting:
- a **reason code** (e.g. `CORP-STOCK`), shown on the order line as a label beside Reorder / Out of stock;
- for one-row-per-part reports, **which branch gets the suggestion** (each branch with demand, or a set stocking
  branch);
- a **quantity** (e.g. 1, the package quantity, up to a minimum).

The order screen runs the branch's suggesting rules: a part it already suggests gains the label; a part it wouldn't
order is added with the rule's quantity, marked as suggested by that reason, unticked.

**Likely order.** (1) Reason codes on Cleanup checks shown on the non-JD order screen; (2) the one-row-per-part engine
over non-JD parts, for a non-JD Corporate-Stocking-style rule; (3) Inventory reports (Corporate Stocking) plug in
when JD ordering exists.

**Open questions (for Brian and Ben).** Which branch orders a part-grain suggestion; the quantity rule; whether a
reason-code part counts in the order total before it is ticked; several reasons on one part (show all?); whether
reason codes appear on the export / in Equip; who may switch a rule's suggesting on.

## F13. The combine vault (branch 12)

**Idea (Brian, 2026-11-06).** Branch 12 isn't a physical location: it's the combine vault, holding combine and stripper parts,
like a trailer that can be moved closer to the stores that may need those parts but don't normally stock them. The Hub could
help manage that inventory: what to load, where to move it, what the nearby stores need. Non-JD parts aren't in the vault,
which is why non-JD ordering excludes branch 12. Later, after JD ordering. JD ordering includes every branch, 12 too.
