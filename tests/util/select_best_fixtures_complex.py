#!/usr/bin/env python3
import argparse, json, os, re, glob, time, subprocess
from pathlib import Path

TRICKY_DEFAULT = [
  'json','jira','nosql','symlink','symlinks','xdg','avalara','tax','dedupe','lead role','paths',
  'dynamodb','salesforce','hyperdx','postman','oauth','ffmpeg','avfoundation','base.en','normalize','loudnorm','acompressor'
]

def git_short_sha(repo):
  try:
    return subprocess.check_output(['git','-C',repo,'rev-parse','--short','HEAD'], text=True).strip()
  except Exception:
    return ''

def read_text(path):
  try:
    with open(path,'r',encoding='utf-8') as f:
      return f.read()
  except Exception:
    return ''

def tricky_count(text, tokens):
  t = text.lower()
  total = 0
  for tok in tokens:
    tok = re.sub(r'[^\w]+',' ', tok.lower()).strip()
    if not tok:
      continue
    total += t.count(tok)
  return total

def scan_batch_fixtures(samples_dir):
  out = []
  for meta in Path(samples_dir).glob('batches/*/*/fixture.json'):
    try:
      data = json.loads(read_text(str(meta)))
    except Exception:
      data = {}
    bucket = data.get('category') or 'unknown'
    # audio/txt/json are siblings; derive from directory contents
    d = meta.parent
    wavs = list(d.glob('*.wav'))
    txts = list(d.glob('*.txt'))
    txt = read_text(str(txts[0])) if txts else ''
    chars = len(txt)
    tc = data.get('tricky_matches') or 0
    score = data.get('score') or (chars + 6*tc)
    for w in wavs:
      out.append({'bucket':bucket,'wav':str(w),'score':score,'chars':chars,'tricky':tc,'source':'batch'})
  return out

def scan_from_logs(voicenotes_root, day, tokens):
  log_path = os.path.join(voicenotes_root,'tx_logs',f'tx-{day}.jsonl') if day else None
  if not log_path or not os.path.isfile(log_path):
    logs = sorted(glob.glob(os.path.join(voicenotes_root,'tx_logs','tx-*.jsonl')))
    log_path = logs[-1] if logs else None
  if not log_path:
    return []
  out = []
  with open(log_path,'r',encoding='utf-8') as f:
    for line in f:
      try:
        o = json.loads(line)
      except Exception:
        continue
      if o.get('kind') != 'success':
        continue
      dur = float(o.get('duration_sec') or 0)
      if dur <= 1.0:
        bucket = 'micro'
      elif dur <= 10:
        bucket = 'short'
      elif dur <= 30:
        bucket = 'medium'
      else:
        bucket = 'long'
      wav = o.get('audio_used') or o.get('wav')
      if not wav or not os.path.isfile(wav):
        continue
      base = wav[:-4]
      txt = ''
      for ext in ('.txt','.en.txt'):
        p = base+ext
        if os.path.isfile(p):
          txt = read_text(p)
          break
      if not txt:
        # fall back to log transcript text if present
        txt = o.get('transcript') or ''
      chars = len(txt)
      tc = tricky_count(txt, tokens)
      score = chars + 6*tc
      out.append({'bucket':bucket,'wav':wav,'score':score,'chars':chars,'tricky':tc,'source':'logs'})
  return out

def pick_top(candidates, per_bucket):
  buckets = {}
  for c in candidates:
    b = c['bucket']
    buckets.setdefault(b, []).append(c)
  picks = {}
  for b, arr in buckets.items():
    arr.sort(key=lambda x: (x['source']!='batch', -x['score']))  # prefer batch fixtures, then score
    picks[b] = arr[:per_bucket]
  return picks

def symlink_baseline(picks, repo):
  short_sha = git_short_sha(repo)
  baseline_id = f"baseline_{time.strftime('%Y%m%d-%H%M')}{('_'+short_sha) if short_sha else ''}_complex"
  base_dir = os.path.join(repo,'tests','fixtures','baselines',baseline_id)
  Path(os.path.join(base_dir,'micro')).mkdir(parents=True, exist_ok=True)
  Path(os.path.join(base_dir,'short')).mkdir(parents=True, exist_ok=True)
  Path(os.path.join(base_dir,'medium')).mkdir(parents=True, exist_ok=True)
  Path(os.path.join(base_dir,'long')).mkdir(parents=True, exist_ok=True)
  for b, arr in picks.items():
    d = os.path.join(base_dir,b)
    for c in arr:
      wav = c['wav']
      dst = os.path.join(d, os.path.basename(wav))
      try:
        if os.path.lexists(dst): os.remove(dst)
        os.symlink(wav, dst)
        base = wav[:-4]
        for ext in ('.json','.txt','.en.txt'):
          side = base+ext
          if os.path.isfile(side):
            sdst = os.path.join(d, os.path.basename(side))
            if os.path.lexists(sdst): os.remove(sdst)
            os.symlink(side, sdst)
      except Exception:
        pass
  meta = {
    'baseline_id': baseline_id,
    'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    'complexity_weighted': True,
    'per_bucket': {b: len(arr) for b,arr in picks.items()},
  }
  with open(os.path.join(base_dir,'baseline.json'),'w',encoding='utf-8') as f:
    json.dump(meta, f, indent=2)
  return base_dir

if __name__ == '__main__':
  import argparse
  ap = argparse.ArgumentParser()
  ap.add_argument('--per-bucket', type=int, default=5)
  ap.add_argument('--day')
  ap.add_argument('--tricky', nargs='*', default=TRICKY_DEFAULT)
  args = ap.parse_args()

  repo = str(Path(__file__).resolve().parents[2])
  voicenotes = os.path.join(os.path.expanduser('~'),'Documents','VoiceNotes')
  samples_dir = os.path.join(repo,'tests','fixtures','samples_current')

  batch_candidates = scan_batch_fixtures(samples_dir)
  log_candidates = scan_from_logs(voicenotes, args.day, args.tricky)
  candidates = batch_candidates + log_candidates
  picks = pick_top(candidates, args.per_bucket)
  base_dir = symlink_baseline(picks, repo)
  print(json.dumps({'BASELINE_DIR': base_dir, 'counts': {b:len(arr) for b,arr in picks.items()}}, indent=2))

