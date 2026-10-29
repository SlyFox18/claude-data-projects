# Transfer rules: a guide for Ben

This page explains the **Transfer rules** page of the Non-JD Parts Order Tool (app version 0.7.0, 2026-10-29):
what a transfer rule is, what each field does, which branch's rule decides what, and how to test a change before
saving it. How the transfer suggestions themselves are worked out is in **REORDER-RULES.md** ("Transfer
suggestions") and section 5 of the user guide.

The rules are kept in the SharePoint list **NonJD_TransferRules** on the Report Site. You edit them on the app's
**Transfer rules** page, next to Rules. A change applies in the app straight away, for everyone; the morning run
uses it the next day.

## What a transfer rule is

Every morning, and live in the app, the tool suggests stock one branch could send to another instead of buying
(**Conventional**), or as extra stock for a branch that sells the part (**Redistribution**). A transfer rule
changes how that works for the parts and branches it covers:

- how much a branch **keeps** before the rest counts as excess it could send;
- whether a branch may **send** or **receive** at all;
- how much extra stock a branch takes by **redistribution**, and the smallest redistribution line worth
  suggesting.

You don't need any rules. With none, the **built-in default** applies everywhere (below). Add a rule only where a
branch, franchise or group of parts should work differently.

## Which branch's rule decides what

**The sending branch's rule decides what counts as excess; the receiving branch's rule decides whether it takes
transfers and how much redistribution.**

| Decided by the sending branch's rule | Decided by the receiving branch's rule |
|---|---|
| **Excess supply**: what it keeps before stock is excess | **Receives**: whether it takes transfers at all |
| **Sends**: whether it may send | **Redistribution up to**: how much extra stock it takes |
| **Redistribution minimum**: the smallest redistribution line it sends | |

Each branch picks its own rule for each part, from its own part record. So for one part, branch 92 may use one
rule and branch 1 another.

## The fields

| Field (SharePoint column) | What it does | Default |
|---|---|---|
| **Name** (Title) | Required. Shown in the list and in Try it. | |
| **Priority** | Required. Of the rules that fit a part, the highest wins (see "How a rule is picked"). | |
| **Active** | Off = the rule is not used. A new rule starts on. | On |
| **Franchise, Dealer group code, Branch, SLC, Source, Vendor code, Product group, Commodity code** | Which parts and branches the rule covers. Blank = any. Case and spaces at either end don't matter. **Vendor code** is the whole number without leading zeros (1234, not 01234); 0 = parts with no vendor code. **Commodity code** is empty for most non-JD parts today. | Blank |
| **Season starts** and **Season ends** (StartMonth, EndMonth) | Months the rule applies. 11 to 2 = November to February. Both blank = all year. | Blank |
| **Excess supply** with **Excess unit** (ExcessSupply, ExcessUnit) | **Sending branch.** What it keeps before stock counts as excess: the larger of its target and this many months (0-60) or weeks (0-260) of supply. Required. | 12 months |
| **Sends** (AllowSend) | **Sending branch.** Off = it never sends; its excess stays put. | On |
| **Receives** (AllowReceive) | **Receiving branch.** Off = it takes no transfers at all, conventional or redistribution. | On |
| **Redistribution up to** with **Redistribution unit** (RedistMax, RedistUnit) | **Receiving branch.** It takes extra stock up to this many months (0-24) or weeks (0-104) of supply, never above what it would itself keep. 0 = no redistribution into it. Blank = 6 months. | 6 months |
| **Redistribution minimum** (RedistMinValue) | **Sending branch.** A redistribution line worth less than this (at the sending branch's cost) is not suggested. 0 = no minimum. Conventional transfers have no minimum. | $0 |
| **Notes** | Free text, for why the rule exists. | |

A rule with a missing or out-of-range setting can't be saved. If one in the list has a problem (for example
someone edited the SharePoint list directly), the page shows it as **Invalid** with the reason, it is skipped,
and Brian's morning email names it.

Each rule in the list shows its state: **Active**, **Off**, **Out of season** (active, but not this month),
**Invalid** (skipped, with the reason) or **Archived**.

## How a rule is picked

For each part at each branch, separately:

1. Only rules that are **Active**, not archived, valid and **in season** this month count.
2. Of those that fit the part (every filled-in criterion matches), the **highest Priority** wins.
3. On a tie, the rule with **more criteria** filled in wins.
4. Then the **lowest rule number**.
5. If none fits, the **built-in default** applies: excess supply **12 months**, sends and receives **on**,
   redistribution up to **6 months**, redistribution minimum **$0**.

This is the same way order rules are picked. The built-in default is the first row of the list. It can't be
edited; add a rule to change it.

## Worked example

Round numbers. A chain costs $10. Branch 92 has 40, sells 1 a month and its target is 2. Branch 1 sells 2 a month,
has none on hand or on order, and its target is 3.

**With no rules (the built-in default):**
- Branch 92 keeps the larger of its target (2) and 12 months of supply (12), so it keeps 12 and has
  40 − 12 = **28** excess.
- Branch 1 needs 3, so it gets **3 from 92** (Conventional) instead of buying.
- Branch 1 can then take up to 6 months of supply, 12 in all, so it gets **9 more** (Redistribution).

**A rule for branch 92: Excess supply 36 months.** Branch 92 now keeps 36, so its excess is 40 − 36 = **4**.
Branch 1 still gets its **3** (Conventional), but only **1** by redistribution: that is all 92 has left.

**Add Redistribution minimum $25 to the same rule.** The redistribution line of 1 is worth $10, under $25, so it
isn't suggested. The conventional 3 stays: the minimum is for redistribution only.

**A rule for branch 1 instead: Redistribution up to 0.** Branch 1 still gets its 3 (Conventional), but no
redistribution.

**A rule for branch 1: Receives off**, or **for branch 92: Sends off.** No transfer between them at all. Branch 1
buys its 3.

Two typical first rules (from the round 2 design): "Cotton, off season: Sends off at branch 2" (and the same for
branch 4: one Branch per rule), and "Branch 92: Redistribution up to 0".

## Try it

While you edit a rule, the **Try it** card shows its effect on **every branch** before you save. It compares the
rules as saved (before) with your draft in place (after):

- **Conventional lines** and **Order $ avoided** (what the transfers save buying);
- **Redistribution lines** and **Redistribution $**;
- the parts whose suggestions change most.

Nothing is saved until you click **Save rule**. A draft with a problem shows the problem instead of figures (for
example "ExcessSupply must be 0-60 months"). A draft that is switched off changes nothing; turn on Active to try
it. **Refresh** re-reads the saved transfers and part settings. Closing with unsaved changes asks first.

## Archive

**Archive** hides a rule you no longer use, instead of deleting it. An archived rule is never used and is hidden
unless **Show archived** is on; then it shows greyed out, and **Unarchive** brings it back (it is used again if it
is active). Nothing is ever deleted.

## Where transfer rules apply

- The daily transfer suggestions (Home, Recommended Reorder step 1, the Transfers page), conventional and
  redistribution.
- One-Time Order's Transfers step (0.7.0), conventional only: each sending branch's rule decides its excess, and a
  receiving branch with **Receives** off gets nothing.
