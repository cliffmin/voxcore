#!/usr/bin/env python3
import argparse, glob, json, os, statistics as stats
from pathlib import Path


def latest_log(root):
    files = sorted(glob.glob(os.path.join(root, 'tx_logs', 'tx-*.jsonl')))
    return files[-1] if files else None


def read_text(path):
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception:
        return ''


def structure_metrics_markdown(md: str):
    lines = md.splitlines()
    headings = sum(1 for ln in lines if ln.lstrip().startswith('#'))
    bullets = sum(1 for ln in lines if ln.lstrip().startswith(('-', '*')))
    paragraphs = md.count('\n\n') + 1 if md else 0
    return {
        'headings': headings,
        'bullets': bullets,
        'paragraphs': paragraphs,
    }


def summarize_numbers(values):
    if not values:
        return {}
    v = sorted(values)
    def pctl(v, p):
        idx = int(round((p/100.0)*(len(v)-1)))
        return v[idx]
    return {
        'count': len(v),
        'min': v[0],
        'p50': stats.median(v),
        'p90': pctl(v, 90),
        'max': v[-1],
        'avg': sum(v)/len(v),
    }


def main():
    ap = argparse.ArgumentParser(description='Compare short (hold) vs long (toggle+refine) performance and structure')
    ap.add_argument('--log', help='Path to tx-YYYY-MM-DD.jsonl (defaults to latest)')
    args = ap.parse_args()

    root = os.path.join(os.path.expanduser('~'), 'Documents', 'VoiceNotes')
    log_path = args.log or latest_log(root)
    if not log_path or not os.path.isfile(log_path):
        print(json.dumps({'error': 'missing_log', 'path': log_path}))
        return

    hold_tx_ms = []
    hold_durations = []

    toggle_tx_ms = []
    toggle_durations = []
    toggle_refine_ms = []

    toggles_detail = []

    with open(log_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except Exception:
                continue
            if e.get('kind') != 'success':
                continue
            sk = e.get('session_kind')
            tx_ms = float(e.get('tx_ms') or 0)
            dur = float(e.get('duration_sec') or 0)

            if sk == 'hold':
                hold_tx_ms.append(tx_ms)
                hold_durations.append(dur)
            elif sk == 'toggle':
                toggle_tx_ms.append(tx_ms)
                toggle_durations.append(dur)
                # Capture refine metrics if present
                refine_ms = e.get('refine_ms')
                if refine_ms is not None:
                    try:
                        toggle_refine_ms.append(float(refine_ms))
                    except Exception:
                        pass
                # Compare baseline TXT vs refined Markdown if paths present
                json_path = e.get('json_path')
                out_md = (e.get('output_path') or '').strip()
                base_txt = ''
                if json_path:
                    base = json_path[:-5] if json_path.endswith('.json') else json_path
                    for ext in ('.txt', '.en.txt', '.english.txt'):
                        cand = base + ext
                        if os.path.isfile(cand):
                            base_txt = read_text(cand)
                            break
                md_text = read_text(out_md) if out_md and os.path.isfile(out_md) else ''
                base_len = len(base_txt)
                md_len = len(md_text)
                md_struct = structure_metrics_markdown(md_text)
                toggles_detail.append({
                    'duration_sec': dur,
                    'tx_ms': tx_ms,
                    'refine_ms': refine_ms,
                    'baseline_chars': base_len,
                    'refined_chars': md_len,
                    'refined_headings': md_struct.get('headings'),
                    'refined_bullets': md_struct.get('bullets'),
                    'refined_paragraphs': md_struct.get('paragraphs'),
                    'output_path': out_md if out_md else None,
                })

    out = {
        'log_path': log_path,
        'hold': {
            'count': len(hold_tx_ms),
            'duration': summarize_numbers(hold_durations),
            'tx_ms': summarize_numbers(hold_tx_ms),
        },
        'toggle': {
            'count': len(toggle_tx_ms),
            'duration': summarize_numbers(toggle_durations),
            'tx_ms': summarize_numbers(toggle_tx_ms),
            'refine_ms': summarize_numbers(toggle_refine_ms) if toggle_refine_ms else {},
            'samples': toggles_detail[:10],
        },
    }
    print(json.dumps(out, indent=2))

if __name__ == '__main__':
    main()
