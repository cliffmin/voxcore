#!/usr/bin/env python3
import argparse, glob, json, os, subprocess, time
from pathlib import Path

def git_short_sha(repo):
    try:
        return subprocess.check_output(["git","-C",repo,"rev-parse","--short","HEAD"], text=True).strip()
    except Exception:
        return ""

def latest_log(root):
    files = sorted(glob.glob(os.path.join(root, 'tx_logs', 'tx-*.jsonl')))
    return files[-1] if files else None

def pick_top(events, per_bucket, short_max, medium_max):
    buckets = {"short":[], "medium":[], "long":[]}
    for e in events:
        if e.get("kind") != "success":
            continue
        dur = float(e.get("duration_sec") or 0)
        chars = int(e.get("transcript_chars") or 0)
        wav = e.get("audio_used") or e.get("wav")
        if not wav or not os.path.isfile(wav):
            continue
        if dur <= short_max:
            k = "short"
        elif dur <= medium_max:
            k = "medium"
        else:
            k = "long"
        buckets[k].append((chars, wav))
    out = {}
    for k, arr in buckets.items():
        arr.sort(key=lambda x: x[0], reverse=True)
        out[k] = arr[:per_bucket]
    return out

def ensure_dir(p):
    Path(p).mkdir(parents=True, exist_ok=True)

def force_symlink(src, dst):
    try:
        if os.path.lexists(dst):
            os.remove(dst)
        os.symlink(src, dst)
    except Exception:
        pass

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--per-bucket', type=int, default=5)
    ap.add_argument('--short-max', type=int, default=10)
    ap.add_argument('--medium-max', type=int, default=30)
    ap.add_argument('--day')
    args = ap.parse_args()

    home = os.path.expanduser('~')
    root = os.path.join(home, 'Documents', 'VoiceNotes')
    repo = str(Path(__file__).resolve().parents[2])

    if args.day:
        log_path = os.path.join(root, 'tx_logs', f'tx-{args.day}.jsonl')
    else:
        log_path = latest_log(root)
    if not log_path or not os.path.isfile(log_path):
        print('ERROR: missing log', log_path or '')
        raise SystemExit(1)

    events = []
    with open(log_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            events.append(obj)

    top = pick_top(events, args.per_bucket, args.short_max, args.medium_max)

    short_sha = git_short_sha(repo)
    baseline_id = f"baseline_{time.strftime('%Y%m%d-%H%M')}{('_'+short_sha) if short_sha else ''}"
    base_dir = os.path.join(repo, 'tests', 'fixtures', 'baselines', baseline_id)
    for b in ('short','medium','long'):
        ensure_dir(os.path.join(base_dir, b))

    # link files
    for b, arr in top.items():
        for _, wav in arr:
            dst_dir = os.path.join(base_dir, b)
            force_symlink(wav, os.path.join(dst_dir, os.path.basename(wav)))
            base = wav[:-4]
            for ext in ('.json','.txt','.en.txt'):
                side = base + ext
                if os.path.isfile(side):
                    force_symlink(side, os.path.join(dst_dir, os.path.basename(side)))

    # write baseline metadata
    meta = {
        'baseline_id': baseline_id,
        'log': log_path,
        'repo': repo,
        'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'per_bucket': args.per_bucket,
        'short_max': args.short_max,
        'medium_max': args.medium_max,
    }
    ensure_dir(base_dir)
    with open(os.path.join(base_dir, 'baseline.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=2)

    print(f"BASELINE_DIR={base_dir}")

if __name__ == '__main__':
    main()

