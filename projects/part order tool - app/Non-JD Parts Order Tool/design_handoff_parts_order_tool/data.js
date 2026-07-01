/* Mock data for the Non-JD Parts Order Tool redesign prototype.
   Values mirror the real screens shared by the user. Attached to window. */
(function () {
  // ---- Recommended Reorder rows (Branch 1 / MC) ----
  const reorder = [
    { part: "859090",  desc: 'BLADE ASSEMBLY 15"',           bin: "SB1",  cost: 68.30,  sales: 102, demands: 4, oh: 9,  oo: 0, target: 11, },
    { part: "60748100",desc: "CHAIN GUIDE ASSY",             bin: "QE6",  cost: 43.80,  sales: 9,   demands: 3, oh: 0,  oo: 0, target: 6,  },
    { part: "474478",  desc: "HYD MOTOR DYNA BMER2300FSSWSR", bin: "",     cost: 457.75, sales: 1,   demands: 1, oh: 0,  oo: 0, target: 4,  },
    { part: "967992",  desc: "LH SHORT OPENER",              bin: "WGB2", cost: 252.66, sales: 5,   demands: 1, oh: 0,  oo: 0, target: 4,  },
    { part: "153692",  desc: "TUBE",                         bin: "QF4",  cost: 4.95,   sales: 25,  demands: 1, oh: 0,  oo: 0, target: 4,  },
    { part: "967711",  desc: "RH LONG OPENER WA",            bin: "WGB2", cost: 285.35, sales: 5,   demands: 1, oh: 0,  oo: 0, target: 4,  },
    { part: "201554",  desc: "BEARING FLANGE 1.25",          bin: "QA2",  cost: 18.40,  sales: 44,  demands: 6, oh: 2,  oo: 0, target: 8,  },
    { part: "330918",  desc: "ROLLER CHAIN #80",             bin: "RC8",  cost: 96.10,  sales: 12,  demands: 2, oh: 1,  oo: 2, target: 5,  },
    { part: "778402",  desc: "SEAL KIT MASTER",              bin: "SK1",  cost: 31.25,  sales: 18,  demands: 3, oh: 4,  oo: 0, target: 9,  },
    { part: "640221",  desc: "IDLER PULLEY ASSY",            bin: "QD3",  cost: 74.00,  sales: 7,   demands: 1, oh: 0,  oo: 0, target: 4,  },
    { part: "118003",  desc: "GREASE FITTING 1/4",           bin: "QA1",  cost: 0.85,   sales: 210, demands: 9, oh: 12, oo: 0, target: 40, },
    { part: "905517",  desc: "GAUGE WHEEL ARM",              bin: "WGA1", cost: 142.90, sales: 6,   demands: 2, oh: 1,  oo: 0, target: 6,  },
  ].map(r => {
    const value = +(r.cost * r.target).toFixed(2);
    const deficit = Math.max(0, r.target - r.oh - r.oo);
    let status = "ok";
    if (r.oh === 0 && r.target > 0) status = "critical";
    else if (deficit > 0) status = "low";
    return { ...r, value, deficit, status };
  });

  // ---- One Time Order results (Branch 11 / MG) ----
  const oneTime = [
    { part: "803-169C", desc: '1/2" FLANGE NUT',            fr: "MG", total: 12.0, oh: 0,  rec: 12 },
    { part: "816-771C", desc: "SEAL",                       fr: "MG", total: 12.0, oh: 0,  rec: 12 },
    { part: "107-138S", desc: "DD W/205 BRG-PLD FLNG-4MM",  fr: "MG", total: 24.0, oh: 10, rec: 14 },
    { part: "188-001V", desc: "BRG AA205DD",                fr: "MG", total: 84.0, oh: 0,  rec: 84 },
    { part: "194-561A", desc: "WALKING TANDEM",             fr: "MG", total: 24.0, oh: 1,  rec: 23 },
    { part: "810-373C", desc: "SEAL KIT MW 3.75 X 1.375",   fr: "MG", total: 12.0, oh: 1,  rec: 11 },
    { part: "330-118B", desc: "BUSHING TANDEM AXLE",        fr: "MG", total: 36.0, oh: 4,  rec: 32 },
    { part: "551-907D", desc: "DISC BLADE 22 NOTCHED",      fr: "MG", total: 48.0, oh: 6,  rec: 42 },
  ];

  // ---- Part detail (859090) ----
  const part = {
    part: "859090", desc: 'BLADE ASSEMBLY 15"', branch: "1",
    franchise: "MC", dealerGroup: "CRUSTBUST", vendor: "1010",
    slc: "—", commodity: "—", bin: "SB1",
    cost: 68.30, sell: 114.06, list: 114.06, stockValue: 614.70,
    onHand: 9, onOrder: 0, backOrder: 0, minQty: 0,
    recOrderQty: 11, stockingTarget: 20, rop: 20.0, reorderCode: "—",
    estOrderValue: 751.30, suggestedQty: 0,
    dateCreated: "Sep 27, 2019", dateLastReq: "Jun 8, 2026",
    cur12Sales: 102, prev12Sales: 66, cur12Req: 4, prev12Req: 2,
    avgMonthlySales: 35.7, avgMonthlyDemand: 1.7, activeMonths: 3,
    superTo: "None", superFrom: "None",
  };

  const history = [
    { m: "Jun 2026", sales: 5, demand: 1 },
    { m: "May 2026", sales: 0, demand: 0 },
    { m: "Apr 2026", sales: 0, demand: 0 },
    { m: "Mar 2026", sales: 0, demand: 0 },
    { m: "Feb 2026", sales: 0, demand: 0 },
    { m: "Jan 2026", sales: 8, demand: 1 },
    { m: "Dec 2025", sales: 0, demand: 0 },
    { m: "Nov 2025", sales: 14, demand: 1 },
    { m: "Oct 2025", sales: 0, demand: 0 },
    { m: "Sep 2025", sales: 0, demand: 0 },
    { m: "Aug 2025", sales: 71, demand: 0 },
    { m: "Jul 2025", sales: 4, demand: 0 },
  ];

  // search results for part lookup
  const searchResults = [
    { part: "859090",  desc: 'BLADE ASSEMBLY 15"',           fr: "MC", bin: "SB1",  oh: 9 },
    { part: "859091",  desc: 'BLADE ASSEMBLY 18"',           fr: "MC", bin: "SB1",  oh: 4 },
    { part: "60748100",desc: "CHAIN GUIDE ASSY",             fr: "MC", bin: "QE6",  oh: 0 },
    { part: "474478",  desc: "HYD MOTOR DYNA BMER2300FSSWSR", fr: "MC", bin: "—",    oh: 0 },
    { part: "967992",  desc: "LH SHORT OPENER",              fr: "MC", bin: "WGB2", oh: 0 },
    { part: "153692",  desc: "TUBE",                         fr: "MC", bin: "QF4",  oh: 0 },
  ];

  const branches = ["1", "2", "5", "11", "14"];
  const franchises = ["MC", "MG", "MX", "AG"];
  const months = ["Jun 2026","May 2026","Apr 2026","Mar 2026","Feb 2026","Jan 2026",
                  "Dec 2025","Nov 2025","Oct 2025","Sep 2025","Aug 2025","Jul 2025"];

  window.APP_DATA = { reorder, oneTime, part, history, searchResults, branches, franchises, months };
})();
