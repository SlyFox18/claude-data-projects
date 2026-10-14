"""Tuning run: one report's chain through the prototype orchestrators at a given concurrency.

Usage: python tune_run.py "<report model>" <concurrency> <label> [spark_conf_json]
Runs the Silver tier (Staging Proto_RunMultiple) then the Gold tier (Presentation), passing each tier's
sub-DAG from fabric-workspace-docs/deploy/dp_refresh_dag.json as dag_json. Prints the UTC window and
the spark_usage.py lines for both orchestrators. Exit 1 if either orchestrator job fails.
"""
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, r"C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\deploy")
from dag_config import load_config, tier_dag  # noqa: E402

PROTOS = [("silver", "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201", "52709f40-5484-462d-9786-a096bb32741d"),
          ("gold", "73fd5443-240e-410a-990a-98827f32c087", "7b221481-19b4-4506-a23c-e220ee1a6944")]


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")


def main():
    model, concurrency, label = sys.argv[1], sys.argv[2], sys.argv[3]
    spark_conf = sys.argv[4] if len(sys.argv) > 4 else ""
    config = load_config()
    start = now()
    ok = True
    for tier, ws, proto in PROTOS:
        dag = tier_dag(config, model, tier)
        print(f"{tier}: {len(dag)} notebooks")
        if not dag:
            continue
        r = subprocess.run([sys.executable, str(HERE / "run_item.py"), ws, proto, "RunNotebook", "5400",
                            "--param", f"dag_json={json.dumps(dag)}", "--param", f"concurrency={concurrency}",
                            "--param", f"run_label={label}_{tier}"]
                           + (["--param", f"spark_conf_json={spark_conf}"] if spark_conf else []),
                           capture_output=True, text=True)
        print(r.stdout[-600:])
        if r.returncode != 0:
            ok = False
            break
    end = now()
    print(f"WINDOW {start} {end}")
    for tier, ws, proto in PROTOS:
        u = subprocess.run([sys.executable, str(HERE / "spark_usage.py"), ws, proto, start, end],
                           capture_output=True, text=True)
        print(tier, u.stdout.strip() or u.stderr[-400:])
    print_report_counts(config, model)
    sys.exit(0 if ok else 1)


def print_report_counts(config, model):
    """Row counts of the report's DP_Presentation tables (compare across tuning runs)."""
    import duckdb
    root = ("abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/"
            "966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/")
    con = duckdb.connect()
    con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
    con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
    tables = next(r["tables"] for r in config["reports"] if r["model"] == model)
    for t in tables:
        n = con.sql(f"SELECT count(*) FROM delta_scan('{root}{t}')").fetchone()[0]
        print(f"  COUNT {t:40s} {n:>12,}")


if __name__ == "__main__":
    main()
