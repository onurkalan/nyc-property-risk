"""Download NYC Open Data datasets as gzipped CSV chunks into data/raw/<dataset>/.

Every value is kept as text; typing happens in the dbt staging models.
Each dataset is written to a temporary folder first and swapped in only when complete,
so a failed run never leaves a half-loaded dataset behind.

Usage:
    python scripts/load_raw.py                      # full load of enabled datasets
    python scripts/load_raw.py --sample 2000        # first 2,000 rows of each (quick check / CI)
    python scripts/load_raw.py --only pluto hpd_violations
"""

from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import shutil
import time
from datetime import datetime, timezone

from common import RAW_DIR, enabled_datasets, http_get, load_config


def load_dataset(portal: str, name: str, ds: dict, page_size: int, sample: int | None) -> int:
    target = RAW_DIR / name
    staging = RAW_DIR / f".{name}.tmp"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    offset = 0
    part = 0
    total = 0
    header: list[str] | None = None
    started = time.time()

    while True:
        limit = min(page_size, sample - total) if sample else page_size
        params = {
            "$limit": limit,
            "$offset": offset,
            "$order": ":id",  # stable ordering so paging never skips or repeats rows
            "$where": ds.get("where"),
        }
        text = http_get(f"{portal}/resource/{ds['id']}.csv", params).decode("utf-8")
        rows = list(csv.reader(io.StringIO(text)))
        if not rows:
            break
        page_header, data = rows[0], rows[1:]

        # Socrata can omit columns that are entirely empty on a page; keep one consistent header.
        if header is None:
            header = page_header
        elif page_header != header:
            for col in page_header:
                if col not in header:
                    header.append(col)
        index = {col: i for i, col in enumerate(page_header)}
        aligned = [[row[index[c]] if c in index and index[c] < len(row) else "" for c in header] for row in data]

        if aligned:
            with gzip.open(staging / f"part-{part:05d}.csv.gz", "wt", encoding="utf-8", newline="") as f:
                writer = csv.writer(f)
                writer.writerow(header)
                writer.writerows(aligned)
            part += 1
            total += len(aligned)
            print(f"    page {part}: {len(aligned):,} rows (total {total:,})")

        if len(data) < limit or (sample and total >= sample):
            break
        offset += limit

    manifest = {
        "dataset": name,
        "id": ds["id"],
        "where": ds.get("where"),
        "rows": total,
        "parts": part,
        "sample": sample,
        "loaded_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "seconds": round(time.time() - started, 1),
    }
    (staging / "_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    if target.exists():
        shutil.rmtree(target)
    staging.rename(target)
    return total


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sample", type=int, help="load only the first N rows of each dataset")
    parser.add_argument("--only", nargs="+", help="dataset names to load (default: all enabled)")
    args = parser.parse_args()

    config = load_config()
    datasets = enabled_datasets(config, args.only)
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    failures = []
    for name, ds in datasets.items():
        print(f"\nLoading {name} ({ds['id']}) {'[sample ' + str(args.sample) + ']' if args.sample else ''}")
        try:
            rows = load_dataset(config["portal"], name, ds, config["page_size"], args.sample)
            print(f"  done: {rows:,} rows")
        except RuntimeError as err:
            failures.append(name)
            print(f"  FAILED: {err}")

    if failures:
        raise SystemExit(f"\nFailed datasets: {', '.join(failures)}")
    print("\nAll datasets loaded.")


if __name__ == "__main__":
    main()
