# Service Time Sheets — Corp Service Manager Quick Reference

> **Audience:** Corp Service Manager  
> **Purpose:** How to read the audit, what flags mean action, and specific examples of what to look for

---

## What this report does

After techs submit their time sheets, the report compares what each tech *claimed* against what EquipRDB actually *invoiced* for that same job. Any gap — in either direction — gets flagged before draw pay is approved.

---

## The two rules techs need to follow

**1. One RO# per job.** If a tech submits the same RO# under two different customers, the system counts both claims. That RO gets flagged as overclaimed even if neither claim is unreasonable on its own. One job, one RO.

**2. What you claim this period must match what was invoiced.** Draw pay is based on hours the customer was actually billed — not what the tech thinks was billed. Techs need to verify the RO hours in the system before they fill out the sheet.

---

## How to read the flags — the ones that need your attention

| Status | What it means |
|---|---|
| **Overclaimed** | Tech claimed more hours than were invoiced. Do not approve until explained. |
| **Underclaimed** | Tech claimed fewer hours than were invoiced. They may be owed more pay. |
| **Match** | Hours reconcile. No action needed. |
| **Draw — Open RO / In Progress** | Job isn't invoiced yet or isn't complete. Normal — revisit next period. |

---

## Real examples — what went wrong and what to do

### Same RO#, two customers
A tech submitted hours for two different customers, but both used the same RO number. One of those RO numbers is wrong. The system sees it as double-claiming the same job, so the total claimed hours look inflated and the RO lands in Overclaimed.

**Fix:** Have the tech pull up both jobs in EquipRDB, confirm the correct RO for each customer, and resubmit with the right numbers.

---

### Draw history doesn't match current claim
A tech filled in Final Draw = 1.83 hours but put 2.05 in the Current Draw column for the same period. Those two numbers are supposed to match — the draw history is a record of what was actually paid, not an estimate. The system uses 2.05 (the current claim), but payroll doesn't know which is correct.

**Fix:** Ask which number is right. If it's 1.83, resubmit. If it's 2.05, confirm the invoice supports it and update the history column to match what gets paid.

---

### Underclaimed on a large-hour job
A tech invoiced 82 hours but only claimed 50. Before assuming it's fine, check whether they submitted all their periods for that RO. A missing pay period submission looks identical to an honest underclaim.

**Fix:** Ask the tech to account for all periods on that RO. If they missed one, resubmit.

---

### Negative Labor Margin (shown in red on Invoice Labor Reconciliation page)
The company paid the tech more in draw than the customer was billed. Usually means the tech overclaimed, or a billing reversal happened after the draw was processed.

**Fix:** Pull the invoice in EquipRDB. If the billed amount was reduced, the tech needs to adjust their next submission. If it wasn't, they overclaimed.

---

## Before approving draw pay

- Any **Overclaimed** row needs an explanation or a corrected submission
- Any **Underclaimed** row with a large hour gap needs a check that no period was missed
- Any **red Labor Margin** on the Invoice Labor Reconciliation page needs a look at the invoice

Everything else — Match, Draw statuses — is clean.

---

## How to navigate the report

| If you need to... | Go to... |
|---|---|
| See the full picture by pay period | Executive Summary |
| Review every submission row by row | Time Sheet Audit |
| Investigate a specific tech | Right-click their name on Time Sheet Audit → drill through |
| See all techs on one RO | Right-click an RO on Tech Audit Detail → drill through |
| Review closed invoices vs. submissions | Invoice Labor Reconciliation |
| See all shared-work ROs at once | Multi-Tech RO Review |
