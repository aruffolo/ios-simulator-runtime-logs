#!/usr/bin/env python3

import re
import sys
from pathlib import Path


PATTERNS = [
    ("errors", re.compile(r"\b(error|fatal|exception|crash|failed)\b", re.IGNORECASE)),
    ("warnings", re.compile(r"\bwarning\b", re.IGNORECASE)),
    ("high_signal", re.compile(r"[✅🚀📦🌐📡📄🛠️]")),
]


def summarize_file(path: Path):
    lines = path.read_text(errors="replace").splitlines()
    print(f"\n[{path.name}] lines={len(lines)}")
    for name, pattern in PATTERNS:
        matches = [line for line in lines if pattern.search(line)]
        print(f"- {name}: {len(matches)}")
        for line in matches[:5]:
            print(f"  {line[:300]}")


def main():
    if len(sys.argv) != 2:
      print("Usage: summarize_session.py <session_dir>")
      return 1
    session_dir = Path(sys.argv[1]).resolve()
    files = [p for p in (session_dir / "console.log", session_dir / "stream.log") if p.exists()]
    if not files:
      print("No console.log or stream.log found.")
      return 1
    print(f"Session: {session_dir}")
    for file in files:
      summarize_file(file)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
