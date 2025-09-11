#!/usr/bin/env python3
"""
Analyze recording durations from logs to find natural clusters for short/medium/long
Pure Python version (no numpy required)
"""

import json
import glob
import statistics
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

def percentile(data, p):
    """Calculate percentile"""
    if not data:
        return 0
    sorted_data = sorted(data)
    index = (len(sorted_data) - 1) * p / 100
    lower = int(index)
    upper = lower + 1
    if upper >= len(sorted_data):
        return sorted_data[lower]
    weight = index - lower
    return sorted_data[lower] * (1 - weight) + sorted_data[upper] * weight

def find_clusters(durations):
    """Find natural clusters using percentiles"""
    if not durations:
        return None
    
    # Calculate percentiles
    p25 = percentile(durations, 25)
    p33 = percentile(durations, 33)
    p50 = percentile(durations, 50)
    p67 = percentile(durations, 67)
    p75 = percentile(durations, 75)
    p90 = percentile(durations, 90)
    
    # Use 33rd and 67th percentiles as natural breakpoints
    # This divides data into roughly equal thirds
    
    return {
        'short_max': round(p33, 1),
        'medium_max': round(p67, 1),
        'percentiles': {
            '25%': round(p25, 1),
            '33%': round(p33, 1),
            '50%': round(p50, 1),
            '67%': round(p67, 1),
            '75%': round(p75, 1),
            '90%': round(p90, 1)
        },
        'stats': {
            'count': len(durations),
            'min': round(min(durations), 1),
            'max': round(max(durations), 1),
            'mean': round(statistics.mean(durations), 1),
            'median': round(statistics.median(durations), 1),
            'stdev': round(statistics.stdev(durations), 1) if len(durations) > 1 else 0
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
        counts.append((bins[i], bins[i+1], count))
    
    # Filter out empty bins for cleaner display
    counts = [(start, end, count) for start, end, count in counts if count > 0]
    
    if not counts:
        return ""
    
    # Create ASCII histogram
    max_count = max(c[2] for c in counts)
    scale = 40 / max_count if max_count > 0 else 1
    
    lines = []
    lines.append("\n📊 Recording Duration Distribution")
    lines.append("=" * 70)
    lines.append("Duration   Count  Histogram")
    lines.append("-" * 70)
    
    for start, end, count in counts:
        bar = '█' * int(count * scale)
        if bar == '' and count > 0:
            bar = '▌'  # Show at least something for non-zero counts
        
        label = f"{start:3d}-{end:<3d}s"
        
        # Mark the breakpoints
        marker = ""
        if start <= breakpoints['short_max'] < end:
            marker = " ← SHORT/MEDIUM"
        elif start <= breakpoints['medium_max'] < end:
            marker = " ← MEDIUM/LONG"
        
        lines.append(f"{label}  {count:4d}  {bar}{marker}")
    
    lines.append("=" * 70)
    
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
    print("🔍 Analyzing your recording durations...")
    print()
    
    durations = load_all_durations()
    
    if not durations:
        print("No recordings found in logs")
        return
    
    breakpoints = find_clusters(durations)
    
    # Display results
    print(f"📈 Found {breakpoints['stats']['count']} recordings in your logs")
    print()
    
    print("📊 Duration Statistics:")
    print(f"  Min:       {breakpoints['stats']['min']}s")
    print(f"  Max:       {breakpoints['stats']['max']}s")
    print(f"  Mean:      {breakpoints['stats']['mean']}s")
    print(f"  Median:    {breakpoints['stats']['median']}s")
    print(f"  Std Dev:   {breakpoints['stats']['stdev']}s")
    print()
    
    print("📏 Duration Percentiles:")
    for p, val in breakpoints['percentiles'].items():
        print(f"  {p:>4}: {val:6.1f}s")
    print()
    
    # Count recordings in each category
    categories = categorize_durations(durations, breakpoints)
    total = sum(categories.values())
    
    print("🎯 Natural Duration Categories (using 33rd/67th percentiles):")
    print(f"  SHORT:  ≤ {breakpoints['short_max']}s  ({categories['short']} recordings, {categories['short']*100//total}%)")
    print(f"  MEDIUM: {breakpoints['short_max']}s - {breakpoints['medium_max']}s  ({categories['medium']} recordings, {categories['medium']*100//total}%)")
    print(f"  LONG:   > {breakpoints['medium_max']}s  ({categories['long']} recordings, {categories['long']*100//total}%)")
    
    # Show histogram
    print(create_histogram(durations, breakpoints))
    
    print()
    print("💡 Recommended config for your ptt_config.lua:")
    print("```lua")
    print("MODEL_BY_DURATION = {")
    print("  ENABLED = true,")
    print(f"  SHORT_SEC = {breakpoints['short_max']},  -- Clips ≤{breakpoints['short_max']}s use base.en (fast)")
    print(f"  MODEL_SHORT = \"base.en\",")
    print(f"  MODEL_LONG = \"medium.en\",  -- Clips >{breakpoints['short_max']}s use medium.en")
    print("}")
    print("```")
    print()
    print("This splits your recordings into:")
    print(f"  • Quick notes/commands: ≤{breakpoints['short_max']}s → Fast base.en model")
    print(f"  • Normal dictation: {breakpoints['short_max']}-{breakpoints['medium_max']}s → Accurate medium.en model")  
    print(f"  • Long form content: >{breakpoints['medium_max']}s → Accurate medium.en model")

if __name__ == "__main__":
    main()
