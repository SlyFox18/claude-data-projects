# Data Flow Diagram — Build Guide

> Build this in PowerPoint (or draw.io if preferred). One slide/canvas.
> Save as `data-flow-diagram.pptx` in this folder when done.
> Goal: readable from 10 feet away. Minimum 24pt labels.

---

## Layout

Three boxes, left to right, with arrows between them. Add the automation note below.

```
+--------------------+              +------------------------+              +----------------------+
|                    |              |                        |              |                      |
|   Equip            |   -------->  |   Central Data         |  -------->   |   Reports & Agents   |
|   (Source System)  |              |   Warehouse            |              |                      |
|                    |              |   (Microsoft Fabric)   |              |   25+ live reports   |
|                    |              |                        |              |   Ask any question   |
+--------------------+              +------------------------+              +----------------------+
```

**Arrow 1 label** (between Equip and Warehouse):
> "Every weekday · 4 AM · Automatic"

**Arrow 2 label** (between Warehouse and Reports):
> "Fresh by 6 AM · Ready when you are"

**Footer note** (below the diagram, centered, smaller font):
> "Monitored automatically. If anything fails, an alert fires to Teams before business hours."

---

## Style Guidance

- Box colors: use company colors or a clean neutral palette (light gray boxes, dark text)
- Arrows: thick, directional, easy to follow at a glance
- Box headings: bold, 28pt+
- Arrow labels: 18–20pt, italicized or in a secondary color
- Footer: 16pt, muted color
- Plenty of white space — don't crowd it

---

## PowerPoint SmartArt Shortcut

If you want a fast path:
1. Insert → SmartArt → Process → "Basic Chevron Process" or "Continuous Arrow Process"
2. Three items: "Equip (Source System)" / "Central Data Warehouse (Microsoft Fabric)" / "Reports & Agents"
3. Add a text box below for the footer note
4. Add arrow labels as separate text boxes over the connectors

---

## Build Checklist

- [ ] Three boxes with clear labels
- [ ] Two arrows with timing labels
- [ ] Footer monitoring note included
- [ ] Readable at 10 feet (large fonts)
- [ ] Saved as `data-flow-diagram.pptx`
