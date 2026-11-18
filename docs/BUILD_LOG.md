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
- [x] Which ACRIS document types count as deeds vs. mortgages vs. satisfactions? (acris_document_types seed)
- How do DOB NOW and older BIS filings overlap for the same job?
- [x] Which violation statuses mean "open"? (DOB: no `*` in prefix; ECB: ACTIVE; HPD: Open)

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

### 2026-11-18 — stg_ecb_violations, stg_dobnow_approved_permits
- **Goal:** Stage the fines (ECB) and the contractor-bearing permits (DOB NOW).
- **Decision / change:** ECB severity is in two schemes (old `Hazardous`/`Non-Hazardous`, new `CLASS - 1/2/3`), normalized to a single `severity_level` (high/medium/low). `Non-Hazardous` maps to medium because the old scheme does not separate major from lesser. The source column `penality_imposed` (misspelled) is renamed in staging. On permits, the applicant license and business name are the contractor key.
- **Problem hit:** The assumed permit grain (permit + sequence) failed with 26,001 duplicate groups.
- **Fix:** Profiled which columns vary inside duplicates: `work_type` in 25,860 of 26,001. One permit number covers several work types (e.g. General Construction + Foundation + Structural). The grain is now permit + sequence + work type. The 217 remaining true duplicates (0.08%, re-issued permits with a different contractor or issue date) are a warning, set to fail above 500, and are deduplicated downstream.
- **Numbers:** ECB 555,604 rows (unique record IDs), 93,082 open. DOB NOW permits 269,443 rows, 9,614 contractors, 44,506 lots. Each full load took about 6 minutes without a token. Tests: 7 pass, 1 warn.
- **Finding (product-critical):** About $302M in unpaid ECB balances across Brooklyn, $221M of it on high-severity violations, on roughly 20k lots. Unpaid balance is a concrete, dollar-denominated buyer red flag and a candidate headline metric for the memo.
- **Lesson:** When a uniqueness test fails, profile which columns vary inside the duplicate groups before deduplicating. Here it revealed a business rule (multi-work-type permits), not dirty data.

### 2026-11-18 — HPD and ACRIS staging; ACRIS document-type seed
- **Goal:** Stage the owner side (HPD registrations and contacts), housing conditions (HPD violations) and transactions (ACRIS master and legals).
- **Decision / change:** Added the `acris_document_types` dbt seed from the city's ACRIS Document Control Codes (7isb-wh4c, 126 codes) instead of a hand-written list. `doc_class` = deed (34) / mortgage (23) / lien (29) / other (40). This answers the Sprint 1 open question on deed vs mortgage types. Caveat: the city classes satisfactions (`SAT`) as mortgage instruments; separate them when computing outstanding debt. HPD class mapped to severity: C high, B medium, A low, I info (information orders are administrative).
- **Problem hit:** `registrationcontactid` is not unique in the source. About 1,450 of 744k IDs (0.2%) are reused, sometimes for different people at different addresses. A first fix (dedupe raw rows, then hash) still collided, because rows that differ only in dropped columns (middle initial, suite) become identical after cleaning.
- **Fix:** Deduplicate after cleaning; `contact_row_key = md5(cleaned row)` is the tested unique key. The source ID's uniqueness is a warning that fails above 2,500.
- **Numbers (Brooklyn, from the portal):** HPD violations 4,285,884 (open: B 572k, A 303k, C 225k, I 109k). ACRIS master 4,337,889 (MTGE 1.23M, DEED 1.07M, SAT 761k, ASST 575k). HPD contact types: SiteManager 156k, Agent 148k, HeadOfficer 121k, CorporateOwner 114k, IndividualOwner 47k. Full dbt build on samples: 49 pass, 3 warn (all explained), 0 errors.
- **Lesson:** A relationship test between two independently sampled tables produces meaningless orphans; it is set to warn and must be read on the full load. Deduplicate at the grain you actually keep, not the raw grain.
