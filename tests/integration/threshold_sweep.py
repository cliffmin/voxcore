#!/usr/bin/env python3
"""
Threshold sweep test to find optimal model switching point.
Tests base.en vs medium.en at different duration thresholds to find
where base.en accuracy drops off significantly.
"""

import subprocess
import json
import glob
import os
import sys
from pathlib import Path
import tempfile
import time

def get_duration(wav_path):
    """Get duration of WAV file in seconds"""
    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
             '-of', 'default=noprint_wrappers=1:nokey=1', wav_path],
            capture_output=True, text=True
        )
        return float(result.stdout.strip())
    except:
        return 0

def transcribe_with_model(wav_path, model):
    """Transcribe audio with specific model using whisper-cpp"""
    whisper = '/opt/homebrew/bin/whisper-cli'
    if not os.path.exists(whisper):
        whisper = '/opt/homebrew/bin/whisper-cpp'
    
    model_path = f'/opt/homebrew/share/whisper-cpp/ggml-{model}.bin'
    
    with tempfile.TemporaryDirectory() as tmpdir:
        output_base = os.path.join(tmpdir, 'output')
        
        # Time the transcription
        start_time = time.time()
        try:
            subprocess.run([
                whisper,
                '-m', model_path,
                '-l', 'en',
                '-oj',
                '-of', output_base,
                '--beam-size', '3',
                '-t', '4',
                '-p', '1',
                wav_path
            ], capture_output=True, check=True)
        except subprocess.CalledProcessError:
            return None, 0
        
        elapsed = (time.time() - start_time) * 1000  # ms
        
        # Extract text from JSON
        json_path = f'{output_base}.json'
        if os.path.exists(json_path):
            with open(json_path, 'r') as f:
                data = json.load(f)
                # Extract text from transcription segments
                segments = data.get('transcription', [])
                text = ' '.join(seg.get('text', '') for seg in segments).strip()
                return text, elapsed
    
    return None, 0

def calculate_wer(reference, hypothesis):
    """Simple word error rate calculation"""
    if not reference or not hypothesis:
        return 100.0
    
    ref_words = reference.lower().split()
    hyp_words = hypothesis.lower().split()
    
    if not ref_words:
        return 100.0
    
    # Simple approach: count matching words
    matches = sum(1 for w in hyp_words if w in ref_words)
    wer = (1 - matches / len(ref_words)) * 100
    return min(100.0, max(0.0, wer))

def load_test_files():
    """Load all test WAV files with their golden transcripts"""
    test_files = []
    
    for category in ['micro', 'short', 'medium', 'long', 'natural', 'challenging']:
        dir_path = f'tests/fixtures/golden/{category}'
        if os.path.exists(dir_path):
            for wav_path in glob.glob(f'{dir_path}/*.wav'):
                txt_path = wav_path.replace('.wav', '.txt')
                if os.path.exists(txt_path):
                    with open(txt_path, 'r') as f:
                        golden_text = f.read().strip()
                    
                    duration = get_duration(wav_path)
                    if duration > 0:
                        test_files.append({
                            'wav': wav_path,
                            'golden': golden_text,
                            'duration': duration,
                            'name': os.path.basename(wav_path).replace('.wav', '')
                        })
    
    return sorted(test_files, key=lambda x: x['duration'])

def test_threshold(threshold, test_files):
    """Test a specific threshold value"""
    results = {
        'threshold': threshold,
        'base_files': [],
        'medium_files': [],
        'base_stats': {'count': 0, 'total_wer': 0, 'total_time': 0, 'total_duration': 0},
        'medium_stats': {'count': 0, 'total_wer': 0, 'total_time': 0, 'total_duration': 0}
    }
    
    for file_info in test_files:
        duration = file_info['duration']
        
        # Skip files way above threshold (>threshold+20s) to save time
        if duration > threshold + 20:
            continue
            
        # Determine which model to use
        if duration <= threshold:
            model = 'base'
            stats_key = 'base_stats'
            files_key = 'base_files'
        else:
            model = 'medium'
            stats_key = 'medium_stats'
            files_key = 'medium_files'
        
        # Transcribe
        transcribed, elapsed = transcribe_with_model(file_info['wav'], model)
        if transcribed is None:
            continue
        
        # Calculate WER
        wer = calculate_wer(file_info['golden'], transcribed)
        
        # Store results
        results[stats_key]['count'] += 1
        results[stats_key]['total_wer'] += wer
        results[stats_key]['total_time'] += elapsed
        results[stats_key]['total_duration'] += duration
        
        # Store file details if near threshold
        if abs(duration - threshold) <= 10:  # Within 10s of threshold
            results[files_key].append({
                'name': file_info['name'],
                'duration': duration,
                'wer': wer,
                'time': elapsed,
                'speed': elapsed / (duration * 1000) if duration > 0 else 0
            })
    
    # Calculate averages
    for stats_key in ['base_stats', 'medium_stats']:
        stats = results[stats_key]
        if stats['count'] > 0:
            stats['avg_wer'] = stats['total_wer'] / stats['count']
            stats['avg_time'] = stats['total_time'] / stats['count']
            stats['avg_speed'] = stats['total_time'] / (stats['total_duration'] * 1000) if stats['total_duration'] > 0 else 0
        else:
            stats['avg_wer'] = 0
            stats['avg_time'] = 0
            stats['avg_speed'] = 0
    
    return results

