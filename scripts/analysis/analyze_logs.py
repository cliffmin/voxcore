#!/usr/bin/env python3
"""
Analyze push-to-talk dictation logs for performance metrics and insights.
Reads JSONL log files from ~/Documents/VoiceNotes/tx_logs/
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any
import statistics

def load_logs(log_dir: Path) -> List[Dict[str, Any]]:
    """Load all JSONL log files."""
    logs = []
    for file in sorted(log_dir.glob("tx-*.jsonl")):
        with open(file, 'r') as f:
            for line in f:
                try:
                    entry = json.loads(line.strip())
                    logs.append(entry)
                except json.JSONDecodeError:
                    continue
    return logs

def analyze_logs(logs: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Analyze log entries for key metrics."""
    
    # Filter for success events
    success_logs = [l for l in logs if l.get('kind') == 'success']
    error_logs = [l for l in logs if l.get('kind') == 'error']
    timeout_logs = [l for l in logs if l.get('kind') == 'timeout']
    refine_logs = [l for l in logs if l.get('kind') == 'refine']
    
    if not success_logs:
        return {"error": "No successful transcriptions found"}
    
    # Extract metrics
    durations = [l.get('duration_sec', 0) for l in success_logs if l.get('duration_sec')]
    tx_times = [l.get('tx_ms', 0) for l in success_logs if l.get('tx_ms')]
    file_sizes = [l.get('wav_bytes', 0) for l in success_logs if l.get('wav_bytes')]
    transcript_lengths = [l.get('transcript_chars', 0) for l in success_logs if l.get('transcript_chars')]
    
    # Models used
    models = {}
    for l in success_logs:
        model = l.get('model', 'unknown')
        models[model] = models.get(model, 0) + 1
    
    # Devices used
    devices = {}
    for l in success_logs:
        device = l.get('device', 'unknown')
        devices[device] = devices.get(device, 0) + 1
    
    # Session kinds
    session_kinds = {}
    for l in success_logs:
        kind = l.get('session_kind', 'unknown')
        session_kinds[kind] = session_kinds.get(kind, 0) + 1
    
    # Calculate statistics
    stats = {
        "total_recordings": len(success_logs),
        "total_errors": len(error_logs),
        "total_timeouts": len(timeout_logs),
        "total_refined": len(refine_logs),
        "success_rate": f"{100 * len(success_logs) / (len(success_logs) + len(error_logs) + len(timeout_logs)):.1f}%",
        
        "duration": {
            "min": f"{min(durations):.1f}s" if durations else "N/A",
            "max": f"{max(durations):.1f}s" if durations else "N/A",
            "avg": f"{statistics.mean(durations):.1f}s" if durations else "N/A",
            "median": f"{statistics.median(durations):.1f}s" if durations else "N/A",
            "total": f"{sum(durations)/60:.1f} minutes" if durations else "N/A",
        },
        
        "transcription_time": {
            "min": f"{min(tx_times)/1000:.1f}s" if tx_times else "N/A",
            "max": f"{max(tx_times)/1000:.1f}s" if tx_times else "N/A",
            "avg": f"{statistics.mean(tx_times)/1000:.1f}s" if tx_times else "N/A",
            "median": f"{statistics.median(tx_times)/1000:.1f}s" if tx_times else "N/A",
        },
        
        "file_size": {
            "min": f"{min(file_sizes)/1024/1024:.1f}MB" if file_sizes else "N/A",
            "max": f"{max(file_sizes)/1024/1024:.1f}MB" if file_sizes else "N/A",
            "avg": f"{statistics.mean(file_sizes)/1024/1024:.1f}MB" if file_sizes else "N/A",
            "total": f"{sum(file_sizes)/1024/1024:.1f}MB" if file_sizes else "N/A",
        },
        
        "transcript_length": {
            "min": f"{min(transcript_lengths)} chars" if transcript_lengths else "N/A",
            "max": f"{max(transcript_lengths)} chars" if transcript_lengths else "N/A",
            "avg": f"{statistics.mean(transcript_lengths):.0f} chars" if transcript_lengths else "N/A",
            "total": f"{sum(transcript_lengths)} chars" if transcript_lengths else "N/A",
        },
        
        "models_used": models,
        "devices_used": devices,
        "session_types": session_kinds,
    }
    
    # Performance ratios
    if durations and tx_times:
        realtime_ratios = [d / (t/1000) for d, t in zip(durations, tx_times) if t > 0]
        if realtime_ratios:
            stats["realtime_ratio"] = {
                "min": f"{min(realtime_ratios):.1f}x",
                "max": f"{max(realtime_ratios):.1f}x",
                "avg": f"{statistics.mean(realtime_ratios):.1f}x",
                "note": "Audio duration / transcription time (higher is better)"
            }
    
    # Daily breakdown
    daily = {}
    for l in success_logs:
        ts = l.get('ts', '')
        if ts:
            try:
                date = ts.split('T')[0]
                if date not in daily:
                    daily[date] = {"count": 0, "duration": 0, "chars": 0}
                daily[date]["count"] += 1
                daily[date]["duration"] += l.get('duration_sec', 0)
                daily[date]["chars"] += l.get('transcript_chars', 0)
            except:
                pass
    
    stats["daily_usage"] = daily
    
    # Recent failures
    recent_errors = []
    for l in error_logs[-5:]:  # Last 5 errors
        recent_errors.append({
            "timestamp": l.get('ts', 'unknown'),
            "duration": f"{l.get('duration_sec', 0):.1f}s",
            "error": l.get('stderr', 'unknown')[:100]
        })
    if recent_errors:
        stats["recent_errors"] = recent_errors
    
    return stats

