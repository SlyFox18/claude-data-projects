# tools/dp-migration/nonjd_reorder_check.py
"""
Non-JD Parts Order Tool: independent check of Fact_NonJD_Reorder.

Re-implements the reorder rules in DuckDB SQL over the same inputs, then compares row by row with the Gold table
Build_Gold_NonJD_Reorder wrote. The rules are Plan C round 1 (docs/superpowers/plans/2026-10-26-non-jd-parts-order-
tool-round-1.md, "The calculation", "Validation" and decisions D13/D14), built on spec 2026-10-20 section 5.5: demand-count stocking
(MinDemands), supply in weeks or months, the Equip minimum always applying, a target of 0 meaning order 0, excluded
branches, line value limits, a mask that ends at the next demand, Manual Order and archived rules. Round 2 Part 1
(spec docs/superpowers/specs/2026-10-27-non-jd-parts-order-tool-round-2-design.md, "The calculation" Part 1 and
"Validation"; plan 2026-10-27-...-round-2-phase-2.md Task E2) adds the A11 rule criteria (SLC, Source, VendorCode,
ProductGroup, CommodityCode), phase-in (step 7b, A18/A19), the phase-in target (step 8), committed app transfers
(step 8b, A14) and their subtraction from the base quantity (step 9). Also prints a fingerprint of the Gold table
(excluding BuiltAtUtc) for run-twice determinism checks, and lists the rules and part settings that are skipped as
invalid.

Usage:
    python nonjd_reorder_check.py --tier dev            # compare, exit 1 on any mismatch
    python nonjd_reorder_check.py --tier dev --fingerprint-only

Run straight after the DP refresh: Silver inputs are read live, so an intraday refresh between the Gold build
and this check causes false mismatches. The round 1 and round 2 list columns (MinDemands, SupplyUnit, MinLineValue,
MaxLineValue, Archived, ManualOrder, MaskedOn; the five criteria; PhaseInQty, PhaseInEnds, PhaseInOn) are read when
the staging tables have them and are NULL otherwise; with no MinDemands every list rule is invalid and the built-in
default applies. A missing NonJD_Transfers table reads as no committed transfers. When Gold lacks some output
columns the check still compares the ones it has, then FAILs.

Auth: Azure CLI (az login as Brian), read-only.
"""
import argparse
import os
import sys
import tempfile
from datetime import date, timezone
from zoneinfo import ZoneInfo

import duckdb

TIERS = {
    "dev": {"staging": ("ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "876255e0-d462-4697-adc1-4a655f5bb101"),
            "presentation": ("73fd5443-240e-410a-990a-98827f32c087", "966efc8a-16f9-423b-aa43-e368fcd8fb91")},
    "prod": {"staging": ("189e5c0a-548a-4feb-93d6-dda9ebbe96c1", "6713bd45-a4ad-47e6-8bff-1bb0415e9784"),
             "presentation": ("7836042d-adb1-4846-b70d-bd42980054c5", "29d9df80-a383-4d40-9807-1e2e6cbff88f")},
}
# Applies when no valid active rule matches a part (step 1). No line value limits.
BUILTIN_DEFAULT = {"RuleName": "Built-in default", "HistoryMonths": 12, "MinDemands": 3, "Supply": 12.0,
                   "SupplyUnit": "Weeks", "DemandBasis": "UnitsSold"}
# Left out of every output (D6); compared trimmed and upper-case.
EXCLUDED_BRANCHES = ["12", "5", "97", "4B", "93C"]
HIST_MONTHS = 60          # Silver_PartSalesHistory depth; HistoryMonths is at most 59
WEEKS_MAX, MONTHS_MAX = 104, 24
# Every output column except the key is compared: these exactly (null-safe), the float ones with a tolerance
# (NULL against a value is still a mismatch; see _diff_where).
COMPARE_COLS = ["RuleId", "RuleName", "DemandBasis", "HistoryMonths", "MinDemands", "SupplyUnit", "DemandCount",
                "ActiveMonths", "CalcTarget", "MinimumNoDemand", "StockingTarget", "ValueCapped", "BelowMinValue",
                "ManualOrder", "MaskedOn", "IsMasked", "RecommendedOrderQty", "SurplusQty", "Status",
                "SLC", "Source", "CommodityCode", "PhaseInQty", "PhaseInEnds", "PhaseInOn", "PhaseInActive",
                "PhaseInEndReason", "AppInboundQty", "AppOutboundQty"]
TOLERANCE_COLS = ["Supply", "SupplyMonths", "MinLineValue", "MaxLineValue", "WindowDemand", "UnitsSoldWindow",
                  "MonthlyRate",
                  "EffectiveMin", "InboundTransferQty", "PendingQty"]
TOLERANCE = 1e-6
OUTPUT_COLS = ["Branch", "Franchise", "PartNumber", "RuleId", "RuleName", "DemandBasis", "HistoryMonths",
               "MinDemands", "SupplyUnit", "Supply", "SupplyMonths", "MinLineValue", "MaxLineValue",
               "WindowDemand", "UnitsSoldWindow", "DemandCount", "ActiveMonths", "MonthlyRate", "CalcTarget", "EffectiveMin",
               "MinimumNoDemand", "StockingTarget", "ValueCapped", "BelowMinValue", "ManualOrder", "MaskedOn",
               "IsMasked", "RecommendedOrderQty", "SurplusQty", "InboundTransferQty", "Status",
               # round 2 Part 1
               "PendingQty", "SLC", "Source", "CommodityCode", "PhaseInQty", "PhaseInEnds", "PhaseInOn",
               "PhaseInActive", "PhaseInEndReason", "AppInboundQty", "AppOutboundQty"]
KEYS = "Branch, Franchise, PartNumber"

# Staging columns read by main(): (required, optional {name: type}). Optional ones are the round 1 and round 2
# additions, NULL until the dataflows carry them (Plan C Task C2, Plan E Task E1).
RULE_COLS = (["Id", "RuleName", "Priority", "Active", "Franchise", "DealerGroupCode", "Branch", "StartMonth",
              "EndMonth", "HistoryMonths", "WeeksOfCover", "DemandBasis"],
             {"MinDemands": "DOUBLE", "SupplyUnit": "VARCHAR", "MinLineValue": "DOUBLE", "MaxLineValue": "DOUBLE",
              "Archived": "BOOLEAN", "SLC": "VARCHAR", "Source": "VARCHAR", "VendorCode": "VARCHAR",
              "ProductGroup": "VARCHAR", "CommodityCode": "VARCHAR"})
SETTINGS_COLS = (["Id", "Branch", "Franchise", "PartNumber", "MinOverride", "Masked", "MaskExpires", "Modified"],
                 {"ManualOrder": "BOOLEAN", "MaskedOn": "DATE", "PhaseInQty": "DOUBLE", "PhaseInEnds": "DATE",
                  "PhaseInOn": "DATE"})
# NonJD_Transfers (df_NonJD_Transfers_Raw: one row per transfer line joined to its header; Cancelled and Placed
# more than 30 days ago already filtered out). Created empty with this schema when the table doesn't exist yet.
APP_TRANSFER_COLS = {"TransferId": "BIGINT", "Status": "VARCHAR", "PlacedAt": "TIMESTAMPTZ", "FromBranch": "VARCHAR",
                     "ToBranch": "VARCHAR", "LineId": "BIGINT", "Franchise": "VARCHAR", "PartNumber": "VARCHAR",
                     "Qty": "DOUBLE", "Kind": "VARCHAR", "Created": "TIMESTAMPTZ"}
CENTRAL = "America/Chicago"
PHASE_IN_MAX = 99999


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.year * 12 + (d.month - 1) + n, 12)
    return date(y, m + 1, 1)


