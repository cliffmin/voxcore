#!/usr/bin/env python3
import argparse, json, os, glob, statistics as stats
from pathlib import Path


def latest_log(default_root: Path) -> Path | None:
    files = sorted(default_root.glob('tx-*.jsonl'))
    return files[-1] if files else None


def pct(v, p):
    if not v:
        return None
    i = int(round((p/100.0) * (len(v)-1)))
    return v[i]


def summarize(values):
    if not values:
        return {}
    v = sorted(values)
    return {
        'count': len(v),
        'min': v[0],
        'p50': stats.median(v),
        'p90': pct(v, 90),
        'max': v[-1],
        'avg': sum(v)/len(v)
    }


def main():
    ap = argparse.ArgumentParser(description='Summarize latest transcription log')
    ap.add_argument('--log', help='Path to tx-YYYY-MM-DD.jsonl (defaults to latest under ~/Documents/VoiceNotes/tx_logs)')
    ap.add_argument('--top', type=int, default=5, help='Show top N slowest events')
    args = ap.parse_args()

    root = Path(os.path.expanduser('~/Documents/VoiceNotes/tx_logs'))
    log_path = Path(args.log) if args.log else latest_log(root)
    if not log_path or not log_path.exists():
        print(json.dumps({'error': 'missing_log', 'path': str(log_path) if log_path else None}))
        return

    hold_tx, hold_dur = [], []
    tog_tx, tog_dur = [], []
    errs = []
    all_events = []

    with log_path.open('r', encoding='utf-8') as f:
        for ln in f:
            ln = ln.strip()
            if not ln:
                continue
            try:
                e = json.loads(ln)
            except Exception:
                continue
            k = e.get('kind')
            all_events.append(e)
            if k == 'success':
                sk = e.get('session_kind')
                tx = float(e.get('tx_ms') or 0)
                dur = float(e.get('duration_sec') or 0)
                if sk == 'hold':
                    hold_tx.append(tx); hold_dur.append(dur)
                elif sk == 'toggle':
                    tog_tx.append(tx); tog_dur.append(dur)
            elif k in ('error', 'timeout'):
                errs.append(e)

    def top_slowest(evts, n=5):
        succ = [e for e in evts if e.get('kind') == 'success']
        succ = [e for e in succ if (e.get('tx_ms') or 0) != 0]
        succ.sort(key=lambda e: float(e.get('tx_ms') or 0), reverse=True)
        out = []
        for e in succ[:n]:
            out.append({
                'ts': e.get('ts'),
                'kind': e.get('session_kind'),
                'tx_ms': e.get('tx_ms'),
                'duration_sec': e.get('duration_sec'),
                'model': e.get('model'),
                'wav': e.get('wav'),
            })
        return out

    out = {
        'log_path': str(log_path),
        'counts': {
            'total': len(all_events),
            'success': sum(1 for e in all_events if e.get('kind') == 'success'),
            'error': sum(1 for e in all_events if e.get('kind') == 'error'),
            'timeout': sum(1 for e in all_events if e.get('kind') == 'timeout'),
        },
        'hold': {
            'duration_sec': summarize(hold_dur),
            'tx_ms': summarize(hold_tx),
        },
        'toggle': {
            'duration_sec': summarize(tog_dur),
            'tx_ms': summarize(tog_tx),
        },
        'errors': [{'ts': e.get('ts'), 'tx_code': e.get('tx_code'), 'stderr': e.get('stderr', '')[:200]} for e in errs][-10:],
        'top_slowest': top_slowest(all_events, n=args.top),
    }
    print(json.dumps(out, indent=2))


if __name__ == '__main__':
    main()
