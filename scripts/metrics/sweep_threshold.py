#!/usr/bin/env python3
# Sweep threshold between two models on golden fixtures and find the optimal by WER and/or time.
# Usage: scripts/metrics/sweep_threshold.py --golden tests/fixtures/golden --models base.en medium.en --start 4 --end 60 --step 2

import argparse, os, sys, json, subprocess, time
from pathlib import Path

WHISPER = Path.home() / ".local/bin/whisper"

CATEGORIES = ["micro", "short", "medium", "long"]


def list_wavs(root: Path):
    files = []
    for cat in CATEGORIES:
        d = root / cat
        if not d.is_dir():
            continue
        for p in d.glob("*.wav"):
            files.append(p)
    return files


def transcribe(wav: Path, model: str, outdir: Path):
    outdir.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    cmd = [str(WHISPER), str(wav), "--model", model, "--language", "en", "--output_format", "txt", "--output_dir", str(outdir), "--device", "cpu", "--fp16", "False", "--verbose", "False", "--temperature", "0"]
    rc = subprocess.call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    dt = time.time() - t0
    out = outdir / (wav.stem + ".txt")
    if not out.exists():
        # try language-suffixed outputs
        for suf in (".en.txt", ".english.txt"):
            cand = outdir / (wav.stem + suf)
            if cand.exists():
                out = cand
                break
    text = out.read_text(encoding="utf-8") if out.exists() else ""
    return rc, dt, text


def wer(a: str, b: str):
    # Simple bag-of-words mismatch ratio as a proxy
    aw = [w for w in ''.join(ch if ch.isalnum() or ch.isspace() else ' ' for ch in a.lower()).split() if w]
    bw = [w for w in ''.join(ch if ch.isalnum() or ch.isspace() else ' ' for ch in b.lower()).split() if w]
    if not aw:
        return 0.0
    aset = set(aw)
    bset = set(bw)
    common = len(aset & bset)
    return float(len(aset) - common) / float(len(aset))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--golden", default="tests/fixtures/golden")
    ap.add_argument("--models", nargs=2, default=["base.en", "medium.en"], help="short_model long_model")
    ap.add_argument("--start", type=float, default=6.0)
    ap.add_argument("--end", type=float, default=40.0)
    ap.add_argument("--step", type=float, default=2.0)
    args = ap.parse_args()

    golden = Path(args.golden)
    if not golden.exists():
        print(json.dumps({"error": "missing_golden", "golden": str(golden)}))
        sys.exit(0)

    wavs = list_wavs(golden)
    if not wavs:
        print(json.dumps({"error": "no_wavs", "golden": str(golden)}))
        sys.exit(0)

    # Precompute reference texts
    refs = {}
    durations = {}
    for w in wavs:
        txt = (w.parent / (w.stem + ".txt"))
        refs[str(w)] = txt.read_text(encoding="utf-8") if txt.exists() else ""
        # Estimate duration from size if needed (16k mono s16 -> 32000 bytes/sec). Prefer ffprobe if available.
        try:
            import subprocess
            out = subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(w)], text=True).strip()
            durations[str(w)] = float(out)
        except Exception:
            sz = w.stat().st_size
            durations[str(w)] = max(0.0, (sz - 44) / 32000.0)

    tmp = Path("/tmp/threshold_sweep")
    tmp.mkdir(exist_ok=True)

    short_model, long_model = args.models

    # Transcribe each file with both models once
    cache = {}
    for w in wavs:
        base_dir = tmp / "base" / w.parent.name
        med_dir = tmp / "med" / w.parent.name
        rc_b, t_b, txt_b = transcribe(w, short_model, base_dir)
        rc_m, t_m, txt_m = transcribe(w, long_model, med_dir)
        cache[str(w)] = {
            "dur": durations[str(w)],
            "ref": refs[str(w)],
            "short": {"model": short_model, "rc": rc_b, "sec": t_b, "txt": txt_b},
            "long": {"model": long_model, "rc": rc_m, "sec": t_m, "txt": txt_m},
        }

    # Sweep thresholds
    t = args.start
    best = None
    results = []
    while t <= args.end + 1e-9:
        total_wer = 0.0
        total_sec = 0.0
        count = 0
        for w, rec in cache.items():
            use_long = (rec["dur"] > t)
            choice = rec["long"] if use_long else rec["short"]
            total_sec += float(choice["sec"]) if choice["sec"] is not None else 0.0
            total_wer += wer(rec["ref"], choice["txt"]) if rec["ref"] else 0.0
            count += 1
        avg_wer = (total_wer / max(1, count))
        avg_sec = (total_sec / max(1, count))
        results.append({"threshold_sec": t, "avg_wer": avg_wer, "avg_sec": avg_sec})
        if best is None or (avg_wer < best["avg_wer"]) or (abs(avg_wer - best["avg_wer"]) < 1e-6 and avg_sec < best["avg_sec"]):
            best = {"threshold_sec": t, "avg_wer": avg_wer, "avg_sec": avg_sec}
        t += args.step

    print(json.dumps({"best": best, "results": results}, indent=2))


if __name__ == "__main__":
    main()

