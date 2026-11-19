"""Find raw CSV chunks that DuckDB cannot parse, and show the offending lines.

Uses the same read_csv options as dbt/models/staging/_sources.yml.

Usage:
    python scripts/find_bad_csv.py acris_legals
"""

from __future__ import annotations

import gzip
import re
import sys

import duckdb

from common import RAW_DIR


def main() -> None:
    name = sys.argv[1]
    files = sorted((RAW_DIR / name).glob("part-*.csv.gz"))
    print(f"Checking {len(files)} files in {RAW_DIR / name}")
    con = duckdb.connect()
    bad = 0
    for path in files:
        try:
            con.sql(f"select count(*) from read_csv('{path.as_posix()}', header=true, all_varchar=true, delim=',', quote='\"', escape='\"')").fetchall()
        except Exception as err:  # noqa: BLE001 - we want every parser error
            bad += 1
            message = str(err)
            print(f"\nFAILED: {path.name}\n{message[:800]}")
            match = re.search(r"Line: (\d+)", message)
            if match:
                target = int(match.group(1))
                with gzip.open(path, "rt", encoding="utf-8", newline="") as f:
                    for i, line in enumerate(f, start=1):
                        if target - 2 <= i <= target + 1:
                            print(f"  line {i}: {line.rstrip()[:300]!r}")
                        if i > target + 1:
                            break
    print(f"\nDone. {bad} file(s) failed.")


if __name__ == "__main__":
    main()
