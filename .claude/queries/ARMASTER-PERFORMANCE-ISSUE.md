# 7:30 AM Refresh Window Performance Issue Investigation

**SCOPE UPDATED:** Originally thought to be ArMaster-specific, now confirmed as systemic 7:30 AM timing issue

## 🚨 Issue Summary

**Status:** ACTIVE - Requires Urgent Investigation
**Priority:** HIGH (Scope expanded - affects multiple table families)
**Impact:** 200-400% increase in refresh times affecting F4 CU consumption
**Timeframe:** Last 2 weeks (approximately)
**Pattern:** Intermittent (today armaster 3:30 min, contact 4:23 min - both improved)
**Root Cause:** 7:30 AM weekday refresh window has systemic resource contention

---

## Affected Tables

**EXPANDED SCOPE:** Four tables confirmed (multiple table families, proving systemic issue):

| Table | Table Family | Rows | Historical Time | Current Time | Today's Time | Increase |
|-------|--------------|------|----------------|--------------|--------------|----------|
| ArMaster_Contact | ArMaster | 53,470 | 1-2 min | 6-8 min | Not recorded | 300-400% |
| ArMaster_Customer | ArMaster | 53,470 | 1-2 min | 6-8 min | Not recorded | 300-400% |
| armaster | ArMaster | 53,470 | 1-2 min | 6-7 min | 3:30 min (✓) | 200-350% |
| **contact** | **Contact** | **81,648** | **1:30-2 min** | **6-8 min** | **4:23 min (✓)** | **200-400%** |

**Key Finding:** contact table proves issue is NOT ArMaster-specific - it's a 7:30 AM timing window problem!

---

## Common Characteristics

### What's the Same Across All Three Tables:
- ✅ **Same row count:** ~53,470 rows
- ✅ **Same refresh schedule:** 7:30 AM weekdays only (no weekends)
- ✅ **Same refresh method:** Pipeline-driven (not standalone dataflows)
- ✅ **Same ODBC connection:** EquipRDB64 (SQL Anywhere)
- ✅ **Same timeframe:** Performance degraded in last 2 weeks
- ✅ **Same table family:** All ArMaster tables from source system
- ✅ **Query folding confirmed:** Queries do push to source database

### What's Different:
- ❌ **Not all tables constantly slow:** armaster showed improvement today (3:30 vs 6-7)
- ❌ **Suggests intermittent issue:** Not constant degradation, timing/resource dependent

---

## Root Cause Analysis

### Most Likely Causes (Priority Order):

#### 1. Data Gateway Issue (Most Likely)
**Evidence:**
- All tables use same ODBC connection via gateway
- All affected at same time
- Query folding works (not a Power Query issue)

**Investigation Steps:**
- [ ] Check gateway machine health (CPU, Memory, Disk, Network)
- [ ] Review gateway logs for errors/warnings during 7:30 AM window
- [ ] Check if gateway needs restart or updates
- [ ] Verify no competing workloads on gateway server
- [ ] Test gateway performance at different times of day

