#!/usr/bin/env python3
"""Generate readable performance reports from benchmark results."""

import sys
import os
from pathlib import Path
from collections import defaultdict
import statistics

def parse_benchmark_file(filepath):
    """Parse benchmark results file."""
    results = defaultdict(list)
    
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Skip header
    for line in lines[1:]:
        if not line.strip():
            continue
        
        parts = line.strip().split('|')
        if len(parts) < 4:
            continue
            
        rc = int(parts[0])
        elapsed = float(parts[1])
        wav_path = parts[2]
        json_path = parts[3]
        
        # Determine category from path
        if '/micro/' in wav_path:
            category = 'micro'
        elif '/short/' in wav_path:
            category = 'short'
        elif '/medium/' in wav_path:
            category = 'medium'
        elif '/long/' in wav_path:
            category = 'long'
        else:
            category = 'unknown'
        
        # Extract filename
        filename = os.path.basename(wav_path).replace('.wav', '').replace('.norm', '')
        
        results[category].append({
            'filename': filename,
            'elapsed': elapsed,
            'rc': rc,
            'wav_path': wav_path
        })
    
    return results

def generate_report(results):
    """Generate formatted performance report."""
    
    print("=" * 70)
    print(" " * 20 + "TRANSCRIPTION PERFORMANCE REPORT")
    print("=" * 70)
    print()
    
    # Category order
    categories = ['micro', 'short', 'medium', 'long']
    
    all_times = []
    
    for category in categories:
        if category not in results or not results[category]:
            continue
        
        items = results[category]
        times = [item['elapsed'] for item in items]
        all_times.extend(times)
        
        print(f"📁 {category.upper()} CLIPS ({len(items)} samples)")
        print("-" * 40)
        
        # Sort by elapsed time
        items.sort(key=lambda x: x['elapsed'])
        
        for item in items:
            status = "✅" if item['rc'] == 0 else "❌"
            # Format timestamp from filename
            timestamp = item['filename'].replace('2025-Sep-06_', '').replace('_', ' ')
            print(f"  {status} {item['elapsed']:6.2f}s  {timestamp}")
        
        # Category stats
        avg_time = statistics.mean(times)
        min_time = min(times)
        max_time = max(times)
        
        print(f"\n  📊 Stats: avg={avg_time:.2f}s, min={min_time:.2f}s, max={max_time:.2f}s")
        print()
    
    # Overall summary
    if all_times:
        print("=" * 70)
        print("📈 OVERALL PERFORMANCE SUMMARY")
        print("-" * 40)
        print(f"  Total samples:        {len(all_times)}")
        print(f"  Total time:           {sum(all_times):.2f} seconds")
        print(f"  Average time:         {statistics.mean(all_times):.2f} seconds")
        print(f"  Median time:          {statistics.median(all_times):.2f} seconds")
        print(f"  Fastest transcription: {min(all_times):.2f} seconds")
        print(f"  Slowest transcription: {max(all_times):.2f} seconds")
        
        if len(all_times) > 1:
            print(f"  Standard deviation:   {statistics.stdev(all_times):.2f} seconds")
        
        # Performance assessment
        avg = statistics.mean(all_times)
        print()
        print("  Performance Rating: ", end="")
        if avg < 5:
            print("⚡ EXCELLENT (< 5s average)")
        elif avg < 10:
            print("✅ GOOD (5-10s average)")
        elif avg < 15:
            print("⚠️  ACCEPTABLE (10-15s average)")
        else:
            print("🐌 SLOW (> 15s average)")
    
    print("=" * 70)

def main():
    if len(sys.argv) < 2:
        # Find the latest benchmark file
        baselines_dir = Path("tests/fixtures/baselines")
        benchmark_files = list(baselines_dir.glob("*/benchmark_results_*.txt"))
        
        if not benchmark_files:
            print("No benchmark files found")
            sys.exit(1)
        
        # Get the most recent file
        filepath = max(benchmark_files, key=lambda p: p.stat().st_mtime)
        print(f"Using latest benchmark: {filepath}")
        print()
    else:
        filepath = Path(sys.argv[1])
    
    if not filepath.exists():
        print(f"File not found: {filepath}")
        sys.exit(1)
    
    results = parse_benchmark_file(filepath)
    generate_report(results)

if __name__ == "__main__":
    main()
