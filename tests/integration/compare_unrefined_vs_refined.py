#!/usr/bin/env python3
import argparse, os, subprocess, time, json
from pathlib import Path


def read_text(p: Path) -> str:
    try:
        return p.read_text(encoding='utf-8')
    except Exception:
        return ''


def whisper_transcribe(whisper: Path, wav: Path, outdir: Path, model='base.en', lang='en'):
    outdir.mkdir(parents=True, exist_ok=True)
    base = wav.stem
    json_path = outdir / f"{base}.json"
    if json_path.exists():
        return json_path
    cmd = [str(whisper), str(wav), '--model', model, '--language', lang, '--output_format', 'json', '--output_dir', str(outdir), '--beam_size', '3', '--device', 'cpu', '--fp16', 'False', '--verbose', 'False', '--temperature', '0']
    rc = subprocess.call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if rc != 0:
        return None
    return json_path if json_path.exists() else None


def run_voxcompose(vox_bin: str, text: str, sidecar: Path) -> (int, float, str):
    # Runs: echo text | java -jar vox.jar --sidecar sidecar.json
    t0 = time.monotonic()
    try:
        p = subprocess.Popen([vox_bin, '--sidecar', str(sidecar)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        out, err = p.communicate(text, timeout=30)
        rc = p.returncode
    except Exception:
        return (1, 0.0, '')
    elapsed = time.monotonic() - t0
    return (rc, elapsed, out)


def structure_metrics_markdown(md: str):
    lines = md.splitlines()
    headings = sum(1 for ln in lines if ln.lstrip().startswith('#'))
    bullets = sum(1 for ln in lines if ln.lstrip().startswith(('-', '*')))
    paragraphs = md.count('\n\n') + 1 if md else 0
    return {'headings': headings, 'bullets': bullets, 'paragraphs': paragraphs}


def list_wavs(base_dir: Path, bucket: str):
    d = base_dir / bucket
    if not d.is_dir():
        return []
    return [p for p in d.iterdir() if p.suffix.lower() == '.wav']


def main():
    ap = argparse.ArgumentParser(description='Compare unrefined vs refined on the SAME dataset (long bucket by default)')
    ap.add_argument('baseline_dir', help='Path to baseline directory (tests/fixtures/baselines/<id>)')
    ap.add_argument('--bucket', default='long', choices=['micro','short','medium','long'])
    ap.add_argument('--whisper', default=str(Path.home()/'.local/bin/whisper'))
    ap.add_argument('--model', default='base.en')
    ap.add_argument('--lang', default='en')
    ap.add_argument('--vox-bin', default=f"/usr/bin/java -jar {Path.home()}/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar", help='Command to run VoxCompose (java -jar path)')
    args = ap.parse_args()

    base = Path(args.baseline_dir)
    if not base.is_dir():
        print(json.dumps({'error':'not_dir','path':str(base)}))
        return

    # Resolve voxcompose bin: if string contains spaces, use shell
    vox_bin = args.vox-bin if hasattr(args, 'vox-bin') else args.vox_bin
    use_shell = True if ' ' in vox_bin else False

    whisper = Path(args.whisper)
    wavs = list_wavs(base, args.bucket)
    if not wavs:
        print(json.dumps({'error':'no_wavs','bucket':args.bucket}))
        return

    tmp = base / 'tmp_compare'
    tmp.mkdir(exist_ok=True)

    rows = []
    for wav in wavs:
        outdir = tmp / wav.stem
        json_path = whisper_transcribe(whisper, wav, outdir, model=args.model, lang=args.lang)
        if not json_path:
            rows.append({'wav':str(wav),'error':'whisper_failed'})
            continue
        # Baseline text
        base_txt = ''
        for ext in ('.txt','.en.txt','.english.txt'):
            p = json_path.with_suffix(ext)
            if p.exists():
                base_txt = read_text(p)
                break
        if not base_txt:
            # Extract from JSON if TXT not present
            try:
                data = json.loads(read_text(json_path))
                base_txt = data.get('text','') if isinstance(data, dict) else ''
            except Exception:
                base_txt = ''
        # Refine with VoxCompose
        sidecar = outdir / 'refine.json'
        # Allow shell for java -jar form
        if use_shell:
            import shlex
            cmd = f"{vox_bin} --sidecar {shlex.quote(str(sidecar))}"
            t0 = time.monotonic()
            p = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            out, err = p.communicate(base_txt, timeout=30)
            rc = p.returncode
            elapsed = time.monotonic() - t0
        else:
            rc, elapsed, out = run_voxcompose(vox_bin, base_txt, sidecar)
        if rc != 0:
            rows.append({'wav':str(wav),'baseline_chars':len(base_txt),'refine_rc':rc})
            continue
        refined = out or ''
        sm = structure_metrics_markdown(refined)
        rows.append({
            'wav': str(wav),
            'baseline_chars': len(base_txt),
            'refined_chars': len(refined),
            'delta_chars': (len(refined)-len(base_txt)),
            'refine_sec': elapsed,
            'refined_headings': sm['headings'],
            'refined_bullets': sm['bullets'],
            'refined_paragraphs': sm['paragraphs'],
        })

    print(json.dumps({'bucket': args.bucket, 'count': len(rows), 'rows': rows}, indent=2))

if __name__ == '__main__':
    main()
