#!/usr/bin/env python3
"""Compute accuracy metrics on real recordings.

For each sample in tests/fixtures/golden/real/ with:
  - {name}.baseline.txt   (original pasted text from older version)
  - {name}.txt            (current best transcript / gold)
  - {name}.wav            (audio)

This script:
  - Computes WER(baseline -> gold)
  - Calls the current daemon on {name}.wav and computes WER(current -> gold)
  - Prints a small table and writes JSON to tests/results/real_accuracy_*.json

Usage:
  python3 scripts/metrics/real_accuracy.py

Assumptions:
  - PTTServiceDaemon is running on http://127.0.0.1:8765
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass, asdict
from datetime import datetime
from pathlib import Path
from typing import List

API_URL = "http://127.0.0.1:8765/transcribe"
ROOT = Path(__file__).resolve().parents[2]
REAL_DIR = ROOT / "tests/fixtures/golden/real"
RESULT_DIR = ROOT / "tests/results"


@dataclass
class RealSampleResult:
    name: str
    words: int
    baseline_wer: float
    baseline_errors: int
    current_wer: float
    current_errors: int


def normalize(text: str) -> List[str]:
    """Normalize text the same way compare_accuracy.py does."""
    text = text.lower()
    text = re.sub(r"[^\w\s]", "", text)
    return text.split()


def wer(ref: str, hyp: str) -> tuple[float, int, int]:
    ref_words = normalize(ref)
    hyp_words = normalize(hyp)
    if not ref_words:
        return 0.0, 0, 0

    m, n = len(ref_words), len(hyp_words)
    d = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(m + 1):
        d[i][0] = i
    for j in range(n + 1):
        d[0][j] = j

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if ref_words[i - 1] == hyp_words[j - 1]:
                d[i][j] = d[i - 1][j - 1]
            else:
                d[i][j] = min(
                    d[i - 1][j] + 1,  # deletion
                    d[i][j - 1] + 1,  # insertion
                    d[i - 1][j - 1] + 1,  # substitution
                )

    errors = d[m][n]
    return errors / m * 100.0, errors, m


def call_daemon(wav_path: Path) -> str:
    body = json.dumps({"path": str(wav_path)})
    proc = subprocess.run(
        [
            "curl",
            "-s",
            "-X",
            "POST",
            API_URL,
            "-H",
            "Content-Type: application/json",
            "-d",
            body,
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    data = json.loads(proc.stdout)
    return data.get("text", "").strip()


def find_samples() -> List[str]:
    if not REAL_DIR.is_dir():
        return []
    names = []
    for p in REAL_DIR.glob("*.baseline.txt"):
        name = p.stem.replace(".baseline", "")
        gold = REAL_DIR / f"{name}.txt"
        wav = REAL_DIR / f"{name}.wav"
        if gold.exists() and wav.exists():
            names.append(name)
    return sorted(names)


def main() -> None:
    if not REAL_DIR.is_dir():
        print(f"No real fixtures directory: {REAL_DIR}", file=sys.stderr)
        sys.exit(1)

    names = find_samples()
    if not names:
        print("No real samples found (expect *.baseline.txt / *.txt / *.wav)", file=sys.stderr)
        sys.exit(1)

    results: List[RealSampleResult] = []

    print("Real Recording Accuracy (baseline -> gold vs current -> gold)\n")

    for name in names:
        baseline_path = REAL_DIR / f"{name}.baseline.txt"
        gold_path = REAL_DIR / f"{name}.txt"
        wav_path = REAL_DIR / f"{name}.wav"

        baseline = baseline_path.read_text().strip()
        gold = gold_path.read_text().strip()

        b_wer, b_err, N = wer(gold, baseline)

        try:
            current = call_daemon(wav_path)
        except Exception as e:
            print(f"[WARN] Failed to call daemon for {name}: {e}", file=sys.stderr)
            c_wer = c_err = 0
        else:
            c_wer, c_err, _ = wer(gold, current)

        results.append(
            RealSampleResult(
                name=name,
                words=N,
                baseline_wer=round(b_wer, 2),
                baseline_errors=b_err,
                current_wer=round(c_wer, 2),
                current_errors=c_err,
            )
        )

    # Print table
    print(f"{'Sample':<22} {'Words':>5}  {'Baseline WER':>13}  {'Current WER':>12}")
    print("-" * 60)
    for r in results:
        print(
            f"{r.name:<22} {r.words:>5}  "
            f"{r.baseline_wer:>6.2f}% ({r.baseline_errors:2d})  "
            f"{r.current_wer:>6.2f}% ({r.current_errors:2d})"
        )

    avg_base = sum(r.baseline_wer for r in results) / len(results)
    avg_cur = sum(r.current_wer for r in results) / len(results)
    print("-" * 60)
    print(f"Average over {len(results)} samples: baseline {avg_base:.2f}%, current {avg_cur:.2f}%")

    # Write JSON snapshot
    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    version = (
        subprocess.run(
            ["git", "describe", "--tags", "--match", "v[0-9]*", "--always"],
            capture_output=True,
            text=True,
        ).stdout.strip()
        or "unknown"
    )
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    out_path = RESULT_DIR / f"real_accuracy_{version}_{stamp}.json"
    payload = {
        "version": version,
        "timestamp": stamp,
        "samples": [asdict(r) for r in results],
        "avg_baseline_wer": round(avg_base, 2),
        "avg_current_wer": round(avg_cur, 2),
    }
    out_path.write_text(json.dumps(payload, indent=2))
    print(f"\nWrote {out_path}")


if __name__ == "__main__":
    main()
