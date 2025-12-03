#!/usr/bin/env python3
"""
Compare performance metrics across VoxCore versions.
Analyzes recordings organized by version in ~/Documents/VoiceNotes/by_version/

Usage:
    python compare_versions.py
    python compare_versions.py --versions 0.3.0 0.4.0 0.4.3
    python compare_versions.py --metric accuracy
"""

import argparse
import json
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Any


def load_version_recordings(base_dir: Path, version: str) -> List[Dict[str, Any]]:
    """Load all recording metadata for a specific version."""
    version_dir = base_dir / f"voxcore-{version}"
    
    if not version_dir.exists():
        return []
    
    recordings = []
    for session_dir in version_dir.iterdir():
        if not session_dir.is_dir():
            continue
        
        # Load version metadata
        version_file = session_dir / ".version"
        metadata = {}
        if version_file.exists():
            with open(version_file) as f:
                for line in f:
                    if '=' in line:
                        key, value = line.strip().split('=', 1)
                        metadata[key] = value
        
        # Load transcription metadata if available
        json_files = list(session_dir.glob("*.json"))
        if json_files:
            try:
                with open(json_files[0]) as f:
                    tx_data = json.load(f)
                    metadata.update(tx_data)
            except json.JSONDecodeError:
                pass
        
        # Get WAV file info
        wav_files = list(session_dir.glob("*.wav"))
        if wav_files:
            metadata['wav_file'] = str(wav_files[0])
            metadata['session_name'] = session_dir.name
        
        if metadata:
            recordings.append(metadata)
    
    return recordings


def calculate_stats(recordings: List[Dict[str, Any]], metric: str) -> Dict[str, float]:
    """Calculate statistics for a given metric across recordings."""
    values = []
    models = []
    
    for rec in recordings:
        value = None
        
        # Map metric names to JSON fields
        if metric == "transcription_time":
            value = rec.get('tx_ms') or rec.get('transcription_ms')
        elif metric == "duration":
            value = rec.get('duration_sec') or rec.get('duration')
        elif metric == "chars":
            value = rec.get('transcript_chars') or rec.get('length')
        elif metric == "wer":  # Word Error Rate (if available from benchmarks)
            value = rec.get('wer')
        elif metric == "model":
            models.append(rec.get('model', 'unknown'))
            continue
        
        if value is not None:
            try:
                values.append(float(value))
            except (ValueError, TypeError):
                pass
    
    # Handle model aggregation separately
    if metric == "model" and models:
        from collections import Counter
        model_counts = Counter(models)
        most_common = model_counts.most_common(1)[0]
        return {
            "primary_model": most_common[0],
            "count": most_common[1],
            "total_recordings": len(models),
            "all_models": dict(model_counts)
        }
    
    if not values:
        return {}
    
    return {
        'count': len(values),
        'mean': statistics.mean(values),
        'median': statistics.median(values),
        'min': min(values),
        'max': max(values),
        'stdev': statistics.stdev(values) if len(values) > 1 else 0
    }


def compare_versions(base_dir: Path, versions: List[str], metrics: List[str]):
    """Compare performance metrics across versions."""
    
    print(f"VoxCore Version Comparison")
    print(f"=" * 80)
    print()
    
    # Load recordings for each version
    version_data = {}
    for version in versions:
        recordings = load_version_recordings(base_dir, version)
        version_data[version] = recordings
        print(f"v{version}: {len(recordings)} recordings")
    
    print()
    print("-" * 80)
    print()
    
    # Compare each metric
    for metric in metrics:
        print(f"Metric: {metric}")
        print(f"-" * 40)
        
        for version in versions:
            recordings = version_data[version]
            if not recordings:
                print(f"  v{version}: No data")
                continue
            
            stats = calculate_stats(recordings, metric)
            
            if not stats:
                print(f"  v{version}: No {metric} data")
                continue
            
            if 'model' in stats:
                # Model is categorical
                print(f"  v{version}: {stats['model']}")
            else:
                # Numeric metrics
                print(f"  v{version}:")
                print(f"    Count:  {stats['count']}")
                print(f"    Mean:   {stats['mean']:.2f}")
                print(f"    Median: {stats['median']:.2f}")
                print(f"    Range:  {stats['min']:.2f} - {stats['max']:.2f}")
                if stats['stdev'] > 0:
                    print(f"    StdDev: {stats['stdev']:.2f}")
        
        print()
    
    # Summary comparison
    print("-" * 80)
    print("Summary")
    print("-" * 40)
    
    # Compare transcription speed improvements
    if "transcription_time" in metrics:
        print("Transcription Speed Improvements:")
        baseline_version = versions[0]
        baseline_recordings = version_data[baseline_version]
        baseline_stats = calculate_stats(baseline_recordings, "transcription_time")
        
        if baseline_stats:
            baseline_mean = baseline_stats['mean']
            print(f"  Baseline (v{baseline_version}): {baseline_mean:.0f}ms")
            
            for version in versions[1:]:
                current_recordings = version_data[version]
                current_stats = calculate_stats(current_recordings, "transcription_time")
                
                if current_stats and baseline_mean > 0:
                    current_mean = current_stats['mean']
                    improvement = ((baseline_mean - current_mean) / baseline_mean) * 100
                    speedup = baseline_mean / current_mean if current_mean > 0 else 0
                    
                    print(f"  v{version}: {current_mean:.0f}ms ({improvement:+.1f}%, {speedup:.2f}x)")


def main():
    parser = argparse.ArgumentParser(description="Compare VoxCore versions performance")
    parser.add_argument(
        '--versions',
        nargs='+',
        default=['0.3.0', '0.4.0', '0.4.3'],
        help='Versions to compare (default: 0.3.0 0.4.0 0.4.3)'
    )
    parser.add_argument(
        '--exclude-versions',
        nargs='+',
        default=[],
        help='Versions to exclude from analysis (e.g., performance-only versions)'
    )
    parser.add_argument(
        '--metrics',
        nargs='+',
        default=['transcription_time', 'duration', 'chars'],
        help='Metrics to compare (default: transcription_time duration chars)'
    )
    parser.add_argument(
        '--base-dir',
        type=Path,
        default=Path.home() / 'Documents' / 'VoiceNotes' / 'by_version',
        help='Base directory for versioned recordings'
    )
    
    args = parser.parse_args()
    
    if not args.base_dir.exists():
        print(f"Error: Base directory not found: {args.base_dir}")
        print(f"Run: ./scripts/utilities/organize_by_version.sh")
        return 1
    
    # Filter out excluded versions
    versions = [v for v in args.versions if v not in args.exclude_versions]
    if not versions:
        print("Error: All versions excluded")
        return 1
    
    if args.exclude_versions:
        print(f"Excluding versions: {', '.join(args.exclude_versions)}")
        print()
    
    compare_versions(args.base_dir, versions, args.metrics)
    return 0


if __name__ == '__main__':
    exit(main())

