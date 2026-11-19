"""Download NYC Open Data datasets as gzipped CSV chunks into data/raw/<dataset>/.

Every value is kept as text; typing happens in the dbt staging models.
Each dataset is written to a temporary folder first and swapped in only when complete,
so a failed run never leaves a half-loaded dataset behind.

Paging is keyset-based: each request asks for rows whose system row id (:id) is greater
than the last one received. Offset paging ("skip N rows") gets slower with every page and
timed out past ~4M rows on HPD violations; keyset pages take the same time at any depth.

Full loads checkpoint after every page. If a run fails, rerunning the same command resumes
from the last saved page. Use --fresh to discard a partial load and start over.

Usage:
    python scripts/load_raw.py                      # full load of enabled datasets
    python scripts/load_raw.py --sample 2000        # first 2,000 rows of each (quick check / CI)
    python scripts/load_raw.py --only pluto hpd_violations
    python scripts/load_raw.py --only hpd_violations --fresh
"""

from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import shutil
import sys
import time
from datetime import datetime, timezone

from common import RAW_DIR, enabled_datasets, http_get, load_config

# Print progress immediately even when output is piped (e.g. to Tee-Object).
sys.stdout.reconfigure(line_buffering=True)

CHECKPOINT = "_checkpoint.json"


def _where(base: str | None, last_id: str | None) -> str | None:
    clauses = [f"({base})"] if base else []
    if last_id:
        clauses.append(f":id > '{last_id}'")
    return " AND ".join(clauses) or None


def load_dataset(portal: str, name: str, ds: dict, page_size: int, sample: int | None, fresh: bool = False) -> int:
    target = RAW_DIR / name
    staging = RAW_DIR / f".{name}.tmp"
    checkpoint_path = staging / CHECKPOINT

    part, total, last_id, header = 0, 0, None, None
    resumable = not sample and not fresh and checkpoint_path.exists()
    if resumable:
        cp = json.loads(checkpoint_path.read_text(encoding="utf-8"))
        if cp.get("id") == ds["id"] and cp.get("where") == ds.get("where"):
            part, total, last_id, header = cp["parts"], cp["rows"], cp["last_id"], cp["header"]
            print(f"    resuming after page {part} ({total:,} rows already loaded)")
        else:
            resumable = False
    if not resumable:
        if staging.exists():
            shutil.rmtree(staging)
        staging.mkdir(parents=True)

    started = time.time()

    while True:
        limit = min(page_size, sample - total) if sample else page_size
        params = {
            "$select": ":*,*",  # include the system row id (:id) for keyset paging
            "$limit": limit,
            "$order": ":id",
            "$where": _where(ds.get("where"), last_id),
        }
        text = http_get(f"{portal}/resource/{ds['id']}.csv", params).decode("utf-8")
        rows = list(csv.reader(io.StringIO(text)))
        if not rows:
            break
        page_header, data = rows[0], rows[1:]
        if not data:
            break
        last_id = data[-1][page_header.index(":id")]

        # Drop Socrata system columns (:id, :created_at, :updated_at, :version) from the output.
        keep = [i for i, col in enumerate(page_header) if not col.startswith(":")]
        page_header = [page_header[i] for i in keep]
        data = [[row[i] if i < len(row) else "" for i in keep] for row in data]

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
            if not sample:
                checkpoint_path.write_text(
                    json.dumps({"id": ds["id"], "where": ds.get("where"), "parts": part,
                                "rows": total, "last_id": last_id, "header": header}),
                    encoding="utf-8",
                )

        if len(data) < limit or (sample and total >= sample):
            break

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
    if checkpoint_path.exists():
        checkpoint_path.unlink()

    if target.exists():
        shutil.rmtree(target)
    staging.rename(target)
    return total


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sample", type=int, help="load only the first N rows of each dataset")
    parser.add_argument("--only", nargs="+", help="dataset names to load (default: all enabled)")
    parser.add_argument("--fresh", action="store_true", help="ignore any partial load and start over")
    args = parser.parse_args()

    config = load_config()
    datasets = enabled_datasets(config, args.only)
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    failures = []
    for name, ds in datasets.items():
        print(f"\nLoading {name} ({ds['id']}) {'[sample ' + str(args.sample) + ']' if args.sample else ''}")
        try:
            rows = load_dataset(config["portal"], name, ds, config["page_size"], args.sample, args.fresh)
            print(f"  done: {rows:,} rows")
        except RuntimeError as err:
            failures.append(name)
            print(f"  FAILED: {err}")
            if not args.sample:
                print(f"  Partial load kept. Rerun the same command to resume {name}.")

    if failures:
        raise SystemExit(f"\nFailed datasets: {', '.join(failures)}")
    print("\nAll datasets loaded.")


if __name__ == "__main__":
    main()
