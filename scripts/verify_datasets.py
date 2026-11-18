"""Confirm each dataset ID resolves, its filter column exists, and how many rows the filter returns.

Usage:
    python scripts/verify_datasets.py            # enabled datasets
    python scripts/verify_datasets.py --all      # every dataset in the config
"""

from __future__ import annotations

import argparse
import json
import re

from common import enabled_datasets, http_get, load_config

# Identifiers on the left side of comparisons in a simple SoQL where clause
FILTER_FIELD = re.compile(r"\b([a-z_][a-z0-9_]*)\s*(?:=|!=|<>|<=|>=|<|>|\bin\b|\blike\b)", re.IGNORECASE)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="check disabled datasets too")
    args = parser.parse_args()

    config = load_config()
    portal = config["portal"]
    datasets = config["datasets"] if args.all else enabled_datasets(config)

    problems = 0
    for name, ds in datasets.items():
        print(f"\n{name}  ({ds['id']})")
        try:
            meta = json.loads(http_get(f"{portal}/api/views/{ds['id']}.json"))
        except RuntimeError as err:
            problems += 1
            print(f"  ERROR: could not load metadata: {err}")
            continue

        print(f"  Portal name : {meta.get('name')}")
        fields = {c.get("fieldName") for c in meta.get("columns", [])}
        print(f"  Columns     : {len(fields)}")

        where = ds.get("where")
        if where:
            missing = [f for f in FILTER_FIELD.findall(where) if f.lower() not in {x.lower() for x in fields}]
            if missing:
                problems += 1
                print(f"  ERROR: filter column(s) not found: {', '.join(missing)}")
                print(f"         available columns include: {', '.join(sorted(fields)[:40])}")
                continue

        try:
            rows = json.loads(
                http_get(f"{portal}/resource/{ds['id']}.json", {"$select": "count(*) AS n", "$where": where})
            )
            count = int(rows[0]["n"]) if rows else 0
            print(f"  Filter      : {where or '(none)'}")
            print(f"  Row count   : {count:,}")
            if count == 0:
                problems += 1
                print("  WARNING: filter returns zero rows; check the borough value format")
        except RuntimeError as err:
            problems += 1
            print(f"  ERROR: count query failed: {err}")

    print(f"\nDone. {problems} problem(s) found.")
    raise SystemExit(1 if problems else 0)


if __name__ == "__main__":
    main()
