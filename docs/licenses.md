# Licenses, Citations & Attribution

**Audit date:** 2026-05-25 (Phase E.4 license audit).
**Scope:** datasets used or planned, third-party code dependencies, the
project's own license, and the resulting use/distribution restrictions.

> **Headline finding:** The training data (HAM10000) and the planned external
> validation data (ISIC 2019) are both licensed **CC BY-NC 4.0**
> (Attribution–NonCommercial). The trained model checkpoints are derivative
> works of this data, so **the project as a whole is restricted to
> non-commercial use**. See [§4](#4-implications--restrictions).

---

## 1. Project License

**This project is licensed under the MIT License — see [`LICENSE`](../LICENSE)
in the repository root** (Copyright (c) 2026 Jiahao).

MIT was chosen for maximum reuse of the *source code* in an academic / open
context. **Crucially, the MIT license governs the code only.** It does **not**
and **cannot** relax the CC BY-NC 4.0 obligations that attach to the trained
model weights (and any other dataset-derived artefact) by virtue of the
training data — see [§4](#4-implications--restrictions). In short:

- **Code** → MIT (permissive; commercial reuse of the code is allowed).
- **Trained weights / dataset-derived artefacts** → CC BY-NC 4.0
  (non-commercial only), inherited from HAM10000 / ISIC 2019.

Every dependency below is compatible with MIT (all permissive: BSD / Apache-2.0
/ MIT / PSF-based).

---

## 2. Datasets Used

All citations below were verified against official/primary sources on
2026-05-25; the retrieved URLs are recorded for each.

### 2.1 HAM10000 (training data — currently used)

- **License:** CC BY-NC 4.0 (Attribution–NonCommercial 4.0 International).
  Non-commercial use only; attribution required.
- **Dataset source:** Harvard Dataverse, ViDIR Group, Medical University of
  Vienna. DOI `10.7910/DVN/DBW86T`.
  Verified: <https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/DBW86T>
- **Required citation (verified via PubMed 30106392):**

  > Tschandl P., Rosendahl C. & Kittler H. The HAM10000 dataset, a large
  > collection of multi-source dermatoscopic images of common pigmented skin
  > lesions. *Scientific Data* **5**, 180161 (2018).
  > doi:10.1038/sdata.2018.161

  Verified: <https://pubmed.ncbi.nlm.nih.gov/30106392/> ·
  DOI <https://doi.org/10.1038/sdata.2018.161>

### 2.2 ISIC 2019 (external validation — planned, Phase E)

- **License:** CC BY-NC 4.0 (per the ISIC Challenge data page).
  Verified: <https://challenge.isic-archive.com/data/>
- **Composition:** ISIC 2019 aggregates three sources — **BCN_20000 +
  HAM10000 + MSK**. (This is why Phase E.3 cross-set deduplication is critical:
  ISIC 2019 *contains* HAM10000.)
- **Required attribution (verbatim from the ISIC data page):**

  > BCN_20000 Dataset: (c) Department of Dermatology, Hospital Clínic de
  > Barcelona.
  > HAM10000 Dataset: (c) by ViDIR Group, Department of Dermatology, Medical
  > University of Vienna; doi:10.1038/sdata.2018.161.
  > MSK Dataset: (c) Anonymous; arXiv:1710.05006 and arXiv:1902.03368.

- **Required aggregate citations (verified):**

  **[1]** Tschandl P., Rosendahl C. & Kittler H. The HAM10000 dataset, a large
  collection of multi-source dermatoscopic images of common pigmented skin
  lesions. *Scientific Data* **5**, 180161 (2018). doi:10.1038/sdata.2018.161.

  **[2]** Codella N.C.F., Gutman D., Celebi M.E., Helba B., Marchetti M.A.,
  Dusza S.W., Kalloo A., Liopyris K., Mishra N., Kittler H., Halpern A. "Skin
  Lesion Analysis Toward Melanoma Detection: A Challenge at the 2017
  International Symposium on Biomedical Imaging (ISBI), Hosted by the
  International Skin Imaging Collaboration (ISIC)", 2017. arXiv:1710.05006.
  Verified: <https://arxiv.org/abs/1710.05006>

  **[3]** Hernández-Pérez C., Combalia M., Podlipnik S., Codella N.C.F.,
  Rotemberg V., Halpern A.C., Reiter O., Carrera C., Barreiro A., Helba B.,
  Puig S., Vilaplana V., Malvehy J. BCN20000: Dermoscopic Lesions in the Wild.
  *Scientific Data* **11**(1):641 (2024). doi:10.1038/s41597-024-03387-w.
  Verified: <https://www.nature.com/articles/s41597-024-03387-w> ·
  <https://pmc.ncbi.nlm.nih.gov/articles/PMC11183228/>

- **Class-mapping note (Phase E.2):** ISIC 2019 has 8 classes
  (MEL, NV, BCC, AK, BKL, DF, VASC, SCC); HAM10000 has 7. `AK ≈ akiec`. **SCC**
  has no HAM10000 equivalent and must be dropped or reported as an unsupported
  class during external evaluation. (Tracked under Phase E, not this audit.)

---

## 3. Dependency Licenses

Python package licenses were read from the installed package metadata in
`.venv` (authoritative for the exact pinned versions in `requirements.txt` /
the separately-installed PyTorch stack). All are permissive and OSI-approved.
**No GPL, AGPL, or LGPL dependency is present** in the stack.

| Package | Version | License | Reference |
|---|---|---|---|
| torch | 2.11.0+cu128 | BSD-3-Clause | <https://pypi.org/project/torch/> |
| torchvision | 0.26.0+cu128 | BSD-3-Clause | <https://pypi.org/project/torchvision/> |
| timm | 1.0.12 | Apache-2.0 | <https://pypi.org/project/timm/> |
| fastapi | 0.115.6 | MIT | <https://pypi.org/project/fastapi/> |
| starlette (FastAPI dep) | 0.41.3 | BSD-3-Clause | <https://pypi.org/project/starlette/> |
| uvicorn | 0.32.1 | BSD-3-Clause | <https://pypi.org/project/uvicorn/> |
| pydantic | 2.13.3 | MIT | <https://pypi.org/project/pydantic/> |
| numpy | 2.1.3 | BSD-3-Clause | <https://pypi.org/project/numpy/> |
| pandas | 2.2.3 | BSD-3-Clause | <https://pypi.org/project/pandas/> |
| scikit-learn | 1.5.2 | BSD-3-Clause | <https://pypi.org/project/scikit-learn/> |
| matplotlib | 3.9.3 | Matplotlib License (PSF-based, BSD-compatible) | <https://pypi.org/project/matplotlib/> |
| pillow | 11.0.0 | MIT-CMU (HPND, BSD-compatible) | <https://pypi.org/project/pillow/> |
| python-multipart | 0.0.20 | Apache-2.0 | <https://pypi.org/project/python-multipart/> |
| pyyaml | 6.0.2 | MIT | <https://pypi.org/project/PyYAML/> |
| tqdm | 4.67.1 | MPL-2.0 AND MIT | <https://pypi.org/project/tqdm/> |
| Flutter SDK | (frontend) | BSD-3-Clause | <https://github.com/flutter/flutter/blob/master/LICENSE> |

**Notes**
- **tqdm** is dual-noted `MPL-2.0 AND MIT`: the bulk of the library is MIT;
  a small portion (the CLI) is MPL-2.0, a *file-level* weak copyleft. MPL-2.0
  obligations attach only to MPL-licensed files if **they** are modified and
  redistributed — we use tqdm unmodified, so no source-disclosure obligation
  falls on this project's code.
- **matplotlib** uses its own PSF-derived license, which is BSD-compatible and
  imposes no copyleft.
- **Pillow** (MIT-CMU / HPND) is permissive and BSD-compatible.
- These are permissive licenses: they require preserving copyright/license
  notices when redistributing the libraries (e.g. inside a Docker image —
  relevant to Phase F), but place no restriction on this project's own code or
  on commercial use *of the code*. The binding non-commercial restriction comes
  entirely from the datasets (§2), not the code dependencies.

---

## 4. Implications & Restrictions

1. **The trained checkpoints are derivative works of HAM10000** (and, once
   Phase E evaluates on it, of ISIC 2019). CC BY-NC 4.0 therefore **propagates
   to the model weights** and to anything that embeds them.
2. **This project as a whole is non-commercial use only.** The CC BY-NC 4.0
   "NonCommercial" term governs the weights regardless of what code license is
   chosen for the source.
3. **Permitted:** academic, research, and educational use — including the
   thesis defense, demos, publications, and educational deployment.
4. **Not permitted without renegotiating the dataset licenses:** any commercial
   use — a clinical product, a paid app-store application, a commercial API,
   or bundling the weights into a commercial offering.
5. **Distribution:** when redistributing (e.g. a Phase F release or Docker
   image), the model artefacts must carry the CC BY-NC 4.0 notice and the
   required dataset attributions (§2). Bundled third-party libraries must retain
   their own permissive license/notice files (§3).
6. **Not a medical device.** Independently of licensing, the system is an
   educational prototype and is not cleared for clinical use under any
   regulatory framework (already stated throughout the project).

---

## 5. Required Attributions

The dataset attributions in §2 **must** appear in:

- **`README.md`** — License & Citations section (added; links here).
- **The mobile app About page** (`SafetyAboutScreen`) — should display the
  HAM10000 attribution now, and the ISIC 2019 / BCN_20000 / MSK attributions
  once external validation ships. *(UI change tracked separately — not part of
  this docs-only audit.)*
- **Any published report, thesis, or slide deck** — full citations [1]–[3]
  from §2.2 plus the HAM10000 citation from §2.1.
- **Any redistribution of the model weights** — the CC BY-NC 4.0 notice and
  the dataset attributions.

---

## 6. How to Cite This Project

> Author and year are placeholders for the maintainer to fill in.

```bibtex
@misc{skinlesion_cnn_2026,
  title        = {CNN-Based Skin Lesion Classification for Early Skin Cancer Detection},
  author       = {<AUTHOR NAME(S)>},
  year         = {<YEAR>},
  howpublished = {\url{<REPOSITORY OR RELEASE URL>}},
  note         = {Educational prototype. Trained on the HAM10000 dataset
                  (CC BY-NC 4.0); non-commercial use only.}
}
```

Any use of this project must **also** cite the underlying datasets — the
HAM10000 citation (§2.1) and, if ISIC 2019 results are used, citations [1]–[3]
(§2.2).

---

## 7. Acknowledgments

- **HAM10000** — Philipp Tschandl, Cliff Rosendahl, Harald Kittler, and the
  ViDIR Group, Department of Dermatology, Medical University of Vienna.
- **ISIC 2019 / BCN_20000** — Department of Dermatology, Hospital Clínic de
  Barcelona; and the International Skin Imaging Collaboration (ISIC) archive.
- **MSK dataset** — contributors to the ISIC archive (arXiv:1710.05006,
  arXiv:1902.03368).
- **Open-source libraries** — the PyTorch, timm, FastAPI/Starlette/uvicorn,
  pydantic, NumPy, pandas, scikit-learn, matplotlib, Pillow, and Flutter
  communities, whose permissive-licensed work this project builds on.
