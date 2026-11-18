# Build log

Short entries as you go: what you decided, what broke, how you fixed it, what you learned.
This becomes the case study and your interview stories.

## Template

### YYYY-MM-DD — title
- **Goal:**
- **Decision / change:**
- **Problem hit:**
- **Fix:**
- **Numbers:** (rows loaded, tests passing, run time)
- **Lesson:**

---

## Sprint 1 — Foundation (weeks 1–2)

Definition of done:
- [x] `verify_datasets.py` passes for every enabled dataset (IDs, filter columns, non-zero counts)
- [x] Sample load works for all enabled datasets
- [ ] `profile_raw.py` output reviewed; staging models written for each enabled source
- [x] `stg_pluto` and `dim_property` build with all tests passing on the full Brooklyn load
- [ ] CI green on GitHub
- [ ] (1 of 3 done) Look up 3 known addresses and sanity-check their lot data by hand

Open questions to resolve in Sprint 1:
- Which ACRIS document types count as deeds vs. mortgages vs. satisfactions?
- How do DOB NOW and older BIS filings overlap for the same job?
- Which violation statuses mean "open"?

### 2026-11-17 — Project kickoff
- **Goal:** Repo scaffold, loaders, dbt project, property spine.
- **Decision / change:** DuckDB + dbt Core (free, local, portable). Raw data stored as text-only gzipped CSV; all typing in dbt staging. Brooklyn and 1–4 family / small multifamily as v1 scope.
- **Lesson:**
### 2026-11-17 — Dataset verification, sample load, full PLUTO load
- **Goal:** Prove every dataset ID and borough filter before writing more staging models.
- **Decision / change:** Ran `verify_datasets.py --all` against all 15 datasets, including disabled ones.
- **Problem hit:** 13 of 15 passed on the first try. Both DOB NOW datasets (`w9ak-ipjd`, `rbx6-tga4`) returned 0 rows with `borough = 'BROOKLYN'`. DOB complaints (`eabe-havv`) has no borough column at all.
- **Fix:** A `$group=borough` query showed that DOB NOW stores title case (`'Brooklyn'`). Complaints are filtered on `community_board like '3%'` (961,374 rows; `bin like '3%'` gives 961,395, a 21-row difference worth checking later). The borough is now coded four different ways across sources: `BK`, `BROOKLYN`, `Brooklyn`, `3`.
- **Numbers:** All 15 verified, 0 problems. Brooklyn row counts: PLUTO 276,106; BIS permits 947,692; BIS filings 692,101; DOB NOW filings 269,930; DOB NOW permits 269,089; DOB violations 748,554; ECB 555,534; HPD violations 4,285,884; HPD registrations 80,850; HPD contacts 744,753 (citywide); ACRIS master 4,337,889; ACRIS legals 7,498,400; ACRIS parties 46.8M (citywide); DOF sales 239,778; DOB complaints 961,374. The sample load (2,000 rows × 12 datasets) took 37s. The full PLUTO load took 3m10s with no app token. dbt build: 15/15 pass on the sample and on the full load.
- **dim_property (full Brooklyn):** 1–4 family 220,528; small multifamily 22,696 (v1 target is 243,224 lots, 88%); non-residential 26,540; mid multifamily 5,376; large multifamily 966.
- **Spot checks:** 620 Atlantic Ave resolves to BBL 3011180001 (Barclays Center, built 2011, owner `ARENA NOMINEE SUB B,`). The owner name has a trailing comma, so owner names need cleaning before entity resolution. A plain-text lookup of `209 JORALEMON` (Borough Hall) returned nothing. That means address search cannot be raw string matching; it needs normalization (house-number ranges, street suffixes) or geocoding (NYC Geoclient / Geosupport). That work is planned for Sprint 3 and the app.
- **Lesson:** Run a `$group` on the filter column before trusting a filter. A zero-row result fails silently unless the script checks for it. A free Socrata app token should speed up the multi-million-row loads (HPD violations, ACRIS).

### 2026-11-18 — stg_dob_violations
- **Goal:** First event-level staging model; answer "which violation statuses mean open?"
- **Decision / change:** Status is parsed from the `violation_category` prefix. A `*` means closed, `W` means work without permit, `H` means hazardous. Added `safe_yyyymmdd` / `safe_mdy` date macros that null out impossible dates.
- **Problem hit:** Raw issue dates range from year 0202 to 3321 (typos). There is no BBL column; it is built from boro/block/lot, and 3,794 rows (0.5%) have no block/lot.
- **Fix:** Dates outside 1900 to next year become null (11 rows). BBL is left null where the parts are missing; those rows can still join on BIN.
- **Numbers:** 748,554 rows, loaded in 2m05s. 234,757 open, which exactly matches the source's sum of ACTIVE categories. 16,085 work-without-permit, 569 hazardous. 4/4 tests pass.
- **Finding (product-critical):** 45% of open violations were issued before 2010, which looks like stale, never-closed paperwork. Recent open violations are dominated by `LBLVIO` (57k since 2016), `BENCH` and `HBLVIO`. These appear to be boiler-filing and energy-benchmarking compliance items, not physical hazards (to be confirmed against DOB's code list). A raw open-violation count would badly mislead the risk score. The score needs severity × recency, with type classification as a candidate for the AI step.
- **Lesson:** Reconcile parsed flags back to source totals. An exact match is a strong correctness check for a free-text parsing rule.
- 2026-11-18: First CI run failed: the Secret Token had been stored instead of the App Token (HTTP 403 “Invalid app_token”). Fixed the secret; added .strip() to token handling. CI green, 7m24s.
