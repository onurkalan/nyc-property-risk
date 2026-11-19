"""Shared helpers for the raw-data scripts. Standard library only."""

from __future__ import annotations

import json
import os
import http.client
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "config" / "datasets.json"
RAW_DIR = ROOT / "data" / "raw"

USER_AGENT = "nyc-property-risk/0.1 (portfolio project)"
RETRY_STATUSES = {429, 500, 502, 503, 504}


def load_config() -> dict:
    with CONFIG_PATH.open(encoding="utf-8") as f:
        return json.load(f)


def enabled_datasets(config: dict, only: list[str] | None = None) -> dict:
    datasets = {k: v for k, v in config["datasets"].items() if v.get("enabled")}
    if only:
        unknown = set(only) - set(config["datasets"])
        if unknown:
            raise SystemExit(f"Unknown dataset name(s): {', '.join(sorted(unknown))}")
        datasets = {k: config["datasets"][k] for k in only}
    return datasets


def http_get(url: str, params: dict | None = None, retries: int = 5, timeout: int = 120) -> bytes:
    """GET with an optional Socrata app token and exponential backoff on throttling/server errors."""
    if params:
        clean = {k: v for k, v in params.items() if v is not None}
        url = f"{url}?{urllib.parse.urlencode(clean)}"
    headers = {"User-Agent": USER_AGENT}
    token = (os.environ.get("SOCRATA_APP_TOKEN") or "").strip()
    if token:
        headers["X-App-Token"] = token

    delay = 2.0
    for attempt in range(1, retries + 1):
        request = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.read()
        except urllib.error.HTTPError as err:
            body = err.read().decode("utf-8", errors="replace")[:500]
            if err.code in RETRY_STATUSES and attempt < retries:
                print(f"    HTTP {err.code}, retrying in {delay:.0f}s (attempt {attempt}/{retries})")
                time.sleep(delay)
                delay *= 2
                continue
            raise RuntimeError(f"HTTP {err.code} for {url}\n{body}") from err
        except (urllib.error.URLError, TimeoutError, ConnectionError, http.client.IncompleteRead) as err:
            if attempt < retries:
                print(f"    Network error ({err}), retrying in {delay:.0f}s (attempt {attempt}/{retries})")
                time.sleep(delay)
                delay *= 2
                continue
            raise RuntimeError(f"Network error for {url}: {err}") from err
    raise RuntimeError(f"Exhausted retries for {url}")
