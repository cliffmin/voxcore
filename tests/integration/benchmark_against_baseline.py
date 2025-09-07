#!/usr/bin/env python3
import argparse, os, time, subprocess, json
from pathlib import Path

def list_wavs(base_dir):
    out = []
    for bucket in ("short","medium","long"):
        d = Path(base_dir)/bucket
        if not d.is_dir():
            continue
        for p in d.iterdir():
            if p.suffix.lower() == '.wav':
                out.append((bucket, str(p)))
    return out

def run_whisper(whisper, wav, model, lang, outdir):
    outdir.mkdir(parents=True, exist_ok=True)
    t0 = time.monotonic()
    try:
        rc = subprocess.call([
            str(whisper), str(wav), '--model', model, '--language', lang,
            '--output_format', 'json', '--output_dir', str(outdir), '--beam_size', '3',
            '--device', 'cpu', '--fp16', 'False', '--verbose', 'False', '--temperature', '0'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        rc = 1
    elapsed = time.monotonic()-t0
    return rc, elapsed

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('baseline_dir')
    ap.add_argument('--whisper', default=os.path.expanduser('~/.local/bin/whisper'))
    ap.add_argument('--model', default='base.en')
    ap.add_argument('--lang', default='en')
    args = ap.parse_args()

    base = Path(args.baseline_dir)
    if not base.is_dir():
        print(f"Not a directory: {base}")
        raise SystemExit(2)
    whisper = Path(args.whisper)
    if not whisper.exists():
        print(f"Missing whisper CLI at {whisper}")
        raise SystemExit(2)

    rows = []
    for bucket, wav in list_wavs(base):
        base_name = Path(wav).stem
        outdir = base/"tmp_outputs"/base_name
        rc, elapsed = run_whisper(whisper, wav, args.model, args.lang, outdir)
        rows.append((rc, elapsed, wav, str(outdir/(base_name+'.json'))))

    # Write results file
    results_path = base / f"benchmark_results_{time.strftime('%Y%m%d-%H%M%S')}.txt"
    with open(results_path, 'w', encoding='utf-8') as f:
        f.write('rc|elapsed_sec|wav|json')
        for rc, elapsed, wav, j in rows:
            f.write(f"\n{rc}|{elapsed:.3f}|{wav}|{j}")

    print(json.dumps({"results": str(results_path)}, indent=2))

if __name__ == '__main__':
    main()

