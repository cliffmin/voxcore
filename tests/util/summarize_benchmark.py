#!/usr/bin/env python3
import sys, statistics as stats, json, os
from collections import defaultdict

if len(sys.argv) < 2:
    print("usage: summarize_benchmark.py <results_file>", file=sys.stderr)
    sys.exit(2)

path = sys.argv[1]
if not os.path.isfile(path):
    print(f"missing file: {path}", file=sys.stderr)
    sys.exit(2)

rows = []
with open(path, 'r', encoding='utf-8') as f:
    header = f.readline()
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split('|')
        if len(parts) < 4:
            continue
        rc = int(parts[0])
        try:
            elapsed = float(parts[1])
        except:
            continue
        wav = parts[2]
        bucket = 'unknown'
        if '/short/' in wav:
            bucket = 'short'
        elif '/medium/' in wav:
            bucket = 'medium'
        elif '/long/' in wav:
            bucket = 'long'
        rows.append((rc, elapsed, wav, bucket))

if not rows:
    print(json.dumps({"error": "no_data"}))
    sys.exit(0)

buckets = defaultdict(list)
for rc, elapsed, wav, bucket in rows:
    buckets[bucket].append((rc, elapsed, wav))


def summarize(items):
    if not items:
        return {"count": 0}
    rc_vals = [rc for rc,_,_ in items]
    times = [t for _,t,_ in items]
    times_sorted = sorted(times)
    def pctl(v, p):
        if not v:
            return None
        idx = int(round((p/100.0)*(len(v)-1)))
        return v[idx]
    out = {
        "count": len(items),
        "success": sum(1 for r in rc_vals if r == 0),
        "fail": sum(1 for r in rc_vals if r != 0),
        "min_sec": min(times),
        "p50_sec": stats.median(times),
        "p90_sec": pctl(times_sorted, 90),
        "max_sec": max(times),
        "avg_sec": sum(times)/len(times),
    }
    return out

rows3 = [(rc, elapsed, wav) for (rc, elapsed, wav, bucket) in rows]
summary = {"overall": summarize(rows3)}
for b in sorted(buckets.keys()):
    summary[b] = summarize(buckets[b])

print(json.dumps(summary, indent=2))