def main():
    print("🔬 Threshold Sweep Test")
    print("Finding optimal model switching point...")
    print("=" * 70)
    
    # Load test files
    test_files = load_test_files()
    print(f"Loaded {len(test_files)} test files")
    print(f"Duration range: {test_files[0]['duration']:.1f}s - {test_files[-1]['duration']:.1f}s")
    print()
    
    # Test thresholds from 10s to 60s in 10s increments
    thresholds = range(10, 61, 10)
    all_results = []
    
    prev_base_wer = None
    
    for threshold in thresholds:
        print(f"\nTesting threshold: {threshold}s")
        print("-" * 40)
        
        results = test_threshold(threshold, test_files)
        all_results.append(results)
        
        base_stats = results['base_stats']
        medium_stats = results['medium_stats']
        
        # Print results
        if base_stats['count'] > 0:
            print(f"  base.en (≤{threshold}s):")
            print(f"    Files: {base_stats['count']}")
            print(f"    Avg WER: {base_stats['avg_wer']:.1f}%")
            print(f"    Avg time: {base_stats['avg_time']:.0f}ms")
            print(f"    Speed: {base_stats['avg_speed']:.3f}x realtime")
        
        if medium_stats['count'] > 0:
            print(f"  medium.en (>{threshold}s):")
            print(f"    Files: {medium_stats['count']}")
            print(f"    Avg WER: {medium_stats['avg_wer']:.1f}%")
            print(f"    Avg time: {medium_stats['avg_time']:.0f}ms")
            print(f"    Speed: {medium_stats['avg_speed']:.3f}x realtime")
        
        # Check for steep accuracy drop
        if prev_base_wer is not None and base_stats['count'] > 0:
            wer_increase = base_stats['avg_wer'] - prev_base_wer
            if wer_increase > 10:  # >10% WER increase
                print(f"\n⚠️  WARNING: Steep accuracy drop detected!")
                print(f"   WER increased by {wer_increase:.1f}% from previous threshold")
        
        if base_stats['count'] > 0:
            prev_base_wer = base_stats['avg_wer']
    
    # Find optimal threshold
    print("\n" + "=" * 70)
    print("📊 Analysis Summary")
    print("=" * 70)
    
    # Find best threshold (balancing accuracy and including more files with base)
    best_threshold = 10
    best_score = float('inf')
    
    for result in all_results:
        threshold = result['threshold']
        base_stats = result['base_stats']
        
        if base_stats['count'] > 0:
            # Score = WER + speed penalty - file count bonus
            # Lower score is better
            score = (base_stats['avg_wer'] + 
                    base_stats['avg_speed'] * 100 -  # Penalize slow speed
                    base_stats['count'] * 0.5)        # Bonus for more files
            
            print(f"Threshold {threshold}s: WER={base_stats['avg_wer']:.1f}%, "
                  f"Speed={base_stats['avg_speed']:.3f}x, "
                  f"Files={base_stats['count']}, Score={score:.1f}")
            
            if score < best_score and base_stats['avg_wer'] < 40:  # WER must be reasonable
                best_score = score
                best_threshold = threshold
    
    print(f"\n🎯 Recommended threshold: {best_threshold}s")
    print(f"   This provides the best balance of accuracy and performance")
    
    # Show what happens at boundaries
    print("\n📈 Files near recommended threshold:")
    for result in all_results:
        if result['threshold'] == best_threshold:
            print(f"\nFiles just below {best_threshold}s (using base.en):")
            for f in sorted(result['base_files'], key=lambda x: -x['duration'])[:3]:
                print(f"  {f['name']}: {f['duration']:.1f}s, WER={f['wer']:.1f}%, {f['time']:.0f}ms")
            
            print(f"\nFiles just above {best_threshold}s (using medium.en):")
            for f in sorted(result['medium_files'], key=lambda x: x['duration'])[:3]:
                print(f"  {f['name']}: {f['duration']:.1f}s, WER={f['wer']:.1f}%, {f['time']:.0f}ms")

if __name__ == '__main__':
    main()
