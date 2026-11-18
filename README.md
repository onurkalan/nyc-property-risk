# NYC Property Risk Intelligence

Type a NYC address and get a risk report on the building, its owner and recent
contractors, in English and Turkish.

This repo is built in layers, and each layer is useful on its own:

| Layer | What it shows | Status |
|---|---|---|
| Raw loaders (Python) | Ingesting messy public data reliably | Sprint 1 |
| dbt models + tests | Analytics engineering: staging, entity resolution, marts | Sprint 1 → 3 |
| Dashboard | BI: building risk profile, neighborhood view | Sprint 4 |
| AI agent + evals | Due diligence memo, contractor vetting, violation classification | Sprint 5 → 6 |
| Deployed app | Address search → memo (EN/TR) | Sprint 7 |

## Scope of version 1

- Borough: **Brooklyn** (change in `config/datasets.json`)
- Property types: 1–4 family and small multifamily (filtered in the marts, not at load)
- Sources: City Planning lot data (PLUTO), Buildings Department permits, filings and
  violations, environmental control board violations, Housing Preservation and
  Development violations and registrations, ACRIS deeds/mortgages, DOF sales

## Stack (all free)

- Python 3.11+ (standard library only for the loaders)
- DuckDB as the local warehouse
- dbt Core with the `dbt-duckdb` adapter
- GitHub Actions for CI

## Setup

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Optional but recommended: a free Socrata app token raises rate limits.
# Create one at https://data.cityofnewyork.us (profile -> developer settings).
export SOCRATA_APP_TOKEN=your_token_here
```

## Run Sprint 1

```bash
# 1. Confirm every dataset ID in the config resolves, and print its real name
python scripts/verify_datasets.py

# 2. Pull a small sample of every dataset first (fast, good for checking filters)
python scripts/load_raw.py --sample 2000

# 3. Look at the real column names in what you downloaded
python scripts/profile_raw.py

# 4. Build and test the dbt models (creates dbt/nyc_property_risk.duckdb)
cd dbt
dbt build --profiles-dir .

# 5. When the sample looks right, do the full Brooklyn load
cd ..
python scripts/load_raw.py
cd dbt && dbt build --profiles-dir .

# 6. Browse documentation and lineage
dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .
```

## Layout

```
config/datasets.json      dataset IDs, borough filters, loader settings
scripts/                  verify, load and profile raw data
data/raw/<dataset>/       downloaded CSV chunks (git-ignored)
dbt/                      dbt project (DuckDB file dbt/nyc_property_risk.duckdb, git-ignored)
docs/BUILD_LOG.md         decisions, problems, fixes -> becomes the case study
.github/workflows/ci.yml  sample load + dbt build on every push
```

## Keys that join everything

- **BBL** (borough-block-lot): 10 digits, identifies a tax lot. Borough codes:
  1 Manhattan, 2 Bronx, 3 Brooklyn, 4 Queens, 5 Staten Island.
- **BIN** (building identification number): identifies a building. One lot can
  hold several buildings; condos split one building into many lots.

## Disclaimer

Public data has errors and lags. Reports produced by this project do not replace a
title search, attorney review or physical inspection.