def print_report(stats: Dict[str, Any]):
    """Print formatted analysis report."""
    
    print("\n" + "="*60)
    print("PUSH-TO-TALK DICTATION ANALYTICS")
    print("="*60)
    
    print(f"\n📊 OVERALL STATISTICS")
    print(f"  Total recordings: {stats.get('total_recordings', 0)}")
    print(f"  Success rate: {stats.get('success_rate', 'N/A')}")
    print(f"  Errors: {stats.get('total_errors', 0)}")
    print(f"  Timeouts: {stats.get('total_timeouts', 0)}")
    print(f"  Refined (LLM): {stats.get('total_refined', 0)}")
    
    if 'duration' in stats:
        print(f"\n⏱️  RECORDING DURATION")
        d = stats['duration']
        print(f"  Min: {d['min']} | Max: {d['max']}")
        print(f"  Average: {d['avg']} | Median: {d['median']}")
        print(f"  Total recorded: {d['total']}")
    
    if 'transcription_time' in stats:
        print(f"\n⚡ TRANSCRIPTION SPEED")
        t = stats['transcription_time']
        print(f"  Min: {t['min']} | Max: {t['max']}")
        print(f"  Average: {t['avg']} | Median: {t['median']}")
    
    if 'realtime_ratio' in stats:
        r = stats['realtime_ratio']
        print(f"  Realtime ratio: {r['avg']} ({r['note']})")
    
    if 'file_size' in stats:
        print(f"\n💾 FILE SIZES")
        f = stats['file_size']
        print(f"  Average: {f['avg']} | Total: {f['total']}")
    
    if 'transcript_length' in stats:
        print(f"\n📝 TRANSCRIPT LENGTH")
        tl = stats['transcript_length']
        print(f"  Min: {tl['min']} | Max: {tl['max']}")
        print(f"  Average: {tl['avg']} | Total: {tl['total']}")
    
    if 'models_used' in stats:
        print(f"\n🤖 MODELS USED")
        for model, count in stats['models_used'].items():
            print(f"  {model}: {count} times")
    
    if 'devices_used' in stats:
        print(f"\n🖥️  DEVICES USED")
        for device, count in stats['devices_used'].items():
            print(f"  {device}: {count} times")
    
    if 'session_types' in stats:
        print(f"\n🎯 SESSION TYPES")
        for kind, count in stats['session_types'].items():
            print(f"  {kind}: {count} times")
    
    if 'daily_usage' in stats and stats['daily_usage']:
        print(f"\n📅 DAILY USAGE")
        for date in sorted(stats['daily_usage'].keys())[-7:]:  # Last 7 days
            d = stats['daily_usage'][date]
            print(f"  {date}: {d['count']} recordings, {d['duration']/60:.1f} min, {d['chars']} chars")
    
    if 'recent_errors' in stats and stats['recent_errors']:
        print(f"\n❌ RECENT ERRORS")
        for err in stats['recent_errors']:
            print(f"  {err['timestamp']}: {err['duration']} - {err['error']}")
    
    print("\n" + "="*60)

def main():
    # Default log directory
    log_dir = Path.home() / "Documents" / "VoiceNotes" / "tx_logs"
    
    if len(sys.argv) > 1:
        log_dir = Path(sys.argv[1])
    
    if not log_dir.exists():
        print(f"Error: Log directory not found: {log_dir}")
        sys.exit(1)
    
    print(f"Analyzing logs from: {log_dir}")
    
    logs = load_logs(log_dir)
    if not logs:
        print("No log entries found")
        sys.exit(1)
    
    print(f"Found {len(logs)} total log entries")
    
    stats = analyze_logs(logs)
    print_report(stats)
    
    # Optional: Save detailed JSON report
    if "--json" in sys.argv:
        output_file = Path("transcription_analytics.json")
        with open(output_file, 'w') as f:
            json.dump(stats, f, indent=2, default=str)
        print(f"\nDetailed JSON report saved to: {output_file}")

if __name__ == "__main__":
    main()
