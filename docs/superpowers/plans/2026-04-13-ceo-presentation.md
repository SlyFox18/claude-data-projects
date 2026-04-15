# CEO Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build all presentation materials for a 30–45 minute CEO presentation covering the data platform built on Microsoft Fabric/Power BI — following the transformation arc (before → now → what's next).

**Architecture:** Four deliverables — a guiding slide deck, a business-friendly data flow diagram, a demo script with talking points and agent questions, and a presenter reference card. All materials live in `projects/executive centre - report/presentation/` (a neutral project folder already set up for this work).

**Tech Stack:** PowerPoint (slide deck), draw.io or PowerPoint SmartArt (diagram), Markdown (demo script and reference card)

**Spec:** [docs/superpowers/specs/2026-04-13-ceo-presentation-design.md](../specs/2026-04-13-ceo-presentation-design.md)

---

## File Map

| File | Purpose |
|------|---------|
| `projects/executive centre - report/presentation/CEO-Presentation.pptx` | Guiding slide deck (not a heavy deck — section headers, key messages, simple visuals) |
| `projects/executive centre - report/presentation/data-flow-diagram.pptx` | Standalone data flow diagram for Section 3 — source → warehouse → reports/agents |
| `projects/executive centre - report/presentation/DEMO-SCRIPT.md` | Full demo script: report order, talking points per report, agent questions, transitions |
| `projects/executive centre - report/presentation/PRESENTER-CARD.md` | One-page quick reference — section order, timing, key phrases, agent questions |
| `projects/executive centre - report/presentation/README.md` | Index of all materials, what each file is for, what's still TBD |

---

## Task 1: Set Up Presentation Folder

**Files:**
- Create: `projects/executive centre - report/presentation/README.md`

- [ ] **Step 1: Create the presentation folder**

```bash
mkdir -p "C:/Users/bfox/Documents/Git-Projects/data-projects/projects/executive centre - report/presentation"
```

- [ ] **Step 2: Create README index**

Create `projects/executive centre - report/presentation/README.md` with this content:

```markdown
# CEO Presentation Materials

**Status:** In progress
**Estimated runtime:** 36 minutes + Q&A
**Spec:** [Design doc](../../docs/superpowers/specs/2026-04-13-ceo-presentation-design.md)

## Files

| File | Purpose | Status |
|------|---------|--------|
| CEO-Presentation.pptx | Guiding slide deck | ⬜ Not started |
| data-flow-diagram.pptx | Section 3 data flow visual | ⬜ Not started |
| DEMO-SCRIPT.md | Full demo script with talking points | ⬜ Not started |
| PRESENTER-CARD.md | One-page quick reference | ⬜ Not started |

## Open Items

- [ ] Final report selection — pending input from corporate parts manager
- [ ] Slide deck review pass once reports are confirmed
- [ ] Practice run timing check

## Section Order (Quick Reference)

1. The Before (~4 min) — Equip limitations, manual work, bottlenecks
2. Reports + Agents (~15 min) — Live demo, HTML design callout, 2 agent demos
3. The Engine (~5 min) — Data flow diagram, automation, monitoring
4. How We Build It (~6 min) — AI, versioning, Fabric integration, knowledge base
5. What's Next (~6 min) — Broader rollout, branch security, apps, agents, roadmap
```

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/data-projects"
git add "projects/executive centre - report/presentation/README.md"
git commit -m "feat: scaffold CEO presentation folder"
```

---

## Task 2: Demo Script — Sections 1, 3, 4, 5 (No Report Dependency)

Write the full demo script for all sections except the live report walkthrough in Section 2 (which depends on final report selection). This unblocks the rest of the prep work.

**Files:**
- Create: `projects/executive centre - report/presentation/DEMO-SCRIPT.md`

- [ ] **Step 1: Create DEMO-SCRIPT.md**

Create `projects/executive centre - report/presentation/DEMO-SCRIPT.md`:

```markdown
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

> **NOTE: Report order and talking points TBD — see Task 3. Agent scripts below are complete.**

### HTML Design Callout
*(Weave this in during whichever report has the most visual polish — Customer Anatomy or similar)*

> "One thing worth pointing out — standard Power BI has limits on how things can look. By writing HTML directly into these visuals, we get full design control. Custom colors, badges, icons, conditional formatting you can't get with the built-in tools. It sounds like a small thing, but it's the difference between a report that looks like software and one that looks like a business tool."

---

