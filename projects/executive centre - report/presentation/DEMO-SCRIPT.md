# CEO Presentation — Demo Script

> **Usage:** Read the bold lines aloud (or close to them). The bullets underneath are reminders of what to show/click — not more words to say.

---

## SECTION 1 · The Before (~4 min)

**Opening line:**
> "Before I show you what we've built, I want to take two minutes on where things were — because it makes everything else make more sense."

**Talk through:**
- Manual process: every report started with someone (me) pulling data from Equip, cleaning it in Excel, and sending a file. By the time it landed in someone's inbox, it was already a little stale.
- The bottleneck: every data question came to one person. Want to know how many open work orders are in Branch 5? Ask Brian. Want last month's parts adjustments? Ask Brian.
- Equip's limits: *"Equip is great at running the business — tracking work orders, parts, invoices. But its built-in reporting is limited. You can't combine parts and service data in one view. You can't schedule a report to run itself. You can't ask it a question it wasn't pre-built to answer."*

**Close Section 1:**
> "So that's the before. Here's what we built instead."

---

## SECTION 2 · The Reports + Agents (~15 min)

> **NOTE: Report order and talking points TBD — pending confirmation from corporate parts manager. See plan Task 3.**

### HTML Design Callout
*(Weave this in during whichever report has the most visual polish — Customer Anatomy or similar)*

> "One thing worth pointing out — standard Power BI has limits on how things can look. By writing HTML directly into these visuals, we get full design control. Custom colors, badges, icons, conditional formatting you can't get with the built-in tools. It sounds like a small thing, but it's the difference between a report that looks like software and one that looks like a business tool."

---

### Agent Demo 1 — Service Agent
*(After the Inspections or service-related report)*

**Transition line:**
> "So those reports answer the questions we already knew to ask. But what about the question you just thought of in the last 30 seconds?"

**Action:** Open the Service Agent — connected to all service report semantic models in RP - Service Reports workspace. Confirm exact navigation path before presentation day.

**Questions to ask live:**
1. *"Which branch has the most open work orders right now?"*
2. *"Show me inspections that have been open more than 30 days"*
3. *"How many CS770 inspections are currently open across all branches?"*
4. *"Which branch has the most open CS690 inspections?"*

**If time allows:**
5. *"Break down open inspections by type across all branches"*

**Talking point between questions:**
> "Notice it's not just returning a number — it understands the context of the data. It knows what a work order is, what an inspection type is, how to compare across branches."

---

### Agent Demo 2 — Parts & Invoice Agent
*(Separate beat, after report walkthrough)*

**Transition line:**
> "That agent was connected to all of our service reports. This next one works at a different level — not summarized reports, but the raw transaction data. Individual parts. Individual invoices."

**Action:** Open the Parts & Invoice Agent — connected to jdis_Part_Information and Invoice raw tables. Confirm navigation path before presentation day.

**Questions to ask live:**
1. *"What are the top 10 parts by invoice volume this quarter?"*
2. *"Show me all invoices over $5,000 from the last 30 days"*
3. *"Which parts haven't had a single invoice in the last 6 months?"*

**If time allows:**
4. *"What's the average invoice value per customer for branch 5?"*

**Close agent section:**
> "And we can build more of these. Connected to any combination of data in the system. This one took less than a day to set up once the data infrastructure was in place. That infrastructure is what makes it fast."

---

## SECTION 3 · The Engine (~5 min)

**Transition:**
> "Let me show you quickly what's actually running underneath all of this."

**Action:** Pull up the data flow diagram (data-flow-diagram.pptx)

**Walk the diagram left to right:**
> "Data comes in from Equip — our source system — every morning starting at 4 AM. It flows into a central data warehouse in Microsoft Fabric. From there, it feeds every report and every agent you just saw."

