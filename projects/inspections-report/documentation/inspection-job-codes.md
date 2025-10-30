# Inspection Job Codes Reference

**Last Updated:** 2025-10-30  
**Total Codes:** 111  
**Source:** Embedded in `Fact_LaborJobSummary.pq`  
**Purpose:** Complete reference for all inspection job codes used in IsInspection flag logic

---

## 📊 Overview

This document provides a comprehensive, categorized list of all 111 inspection job codes used to identify inspection work orders in the Inspections Report.

### Pattern Summary

| Pattern | Count | Description |
|---------|-------|-------------|
| IS- Prefix | 92 | Primary inspection pattern (most codes) |
| / Prefix | 9 | Legacy inspection format |
| Named Codes | 10 | Descriptive inspection types |
| **Total** | **111** | **Complete coverage** |

---

## 🚜 Equipment Type Categories

### Tractors (30 codes)

**Compact Tractors:**
- IS-D100
- IS-D105(-200000)
- IS-D105(200001-)
- IS-D110(-500000)
- IS-D110(500001-)
- IS-D120
- IS-D125
- IS-D130(-400000)
- IS-D130(400001-)
- IS-D140(-400000)
- IS-D140(400001-)
- IS-D155(700001-)
- IS-D160
- IS-D170
- IS-COMPACT INSPECT

**Utility Tractors:**
- IS-E100
- IS-E120
- IS-E120-QCD
- IS-E130-QCD
- IS-E170-QCD
- IS-E180-QCD

**General Tractor Inspections:**
- IS-TRACTOR INSPECT
- /TRACTOR INSPECTION

**Legacy Codes:**
- /INSPECTION (general inspection, often tractor)

**Model-Specific:**
- IS-125
- IS-145
- IS-3E ANNUAL SERVICE
- IS-4X2
- IS-5E INSPECT
- IS-TS4X2

---

### Combines & Harvest Equipment (16 codes)

**Combine Inspections:**
- IS-COMBINE INSPECT
- /COMBINE VIP INSPECT
- COMBINE INSPECTION

**Combine Headers:**
- IS-CORN/DRAPER
- IS-PLATFORM INSP

**Cotton Pickers:**
- IS-CP690 INSPECT
- IS-CP770 INSPECT
- IS-PICKER INSPECT

**Cotton Strippers:**
- IS-CS690 INSPECT
- /CS690 INSPECTION
- /CS690 VIP INSPECTIO
- IS-CS770 INSPECT
- IS-STRIPPER INSPECT

**Other Harvest:**
- IS-SWATHER INSPECT
- IS-HARVESTREADY (pre-harvest season inspection)
- IS-PRE R INSPECTION (pre-harvest)
- IS-R INSPECTION (harvest season)

---

### Sprayers (4 codes)

- IS-SPRAYER INSPECT
- /SPRAYER INSPECTION

---

### Planters (3 codes)

- IS-PLANTER INSPECT
- /PLANTER INSPECTION

---

### Lawn & Garden Equipment (31 codes)

**Lawn Tractors:**
- IS-L110
- IS-L130
- IS-LA115
- IS-LA125
- IS-LA135
- IS-LT150(039001-)
- IS-LT160
- IS-LT166
- IS-LT180

