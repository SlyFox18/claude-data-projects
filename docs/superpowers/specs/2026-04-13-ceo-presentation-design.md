# CEO Presentation Design
**Date:** 2026-04-13
**Status:** Approved — ready for implementation planning

---

## Overview

A 30–45 minute semi-formal presentation for the company CEO demonstrating the data platform that has been built on Microsoft Fabric / Power BI. The presentation follows a transformation arc — before vs. now — with business value woven throughout every section. Live demos are central to the format.

**Audience:** CEO — business-first, not technical. No jargon. Lead with outcomes, not mechanics.
**Format:** A few guiding slides + live demos. Not a heavy deck.
**Estimated runtime:** ~36 minutes + buffer for questions.

---

## Structure

### Section 1 · The Before — Setting the Stage (~4 min)

Frame the problem that the rest of the presentation solves:

- Manual data pulls, Excel prep work, reports outdated before they were shared
- One person as a bottleneck for every data question
- **Equip's built-in reporting limitations** — the source system (Equip) has limited reporting flexibility, no cross-module views, no ability to combine parts + service + financial data in one place, and no automation. It does what it does well, but it wasn't built to answer the business questions we have.

Goal: make the CEO feel the pain of the "before" so everything that follows lands as the answer to it.

---

### Section 2 · The Reports + Agents — Live Demo (~15 min)

The bulk of the demo. Each report is introduced with its business question, not its features.

**Reports:**
4–5 reports TBD — final selection pending input from corporate parts manager. Criteria for selection:
- Reports the CEO already references or has asked about
- Shows breadth across parts, service, and financial categories
- Strong visual impact
- Clear "before" story (something that used to be a manual Excel pull)

**HTML design callout** (during one report demo):
Briefly highlight an HTML-powered visual — a badge, KPI card, or conditional formatting element. Message: *"Standard Power BI has limits on how things can look. By writing HTML directly into visuals, we get full design control — custom colors, badges, formatted cards — things you can't do with the built-in tools."*

**Agent Demo 1 — Service Agent** (after Inspections/service report):

Connected to all service report semantic models in the RP - Service Reports workspace.

Natural pivot: *"The reports answer the questions we already knew to ask. But what about questions you think of on the spot?"*

Sample questions:
- "Which branch has the most open work orders right now?"
- "Show me inspections that have been open more than 30 days"
- "What's the average turnaround time on work orders this month vs last month?"
- "Which technician has the most open tickets?"

**Agent Demo 2 — Parts & Invoice Agent** (separate beat):

Connected to `jdis_Part_Information` and `Invoice` raw tables. Works at the transaction level, not summarized reports.

Frame: *"This one works at the raw transaction level — individual parts and invoice records."*

Sample questions:
- "What are the top 10 parts by invoice volume this quarter?"
- "Show me all invoices over $5,000 from the last 30 days"
- "Which parts haven't had a single invoice in the last 6 months?"
- "What's the average invoice value per customer for branch 5?"

Close: *"And we can build more of these — connected to any combination of data. This one took less than a day to set up."*

---

### Section 3 · The Engine — What Makes It Run (~5 min)

Pull back the curtain with a simple visual — not technical depth, just the concept:

> Source system → Central data warehouse → Reports & Agents

Key messages (plain language):
- Runs automatically at 4 AM every weekday — no one has to touch it
- 25+ reports refreshed, monitored, and confirmed before business hours
- If something fails, an automated alert fires to Teams immediately
- Every change to the system is tracked and reversible — like a save history for infrastructure

---

### Section 4 · How We Build It — AI, Versioning & Automation (~6 min)

The "behind the developer" section. Lead with outcomes, not tools:

- **AI-assisted development** — *"What used to take a full day now takes an hour. The AI understands our entire system and helps write, review, and test changes."*
- **Version control (GitHub)** — *"Every change has a record. We can see what changed, why, and roll back anything that breaks."*
- **Direct Fabric integration** — *"Changes flow from a sandbox environment to production through a review process — the reports themselves are version-controlled too."*
- **Documented knowledge base** — *"All institutional knowledge about how the data works is documented and searchable — not just in someone's head."*
- **Code-first operations** — *"Routine tasks — report updates, new metrics, data fixes — done via code rather than clicking through UIs. Faster, auditable, and repeatable."*

---

### Section 5 · What's Next — The Roadmap (~6 min)

Close with the future. Frame everything as "what the platform now makes possible."

**Broader Rollout — Getting This to the Right People:**

> *"The foundation is built. The next step is getting this in front of the right people — in a way where everyone sees exactly what they need to see, nothing more."*

- **Distribution options** — Teams tabs, Power Apps, embedded web apps, automated report snapshots delivered via email or Teams on a schedule
- **Branch-level security** — a Branch 1 parts manager logs in and sees only Branch 1 data. Same report, personalized view, enforced automatically by login. No extra work per user — built into the system.
- **No extra licenses needed** — for certain delivery methods (embedded web app), end users don't need a Power BI license to view reports

**Additional roadmap items:**
- **Power Apps / Web Apps** — custom tools built on the same data, accessible on phones and tablets
- **More data agents** — financial, customer, cross-department — any question, any dataset
- **Self-serve reporting** — managers pull their own views without waiting on IT
- **AI-driven insights** — anomalies and trends surfaced automatically, not just on demand
- **Expanded data sources** — external data alongside operational data

---

## Open Items

| Item | Owner | Status |
|------|-------|--------|
| Final report selection for Section 2 demo | Corporate parts manager + Brian | Pending — parts manager reviewing options |
| Slide template / visual style | Brian | Not started |
| Simple data flow diagram for Section 3 | Brian | Not started |
| Practice run timing | Brian | Not started |

---

## Out of Scope

- Deep technical explanations of Power Query, DAX, or Git internals
- Detailed Power BI Embedded implementation (separate project, post-presentation)
- Row-level security setup details (mentioned as a capability, not demoed)