def columns(con, source: str) -> set:
    """Column names of `source` (a table name or a delta_scan(...) call)."""
    return {r[0] for r in con.execute(f"DESCRIBE SELECT * FROM {source}").fetchall()}


def select_list(con, source: str, required: list, optional: dict, have: set = None) -> str:
    """SELECT list over `source` (a table name or a delta_scan(...) call): the required columns (ValueError if
    one is missing), then each optional column cast to its declared type (MaskedOn may arrive as a timestamp), or
    a typed NULL under its name when the source lacks it. `have` = the source's columns, if already known."""
    have = columns(con, source) if have is None else have
    missing = [c for c in required if c not in have]
    if missing:
        raise ValueError(f"{source} is missing column(s): {', '.join(missing)}")
    return ", ".join(required + [f"CAST({c if c in have else 'NULL'} AS {t}) AS {c}" for c, t in optional.items()])


def _whole_between(col: str, lo: int, hi: int) -> str:
    # NaN and +-inf fail (DuckDB sorts NaN above every number, so BETWEEN is false)
    return f"({col} = floor({col}) AND {col} BETWEEN {lo} AND {hi})"


def _non_negative(col: str) -> str:
    # isfinite: DuckDB sorts NaN above every number, so NaN >= 0 would pass on its own
    return f"(isfinite({col}) AND {col} >= 0)"


# Active, not archived rules of NonJD_OrderRules with a display name and their problems ('' = valid). SharePoint
# numbers arrive as doubles, so "whole number" is checked explicitly. Inactive (Active false or NULL) and archived
# (Archived true) rules are ignored entirely: neither matched nor reported. A blank or missing name shows as
# "Rule <Id>". concat_ws skips NULLs, so every problem of a rule is listed. MinActiveMonths is left in the list
# unused (D1) and is not checked. The Supply amount lives in the WeeksOfCover column; its range follows SupplyUnit
# (blank = Weeks) and is only checked when the unit itself is valid. MinLineValue <= MaxLineValue is only checked
# when both are valid.
RULE_CHECK_CTE = f"""
    rule_check AS (
        SELECT *,
               coalesce(nullif(trim(RuleName), ''), 'Rule ' || CAST(CAST(Id AS BIGINT) AS VARCHAR)) AS RuleLabel,
               concat_ws('; ',
                 CASE WHEN Priority IS NULL THEN 'Priority is missing' END,
                 CASE WHEN HistoryMonths IS NULL THEN 'HistoryMonths is missing'
                      WHEN NOT {_whole_between('HistoryMonths', 1, 59)}
                      THEN 'HistoryMonths must be a whole number 1-59' END,
                 CASE WHEN MinDemands IS NULL THEN 'MinDemands is missing'
                      WHEN NOT {_whole_between('MinDemands', 0, 9999)}
                      THEN 'MinDemands must be a whole number 0-9999' END,
                 CASE WHEN coalesce(upper(trim(SupplyUnit)), '') NOT IN ('', 'WEEKS', 'MONTHS')
                      THEN 'SupplyUnit must be Weeks or Months'
                      WHEN WeeksOfCover IS NULL THEN 'Supply is missing'
                      WHEN upper(trim(SupplyUnit)) = 'MONTHS' AND NOT (WeeksOfCover BETWEEN 0 AND {MONTHS_MAX})
                      THEN 'Supply must be 0-{MONTHS_MAX} months'
                      WHEN coalesce(upper(trim(SupplyUnit)), '') <> 'MONTHS'
                           AND NOT (WeeksOfCover BETWEEN 0 AND {WEEKS_MAX})
                      THEN 'Supply must be 0-{WEEKS_MAX} weeks' END,
                 CASE WHEN MinLineValue IS NOT NULL AND NOT {_non_negative('MinLineValue')}
                      THEN 'MinLineValue must be 0 or more' END,
                 CASE WHEN MaxLineValue IS NOT NULL AND NOT {_non_negative('MaxLineValue')}
                      THEN 'MaxLineValue must be 0 or more' END,
                 CASE WHEN {_non_negative('MinLineValue')} AND {_non_negative('MaxLineValue')}
                           AND MinLineValue > MaxLineValue
                      THEN 'MinLineValue must not be more than MaxLineValue' END,
                 CASE WHEN (StartMonth IS NULL) <> (EndMonth IS NULL)
                      THEN 'StartMonth and EndMonth must both be set or both blank' END,
                 CASE WHEN StartMonth IS NOT NULL AND NOT {_whole_between('StartMonth', 1, 12)}
                      THEN 'StartMonth must be a whole number 1-12' END,
                 CASE WHEN EndMonth IS NOT NULL AND NOT {_whole_between('EndMonth', 1, 12)}
                      THEN 'EndMonth must be a whole number 1-12' END,
                 CASE WHEN coalesce(upper(trim(DemandBasis)), '') NOT IN ('UNITSSOLD', 'REQUESTS')
                      THEN 'DemandBasis must be UnitsSold or Requests' END
               ) AS problems
        FROM order_rules
        WHERE coalesce(Active, false) AND NOT coalesce(Archived, false)
    )"""

