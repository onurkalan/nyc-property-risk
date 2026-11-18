"""Print the real columns, fill rates and example values of each downloaded dataset.

Use the output to write (or correct) the dbt staging models.

Usage:
    python scripts/profile_raw.py                 # all downloaded datasets
    python scripts/profile_raw.py pluto           # one dataset
    python scripts/profile_raw.py --rows 20000    # profile more rows
"""

from __future__ import annotations

import argparse
import csv
import gzip
from collections import Counter

from common import RAW_DIR


def profile(name: str, max_rows: int) -> None:
    folder = RAW_DIR / name
    parts = sorted(folder.glob("part-*.csv.gz"))
    if not parts:
        print(f"\n{name}: no data downloaded")
        return

    filled: Counter = Counter()
    examples: dict[str, Counter] = {}
    seen = 0
    header: list[str] = []
    for part in parts:
        with gzip.open(part, "rt", encoding="utf-8", newline="") as f:
            reader = csv.reader(f)
            header = next(reader)
            for row in reader:
                for col, value in zip(header, row):
                    if value.strip():
                        filled[col] += 1
                        examples.setdefault(col, Counter())[value.strip()[:60]] += 1
                seen += 1
                if seen >= max_rows:
                    break
        if seen >= max_rows:
            break

    print(f"\n=== {name}: {len(header)} columns, profiled {seen:,} rows ===")
    for col in header:
        rate = filled[col] / seen if seen else 0
        top = ", ".join(f"{v!r}" for v, _ in examples.get(col, Counter()).most_common(3))
        print(f"  {col:<45} {rate:6.1%}  {top}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("datasets", nargs="*", help="dataset names (default: all downloaded)")
    parser.add_argument("--rows", type=int, default=5000, help="rows to profile per dataset")
    args = parser.parse_args()

    names = args.datasets or sorted(p.name for p in RAW_DIR.iterdir() if p.is_dir() and not p.name.startswith("."))
    for name in names:
        profile(name, args.rows)


if __name__ == "__main__":
    main()
