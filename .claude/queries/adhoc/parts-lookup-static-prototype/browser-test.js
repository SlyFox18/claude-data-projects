/**
 * PARTS LOOKUP STATIC-FILE PROTOTYPE - BROWSER READ-LATENCY / CONCURRENCY TEST
 * ============================================================================
 * Paste this directly into the DevTools console while viewing the test
 * SharePoint document library in the browser (so fetch() calls carry the
 * browser's existing authenticated session - no auth code needed here).
 *
 * What it does:
 *   1. Computes the same 2-char PartNumber-prefix bucket that partition.py
 *      used to name each JSON file (see safePrefix below - must stay in
 *      sync with partition.py's safe_prefix()).
 *   2. Fetches the partition file for each TEST_PART_NUMBERS entry from an
 *      ABSOLUTE SharePoint URL (built from LIBRARY_BASE - NOT a relative
 *      path, since this console will likely be attached to a
 *      .../Forms/AllItems.aspx page, and a relative fetch from there would
 *      resolve into a nonexistent Forms/ location instead of the library
 *      root).
 *   3. Times fetch+JSON-parse with performance.now(), filters for exact
 *      PartNumber matches, and logs elapsed ms / row count / match count
 *      for each part number, run sequentially.
 *   4. Runs a concurrency test: 10 simultaneous fetches of the same file
 *      (first test part number) via Promise.all, logging total wall-clock
 *      time for all 10 to complete.
 *
 * Requires: browser already authenticated into the
 * SouthPlainsImplement-ReportSite SharePoint site (i.e. this tab is
 * currently viewing a page in that site).
 *
 * See docs/superpowers/specs/2026-08-14-parts-lookup-static-file-prototype-design.md
 * for the design this supports.
 * ============================================================================
 */

(async function () {
  // Absolute library root - do NOT resolve prefix.json relative to the
  // current page. The page this script is pasted into is typically
  // .../Test%20%20Part%20Availability/Forms/AllItems.aspx, and a bare
  // relative fetch("AB.json") from there would incorrectly resolve to
  // .../Forms/AB.json (does not exist) instead of the library root.
  const LIBRARY_BASE =
    "https://spitractor.sharepoint.com/sites/SouthPlainsImplement-ReportSite/Test%20%20Part%20Availability";

  // Real part numbers pulled from partslookup_extract.parquet (1,060,738
  // rows), chosen to span 6 distinct 2-char prefixes so the test exercises
  // more than one partition file.
  const TEST_PART_NUMBERS = [
    "RE568839", // prefix RE
    "R127764", // prefix R1
    "AN220364", // prefix AN
    "19M7775", // prefix 19
    "JDE80", // prefix JD
    "SE501403", // prefix SE
  ];

  // Must exactly match partition.py's safe_prefix(): uppercase, take first
  // 2 chars, replace any non-[A-Z0-9] char with "_", fall back to
  // "_EMPTY_" if the result is empty.
  function safePrefix(partNumber, length) {
    const prefix = String(partNumber).toUpperCase().slice(0, length);
    const replaced = prefix.replace(/[^A-Z0-9]/g, "_");
    return replaced || "_EMPTY_";
  }

  function partitionUrl(prefix) {
    return `${LIBRARY_BASE}/${prefix}.json`;
  }

  async function timedLookup(partNumber) {
    const prefix = safePrefix(partNumber, 2);
    const url = partitionUrl(prefix);

    const start = performance.now();
    const response = await fetch(url, { credentials: "include" });
    if (!response.ok) {
      throw new Error(
        `Fetch failed for ${partNumber} (prefix ${prefix}): ${response.status} ${response.statusText}`
      );
    }
    const rows = await response.json();
    const elapsedMs = performance.now() - start;

    const matches = rows.filter((row) => row.PartNumber === partNumber);

    console.log(
      `[${partNumber}] prefix=${prefix} elapsed=${elapsedMs.toFixed(
        1
      )}ms fileRows=${rows.length} exactMatches=${matches.length}`
    );

    return { partNumber, prefix, elapsedMs, fileRows: rows.length, matches: matches.length };
  }

  console.log("=== Sequential lookups ===");
  const sequentialResults = [];
  for (const partNumber of TEST_PART_NUMBERS) {
    try {
      const result = await timedLookup(partNumber);
      sequentialResults.push(result);
    } catch (err) {
      console.error(err);
    }
  }
  console.table(sequentialResults);

  console.log("\n=== Concurrency test: 10 simultaneous fetches of the same file ===");
  const concurrencyPartNumber = TEST_PART_NUMBERS[0];
  const concurrencyPrefix = safePrefix(concurrencyPartNumber, 2);
  const concurrencyUrl = partitionUrl(concurrencyPrefix);

  const concurrencyStart = performance.now();
  await Promise.all(
    Array.from({ length: 10 }, () =>
      fetch(concurrencyUrl, { credentials: "include" }).then((r) => r.json())
    )
  );
  const concurrencyElapsedMs = performance.now() - concurrencyStart;

  console.log(
    `10 concurrent fetches of ${concurrencyPrefix}.json completed in ${concurrencyElapsedMs.toFixed(
      1
    )}ms total`
  );
})();