INVALID_RULES_SQL = f"""
    WITH {RULE_CHECK_CTE}
    SELECT Id, RuleLabel, problems FROM rule_check WHERE problems <> '' ORDER BY Id
"""

# The app's settings, latest row per part (Modified desc, then Id desc), with its problems ('' = valid). Only the
# row in use is checked. An invalid PhaseInQty (not a whole number 1-99999; NaN and +-inf fail too) is ignored:
# the reference reads it as NULL (phase_qty), while PhaseInEnds and PhaseInOn are still output as stored.
SETTINGS_CHECK_CTE = f"""
    part_settings AS (
        SELECT * EXCLUDE (rn),
               CASE WHEN {_whole_between('PhaseInQty', 1, PHASE_IN_MAX)} THEN CAST(PhaseInQty AS INTEGER) END
                 AS phase_qty,
               concat_ws('; ',
                 CASE WHEN PhaseInQty IS NOT NULL AND NOT {_whole_between('PhaseInQty', 1, PHASE_IN_MAX)}
                      THEN 'PhaseInQty must be a whole number 1-{PHASE_IN_MAX}' END
               ) AS problems
        FROM (SELECT *, row_number() OVER (PARTITION BY Branch, Franchise, PartNumber
                                           ORDER BY Modified DESC, Id DESC) AS rn
              FROM settings)
        WHERE rn = 1
    )"""

INVALID_SETTINGS_SQL = f"""
    WITH {SETTINGS_CHECK_CTE}
    SELECT Id, Branch, Franchise, PartNumber, problems FROM part_settings WHERE problems <> ''
    ORDER BY Id, Branch, Franchise, PartNumber
"""

_EXCLUDED_SQL = ", ".join(f"'{b}'" for b in EXCLUDED_BRANCHES)

