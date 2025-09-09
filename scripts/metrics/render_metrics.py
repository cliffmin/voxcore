#!/usr/bin/env python3
# Render a simple SVG performance chart from latest tx_logs, without external deps.
# It invokes tests/util/report_short_vs_long.py to get JSON, then writes docs/assets/metrics.svg.

import json, os, subprocess, sys, shutil, math
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSETS = REPO / "docs" / "assets"
ASSETS.mkdir(parents=True, exist_ok=True)
OUT = ASSETS / "metrics.svg"

REPORT = REPO / "tests" / "util" / "report_short_vs_long.py"
if not REPORT.exists():
    print("missing report_short_vs_long.py", file=sys.stderr)
    sys.exit(0)

try:
    out = subprocess.check_output([sys.executable, str(REPORT)], stderr=subprocess.DEVNULL, text=True)
    data = json.loads(out)
except Exception as e:
    print(f"could not compute metrics: {e}", file=sys.stderr)
    sys.exit(0)

hold = data.get('hold', {})
toggle = data.get('toggle', {})

hold_avg = (hold.get('tx_ms') or {}).get('avg')
toggle_avg = (toggle.get('tx_ms') or {}).get('avg')
refine_avg = (toggle.get('refine_ms') or {}).get('avg')

# Compute structure metrics if present in samples
samples = toggle.get('samples') or []
if samples:
    avg_headings = sum((s.get('refined_headings') or 0) for s in samples) / max(1, len(samples))
    avg_bullets = sum((s.get('refined_bullets') or 0) for s in samples) / max(1, len(samples))
else:
    avg_headings = avg_bullets = 0

# Build a very simple SVG bar chart
W, H = 680, 280
P = 40
bar_w = 80
bars = []
labels = []
vals = []
colors = ["#4F46E5", "#10B981", "#F59E0B"]  # indigo, emerald, amber

if hold_avg:
    labels.append("Hold tx (ms)")
    vals.append(hold_avg)
if toggle_avg:
    labels.append("Toggle tx (ms)")
    vals.append(toggle_avg)
if refine_avg:
    labels.append("Refine (ms)")
    vals.append(refine_avg)

if not vals:
    # No numeric data—write a placeholder SVG
    OUT.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="680" height="200">\n'
                   '  <text x="20" y="100" font-family="Menlo,monospace" font-size="14">No metrics available (record a few sessions)</text>\n'
                   '</svg>\n', encoding='utf-8')
    print(str(OUT))
    sys.exit(0)

max_v = max(vals)
scale = (H - 2*P) / max_v if max_v > 0 else 1

svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}">']
svg.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="#ffffff"/>')
svg.append(f'<text x="{P}" y="{P-12}" font-family="Menlo,monospace" font-size="14" fill="#111827">Transcription & Refine Timing</text>')

# Axes
svg.append(f'<line x1="{P}" y1="{H-P}" x2="{W-P}" y2="{H-P}" stroke="#9CA3AF" stroke-width="1"/>')
svg.append(f'<line x1="{P}" y1="{P}" x2="{P}" y2="{H-P}" stroke="#9CA3AF" stroke-width="1"/>')

x = P + 20
for i, v in enumerate(vals):
    h = v * scale
    y = (H - P) - h
    color = colors[i % len(colors)]
    svg.append(f'<rect x="{x}" y="{y}" width="{bar_w}" height="{h}" fill="{color}" rx="4"/>')
    svg.append(f'<text x="{x + bar_w/2}" y="{H-P+16}" text-anchor="middle" font-family="Menlo,monospace" font-size="11" fill="#374151">{labels[i]}</text>')
    svg.append(f'<text x="{x + bar_w/2}" y="{y-6}" text-anchor="middle" font-family="Menlo,monospace" font-size="11" fill="#111827">{v:.0f}</text>')
    x += bar_w + 40

# Structure callouts
svg.append(f'<text x="{W-P-240}" y="{P+8}" font-family="Menlo,monospace" font-size="12" fill="#111827">Markdown structure (avg across toggles)</text>')
svg.append(f'<text x="{W-P-240}" y="{P+24}" font-family="Menlo,monospace" font-size="11" fill="#374151">Headings: {avg_headings:.1f}  Bullets: {avg_bullets:.1f}</text>')

svg.append('</svg>\n')
OUT.write_text('\n'.join(svg), encoding='utf-8')
print(str(OUT))