### Agent Demo 1 — Service Agent
*(After the Inspections or service-related report)*

**Transition line:**
> "So those reports answer the questions we already knew to ask. But what about the question you just thought of in the last 30 seconds?"

**Action:** Open the Service Agent (in Power BI / Copilot interface — confirm exact location before presentation)

**Questions to ask live:**
1. *"Which branch has the most open work orders right now?"*
2. *"Show me inspections that have been open more than 30 days"*
3. *"What's the average turnaround time on work orders this month vs last month?"*

**If time allows:**
4. *"Which technician has the most open tickets?"*

**Talking point between questions:**
> "Notice it's not just returning a number — it understands the context of the data. It knows what a work order is, what a branch is, how dates work in our system."

---

### Agent Demo 2 — Parts & Invoice Agent
*(Separate beat, after reports)*

**Transition line:**
> "That agent was connected to all of our service reports. This next one works at a different level — not summarized reports, but the raw transaction data. Individual parts. Individual invoices."

**Action:** Open the Parts & Invoice Agent

**Questions to ask live:**
1. *"What are the top 10 parts by invoice volume this quarter?"*
2. *"Show me all invoices over $5,000 from the last 30 days"*
3. *"Which parts haven't had a single invoice in the last 6 months?"*

**If time allows:**
4. *"What's the average invoice value per customer for branch 5?"*

**Close Agent section:**
> "And we can build more of these. Connected to any combination of data in the system. This one took less than a day to set up once the data infrastructure was in place. That infrastructure is what makes it fast."

---

## SECTION 3 · The Engine (~5 min)

**Transition:**
> "Let me show you quickly what's actually running underneath all of this."

**Action:** Show the data flow diagram (data-flow-diagram.pptx or slide)

**Walk the diagram left to right:**
> "Data comes in from Equip — our source system — every morning starting at 4 AM. It flows into a central data warehouse in Microsoft Fabric. From there, it feeds every report and every agent you just saw."

**Key messages (say these, in this order):**
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
- Distribution options worth mentioning: Teams channel tabs, Power Apps, automated scheduled snapshots, embedded web apps

**Roadmap items (move through these at a pace that matches energy in the room):**
- More agents — financial, customer, cross-department. Any question, any dataset.
- Power Apps and web apps — custom tools built on this same data, accessible on a phone or tablet
- Self-serve — managers pull their own views, answer their own questions, without waiting on IT
- AI-driven insights — not just AI helping build things, but AI watching the data and surfacing anomalies automatically
- Expanded data sources — bringing external data (market, manufacturer, etc.) alongside operational data

**Closing line:**
> "Everything I showed you today runs on infrastructure we built over the last [X months/year]. The reason the roadmap items are achievable is because the hard part — the foundation — is done."

---

## Q&A Prep

Likely questions and suggested responses:

**"How long did this take to build?"**
> "The core infrastructure — the pipeline, the central data warehouse, the first wave of reports — took about [X months]. We've been adding to it continuously since."

**"What does this cost?"**
> "The platform runs on Microsoft Fabric, which is part of our Microsoft licensing. The AI tooling that helps build it is a separate subscription — [mention cost if comfortable]. The efficiency gains in development time have been significant."

**"Could other departments use this?"**
> "Yes — the architecture is designed for that. Adding a new data source or a new set of reports is much faster now than it was to build the first ones. The hardest work is already done."

**"What happens if it breaks?"**
> "Automated monitoring fires a Teams alert if any phase of the pipeline fails. There's a runbook — a step-by-step troubleshooting guide — for every failure scenario. And because everything is version-controlled, rolling back a bad change takes minutes."

**"Who else knows how this works?"**
> "That's actually one of the things the knowledge base addresses directly. The goal is that this isn't a single point of failure. The documentation, the version history, and the AI tooling all help with continuity."
```

- [ ] **Step 2: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/data-projects"
git add "projects/executive centre - report/presentation/DEMO-SCRIPT.md"
git commit -m "feat: add CEO presentation demo script (sections 1, 3, 4, 5 complete; section 2 reports TBD)"
```

---

## Task 3: Demo Script — Section 2 Report Walkthrough

**Prerequisite:** Final report selection from corporate parts manager.

**Files:**
- Modify: `projects/executive centre - report/presentation/DEMO-SCRIPT.md` (fill in Section 2 report block)

- [ ] **Step 1: Get final report list from parts manager**