# Parameters: $cur = first day of the run's Central-time month, $today = the run's Central date.
# Every value that is ceil'd or floor'd is first rounded to 9 decimals (round9), so double noise such as
# (5 / 3) * 5.2 * 12 / 52 = 2.0000000000000004 gives 2, not 3. Line values (qty x cost) are compared rounded to
# 9 decimals too, so 3 x 0.1 is not "more than 0.3". Build_Gold_NonJD_Reorder and the app engine do the same.
EXPECTED_SQL = f"""
    WITH {RULE_CHECK_CTE},
    {SETTINGS_CHECK_CTE},
    -- scope: non-JD parts with a cost, at the included branches (D6). NULL franchise or branch drops out.
    in_scope_parts AS (
        SELECT * FROM parts
        WHERE Cost > 0
          AND upper(trim(Franchise)) NOT IN ('D', 'ZP', 'S', '95')
          AND NOT starts_with(upper(trim(Franchise)), 'T')
          AND NOT starts_with(upper(trim(Franchise)), 'U')
          AND upper(trim(Branch)) NOT IN ({_EXCLUDED_SQL})
    ),
    -- step 1: valid active rules in season this month (wrapping ranges such as 11-2 included)
    usable_rules AS (
        SELECT Id, RuleLabel, Priority,
               nullif(upper(trim(Franchise)), '') AS c_franchise,
               nullif(upper(trim(DealerGroupCode)), '') AS c_dgc,
               nullif(upper(trim(Branch)), '') AS c_branch,
               nullif(upper(trim(SLC)), '') AS c_slc,
               nullif(upper(trim(Source)), '') AS c_source,
               nullif(upper(trim(VendorCode)), '') AS c_vendor,
               nullif(upper(trim(ProductGroup)), '') AS c_pg,
               nullif(upper(trim(CommodityCode)), '') AS c_cc,
               CAST(HistoryMonths AS INTEGER) AS hm, CAST(MinDemands AS INTEGER) AS md,
               WeeksOfCover AS supply,
               CASE WHEN upper(trim(SupplyUnit)) = 'MONTHS' THEN 'Months' ELSE 'Weeks' END AS unit,
               MinLineValue AS minlv, MaxLineValue AS maxlv,
               CASE upper(trim(DemandBasis)) WHEN 'UNITSSOLD' THEN 'UnitsSold' ELSE 'Requests' END AS basis
        FROM rule_check
        WHERE problems = ''
          AND (StartMonth IS NULL
               OR (StartMonth <= EndMonth AND month($cur) BETWEEN StartMonth AND EndMonth)
               OR (StartMonth > EndMonth AND (month($cur) >= StartMonth OR month($cur) <= EndMonth)))
    ),
    -- A11: each part's values for the eight criteria, trimmed and upper-case (blank -> NULL, which matches only a
    -- blank criterion). ProductGroup comes from Silver_InMaster (per branch; no row = blank). VendorCode is an
    -- integer, compared as its integer's text ("1234"; a criterion "01234" or "1234.0" does not match).
    part_crit AS (
        SELECT sc.Branch, sc.Franchise, sc.PartNumber,
               upper(trim(sc.Franchise)) AS p_franchise, upper(trim(sc.DealerGroupCode)) AS p_dgc,
               upper(trim(sc.Branch)) AS p_branch, upper(trim(sc.SLC)) AS p_slc, upper(trim(sc.Source)) AS p_source,
               CAST(CAST(sc.VendorCode AS BIGINT) AS VARCHAR) AS p_vendor, upper(trim(im.ProductGroup)) AS p_pg,
               upper(trim(sc.CommodityCode)) AS p_cc
        FROM in_scope_parts sc LEFT JOIN inmaster im USING (Branch, Franchise, PartNumber)
    ),
    -- step 1: each part's rule: highest Priority, then more non-blank criteria (all eight count; season doesn't),
    -- lowest Id
    part_rule AS (
        SELECT * EXCLUDE (rn) FROM (
            SELECT pc.Branch, pc.Franchise, pc.PartNumber, u.*,
                   row_number() OVER (PARTITION BY pc.Branch, pc.Franchise, pc.PartNumber
                                      ORDER BY u.Priority DESC,
                                               CAST(u.c_franchise IS NOT NULL AS INTEGER)
                                                 + CAST(u.c_dgc IS NOT NULL AS INTEGER)
                                                 + CAST(u.c_branch IS NOT NULL AS INTEGER)
                                                 + CAST(u.c_slc IS NOT NULL AS INTEGER)
                                                 + CAST(u.c_source IS NOT NULL AS INTEGER)
                                                 + CAST(u.c_vendor IS NOT NULL AS INTEGER)
                                                 + CAST(u.c_pg IS NOT NULL AS INTEGER)
                                                 + CAST(u.c_cc IS NOT NULL AS INTEGER) DESC,
                                               u.Id ASC) AS rn
            FROM part_crit pc JOIN usable_rules u
              ON (u.c_franchise IS NULL OR u.c_franchise = pc.p_franchise)
             AND (u.c_dgc IS NULL OR u.c_dgc = pc.p_dgc)
             AND (u.c_branch IS NULL OR u.c_branch = pc.p_branch)
             AND (u.c_slc IS NULL OR u.c_slc = pc.p_slc)
             AND (u.c_source IS NULL OR u.c_source = pc.p_source)
             AND (u.c_vendor IS NULL OR u.c_vendor = pc.p_vendor)
             AND (u.c_pg IS NULL OR u.c_pg = pc.p_pg)
             AND (u.c_cc IS NULL OR u.c_cc = pc.p_cc))
        WHERE rn = 1
    ),
    -- step 8b (A14): committed app transfer lines. Draft and Exported count; Placed counts while the Central date
    -- of PlacedAt (a UTC instant) is on or after the build's Central date; any other status (Cancelled, NULL, a
    -- different spelling) never counts, and neither does Placed without a PlacedAt. Lines to or from an excluded
    -- branch (D6) are ignored. Branches are compared trimmed and upper-case; franchise and part number exactly, as
    -- stored in the line. Qty: NULL = 0, truncated toward zero per line.
    committed_lines AS (
        SELECT upper(trim(FromBranch)) AS fb, upper(trim(ToBranch)) AS tb, Franchise, PartNumber,
               CAST(trunc(coalesce(Qty, 0)) AS BIGINT) AS q
        FROM app_transfers
        WHERE (Status IN ('Draft', 'Exported')
               OR (Status = 'Placed'
                   AND CAST(timezone('{CENTRAL}', CAST(PlacedAt AS TIMESTAMPTZ)) AS DATE) >= $today))
          AND upper(trim(FromBranch)) NOT IN ({_EXCLUDED_SQL})
          AND upper(trim(ToBranch)) NOT IN ({_EXCLUDED_SQL})
    ),
    app_inbound AS (SELECT tb, Franchise, PartNumber, sum(q) AS q FROM committed_lines GROUP BY ALL),
    app_outbound AS (SELECT fb, Franchise, PartNumber, sum(q) AS q FROM committed_lines GROUP BY ALL),
    -- display only: open transfers into the branch, by trimmed upper-case part number
    inbound_transfers AS (
        SELECT trim(RequestingBranch) AS b, upper(trim(PartNumber)) AS pn, sum(coalesce(OpenQty, 0)) AS q
        FROM transfers GROUP BY ALL
    ),
    -- one row per in-scope part with its rule (or the built-in default), minimum, settings and stock.
    -- Step 11 (live mask): Masked, not expired (MaskExpires >= Central today), and not requested after the day it
    -- was masked (dates compared; a blank MaskedOn or DateLastRequested never ends the mask).
    part_inputs AS (
        SELECT sc.Branch, sc.Franchise, sc.PartNumber, sc.QuantityOnHand, CAST(sc.Cost AS DOUBLE) AS cost,
               CAST(trunc(coalesce(sc.QuantityOnHand, 0)) AS INTEGER) AS oh,
               CAST(trunc(coalesce(sc.OnOrder, 0)) AS INTEGER) AS oo,
               p.Id AS RuleId,
               CASE WHEN p.Id IS NULL THEN '{BUILTIN_DEFAULT["RuleName"]}' ELSE p.RuleLabel END AS RuleName,
               coalesce(p.basis, '{BUILTIN_DEFAULT["DemandBasis"]}') AS DemandBasis,
               coalesce(p.hm, {BUILTIN_DEFAULT["HistoryMonths"]}) AS HistoryMonths,
               coalesce(p.md, {BUILTIN_DEFAULT["MinDemands"]}) AS MinDemands,
               coalesce(p.unit, '{BUILTIN_DEFAULT["SupplyUnit"]}') AS SupplyUnit,
               coalesce(p.supply, CAST({BUILTIN_DEFAULT["Supply"]} AS DOUBLE)) AS Supply,
               CAST(p.minlv AS DOUBLE) AS MinLineValue, CAST(p.maxlv AS DOUBLE) AS MaxLineValue,
               CAST(ps.MinOverride AS DOUBLE) AS min_override, CAST(r.MinimumQty AS DOUBLE) AS equip_min,
               coalesce(ps.ManualOrder, false) AS ManualOrder, ps.MaskedOn,
               coalesce(ps.Masked, false)
                 AND (ps.MaskExpires IS NULL OR ps.MaskExpires >= $today)
                 AND NOT coalesce(ps.MaskedOn IS NOT NULL AND CAST(sc.DateLastRequested AS DATE) > ps.MaskedOn,
                                  false) AS IsMasked,
               CAST(coalesce(t.q, 0.0) AS DOUBLE) AS InboundTransferQty,
               -- round 2: Silver_PartInformation values as stored (display; PendingQty is used by Part 2)
               CAST(sc.PendingQty AS DOUBLE) AS PendingQty, sc.SLC, sc.Source, sc.CommodityCode,
               -- step 7b inputs: PhaseInQty validated (invalid -> NULL), the dates as stored
               ps.phase_qty AS PhaseInQty, ps.PhaseInEnds, ps.PhaseInOn,
               CAST(coalesce(ai.q, 0) AS INTEGER) AS AppInboundQty,
               CAST(coalesce(ao.q, 0) AS INTEGER) AS AppOutboundQty
        FROM in_scope_parts sc
        LEFT JOIN part_rule p USING (Branch, Franchise, PartNumber)
        LEFT JOIN rules r USING (Branch, Franchise, PartNumber)
        LEFT JOIN part_settings ps USING (Branch, Franchise, PartNumber)
        LEFT JOIN inbound_transfers t ON t.b = trim(sc.Branch) AND t.pn = upper(trim(sc.PartNumber))
        LEFT JOIN app_inbound ai
          ON ai.tb = upper(trim(sc.Branch)) AND ai.Franchise = sc.Franchise AND ai.PartNumber = sc.PartNumber
        LEFT JOIN app_outbound ao
          ON ao.fb = upper(trim(sc.Branch)) AND ao.Franchise = sc.Franchise AND ao.PartNumber = sc.PartNumber
    ),
    -- step 2: full months only (the current partial month is left out); NULL counts as 0
    monthly_demand AS (
        SELECT Branch, Franchise, PartNumber, MonthStart,
               sum(coalesce(SalesQty, 0)) AS units, sum(coalesce(RequestCount, 0)) AS requests
        FROM hist WHERE MonthStart < $cur
        GROUP BY ALL
    ),
    -- steps 2-3: the rule's last HistoryMonths full months: demand on the rule's basis, demands (transactions)
    -- whatever the basis. part_inputs is one row per key (a duplicate part key would show up as dup_expected
    -- anyway), so no DISTINCT is needed.
    window_demand AS (
        SELECT pi.Branch, pi.Franchise, pi.PartNumber,
               sum(CASE pi.DemandBasis WHEN 'UnitsSold' THEN m.units ELSE m.requests END) AS raw_demand,
               sum(m.requests) AS raw_requests, sum(m.units) AS raw_units,
               count(*) FILTER (WHERE (CASE pi.DemandBasis WHEN 'UnitsSold' THEN m.units ELSE m.requests END) > 0)
                 AS active
        FROM part_inputs pi
        JOIN monthly_demand m USING (Branch, Franchise, PartNumber)
        WHERE m.MonthStart >= CAST($cur - to_months(pi.HistoryMonths) AS DATE)
        GROUP BY ALL
    ),
    -- steps 3-5: WindowDemand (round9, negative -> 0), DemandCount (negative -> 0), UnitsSoldWindow (round9,
    -- negative -> 0, whatever the basis; D14), ActiveMonths (display only), MonthlyRate over calendar months,
    -- SupplyMonths. No activity (D14) = DemandCount 0 and UnitsSoldWindow 0.
    demand AS (
        SELECT *, WindowDemand / HistoryMonths AS MonthlyRate, DemandCount = 0 AND UnitsSoldWindow = 0 AS no_activity,
               CASE SupplyUnit WHEN 'Months' THEN Supply ELSE Supply * 12 / 52 END AS SupplyMonths
        FROM (SELECT pi.*,
                     greatest(0.0, round(CAST(coalesce(w.raw_demand, 0) AS DOUBLE), 9)) AS WindowDemand,
                     CAST(greatest(0, coalesce(w.raw_requests, 0)) AS INTEGER) AS DemandCount,
                     greatest(0.0, round(CAST(coalesce(w.raw_units, 0) AS DOUBLE), 9)) AS UnitsSoldWindow,
                     CAST(coalesce(w.active, 0) AS INTEGER) AS ActiveMonths
              FROM part_inputs pi LEFT JOIN window_demand w USING (Branch, Franchise, PartNumber))
    ),
    -- steps 6-8: CalcTarget (0 below MinDemands); EffectiveMin = MinOverride, else the Equip minimum, even with no
    -- demand (D4); MinimumNoDemand flags Equip minimums on parts with no activity in the window (Cleanup; D14);
    -- step 7b (A18): phase-in is active while PhaseInQty > 0, PhaseInEnds is blank or on/after the build's Central
    -- date, and the part has fewer demands than max(MinDemands, 1). Worked out fresh every day. PhaseInEndReason
    -- (display only): Expired (end date passed) wins over MetCriteria (enough demands); NULL without a phase-in.
    -- Step 8: StockingTarget = max(CalcTarget, EffectiveMin rounded up, PhaseInQty rounded up while active).
    -- Masked and Manual order still order 0 (A19, step 12).
    target AS (
        SELECT *, CAST(greatest(CalcTarget, ceil(EffectiveMin),
                                CASE WHEN PhaseInActive THEN ceil(PhaseInQty) ELSE 0 END) AS INTEGER) AS StockingTarget
        FROM (SELECT *,
                     CASE WHEN DemandCount >= MinDemands
                          THEN CAST(ceil(round(MonthlyRate * SupplyMonths, 9)) AS INTEGER) ELSE 0 END AS CalcTarget,
                     coalesce(min_override, equip_min, 0.0) AS EffectiveMin,
                     min_override IS NULL AND coalesce(equip_min, 0) > 0 AND no_activity AS MinimumNoDemand,
                     coalesce(PhaseInQty > 0, false)
                       AND (PhaseInEnds IS NULL OR PhaseInEnds >= $today)
                       AND DemandCount < greatest(MinDemands, 1) AS PhaseInActive,
                     CASE WHEN PhaseInQty > 0 AND PhaseInEnds < $today THEN 'Expired'
                          WHEN PhaseInQty > 0 AND DemandCount >= greatest(MinDemands, 1) THEN 'MetCriteria'
                     END AS PhaseInEndReason
              FROM demand)
    ),
    -- step 9: base quantity, 0 when the target is 0 (D5); stock truncated toward zero; committed app transfers
    -- into the part (step 8b) are subtracted like stock on order
    base_qty AS (
        SELECT *, CASE WHEN StockingTarget = 0 THEN 0
                       ELSE greatest(0, StockingTarget - oh - oo - AppInboundQty) END AS bq
        FROM target
    ),
    -- step 10a: MaxLineValue cuts the quantity back to stay at or under it (only with something to order)
    capped AS (
        SELECT *,
               bq > 0 AND cost > 0 AND MaxLineValue IS NOT NULL AND round(bq * cost, 9) > MaxLineValue AS ValueCapped,
               CASE WHEN bq > 0 AND cost > 0 AND MaxLineValue IS NOT NULL AND round(bq * cost, 9) > MaxLineValue
                    THEN CAST(floor(round(MaxLineValue / cost, 9)) AS INTEGER) ELSE bq END AS cq
        FROM base_qty
    ),
    -- step 10b: then a line still above 0 but below MinLineValue is not suggested (quantity 0). A line the cap
    -- cut to 0 is not BelowMinValue: its status is AboveMaxValue (D13).
    valued AS (
        SELECT *, CASE WHEN BelowMinValue THEN 0 ELSE cq END AS vq
        FROM (SELECT *, cq > 0 AND cost > 0 AND MinLineValue IS NOT NULL
                        AND round(cq * cost, 9) < MinLineValue AS BelowMinValue
              FROM capped)
    ),
    -- step 12: order 0 when Manual Order or masked
    order_qty AS (
        SELECT *, CASE WHEN ManualOrder OR IsMasked THEN 0 ELSE vq END AS RecommendedOrderQty
        FROM valued
    ),
    -- steps 13-14: surplus and status (first match). Target 0: NoRecentActivity = no activity (no demands and no
    -- units sold) in the window; NotStocked = some activity, but the target came out 0 (below MinDemands, supply 0,
    -- or net demand <= 0). AboveMaxValue (D13) = the value cap cut the line to 0.
    final AS (
        SELECT *, greatest(0, oh - StockingTarget) AS SurplusQty,
               CASE WHEN ManualOrder THEN 'ManualOrder'
                    WHEN IsMasked THEN 'Masked'
                    WHEN StockingTarget = 0
                    THEN CASE WHEN no_activity THEN 'NoRecentActivity' ELSE 'NotStocked' END
                    WHEN BelowMinValue THEN 'BelowMinValue'
                    WHEN ValueCapped AND cq = 0 THEN 'AboveMaxValue'
                    WHEN RecommendedOrderQty > 0 AND coalesce(QuantityOnHand, 0) <= 0 THEN 'OutOfStock'
                    WHEN RecommendedOrderQty > 0 THEN 'Reorder' ELSE 'OK' END AS Status
        FROM order_qty
    )
    SELECT {", ".join(OUTPUT_COLS)} FROM final
"""