**Key messages — say these in order:**
1. *"Nobody has to start this. It runs automatically, every weekday morning, while everyone's asleep."*
2. *"By the time you walk in, 25+ reports have already refreshed and been checked."*
3. *"If anything goes wrong — a step fails, data looks wrong — an automated alert fires to Teams before business hours."*
4. *"And every change we make to this system is tracked. We can see exactly what changed, when, and why — and roll anything back if something breaks. Like a save history for infrastructure."*

---

## SECTION 4 · How We Build It (~6 min)

**Transition:**
> "The reports and the pipeline are the visible part. I want to spend a few minutes on how we actually build and maintain all of this — because it's changed significantly."

**Talk through each point — keep each under 60 seconds:**

**AI-assisted development:**
> "We use an AI coding assistant that's connected directly to this entire system — it understands every report, every data table, every query. What used to take a full day to build now takes an hour. It writes code, reviews changes, catches mistakes."

**Version control:**
> "Every change to any report, any query, any piece of the pipeline is tracked in GitHub. I can look at the history and see every modification ever made, who made it, and why. And if something breaks, I can roll back to any previous state."

**Sandbox → Production:**
> "Before anything goes live, it goes through a sandbox environment first. Changes get tested there, then promoted to production through a review process. The reports themselves are version-controlled — not just the code behind them."

**Knowledge base:**
> "All the institutional knowledge about how our data works — what tables mean, how things connect, known quirks — is documented in a searchable knowledge base. It's not just in my head. If something happened to me tomorrow, someone could pick this up."

**Code-first operations:**
> "Routine tasks — updating a report, adding a new metric, fixing a data issue — are done through code now rather than clicking through interfaces. That means they're faster, there's a record of every change, and the same task can be repeated exactly."

---

## SECTION 5 · What's Next (~6 min)

**Transition:**
> "The foundation is solid. Here's where this goes next."

**Broader Rollout:**
> "Right now, most of this is being used by a small group. The next step is getting it in front of the right people across the company — and doing it in a way where everyone sees exactly what they need to see, nothing more."

- *"A Branch 1 parts manager logs in and sees only Branch 1 data. Same report, personalized view, enforced automatically by their login. No extra configuration per person — it's built into the system."*
- *"And for certain delivery methods — embedding reports in a web application, for example — end users don't need a Power BI license at all to view the data."*
- Distribution options to mention: Teams channel tabs, Power Apps, automated scheduled snapshots delivered via email or Teams, embedded web apps

**Roadmap items — pace to match energy in the room:**
- *"More agents — financial, customer, cross-department. Any question, any dataset."*
- *"Power Apps and web apps — custom tools built on this same data, accessible on a phone or tablet."*
- *"Self-serve — managers pull their own views, answer their own questions, without waiting on IT."*
- *"AI-driven insights — not just AI helping build things, but AI watching the data and surfacing anomalies automatically."*
- *"Expanded data sources — bringing external data alongside our operational data."*

**Closing line:**
> "Everything I showed you today runs on infrastructure we built over the last year. The reason the roadmap items are achievable is because the hard part — the foundation — is done."

---

## Q&A Prep

Likely questions and suggested responses:

**"How long did this take to build?"**
> "The core infrastructure — the pipeline, the central data warehouse, the first wave of reports — took about a year. We've been adding to it continuously since."

**"What does this cost?"**
> "The platform runs on Microsoft Fabric, which is part of our Microsoft licensing. The AI tooling that helps build it is a separate subscription. The efficiency gains in development time have been significant."

**"Could other departments use this?"**
> "Yes — the architecture is designed for that. Adding a new data source or a new set of reports is much faster now than it was to build the first ones. The hardest work is already done."

**"What happens if it breaks?"**
> "Automated monitoring fires a Teams alert if any phase of the pipeline fails. There's a runbook — a step-by-step troubleshooting guide — for every failure scenario. And because everything is version-controlled, rolling back a bad change takes minutes."

**"Who else knows how this works?"**
> "That's actually one of the things the knowledge base addresses directly. The goal is that this isn't a single point of failure. The documentation, the version history, and the AI tooling all help with continuity."
