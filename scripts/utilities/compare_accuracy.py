#!/usr/bin/env python3
"""
Compare transcription accuracy across golden test fixtures.

Measures:
- Word Error Rate (WER) of raw whisper output vs gold
- Word Error Rate (WER) of post-processed output vs gold  
- Improvement delta from post-processing

File structure expected per sample:
  - {name}.txt         - Gold transcript (what should be output)
  - {name}.raw.txt     - Raw whisper-cpp output (before post-processing)
  - {name}.processed.txt - Post-processed output (optional, for comparison)
  - {name}.json        - Metadata including baseline info

Usage:
  python3 scripts/utilities/compare_accuracy.py tests/fixtures/golden
  python3 scripts/utilities/compare_accuracy.py tests/fixtures/golden --category challenging
  python3 scripts/utilities/compare_accuracy.py tests/fixtures/golden --json
"""

import argparse
import json
import os
import sys
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Optional


@dataclass
class AccuracyResult:
    name: str
    category: str
    gold_words: int
    raw_wer: float
    processed_wer: Optional[float]
    improvement: Optional[float]
    raw_errors: int
    processed_errors: Optional[int]
    has_processed: bool


def normalize_text(text: str) -> list[str]:
    """Normalize text for WER comparison."""
    # Lowercase, remove punctuation, split into words
    import re
    text = text.lower()
    text = re.sub(r'[^\w\s]', '', text)
    return text.split()


def calculate_wer(reference: str, hypothesis: str) -> tuple[float, int, int]:
    """
    Calculate Word Error Rate using Levenshtein distance.
    Returns (wer, errors, reference_length)
    """
    ref_words = normalize_text(reference)
    hyp_words = normalize_text(hypothesis)
    
    if not ref_words:
        return 0.0, 0, 0
    
    # Dynamic programming for edit distance
    d = [[0] * (len(hyp_words) + 1) for _ in range(len(ref_words) + 1)]
    
    for i in range(len(ref_words) + 1):
        d[i][0] = i
    for j in range(len(hyp_words) + 1):
        d[0][j] = j
    
    for i in range(1, len(ref_words) + 1):
        for j in range(1, len(hyp_words) + 1):
            if ref_words[i-1] == hyp_words[j-1]:
                d[i][j] = d[i-1][j-1]
            else:
                d[i][j] = min(
                    d[i-1][j] + 1,      # deletion
                    d[i][j-1] + 1,      # insertion
                    d[i-1][j-1] + 1     # substitution
                )
    
    errors = d[len(ref_words)][len(hyp_words)]
    wer = errors / len(ref_words) * 100
    return wer, errors, len(ref_words)


def analyze_sample(category_dir: Path, name: str, category: str) -> Optional[AccuracyResult]:
    """Analyze a single sample."""
    gold_file = category_dir / f"{name}.txt"
    raw_file = category_dir / f"{name}.raw.txt"
    processed_file = category_dir / f"{name}.processed.txt"
    
    if not gold_file.exists():
        return None
    
    gold_text = gold_file.read_text().strip()
    
    # Calculate raw WER
    raw_wer = 0.0
    raw_errors = 0
    if raw_file.exists():
        raw_text = raw_file.read_text().strip()
        raw_wer, raw_errors, _ = calculate_wer(gold_text, raw_text)
    
    # Calculate processed WER if available
    processed_wer = None
    processed_errors = None
    improvement = None
    has_processed = processed_file.exists()
    
    if has_processed:
        processed_text = processed_file.read_text().strip()
        processed_wer, processed_errors, _ = calculate_wer(gold_text, processed_text)
        if raw_wer > 0:
            improvement = raw_wer - processed_wer
    
    return AccuracyResult(
        name=name,
        category=category,
        gold_words=len(normalize_text(gold_text)),
        raw_wer=round(raw_wer, 2),
        processed_wer=round(processed_wer, 2) if processed_wer is not None else None,
        improvement=round(improvement, 2) if improvement is not None else None,
        raw_errors=raw_errors,
        processed_errors=processed_errors,
        has_processed=has_processed
    )