def _params(current_month: date, today: date) -> dict:
    return {"cur": current_month, "today": today}


def expected_reorder(con, current_month: date, today: date):
    """Run the reference rules over tables parts, inmaster, rules, hist, order_rules, settings, transfers and
    app_transfers. current_month = first day of the run's Central-time month; today = the run's Central date (the
    build's, for the mask, phase-in and committed Placed transfers)."""
    return con.execute(EXPECTED_SQL, _params(current_month, today))


def invalid_rules(con) -> list:
    """Active, not archived rows of order_rules that are skipped as invalid, as (Id, RuleName, reason), by Id."""
    return con.execute(INVALID_RULES_SQL).fetchall()


def invalid_settings(con) -> list:
    """Settings rows in use (latest per part) with an invalid value that is ignored, as
    (Id, Branch, Franchise, PartNumber, reason), by Id."""
    return con.execute(INVALID_SETTINGS_SQL).fetchall()


def _diff_where(cols: list = None) -> str:
    """Mismatch condition over `cols` (output column names; default every compared column)."""
    cols = set(COMPARE_COLS + TOLERANCE_COLS) if cols is None else set(cols)
    exact = [f"g.{c} IS DISTINCT FROM e.{c}" for c in COMPARE_COLS if c in cols]
    approx = [f"((g.{c} IS NULL) <> (e.{c} IS NULL) OR abs(g.{c} - e.{c}) > {TOLERANCE})"
              for c in TOLERANCE_COLS if c in cols]
    return " OR ".join(exact + approx) or "false"


