#!/usr/bin/env python3
"""Compare performance between benchmark runs."""

import sys
from pathlib import Path
from collections import defaultdict
import statistics

def parse_benchmark(filepath):
    """Parse a benchmark file and return statistics."""
    times_by_category = defaultdict(list)
    all_times = []
    
    with open(filepath, 'r') as f:
        lines = f.readlines()[1:]  # Skip header
    
    for line in lines:
        if not line.strip():
            continue
        parts = line.strip().split('|')
        if len(parts) < 4:
            continue
        
        elapsed = float(parts[1])
        wav_path = parts[2]
        
        # Categorize
        if '/micro/' in wav_path:
            category = 'micro'
        elif '/short/' in wav_path:
            category = 'short'
        elif '/medium/' in wav_path:
            category = 'medium'
        elif '/long/' in wav_path:
            category = 'long'
        else:
            continue
        
        times_by_category[category].append(elapsed)
        all_times.append(elapsed)
    
    return {
        'by_category': times_by_category,
        'all': all_times,
        'avg': statistics.mean(all_times) if all_times else 0,
        'median': statistics.median(all_times) if all_times else 0,
        'total': sum(all_times) if all_times else 0,
        'count': len(all_times)
    }

def format_time_diff(old, new):
    """Format time difference with color."""
    diff = new - old
    pct = (diff / old * 100) if old > 0 else 0
    
    if diff < 0:
        return f"▼ {abs(diff):.2f}s ({abs(pct):.1f}% faster)"
    elif diff > 0:
        return f"▲ {diff:.2f}s ({pct:.1f}% slower)"
    else:
        return "= No change"

def compare_reports(old_path, new_path):
    """Generate comparison report."""
    old = parse_benchmark(old_path)
    new = parse_benchmark(new_path)
    
    print("=" * 70)
    print(" " * 20 + "PERFORMANCE COMPARISON REPORT")
    print("=" * 70)
    print()
    print(f"Old: {Path(old_path).name}")
    print(f"New: {Path(new_path).name}")
    print()
    
    # Overall comparison
    print("📊 OVERALL METRICS")
    print("-" * 40)
    print(f"  Average time:  {old['avg']:.2f}s → {new['avg']:.2f}s  {format_time_diff(old['avg'], new['avg'])}")
    print(f"  Median time:   {old['median']:.2f}s → {new['median']:.2f}s  {format_time_diff(old['median'], new['median'])}")
    print(f"  Total time:    {old['total']:.2f}s → {new['total']:.2f}s  {format_time_diff(old['total'], new['total'])}")
    print(f"  Sample count:  {old['count']} → {new['count']}")
    print()
    
    # By category
    print("📁 PERFORMANCE BY CATEGORY")
    print("-" * 40)
    
    categories = ['micro', 'short', 'medium', 'long']
    for cat in categories:
        old_times = old['by_category'].get(cat, [])
        new_times = new['by_category'].get(cat, [])
        
        if not old_times and not new_times:
            continue
        
        old_avg = statistics.mean(old_times) if old_times else 0
        new_avg = statistics.mean(new_times) if new_times else 0
        
        print(f"\n  {cat.upper()}: ", end="")
        if old_avg and new_avg:
            print(f"{old_avg:.2f}s → {new_avg:.2f}s  {format_time_diff(old_avg, new_avg)}")
        elif new_avg:
            print(f"New: {new_avg:.2f}s")
        elif old_avg:
            print(f"Old: {old_avg:.2f}s (no new data)")
    
    print()
    print("=" * 70)
    
    # Performance verdict
    improvement = ((old['avg'] - new['avg']) / old['avg'] * 100) if old['avg'] > 0 else 0
    
    print("🎯 VERDICT: ", end="")
    if improvement > 10:
        print(f"✨ SIGNIFICANT IMPROVEMENT ({improvement:.1f}% faster)")
    elif improvement > 0:
        print(f"✅ MINOR IMPROVEMENT ({improvement:.1f}% faster)")
    elif improvement > -10:
        print(f"≈ SIMILAR PERFORMANCE ({abs(improvement):.1f}% difference)")
    else:
        print(f"⚠️  PERFORMANCE DEGRADATION ({abs(improvement):.1f}% slower)")
    
    print("=" * 70)

def main():
    if len(sys.argv) < 3:
        # Find two most recent benchmarks
        baselines_dir = Path("tests/fixtures/baselines")
        benchmark_files = sorted(
            baselines_dir.glob("*/benchmark_results_*.txt"),
            key=lambda p: p.stat().st_mtime,
            reverse=True
        )
        
        if len(benchmark_files) < 2:
            print("Need at least 2 benchmark files for comparison")
            sys.exit(1)
        
        old_path = benchmark_files[1]
        new_path = benchmark_files[0]
        print("Auto-comparing two most recent benchmarks...")
        print()
    else:
        old_path = Path(sys.argv[1])
        new_path = Path(sys.argv[2])
    
    if not old_path.exists() or not new_path.exists():
        print("Benchmark files not found")
        sys.exit(1)
    
    compare_reports(old_path, new_path)

if __name__ == "__main__":
    main()