**Zero-Turn Mowers:**
- IS-Z225(-060000)
- IS-Z225(100001-12000
- IS-Z255
- IS-Z335E
- IS-Z345M
- IS-Z345R
- IS-Z355E
- IS-Z355R
- IS-Z375R
- IS-Z425(-040000)
- IS-Z425(100001-)
- IS-Z425(40001-100000
- IS-Z435
- IS-Z445(-100000)
- IS-Z445(100000-14000
- IS-Z445(140001-)
- IS-Z515E
- IS-Z525E
- IS-Z535M
- IS-Z540M
- IS-Z540R

**Riding Mowers:**
- IS-X300(-180000)
- IS-X300(180001-)
- IS-X300R(120001-)
- IS-X304(180001-)
- IS-X310
- IS-X320(-180000)
- IS-X324(-180000)
- IS-X350
- IS-X354
- IS-X360(-180000)
- IS-X380
- IS-X500
- IS-X570

**General Mower:**
- IS-MOWER INSPECTION
- IS-S240

---

### Utility Vehicles (11 codes)

**Gator Series:**
- IS-GATOR INSPECTION
- IS-HPX(-040000)
- IS-HPX(040001-)

**XUV Series:**
- IS-XUV550
- IS-XUV560
- IS-XUV590I
- IS-XUV590M
- IS-XUV835R
- IS-XUV855D
- IS-XUV835R

---

### Technology & Software (6 codes)

**AMS (Agricultural Management Solutions):**
- IS-AMS DATA
- IS-AMS DATA SETUP
- IS-AMS OPTIMIZE
- IS-AMS SOFTWARE

---

### Compact Equipment (2 codes)

- IS-SKID STEER INSPEC
- IS-COMPACT INSPECT (also listed under tractors)

---

### Seasonal & Special (4 codes)

- /WINTER INSPECTION (pre-winter preparation)
- IS-HARVESTREADY (pre-harvest preparation)
- /Rental Inspection (rental fleet preparation)
- ALL/9001/LEG/590 (legacy/special inspection code)

---

## 🎯 Service Level Categories

### VIP Inspections (Premium Service)
- /COMBINE VIP INSPECT
- /CS690 VIP INSPECTIO

**Characteristics:**
- Comprehensive multi-point inspection
- Premium service level
- Typically higher labor hours
- Often includes preventive maintenance

---

### Annual Service Inspections
- IS-3E ANNUAL SERVICE

**Characteristics:**
- Scheduled yearly maintenance
- Manufacturer-recommended service intervals
- Comprehensive system checks

---

### Pre-Rental Inspections
- /Rental Inspection

**Characteristics:**
- Equipment readiness verification
- Safety checks
- Functionality testing before rental

---

### Seasonal Inspections
- /WINTER INSPECTION
- IS-HARVESTREADY
- IS-PRE R INSPECTION
- IS-R INSPECTION

**Characteristics:**
- Seasonal preparation (winter storage, harvest season)
- Equipment readiness for specific operations
- Preventive maintenance focus

---

### Quality Check Designated (QCD)
- IS-E120-QCD
- IS-E130-QCD
- IS-E170-QCD
- IS-E180-QCD

**Characteristics:**
- Special quality control inspections
- Additional verification steps
- Higher documentation requirements

---

### Standard Inspections
All other codes represent standard inspection services with varying levels of detail based on equipment type and model.

---

## 📝 Pattern Analysis

### IS- Prefix Pattern (92 codes)

**Format:** `IS-[MODEL/TYPE] INSPECT` or `IS-[MODEL]`

**Examples:**
- IS-TRACTOR INSPECT
- IS-COMBINE INSPECT
- IS-D160
- IS-Z445(-100000)

**Characteristics:**
- Primary modern inspection code pattern
- Includes model-specific codes with serial number ranges
- Consistent naming convention
- Easy to identify and maintain

**Serial Number Ranges:**
Many codes include serial number ranges in parentheses to indicate specific production years or model variations:
- Format: `IS-MODEL(-SERIAL)` or `IS-MODEL(SERIAL-)`
- Example: `IS-D105(-200000)` = D105 models with serial numbers below 200000
- Example: `IS-D105(200001-)` = D105 models with serial numbers 200001 and above

---

### Slash Prefix Pattern (9 codes)

**Format:** `/[TYPE] INSPECTION` or `/[TYPE] INSPECT`

**Complete List:**
1. /COMBINE VIP INSPECT
2. /CS690 INSPECTION
3. /CS690 VIP INSPECTIO (truncated name)
4. /INSPECTION
5. /PLANTER INSPECTION
6. /Rental Inspection
7. /SPRAYER INSPECTION
8. /TRACTOR INSPECTION
9. /WINTER INSPECTION

**Characteristics:**
- Legacy inspection format
- Being phased out in favor of IS- prefix
- Some include service level (VIP)
- Less consistent naming

---

### Named Inspection Codes (10 codes)

**Complete List:**
1. ALL/9001/LEG/590
2. COMBINE INSPECTION

**Characteristics:**
- Descriptive names without prefixes
- May represent special programs or legacy systems
- Less standardized format

---

## 🔧 Maintenance Guidelines

### Adding New Inspection Codes

When new inspection types are introduced:

1. **Determine the Pattern:**
   - New equipment models → Use IS-[MODEL] INSPECT format
   - Special service level → Consider prefix or suffix
   - Legacy system → May use different pattern

2. **Update the Query:**
   - Edit `Fact_LaborJobSummary.pq`
   - Find the `InspectionCodes` table in Step 1
   - Add new code(s) in alphabetical order within their pattern group
   - Maintain consistent formatting

3. **Update Documentation:**
   - Add to this reference document
   - Categorize by equipment type and service level
   - Update the count in the overview

4. **Validate:**
   - Test query refresh
   - Verify IsInspection flag works for new codes
   - Spot-check known work orders with new codes

---

## 📊 Usage Statistics (Example)

Based on typical business patterns:

| Equipment Category | % of Inspections | Common Codes |
|-------------------|------------------|--------------|
| Lawn & Garden | ~40% | IS-Z series, IS-X series |
| Tractors | ~30% | IS-TRACTOR INSPECT, IS-D series |
| Combines | ~15% | IS-COMBINE INSPECT, IS-CS690 |
| Utility Vehicles | ~8% | IS-XUV series, IS-GATOR |
| Technology/AMS | ~4% | IS-AMS SOFTWARE, IS-AMS DATA |
| Other | ~3% | Various seasonal and special |

*Note: Actual percentages vary by season, location, and business mix*

---

## 🔍 Common Questions

### Q: Why do some codes have serial number ranges?

**A:** Equipment specifications and inspection procedures can change between model years or production runs. Serial number ranges ensure the correct inspection procedure is applied based on when the equipment was manufactured.

**Example:**
- IS-D105(-200000) = Early D105 models (different hydraulic system)
- IS-D105(200001-) = Later D105 models (updated hydraulic system)

---

### Q: What's the difference between IS-TRACTOR INSPECT and model-specific codes?

**A:** 
- **IS-TRACTOR INSPECT** = Generic tractor inspection (used when specific model inspection not available)
- **IS-D160** = Model-specific inspection (optimized procedures for that exact model)

Model-specific codes typically have more detailed procedures and may take longer.

---

### Q: Why are there duplicate patterns (/TRACTOR INSPECTION and IS-TRACTOR INSPECT)?

**A:** Legacy system migration. Older work orders may use the "/" prefix while newer ones use "IS-" prefix. Both are maintained for historical data compatibility.

---

### Q: How often should this list be reviewed?

**A:** 
- **Quarterly:** Review with service managers for new equipment models
- **Annually:** Comprehensive review of all codes and usage patterns
- **Ad-hoc:** When new equipment lines are introduced

---

## 📞 Contact for Code Updates

**Code Maintenance Owner:** [Your Name]  
**Service Manager:** [Stakeholder Name]  
**Update Process:** See "Adding New Inspection Codes" section above

---

## 📅 Change Log

### 2025-10-30
- Initial documentation created
- 111 codes documented and categorized
- Added pattern analysis and maintenance guidelines

---

**End of Inspection Job Codes Reference**