def compare(con, gold: str, expected: str, cols: list = None) -> dict:
    """Row-by-row compare on the key; `cols` limits the compared columns (default all)."""
    only_gold = con.execute(f"SELECT count(*) FROM (SELECT {KEYS} FROM {gold} EXCEPT SELECT {KEYS} FROM {expected})").fetchone()[0]
    only_exp = con.execute(f"SELECT count(*) FROM (SELECT {KEYS} FROM {expected} EXCEPT SELECT {KEYS} FROM {gold})").fetchone()[0]
    different = con.execute(f"""
        SELECT count(*) FROM {gold} g JOIN {expected} e USING ({KEYS})
        WHERE {_diff_where(cols)}
    """).fetchone()[0]
    dup_gold = con.execute(f"SELECT count(*) - count(DISTINCT ({KEYS})) FROM {gold}").fetchone()[0]
    dup_exp = con.execute(f"SELECT count(*) - count(DISTINCT ({KEYS})) FROM {expected}").fetchone()[0]
    return {"only_gold": only_gold, "only_expected": only_exp, "different": different,
            "dup_gold": dup_gold, "dup_expected": dup_exp}


def _print_labeled(con, sql: str, title: str) -> None:
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    print(f"{title} ({len(rows)} shown):")
    for row in rows:
        print("  " + ", ".join(f"{c}={v!r}" for c, v in zip(cols, row)))


