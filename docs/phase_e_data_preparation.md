# Phase E.1–E.3 — ISIC 2019 External Test Set Preparation

**Date:** 2026-05-25
**Output:** `data/processed/isic2019_clean_test.csv` (4,353 rows) — a
HAM10000-disjoint, HAM10000-label-aligned external test set for the Phase E.6
out-of-distribution evaluation.
**Script:** `scripts/prepare_isic2019.py` (deterministic, idempotent).
**Audit report:** `data/processed/isic2019_prep_report.json` (machine-readable
copy of the counts below; gitignored with the rest of `data/`).

## Source files (`data/external/isic2019/`)

| File | Rows / entries | Used for |
|---|---|---|
| `ISIC_2019_Test_GroundTruth.csv` | 8,238 | one-hot diagnosis labels |
| `ISIC_2019_Test_Metadata.csv` | 8,238 | age / sex / site (no `lesion_id`) |
| `ISIC_2019_Training_Metadata.csv` | 25,331 | reference only (carries `lesion_id`) |
| `ISIC_2019_Test_Input/` | 8,240 entries | images (8,238 `.jpg` + 2 non-image) |

The `ISIC_2019_Test_Input/` folder contains **8,240** entries, not 8,238: the
two extras are `ATTRIBUTION.txt` and `LICENSE.txt`. The script iterates the CSV
(8,238 image rows), so these are naturally excluded.

### Schema differences found vs. the task brief
1. **Extra `UNK` column.** The GroundTruth has 9 class columns —
   `MEL, NV, BCC, AK, BKL, DF, VASC, SCC, **UNK**` — plus `score_weight` and
   `validation_weight`. `UNK` ("none of the above" / outlier) accounts for
   **2,047** rows in which all 8 diagnostic columns are 0. A naïve argmax over
   only the 8 named columns would mis-assign these to MEL, so they are dropped.
2. **No `lesion_id` in the Test Metadata.** It has only
   `image, age_approx, anatom_site_general, sex`. Only the *Training* Metadata
   carries `lesion_id` — see the deduplication note below.

## (a) Label conversion: ISIC 8-class one-hot → HAM 7-class string

`argmax` over the 8 diagnostic columns gives the ISIC class, then:

| ISIC | HAM | Note |
|---|---|---|
| MEL | mel | |
| NV | nv | |
| BCC | bcc | |
| **AK** | **akiec** | Actinic Keratosis maps to HAM's combined "actinic keratosis + intraepithelial carcinoma" class — they share the AK component. |
| BKL | bkl | |
| DF | df | |
| VASC | vasc | |
| **SCC** | *(dropped)* | No HAM equivalent. Intraepithelial carcinoma is technically a *subset* of HAM's `akiec`, but the dataset boundary is ambiguous, so the conservative choice is to drop SCC rather than fold it into `akiec`. |
| **UNK / all-zero** | *(dropped)* | No diagnostic label to map. |

**Dropped at this stage:** 2,047 UNK/all-zero rows, then 165 SCC rows.

## (b) Cross-set deduplication against HAM10000

HAM10000 (`data/processed/splits.csv`, 11,720 rows) is part of ISIC 2019's
**training** split, so any ISIC **test** image that also appears in HAM is
leakage for a model trained on HAM.

**Applied — exact image_id dedup.** Drop every ISIC test row whose `image_id`
is in the HAM `image_id` set (across *all* HAM splits — train, val, and test —
the conservative choice). This removed **1,673** rows. (The full HAM ∩ ISIC-test
image overlap is 1,705; the other 32 were already removed as UNK/SCC.)

> **Note on the HAM split file.** Of the 11,720 HAM rows, 10,015 are the
> canonical HAM10000 images (all present in the ISIC 2019 *training* metadata),
> and the remaining **1,705 are themselves ISIC 2019 *test* images**. In other
> words `splits.csv` already contained the exact images that make up part of the
> ISIC test set; the image_id dedup is precisely what removes that overlap from
> the external evaluation. After dedup the clean test set shares **zero**
> image_ids with `splits.csv` (verified).