def main():
    parser = argparse.ArgumentParser(description="Compare transcription accuracy")
    parser.add_argument("golden_dir", help="Path to golden test fixtures")
    parser.add_argument("--category", help="Filter to specific category")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show per-sample details")
    args = parser.parse_args()
    
    golden_dir = Path(args.golden_dir)
    if not golden_dir.is_dir():
        print(f"Error: {golden_dir} is not a directory", file=sys.stderr)
        sys.exit(1)
    
    categories = ["micro", "short", "medium", "long", "natural", "challenging"]
    if args.category:
        categories = [args.category]
    
    results: list[AccuracyResult] = []
    
    for category in categories:
        category_dir = golden_dir / category
        if not category_dir.is_dir():
            continue
        
        # Find all samples by looking for .txt files (gold transcripts)
        for txt_file in category_dir.glob("*.txt"):
            # Skip raw and processed files
            if txt_file.stem.endswith('.raw') or txt_file.stem.endswith('.processed'):
                continue
            
            name = txt_file.stem
            result = analyze_sample(category_dir, name, category)
            if result:
                results.append(result)
    
    if not results:
        print("No samples found", file=sys.stderr)
        sys.exit(1)
    
    if args.json:
        output = {
            "total_samples": len(results),
            "samples_with_raw": sum(1 for r in results if r.raw_wer > 0 or r.raw_errors >= 0),
            "samples_with_processed": sum(1 for r in results if r.has_processed),
            "avg_raw_wer": round(sum(r.raw_wer for r in results) / len(results), 2),
            "results": [asdict(r) for r in results]
        }
        if any(r.has_processed for r in results):
            processed_results = [r for r in results if r.has_processed]
            output["avg_processed_wer"] = round(
                sum(r.processed_wer for r in processed_results) / len(processed_results), 2
            )
            output["avg_improvement"] = round(
                sum(r.improvement or 0 for r in processed_results) / len(processed_results), 2
            )
        print(json.dumps(output, indent=2))
    else:
        # Table output
        print("\n=== Transcription Accuracy Report ===\n")
        
        # Group by category
        by_category = {}
        for r in results:
            by_category.setdefault(r.category, []).append(r)
        
        for category, cat_results in by_category.items():
            print(f"## {category.upper()}")
            print("-" * 60)
            
            if args.verbose:
                print(f"{'Sample':<30} {'Words':<6} {'Raw WER':<10} {'Proc WER':<10} {'Δ':<8}")
                print("-" * 60)
                for r in cat_results:
                    proc_str = f"{r.processed_wer:.1f}%" if r.processed_wer is not None else "-"
                    imp_str = f"{r.improvement:+.1f}%" if r.improvement is not None else "-"
                    print(f"{r.name:<30} {r.gold_words:<6} {r.raw_wer:.1f}%{'':<5} {proc_str:<10} {imp_str:<8}")
            
            # Category summary
            avg_raw = sum(r.raw_wer for r in cat_results) / len(cat_results)
            total_errors = sum(r.raw_errors for r in cat_results)
            print(f"  Samples: {len(cat_results)}")
            print(f"  Avg Raw WER: {avg_raw:.1f}%")
            print(f"  Total Errors: {total_errors}")
            
            proc_results = [r for r in cat_results if r.has_processed]
            if proc_results:
                avg_proc = sum(r.processed_wer for r in proc_results) / len(proc_results)
                avg_imp = sum(r.improvement or 0 for r in proc_results) / len(proc_results)
                print(f"  Avg Processed WER: {avg_proc:.1f}%")
                print(f"  Avg Improvement: {avg_imp:+.1f}%")
            print()
        
        # Overall summary
        print("=" * 60)
        print("OVERALL SUMMARY")
        print("=" * 60)
        print(f"Total samples: {len(results)}")
        print(f"Average Raw WER: {sum(r.raw_wer for r in results) / len(results):.1f}%")
        
        proc_results = [r for r in results if r.has_processed]
        if proc_results:
            print(f"Average Processed WER: {sum(r.processed_wer for r in proc_results) / len(proc_results):.1f}%")
            print(f"Average Improvement: {sum(r.improvement or 0 for r in proc_results) / len(proc_results):+.1f}%")
        else:
            print("\n(Run post-processor and save as *.processed.txt to see improvement metrics)")


if __name__ == "__main__":
    main()