def _path(tier: str, layer: str, table: str) -> str:
    ws, lh = TIERS[tier][layer]
    return f"abfss://{ws}@onelake.dfs.fabric.microsoft.com/{lh}/Tables/{table}"


def _connect():
    con = duckdb.connect()
    spill = os.path.join(tempfile.gettempdir(), 'nonjd_check_spill').replace("\\", "/")
    con.execute(f"SET memory_limit='3GB'; SET temp_directory='{spill}'; SET preserve_insertion_order=false;")
    con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure; SET TimeZone='UTC';")
    con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    return con


def load_inputs(con, tier: str, current_month: date) -> list:
    """Create the input tables EXPECTED_SQL reads (parts, inmaster, rules, hist, order_rules, settings, transfers,
    app_transfers) from the tier's lakehouses; returns the optional (round 1 and 2) columns and tables the staging
    lakehouse doesn't have yet, read as NULL / empty.
    The session is UTC, so DateLastRequested becomes the timestamp as stored (Equip's wall clock) and its date is
    the date Equip shows; PlacedAt is a UTC instant and EXPECTED_SQL converts it to the Central date."""
    absent = []
    con.execute(f"""CREATE TABLE parts AS SELECT Branch, Franchise, PartNumber, QuantityOnHand, OnOrder, Cost,
                    DealerGroupCode, CAST(DateLastRequested AS TIMESTAMP) AS DateLastRequested,
                    PendingQty, SLC, Source, CommodityCode, VendorCode
                    FROM delta_scan('{_path(tier, 'staging', 'Silver_PartInformation')}')""")
    con.execute(f"""CREATE TABLE inmaster AS SELECT Branch, Franchise, PartNumber, ProductGroup
                    FROM delta_scan('{_path(tier, 'staging', 'Silver_InMaster')}')""")
    con.execute(f"""CREATE TABLE rules AS SELECT Branch, Franchise, PartNumber, MinimumQty
                    FROM delta_scan('{_path(tier, 'staging', 'Silver_PartStockingRules')}')""")
    hist_start = add_months(current_month, -HIST_MONTHS)
    con.execute(f"""CREATE TABLE hist AS SELECT Branch, Franchise, PartNumber, MonthStart, SalesQty, RequestCount
                    FROM delta_scan('{_path(tier, 'staging', 'Silver_PartSalesHistory')}')
                    -- only speeds the read; each rule's window is applied in EXPECTED_SQL
                    WHERE MonthStart >= DATE '{hist_start}'""")
    for name, table, cols in (("order_rules", "NonJD_OrderRules", RULE_COLS),
                              ("settings", "NonJD_PartSettings", SETTINGS_COLS)):
        src = f"delta_scan('{_path(tier, 'staging', table)}')"
        have = columns(con, src)
        absent += [f"{table}.{c}" for c in cols[1] if c not in have]
        con.execute(f"CREATE TABLE {name} AS SELECT {select_list(con, src, *cols, have=have)} FROM {src}")
    con.execute(f"""CREATE TABLE transfers AS SELECT RequestingBranch, PartNumber, OpenQty
                    FROM delta_scan('{_path(tier, 'presentation', 'Fact_OutstandingTransfers')}')""")
    # Committed app transfers (step 8b); the table only exists once df_NonJD_Transfers_Raw has run on the tier.
    src = f"delta_scan('{_path(tier, 'staging', 'NonJD_Transfers')}')"
    typed = ", ".join(f"CAST({c} AS {t}) AS {c}" for c, t in APP_TRANSFER_COLS.items())
    try:
        columns(con, src)
    except duckdb.Error as e:
        absent.append(f"NonJD_Transfers (table: {str(e).splitlines()[0][:120]})")
        con.execute("CREATE TABLE app_transfers ("
                    + ", ".join(f"{c} {t}" for c, t in APP_TRANSFER_COLS.items()) + ")")
    else:
        con.execute(f"CREATE TABLE app_transfers AS SELECT {typed} FROM {src}")
    return absent


