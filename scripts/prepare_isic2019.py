"""Phase E.1-E.3 — prepare a HAM10000-disjoint ISIC 2019 external test set.

Produces ``data/processed/isic2019_clean_test.csv``: ISIC 2019 test images
mapped to the HAM10000 7-class vocabulary, with HAM10000-overlapping images
removed so the set can serve as a genuine out-of-distribution test in Phase E.6.

Pipeline (deterministic / idempotent — re-running yields identical output):

  (a) Label conversion: argmax over the 8 ISIC diagnostic one-hot columns
      (MEL, NV, BCC, AK, BKL, DF, VASC, SCC) -> HAM label string.
        - AK   -> akiec   (Actinic Keratosis maps to HAM's combined AK/IEC class)
        - SCC  -> dropped  (no HAM equivalent; conservative)
        - UNK / all-zero rows -> dropped (no diagnostic label; not in task spec
          but present in the real GroundTruth file as a 9th "UNK" column)
  (b) Cross-set deduplication against HAM10000 (data/processed/splits.csv):
        - drop ISIC test rows whose image_id is in HAM (exact-image leakage).
        - lesion-level dedup is NOT possible: the ISIC 2019 Test Metadata has
          no lesion_id column, ISIC test images are absent from the Training
          Metadata (which does carry lesion_id), and ISIC vs HAM use different
          lesion_id namespaces (e.g. MSK4_xxxx vs IL_xxxxxxx). The step is left
          in place but degrades to a no-op, logged in the report. See the
          limitation in docs/phase_e_data_preparation.md.
  (c) Output CSV with columns: image_id, label, image_path, lesion_id, source.
  (d) Validation report printed to stdout and saved as JSON next to the CSV.

Usage:
    python scripts/prepare_isic2019.py
    python scripts/prepare_isic2019.py --dry-run        # compute + report, no write
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

# 8 ISIC diagnostic classes, in GroundTruth column order. UNK is intentionally
# excluded — it is the "none of the above" outlier class.
ISIC_CLASSES = ["MEL", "NV", "BCC", "AK", "BKL", "DF", "VASC", "SCC"]
# ISIC class -> HAM10000 label. SCC has no entry => dropped.
ISIC_TO_HAM = {
    "MEL": "mel",
    "NV": "nv",
    "BCC": "bcc",
    "AK": "akiec",
    "BKL": "bkl",
    "DF": "df",
    "VASC": "vasc",
}
HAM_VOCAB = {"akiec", "bcc", "bkl", "df", "mel", "nv", "vasc"}
SOURCE_TAG = "isic2019_test_clean"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Prepare HAM-disjoint ISIC 2019 test set.")
    p.add_argument("--ext-dir", default="data/external/isic2019",
                   help="directory holding the ISIC 2019 raw files")
    p.add_argument("--ham-splits", default="data/processed/splits.csv")
    p.add_argument("--out", default="data/processed/isic2019_clean_test.csv")
    p.add_argument("--dry-run", action="store_true",
                   help="compute and report but do not write the output CSV")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    ext = Path(args.ext_dir)
    gt_path = ext / "ISIC_2019_Test_GroundTruth.csv"
    test_meta_path = ext / "ISIC_2019_Test_Metadata.csv"
    train_meta_path = ext / "ISIC_2019_Training_Metadata.csv"
    input_dir = ext / "ISIC_2019_Test_Input"

    gt = pd.read_csv(gt_path)
    test_meta = pd.read_csv(test_meta_path)
    ham = pd.read_csv(args.ham_splits)

    report: dict[str, object] = {}
    report["inputs"] = {
        "ground_truth": str(gt_path), "test_metadata": str(test_meta_path),
        "training_metadata": str(train_meta_path), "ham_splits": str(args.ham_splits),
        "image_dir": str(input_dir),
    }
    start = len(gt)

    # ---- (a) label conversion -------------------------------------------------
    # Drop UNK / all-zero rows: no diagnostic label to map.
    diag_sum = gt[ISIC_CLASSES].sum(axis=1)
    unk_dropped = int((diag_sum == 0).sum())
    g = gt[diag_sum > 0].copy()
    after_unk = len(g)

    # argmax over the 8 diagnostic columns -> ISIC class name.
    g["isic_class"] = g[ISIC_CLASSES].to_numpy().argmax(axis=1)
    g["isic_class"] = g["isic_class"].map(dict(enumerate(ISIC_CLASSES)))

    scc_dropped = int((g["isic_class"] == "SCC").sum())
    g = g[g["isic_class"] != "SCC"].copy()
    after_scc = len(g)

    g["label"] = g["isic_class"].map(ISIC_TO_HAM)
    assert g["label"].notna().all(), "unmapped ISIC class survived SCC/UNK filtering"

    # ---- (b) cross-set deduplication -----------------------------------------
    ham_image_ids = set(ham["image_id"])
    ham_lesion_ids = set(ham["lesion_id"].astype(str))

    img_overlap = int(g["image"].isin(ham_image_ids).sum())
    g = g[~g["image"].isin(ham_image_ids)].copy()
    after_img_dedup = len(g)

    # lesion-level dedup: only feasible if the test metadata carries lesion_id.
    lesion_dedup_applicable = "lesion_id" in test_meta.columns
    lesion_dropped = 0
    if lesion_dedup_applicable:
        meta_lesion = test_meta.set_index("image")["lesion_id"].astype(str)
        g["_lesion"] = g["image"].map(meta_lesion)
        mask = g["_lesion"].isin(ham_lesion_ids)
        lesion_dropped = int(mask.sum())
        g = g[~mask].drop(columns=["_lesion"]).copy()
    after_lesion_dedup = len(g)

    # ---- (c) build output -----------------------------------------------------
    out = pd.DataFrame({
        "image_id": g["image"].to_numpy(),
        "label": g["label"].to_numpy(),
        "image_path": [f"{input_dir.as_posix()}/{img}.jpg" for img in g["image"]],
        "lesion_id": "",  # ISIC 2019 Test Metadata carries no lesion_id
        "source": SOURCE_TAG,
    })
    out = out.sort_values("image_id").reset_index(drop=True)  # deterministic order

    # ---- (d) validation -------------------------------------------------------
    bad_labels = sorted(set(out["label"]) - HAM_VOCAB)
    dup_ids = int(out["image_id"].duplicated().sum())
    missing = [p for p in out["image_path"] if not Path(p).exists()]
    validation = {
        "labels_all_in_ham_vocab": not bad_labels,
        "unexpected_labels": bad_labels,
        "duplicate_image_ids": dup_ids,
        "missing_image_files": len(missing),
        "missing_examples": missing[:5],
    }

    ham_test = ham[ham["split"] == "test"]
    report["counts"] = {
        "initial_test_gt_rows": start,
        "unk_or_allzero_dropped": unk_dropped,
        "after_unk_drop": after_unk,
        "scc_dropped": scc_dropped,
        "after_scc_drop": after_scc,
        "image_id_overlap_with_ham": img_overlap,
        "after_image_id_dedup": after_img_dedup,
        "lesion_dedup_applicable": lesion_dedup_applicable,
        "lesion_id_dropped": lesion_dropped,
        "after_lesion_dedup": after_lesion_dedup,
        "final_rows": len(out),
    }
    report["final_per_class"] = out["label"].value_counts().sort_index().to_dict()
    report["ham_test_per_class"] = ham_test["label"].value_counts().sort_index().to_dict()
    report["validation"] = validation

    # ---- print ----------------------------------------------------------------
    print("=== ISIC 2019 -> HAM-disjoint test set preparation ===")
    c = report["counts"]
    print(f"initial test GT rows        : {c['initial_test_gt_rows']}")
    print(f"  - UNK/all-zero dropped     : {c['unk_or_allzero_dropped']}  -> {c['after_unk_drop']}")
    print(f"  - SCC dropped              : {c['scc_dropped']}  -> {c['after_scc_drop']}")
    print(f"  - image_id dups vs HAM     : {c['image_id_overlap_with_ham']}  -> {c['after_image_id_dedup']}")
    print(f"  - lesion_id dedup          : applicable={c['lesion_dedup_applicable']} "
          f"dropped={c['lesion_id_dropped']}  -> {c['after_lesion_dedup']}")
    print(f"FINAL clean test rows       : {c['final_rows']}")
    print("\nper-class (clean ISIC test):")
    for k, v in report["final_per_class"].items():
        print(f"  {k:6} {v}")
    print("\nper-class (HAM10000 test, 1734):")
    for k, v in report["ham_test_per_class"].items():
        print(f"  {k:6} {v}")
    print("\nvalidation:", json.dumps(validation))

    if not validation["labels_all_in_ham_vocab"] or dup_ids or missing:
        raise SystemExit("VALIDATION FAILED — see report above; output not written.")

    # ---- write ----------------------------------------------------------------
    out_path = Path(args.out)
    report_path = out_path.with_name("isic2019_prep_report.json")
    if args.dry_run:
        print(f"\n[dry-run] would write {len(out)} rows to {out_path}")
        return
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(out_path, index=False)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nwrote {len(out)} rows -> {out_path}")
    print(f"wrote report -> {report_path}")


if __name__ == "__main__":
    main()
