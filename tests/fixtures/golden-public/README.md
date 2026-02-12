# Golden Public Test Fixtures

Synthetic audio fixtures for CI benchmark testing. These are committed to the repo (unlike `golden/` which contains personal recordings).

## Structure

```
golden-public/
  short/   - 4 clips, <21s  (tests fast-model path)
  medium/  - 4 clips, 21-45s (tests model selection threshold)
  long/    - 4 clips, >45s  (tests accurate-model path)
```

Each fixture is a pair:
- `name.wav` - 16kHz mono PCM audio generated with macOS `say` + `ffmpeg`
- `name.txt` - Expected transcript (ground truth)

## Regenerating

```bash
scripts/utilities/generate_golden_public.sh
```

## Vocabulary Hints

When run locally with VoxCompose installed, the benchmark loads vocabulary hints from `~/.config/voxcompose/vocabulary.txt`. CI runs without VoxCompose, using only the static prompt. This means local and CI accuracy numbers may differ slightly. The committed baseline in `tests/results/baselines/` notes which environment produced it.

## Limitations

These fixtures use synthesized speech (macOS `say`). They test the pipeline end-to-end but do not represent real-world accuracy (accents, noise, fast speech). Use `tests/fixtures/golden/` with real recordings for local accuracy testing.