def fingerprint(con, tier: str) -> tuple:
    p = _path(tier, "presentation", "Fact_NonJD_Reorder")
    return con.execute(f"""SELECT count(*), sum(hash(t)::HUGEINT)
                           FROM (SELECT * EXCLUDE (BuiltAtUtc) FROM delta_scan('{p}')) t""").fetchone()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tier", choices=sorted(TIERS), required=True)
    ap.add_argument("--fingerprint-only", action="store_true")
    a = ap.parse_args()
    con = _connect()
    rows, fp = fingerprint(con, a.tier)
    print(f"Fact_NonJD_Reorder ({a.tier}): {rows:,} rows, fingerprint {fp}")
    if a.fingerprint_only:
        return 0

    gold_p = _path(a.tier, "presentation", "Fact_NonJD_Reorder")
    built = con.execute(f"SELECT max(BuiltAtUtc) FROM delta_scan('{gold_p}')").fetchone()[0]
    if built is None:
        sys.exit("Fact_NonJD_Reorder is empty; nothing to check")
    if built.tzinfo is None:
        built = built.replace(tzinfo=timezone.utc)
    today = built.astimezone(ZoneInfo("America/Chicago")).date()
    current_month = date(today.year, today.month, 1)
    print(f"Gold built {built}; checking as of {today} (month {current_month})")

    absent = load_inputs(con, a.tier, current_month)
    if absent:
        print(f"NOTE: read as NULL (not in staging yet): {', '.join(absent)}")
    bad = invalid_rules(con)
    if bad:
        print(f"WARN: {len(bad)} rule(s) skipped as invalid:")
        for rid, name, reason in bad:
            print(f"  {rid} {name!r}: {reason}")
    else:
        print("All active rules are valid")
    bad = invalid_settings(con)
    if bad:
        print(f"WARN: {len(bad)} part setting(s) with an invalid value (ignored):")
        for sid, branch, franchise, pn, reason in bad:
            print(f"  {sid} {branch}|{franchise}|{pn}: {reason}")

    con.execute("CREATE TABLE expected AS " + EXPECTED_SQL, _params(current_month, today))
    gold_cols = {r[0] for r in con.execute(f"DESCRIBE SELECT * FROM delta_scan('{gold_p}')").fetchall()}
    missing = [c for c in OUTPUT_COLS if c not in gold_cols]
    present = [c for c in OUTPUT_COLS if c in gold_cols]
    if missing:
        print(f"FAIL: Fact_NonJD_Reorder has no {', '.join(missing)} (Gold not on the latest rules yet?); "
              f"comparing the other {len(present) - 3} columns")
    con.execute(f"CREATE TABLE gold AS SELECT {', '.join(present)} FROM delta_scan('{gold_p}')")
    result = compare(con, "gold", "expected", present)
    print(result)
    if any(result.values()):
        e_cols = ", ".join(f"e.{c} AS e_{c}" for c in present[3:])
        _print_labeled(con, f"""SELECT g.*, {e_cols}
                                FROM gold g JOIN expected e USING ({KEYS})
                                WHERE {_diff_where(present)} LIMIT 10""",
                       "different (gold columns, then e_ = expected)")
        _print_labeled(con, f"SELECT {KEYS} FROM gold EXCEPT SELECT {KEYS} FROM expected LIMIT 10", "only in gold")
        _print_labeled(con, f"SELECT {KEYS} FROM expected EXCEPT SELECT {KEYS} FROM gold LIMIT 10", "only in expected")
        return 1
    if missing:
        print("The columns Gold has match the reference; FAIL because of the missing columns")
        return 1
    print("PASS: Gold matches the reference rules")
    return 0


if __name__ == "__main__":
    sys.exit(main())
