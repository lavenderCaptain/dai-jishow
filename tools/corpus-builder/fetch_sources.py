#!/usr/bin/env python3
"""Downloads and caches upstream linguistic datasets into raw_data/."""

import argparse
import os
import urllib.request
from pathlib import Path

RAW_DIR = Path(__file__).parent / "raw_data"

SOURCES = {
    "JMdict_e.gz": "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz",
    "kanjidic2.xml.gz": "http://ftp.edrdg.org/pub/Nihongo/kanjidic2.xml.gz",
    "kanjivg.xml.gz": "https://github.com/KanjiVG/kanjivg/releases/download/r20220427/kanjivg-20220427.xml.gz",
    "JMnedict.xml.gz": "http://ftp.edrdg.org/pub/Nihongo/JMnedict.xml.gz",
}

def download_file(url: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        print(f"[skip] {dest.name} already exists ({dest.stat().st_size / 1_048_576:.1f} MB)")
        return
    print(f"[fetch] {url} -> {dest.name} ...")
    req = urllib.request.Request(url, headers={"User-Agent": "DaiJishow-CorpusBuilder/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp, open(dest, "wb") as out:
        total = 0
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            out.write(chunk)
            total += len(chunk)
    print(f"[done]  {dest.name} ({total / 1_048_576:.1f} MB)")

def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch upstream Dai-Jishow corpora")
    parser.add_argument("--include-names", action="store_true", help="Also download JMnedict (~35 MB gz)")
    args = parser.parse_args()

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for filename, url in SOURCES.items():
        if filename == "JMnedict.xml.gz" and not args.include_names:
            continue
        download_file(url, RAW_DIR / filename)

if __name__ == "__main__":
    main()
