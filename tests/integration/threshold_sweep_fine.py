#!/usr/bin/env python3
"""
Fine-grained threshold sweep test focusing on the 15-35s range
where accuracy transitions happen.
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
            ], capture_output=True, check=True, timeout=30)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
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
    """Load test files in the critical duration range"""
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
                    # Focus on files in the 5-40s range
                    if 5 <= duration <= 40:
                        test_files.append({
                            'wav': wav_path,
                            'golden': golden_text,
                            'duration': duration,
                            'name': os.path.basename(wav_path).replace('.wav', '')
                        })
    
    return sorted(test_files, key=lambda x: x['duration'])

def test_both_models(file_info):
    """Test a file with both models to compare"""
    results = {}
    
    for model in ['base', 'medium']:
        text, elapsed = transcribe_with_model(file_info['wav'], model)
        if text:
            wer = calculate_wer(file_info['golden'], text)
            results[model] = {
                'wer': wer,
                'time': elapsed,
                'speed': elapsed / (file_info['duration'] * 1000)
            }
    
    return results

def main():
    print("🔬 Fine-Grained Threshold Analysis")
    print("Testing accuracy vs performance tradeoffs")
    print("=" * 80)
    
    # Load test files
    test_files = load_test_files()
    print(f"Testing {len(test_files)} files in 5-40s range")
    print()
    
    # Test each file with both models
    results_by_duration = []
    
    for file_info in test_files:
        print(f"Testing {file_info['name']} ({file_info['duration']:.1f}s)...")
        results = test_both_models(file_info)
        
        if 'base' in results and 'medium' in results:
            wer_diff = results['base']['wer'] - results['medium']['wer']
            time_diff = results['medium']['time'] - results['base']['time']
            
            results_by_duration.append({
                'duration': file_info['duration'],
                'name': file_info['name'],
                'base_wer': results['base']['wer'],
                'medium_wer': results['medium']['wer'],
                'wer_improvement': wer_diff,
                'base_time': results['base']['time'],
                'medium_time': results['medium']['time'],
                'time_cost': time_diff,
                'speed_base': results['base']['speed'],
                'speed_medium': results['medium']['speed']
            })
    
    # Analyze results by duration buckets
    print("\n" + "=" * 80)
    print("📊 Results by Duration Range")
    print("=" * 80)
    
    buckets = [(5, 10), (10, 15), (15, 20), (20, 25), (25, 30), (30, 35), (35, 40)]
    
    for min_dur, max_dur in buckets:
        bucket_results = [r for r in results_by_duration 
                         if min_dur <= r['duration'] < max_dur]
        
        if bucket_results:
            avg_base_wer = sum(r['base_wer'] for r in bucket_results) / len(bucket_results)
            avg_medium_wer = sum(r['medium_wer'] for r in bucket_results) / len(bucket_results)
            avg_wer_improvement = avg_base_wer - avg_medium_wer
            avg_base_time = sum(r['base_time'] for r in bucket_results) / len(bucket_results)
            avg_medium_time = sum(r['medium_time'] for r in bucket_results) / len(bucket_results)
            avg_time_cost = avg_medium_time - avg_base_time
            
            print(f"\n{min_dur}-{max_dur}s range ({len(bucket_results)} files):")
            print(f"  base.en:   WER={avg_base_wer:.1f}%, Time={avg_base_time:.0f}ms")
            print(f"  medium.en: WER={avg_medium_wer:.1f}%, Time={avg_medium_time:.0f}ms")
            print(f"  Improvement: {avg_wer_improvement:.1f}% better accuracy")
            print(f"  Cost: {avg_time_cost:.0f}ms slower ({avg_time_cost/1000:.1f}s)")
            
            # Mark significant drop-offs
            if avg_base_wer > 35:
                print(f"  ⚠️  base.en accuracy degraded significantly (>35% WER)")
            elif avg_wer_improvement > 15:
                print(f"  📉 Large accuracy gap - medium.en recommended")
            elif avg_wer_improvement < 5 and avg_time_cost > 2000:
                print(f"  💡 Small accuracy gain for high time cost - base.en recommended")
    
    # Find optimal threshold
    print("\n" + "=" * 80)
    print("🎯 Threshold Recommendation")
    print("=" * 80)
    
    # Find where base.en WER exceeds 30% or improvement exceeds 15%
    thresholds_to_consider = []
    
    for r in results_by_duration:
        if r['base_wer'] > 30 or r['wer_improvement'] > 15:
            thresholds_to_consider.append(r['duration'])
    
    if thresholds_to_consider:
        recommended = min(thresholds_to_consider)
        print(f"\nRecommended threshold: {recommended:.0f}s")
        print(f"Files shorter than this should use base.en for speed")
        print(f"Files longer should use medium.en for accuracy")
    else:
        # Use percentile-based recommendation
        durations = [r['duration'] for r in results_by_duration]
        if durations:
            p33 = durations[len(durations)//3]
            print(f"\nRecommended threshold: {p33:.0f}s (33rd percentile)")
            print(f"No significant accuracy drops detected in test set")
    
    # Show specific examples at boundary
    print("\n📈 Example files near recommended threshold:")
    for r in sorted(results_by_duration, key=lambda x: x['duration']):
        if 18 <= r['duration'] <= 25:
            print(f"\n{r['name']} ({r['duration']:.1f}s):")
            print(f"  base.en:   WER={r['base_wer']:.1f}%, {r['base_time']:.0f}ms")
            print(f"  medium.en: WER={r['medium_wer']:.1f}%, {r['medium_time']:.0f}ms")
            if r['wer_improvement'] > 10:
                print(f"  → medium.en {r['wer_improvement']:.1f}% more accurate")

if __name__ == '__main__':
    main()
