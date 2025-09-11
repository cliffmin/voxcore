#!/usr/bin/env python3
"""
Analyze recording durations from logs to find natural clusters for short/medium/long
"""

import json
import os
import glob
from collections import Counter
import numpy as np
from pathlib import Path

def load_all_durations():
    """Load all recording durations from log files"""
    log_dir = Path.home() / "Documents" / "VoiceNotes" / "tx_logs"
    durations = []
    
    for log_file in glob.glob(str(log_dir / "*.jsonl")):
        with open(log_file, 'r') as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    if entry.get('kind') == 'success' and 'duration_sec' in entry:
                        dur = entry['duration_sec']
                        if dur and dur > 0:
                            durations.append(dur)
                except:
                    continue
    
    return sorted(durations)

def find_clusters(durations):
    """Find natural clusters using percentiles and gaps"""
    if not durations:
        return None
    
    durations = np.array(durations)
    
    # Calculate percentiles
    p25 = np.percentile(durations, 25)
    p50 = np.percentile(durations, 50)
    p75 = np.percentile(durations, 75)
    p90 = np.percentile(durations, 90)
    
    # Find natural gaps (where there's a big jump in duration)
    sorted_dur = np.sort(durations)
    gaps = np.diff(sorted_dur)
    
    # Find significant gaps (>2x the median gap)
    median_gap = np.median(gaps[gaps > 0])
    significant_gaps = np.where(gaps > median_gap * 3)[0]
    
    # Natural breakpoints based on gaps
    breakpoints = []
    if len(significant_gaps) > 0:
        # Take the first 2 significant gaps as breakpoints
        for gap_idx in significant_gaps[:2]:
            breakpoints.append(sorted_dur[gap_idx + 1])
    
    # If not enough natural gaps, use percentiles
    if len(breakpoints) < 2:
        # Use 33rd and 67th percentiles as fallback
        breakpoints = [
            np.percentile(durations, 33),
            np.percentile(durations, 67)
        ]
    
    breakpoints = sorted(breakpoints)[:2]
    
    return {
        'short_max': round(breakpoints[0], 1),
        'medium_max': round(breakpoints[1], 1),
        'percentiles': {
            '25%': round(p25, 1),
            '50%': round(p50, 1),
            '75%': round(p75, 1),
            '90%': round(p90, 1)
        },
        'stats': {
            'count': len(durations),
            'min': round(min(durations), 1),
            'max': round(max(durations), 1),
            'mean': round(np.mean(durations), 1),
            'median': round(np.median(durations), 1),
            'std': round(np.std(durations), 1)
        }
    }

def create_histogram(durations, breakpoints):
    """Create ASCII histogram"""
    if not durations:
        return ""
    
    # Create bins
    max_dur = min(max(durations), 150)  # Cap at 150s for display
    bin_size = 5  # 5-second bins
    bins = list(range(0, int(max_dur) + bin_size, bin_size))
    
    # Count recordings in each bin
    counts = []
    for i in range(len(bins) - 1):
        count = sum(1 for d in durations if bins[i] <= d < bins[i+1])
        counts.append(count)
    
    # Create ASCII histogram
    max_count = max(counts) if counts else 1
    scale = 50 / max_count if max_count > 0 else 1
    
    lines = []
    lines.append("\n📊 Recording Duration Distribution")
    lines.append("=" * 60)
    
    for i, count in enumerate(counts):
        if count > 0:
            bar = '█' * int(count * scale)
            label = f"{bins[i]:3d}-{bins[i+1]:3d}s"
            
            # Mark the breakpoints
            marker = ""
            if bins[i] <= breakpoints['short_max'] < bins[i+1]:
                marker = " ← SHORT/MEDIUM boundary"
            elif bins[i] <= breakpoints['medium_max'] < bins[i+1]:
                marker = " ← MEDIUM/LONG boundary"
            
            lines.append(f"{label}: {bar} ({count}){marker}")
    
    lines.append("=" * 60)
    
    return "\n".join(lines)

def categorize_durations(durations, breakpoints):
    """Categorize durations and count each type"""
    short = sum(1 for d in durations if d <= breakpoints['short_max'])
    medium = sum(1 for d in durations if breakpoints['short_max'] < d <= breakpoints['medium_max'])
    long = sum(1 for d in durations if d > breakpoints['medium_max'])
    
    return {
        'short': short,
        'medium': medium,
        'long': long
    }

def main():
    print("🔍 Analyzing recording durations...")
    print()
    
    durations = load_all_durations()
    
    if not durations:
        print("No recordings found in logs")
        return
    
    breakpoints = find_clusters(durations)
    
    # Display results
    print(f"📈 Analyzed {breakpoints['stats']['count']} recordings")
    print()
    
    print("📊 Duration Statistics:")
    print(f"  Min:    {breakpoints['stats']['min']}s")
    print(f"  Max:    {breakpoints['stats']['max']}s")
    print(f"  Mean:   {breakpoints['stats']['mean']}s")
    print(f"  Median: {breakpoints['stats']['median']}s")
    print(f"  StdDev: {breakpoints['stats']['std']}s")
    print()
    
    print("📏 Percentiles:")
    for p, val in breakpoints['percentiles'].items():
        print(f"  {p:>4}: {val}s")
    print()
    
    print("🎯 Recommended Duration Categories:")
    print(f"  SHORT:  ≤ {breakpoints['short_max']}s")
    print(f"  MEDIUM: {breakpoints['short_max']}s - {breakpoints['medium_max']}s")
    print(f"  LONG:   > {breakpoints['medium_max']}s")
    print()
    
    # Count recordings in each category
    categories = categorize_durations(durations, breakpoints)
    total = sum(categories.values())
    
    print("📦 Distribution by Category:")
    print(f"  SHORT:  {categories['short']:3d} recordings ({categories['short']*100//total}%)")
    print(f"  MEDIUM: {categories['medium']:3d} recordings ({categories['medium']*100//total}%)")
    print(f"  LONG:   {categories['long']:3d} recordings ({categories['long']*100//total}%)")
    
    # Show histogram
    print(create_histogram(durations, breakpoints))
    
    print()
    print("💡 Suggested MODEL_BY_DURATION config:")
    print(f"  SHORT_SEC = {breakpoints['short_max']}  # Use base.en for ≤{breakpoints['short_max']}s")
    print(f"  MEDIUM_SEC = {breakpoints['medium_max']}  # Use small.en for {breakpoints['short_max']}-{breakpoints['medium_max']}s")
    print(f"  # Use medium.en for >{breakpoints['medium_max']}s")

if __name__ == "__main__":
    main()