Once confirmed, for each report create a block in DEMO-SCRIPT.md under SECTION 2 using this template:

```markdown
### [Report Name]

**Business question to open with:**
> "[One sentence — the question this report answers]"

**What to show/click:**
- [Slicer or filter to demonstrate first]
- [Key visual to point to]
- [Any drill-through or interaction worth showing]

**Talking point:**
> "[One or two sentences connecting what's on screen to a business decision]"

**Transition to next report:**
> "[One line bridge]"
```

- [ ] **Step 2: Confirm agent access points**

Before finalizing the script, verify:
- Service Agent: confirm exact URL or navigation path in Power BI Service / Teams
- Parts & Invoice Agent: confirm exact URL or navigation path
- Test all sample questions against live agents and adjust wording if any return unexpected results

- [ ] **Step 3: Update README status**

In `projects/executive centre - report/presentation/README.md`, update DEMO-SCRIPT.md status to ✅ Complete.

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/data-projects"
git add "projects/executive centre - report/presentation/DEMO-SCRIPT.md"
git add "projects/executive centre - report/presentation/README.md"
git commit -m "feat: complete demo script section 2 with confirmed report lineup"
```

---

## Task 4: Data Flow Diagram

A simple, business-friendly visual for Section 3. Three boxes, two arrows, plain English labels. No technical terms.

**Files:**
- Create: `projects/executive centre - report/presentation/data-flow-diagram.pptx`

- [ ] **Step 1: Build the diagram in PowerPoint**

Create a new PowerPoint file. On Slide 1, build this layout:

```
+------------------+        +----------------------+        +------------------+
|                  |        |                      |        |   Reports &      |
|   Equip          |  --->  |   Central Data       |  --->  |   Agents         |
|   (Source        |        |   Warehouse          |        |                  |
|    System)       |        |   (Microsoft Fabric) |        |   25+ reports    |
|                  |        |                      |        |   Ask anything   |
+------------------+        +----------------------+        +------------------+
```

Label the arrows:
- First arrow: "Every weekday, 4 AM — automatic"
- Second arrow: "Fresh by 6 AM — ready when you are"

Add a footer note: *"Monitored automatically. Alerts fire to Teams if anything fails."*

Style guidance: keep it clean, large font (24pt minimum), use company colors if available. This will be shown on a screen during a conversation — it needs to read from 10 feet away.

- [ ] **Step 2: Save and update README**

Save as `data-flow-diagram.pptx`. Update README status to ✅ Complete.

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/data-projects"
git add "projects/executive centre - report/presentation/data-flow-diagram.pptx"
git add "projects/executive centre - report/presentation/README.md"
git commit -m "feat: add data flow diagram for presentation section 3"
```

---

## Task 5: Guiding Slide Deck

A light deck — section headers and key messages only. Not a wall of bullets. The demo and conversation carry the content; the slides are visual anchors.

**Files:**
- Create: `projects/executive centre - report/presentation/CEO-Presentation.pptx`

- [ ] **Step 1: Build slide structure**

Create CEO-Presentation.pptx with these slides:

**Slide 1 — Title**
- Title: "Our Data Platform"
- Subtitle: "[Your name] · [Date]"

**Slide 2 — The Before**
- Header: "Where We Started"
- 3 bullet points (large font, short):
  - Manual reports. One bottleneck.
  - Equip answers operational questions. Not analytical ones.
  - Every data question had a queue.

**Slide 3 — The Now (transition into demo)**
- Header: "What We Built"
- Single line: "Let me show you."
- *(This slide is just a visual beat before switching to the live demo)*

**Slide 4 — The Engine (use alongside diagram)**
- Header: "It Runs Itself"
- 4 bullets:
  - Automated every weekday at 4 AM
  - 25+ reports ready before business hours
  - Monitored — alerts fire if anything fails
  - Every change tracked and reversible

**Slide 5 — How We Build It**
- Header: "How We Build & Maintain This"
- 5 bullets:
  - AI-assisted development — days become hours
  - Version control — every change recorded, anything reversible
  - Sandbox → production — tested before it goes live
  - Documented — not just in one person's head
  - Code-first — faster, auditable, repeatable

**Slide 6 — What's Next**
- Header: "Where This Goes"
- 2 grouped sections:
  - *Broader Rollout:* Right people, right data, right access — branch-level views, no extra licenses
  - *Platform Roadmap:* More agents · Apps · Self-serve · AI insights · More data sources