**Not applied — lesion-level dedup (documented limitation).** The intended
extra guard — "drop ISIC test images whose *lesion* appears in HAM" — is **not
feasible** with the available data:
- The ISIC 2019 **Test Metadata has no `lesion_id`** column.
- ISIC test images do **not** appear in the Training Metadata (train/test are
  disjoint — verified: 0 of 8,238), so their lesion ids cannot be recovered.
- ISIC and HAM use **different lesion-id namespaces** (ISIC e.g.
  `MSK4_0011169`; HAM e.g. `IL_7252831`), so the sets would not align even if
  available.

The script keeps the lesion-dedup step but it degrades to a logged no-op
(`lesion_dedup_applicable=false`). The residual risk this leaves is captured
under [Limitations](#limitations).

## (c) Output schema (`isic2019_clean_test.csv`)

| Column | Value |
|---|---|
| `image_id` | ISIC id, e.g. `ISIC_0053453` |
| `label` | HAM vocabulary, e.g. `mel` |
| `image_path` | `data/external/isic2019/ISIC_2019_Test_Input/<image_id>.jpg` |
| `lesion_id` | empty (unavailable in ISIC Test Metadata) |
| `source` | constant `isic2019_test_clean` |

Rows are sorted by `image_id` so re-runs are byte-identical.

## (d) Final statistics

```
initial test GT rows        : 8238
  - UNK/all-zero dropped     : 2047  -> 6191
  - SCC dropped              :  165  -> 6026
  - image_id dups vs HAM     : 1673  -> 4353
  - lesion_id dedup          : not applicable (no lesion_id in test metadata)
FINAL clean test rows       : 4353
```

### Per-class distribution vs. HAM10000 test split

| Class | ISIC clean test | share | HAM10000 test | share |
|---|--:|--:|--:|--:|
| nv | 1,463 | 33.6% | 1,152 | 66.4% |
| mel | 1,135 | 26.1% | 188 | 10.8% |
| bcc | 867 | 19.9% | 91 | 5.2% |
| bkl | 421 | 9.7% | 199 | 11.5% |
| akiec | 355 | 8.2% | 52 | 3.0% |
| vasc | 66 | 1.5% | 27 | 1.6% |
| df | 46 | 1.1% | 25 | 1.4% |
| **Total** | **4,353** | | **1,734** | |

The external set is **substantially less `nv`-dominated** and much **richer in
melanoma and BCC** than the HAM10000 test split. This is a genuinely different
class prior (not just a covariate shift), which is exactly what makes it a
useful generalisation probe — and which Phase E.6 must account for when reading
accuracy vs. macro-averaged metrics.

## How to re-run

```bash
python scripts/prepare_isic2019.py            # writes the CSV + report
python scripts/prepare_isic2019.py --dry-run  # compute + report only, no write
```

The script is deterministic and idempotent: re-running produces a
byte-identical CSV (verified via SHA-256). It self-validates before writing
(all labels in HAM vocabulary, no duplicate `image_id`, every `image_path`
exists) and aborts without writing if any check fails.

## Limitations

- **Lesion-level leakage not fully excludable.** Exact-image leakage is
  removed, but if a HAM lesion contributed a *different photo* to the ISIC test
  set under a different `image_id`, it cannot be detected (no test `lesion_id`;
  different namespaces). Given that the 1,705 HAM/ISIC-test image overlaps were
  all exact-id matches and are removed, the residual risk is believed small but
  is not provably zero.
- **AK↔akiec is an approximate mapping.** HAM's `akiec` bundles actinic
  keratoses *and* intraepithelial carcinoma; ISIC separates AK from SCC. Mapping
  AK→akiec and dropping SCC means the external `akiec` is narrower (AK only)
  than HAM's training definition — a label-definition shift to keep in mind.
- **Acquisition differences.** ISIC 2019 test images (BCN_20000 / MSK sources)
  differ from HAM10000 in devices, sites, and capture conditions; some
  measured degradation in Phase E.6 will be distribution shift rather than pure
  model weakness.
- **Annotation noise.** Ground-truth conventions may differ across the
  aggregated ISIC sources and HAM10000.
- **No skin-tone stratification.** ISIC 2019 metadata has age/sex/site but no
  Fitzpatrick type, so the planned Phase E.5 bias audit cannot stratify by skin
  tone from this data alone.