#### 2. SQL Anywhere Database Issue (Second Most Likely)
**Evidence:**
- All ArMaster tables specifically affected
- Same source database
- Intermittent nature (today's improvement)

**Investigation Steps:**
- [ ] Check SQL Anywhere database performance metrics
- [ ] Review query execution plans for ArMaster tables
- [ ] Verify indexes on ArMaster tables
- [ ] Check if database statistics need updating
- [ ] Look for blocking queries or table locks at 7:30 AM
- [ ] Verify no database maintenance running at 7:30 AM
- [ ] Check SQL Anywhere server resource usage

#### 3. Timing/Resource Contention (Third Most Likely)
**Evidence:**
- All tables refresh at same time (7:30 AM weekdays)
- Intermittent nature (some days worse than others)
- Pipeline-driven (multiple tables competing)

**Investigation Steps:**
- [ ] Document all processes running at 7:30 AM
- [ ] Check if ArMaster tables run in sequence or parallel
- [ ] Test one table at different time (e.g., 10 AM) to isolate
- [ ] Review what else runs at 7:30 AM (other pipelines, dataflows)
- [ ] Check if other users/processes access source DB at 7:30 AM

#### 4. Network Issue (Less Likely but Possible)
**Evidence:**
- ODBC connection relies on network
- Could explain intermittent nature

**Investigation Steps:**
- [ ] Test network latency during 7:30 AM window
- [ ] Compare network performance at different times
- [ ] Check for network changes in last 2 weeks
- [ ] Verify no firewall or routing changes

#### 5. Infrastructure Change (Less Likely)
**Evidence:**
- Issue started ~2 weeks ago

**Investigation Steps:**
- [ ] Check for any infrastructure changes in last 2 weeks
- [ ] Verify ODBC driver version (check if updated)
- [ ] Check if gateway server was patched/updated
- [ ] Review Fabric capacity changes or updates

---

## Business Impact

### CU Consumption Impact:
**Current waste per week (all 3 tables):**
- ArMaster_Contact: 5-6 min extra × 5 days = 25-30 min/week wasted
- ArMaster_Customer: 5-6 min extra × 5 days = 25-30 min/week wasted
- armaster: 4-5 min extra × 5 days = 20-25 min/week wasted
- **Total: 70-85 minutes/week wasted CU consumption**

**If issue affects more tables:** CU impact could be even larger

### Pipeline Timing Impact:
- 7:30 AM pipeline may delay downstream processes
- If multiple tables slow, entire pipeline timing breaks down
- May affect report availability for business users

---

## Optimization Opportunities (Independent of Root Cause)

### Opportunity 1: Reduce Refresh Frequency
**Business Question:** Do ArMaster tables really need daily refresh?

**AR data typically changes:**
- As invoices are created/paid throughout day
- Aging buckets recalculate daily
- But AR reporting often monthly or weekly

**Options:**
- **Weekly refresh:** 80% CU savings (5 days → 1 day)
- **Bi-weekly refresh:** 90% CU savings
- **End-of-month refresh:** 95% CU savings (if AR reporting is monthly)

**Action:** Validate refresh frequency requirement with business users

### Opportunity 2: Implement Incremental Refresh
**Good News:** Both ArMaster_Customer and armaster have ModifiedDate fields!

**Expected Results:**
- Current: 6-8 minutes full refresh
- After: <1 minute for typical daily changes (only load modified records)
- Savings: 85-90% CU reduction even with daily refresh

**Implementation:**
1. Add RangeStart/RangeEnd parameters
2. Add WHERE ModifiedDate >= RangeStart AND ModifiedDate < RangeEnd
3. Configure incremental refresh policy in Power BI

**Action:** Implement incremental refresh for ArMaster_Customer and armaster

### Opportunity 3: Consolidate Refreshes
**Idea:** If tables always refresh together, consider consolidating

**Options:**
- Combine multiple ArMaster tables into single dataflow (if feasible)
- Stagger refresh times within pipeline to reduce contention
- Move to different time slot if 7:30 AM has conflicts

**Action:** Review pipeline structure and optimize sequencing

---

## Investigation Roadmap

### Phase 1: Quick Wins (This Week)
1. **Business Validation:**
   - [ ] Confirm daily refresh requirement with business users
   - [ ] If not daily: Change to weekly (immediate 80% CU savings)

2. **Timing Test:**
   - [ ] Test one ArMaster table at 10 AM instead of 7:30 AM
   - [ ] Compare refresh time to isolate timing issue
   - [ ] Document results

3. **Gateway Health Check:**
   - [ ] Review gateway logs during 7:30 AM window
   - [ ] Check gateway resource usage
   - [ ] Verify no errors or warnings

### Phase 2: Root Cause Investigation (Next 2 Weeks)
1. **Source System Analysis:**
   - [ ] Check SQL Anywhere ArMaster table indexes
   - [ ] Review database statistics and query plans
   - [ ] Look for blocking queries at 7:30 AM
   - [ ] Test direct queries in SQL Anywhere

2. **Network & Infrastructure:**
   - [ ] Test network latency during 7:30 AM
   - [ ] Check for infrastructure changes
   - [ ] Verify ODBC driver version

3. **Pipeline Review:**
   - [ ] Document all 7:30 AM processes
   - [ ] Check for resource contention
   - [ ] Review pipeline execution logs

### Phase 3: Implement Fixes (Week 3-4)
1. **If Root Cause Found:**
   - [ ] Fix gateway/source/network issue
   - [ ] Verify refresh times return to 1-2 minutes
   - [ ] Monitor for 1 week to ensure stable

2. **Implement Incremental Refresh:**
   - [ ] Add to ArMaster_Customer (has ModifiedDate)
   - [ ] Add to armaster (has ModifiedDate)
   - [ ] Check if ArMaster_Contact has ModifiedDate
   - [ ] Test and validate incremental loads

3. **Optimize Pipeline:**
   - [ ] Adjust refresh schedule if needed
   - [ ] Stagger table refreshes
   - [ ] Implement refresh frequency changes from business validation

---

## Monitoring & Validation

### What to Track:
- Daily refresh times for all 3 ArMaster tables
- Gateway health metrics during 7:30 AM window
- SQL Anywhere database performance
- CU consumption for pipeline
- Business user feedback on data freshness

### Success Metrics:
- **Short-term:** Understand root cause
- **Medium-term:** Refresh times back to 1-2 minutes (or less with incremental)
- **Long-term:** Optimized refresh frequency based on business needs
- **CU Impact:** 70-85 minutes/week reclaimed (or more with optimizations)

---

## Next Actions

### Immediate (Today):
1. Share this document with team
2. Start gateway health check
3. Schedule business validation meeting

### This Week:
1. Execute Phase 1 investigation
2. Test one table at different time
3. Document findings

### Next 2 Weeks:
1. Complete root cause investigation
2. Begin implementing fixes
3. Implement incremental refresh

---

## Related Documentation

- [ArMaster_Contact.pq](raw-tables/ArMaster_Contact.pq) - Full query documentation
- [ArMaster_Customer.pq](raw-tables/ArMaster_Customer.pq) - Full query documentation
- [armaster.pq](raw-tables/armaster.pq) - Full query documentation
- [REFRESH-TIMES.md](REFRESH-TIMES.md) - All table refresh times tracking

---

**Document Created:** January 14, 2026
**Last Updated:** January 14, 2026
**Status:** Active Investigation
**Owner:** Brian Fox