**Slide 7 — Close**
- Header: "The Foundation Is Done"
- Single line: "The hard part is behind us."

- [ ] **Step 2: Apply styling**

- Minimum 24pt body font throughout
- No more than 5 bullets per slide
- Remove any slide that doesn't add to the story — fewer slides is better
- If company PowerPoint template exists, apply it

- [ ] **Step 3: Update README**

Update CEO-Presentation.pptx status to ✅ Complete.

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/data-projects"
git add "projects/executive centre - report/presentation/CEO-Presentation.pptx"
git add "projects/executive centre - report/presentation/README.md"
git commit -m "feat: add CEO presentation slide deck"
```

---

## Task 6: Presenter Reference Card

A single-page quick reference to have open during the presentation. Not a script — just the skeleton to stay on time and not forget anything.

**Files:**
- Create: `projects/executive centre - report/presentation/PRESENTER-CARD.md`

- [ ] **Step 1: Create PRESENTER-CARD.md**

```markdown
# Presenter Quick Reference

| Section | Time | First words |
|---------|------|-------------|
| 1 · The Before | 4 min | "Before I show you what we've built..." |
| 2 · Reports + Agents | 15 min | "Here's what we built instead." |
| 3 · The Engine | 5 min | "Let me show you what's running underneath all of this." |
| 4 · How We Build It | 6 min | "The reports are the visible part. Here's how we build and maintain it." |
| 5 · What's Next | 6 min | "The foundation is solid. Here's where this goes." |

---

## Section 2 Checklist
- [ ] Report 1: _________________ → Business question: _________________
- [ ] Report 2: _________________ → Business question: _________________
- [ ] Report 3: _________________ → Business question: _________________
- [ ] Report 4: _________________ → Business question: _________________
- [ ] HTML design callout ← don't skip this
- [ ] Service Agent → "Which branch has the most open work orders right now?"
- [ ] Service Agent → "Show me inspections open more than 30 days"
- [ ] Parts Agent → "Top 10 parts by invoice volume this quarter"
- [ ] Parts Agent → "Invoices over $5,000 last 30 days"
- [ ] Close: "This one took less than a day to set up."

---

## Key Phrases (don't forget these)
- Section 1 close: *"So that's the before. Here's what we built instead."*
- After agent demo: *"We can build more of these — any question, any dataset."*
- Section 3: *"Nobody has to start this. It runs automatically while everyone's asleep."*
- Section 5 close: *"The hard part — the foundation — is done."*

---

## If It Goes Long
Cut in this order:
1. Trim Section 4 bullets (skip knowledge base and code-first if needed)
2. Show 3 reports instead of 4 in Section 2
3. Skip Parts Agent if Service Agent demo ran long

## If It Goes Short
Expand in this order:
1. Let Q&A start earlier — they'll have questions
2. Spend more time on one agent demo (deeper questions)
```

- [ ] **Step 2: Update README**

Update PRESENTER-CARD.md status to ✅ Complete.

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/data-projects"
git add "projects/executive centre - report/presentation/PRESENTER-CARD.md"
git add "projects/executive centre - report/presentation/README.md"
git commit -m "feat: add presenter reference card"
```

---

## Task 7: Practice Run

- [ ] **Step 1: Do a dry run solo** — talk through the full presentation out loud, timer running. Target: 32–38 minutes.
- [ ] **Step 2: Note anything that felt awkward** — update DEMO-SCRIPT.md with adjusted phrasing.
- [ ] **Step 3: Test all agent questions live** — run every sample question in both agents before the presentation day. Adjust wording for any that return unhelpful results.
- [ ] **Step 4: Confirm tech setup** — verify screen sharing works, agents are accessible, reports are fresh, diagram displays correctly at presentation resolution.
- [ ] **Step 5: Final commit**

```bash
cd "C:/Users/bfox/Documents/Git-Projects/data-projects"
git add -A
git commit -m "feat: finalize CEO presentation materials after practice run"
git push origin dev
```

---

## Completion Checklist

- [ ] Task 1: Folder scaffolded, README created
- [ ] Task 2: Demo script complete (Sections 1, 3, 4, 5)
- [ ] Task 3: Section 2 report walkthrough added (after parts manager confirms lineup)
- [ ] Task 4: Data flow diagram built
- [ ] Task 5: Slide deck built
- [ ] Task 6: Presenter reference card created
- [ ] Task 7: Practice run done, agents tested, tech confirmed
