#!/usr/bin/env python3
"""
Punctuate and capitalize ASR text using deepmultilingualpunctuation.

Usage:
  echo "raw asr text" | python3 scripts/punctuate.py
  python3 scripts/punctuate.py --file input.txt

Outputs processed text to stdout. Exits 0 on success, nonzero on error.
"""
import sys
import argparse

try:
    from deepmultilingualpunctuation import PunctuationModel
except Exception as e:
    sys.stderr.write("ERROR: deepmultilingualpunctuation not available. Install with: pipx install deepmultilingualpunctuation\n")
    sys.exit(2)

_model = None

def get_model():
    global _model
    if _model is None:
        _model = PunctuationModel()
    return _model


def main():
    parser = argparse.ArgumentParser(description="Restore punctuation and casing for ASR text")
    parser.add_argument("-f", "--file", dest="file", help="Input file (defaults to stdin)")
    args = parser.parse_args()

    try:
        if args.file:
            with open(args.file, "r", encoding="utf-8") as fh:
                text = fh.read()
        else:
            text = sys.stdin.read()
    except Exception as e:
        sys.stderr.write(f"ERROR: failed to read input: {e}\n")
        return 3

    text = (text or "").strip()
    if not text:
        # Pass through empty
        print("", end="")
        return 0

    try:
        model = get_model()
        out = model.restore_punctuation(text)
        # Avoid adding extra newline
        sys.stdout.write(out)
        return 0
    except Exception as e:
        sys.stderr.write(f"ERROR: punctuator failed: {e}\n")
        return 4


if __name__ == "__main__":
    sys.exit(main())
