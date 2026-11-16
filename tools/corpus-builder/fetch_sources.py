#!/usr/bin/env python3
"""Downloads and caches upstream linguistic datasets into raw_data/."""

import argparse
import urllib.error
import urllib.request
from pathlib import Path

RAW_DIR = Path(__file__).parent / "raw_data"

CORE_SOURCES = {
    "JMdict_e.gz": [
        "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz",
    ],
    "kanjidic2.xml.gz": [
        "http://ftp.edrdg.org/pub/Nihongo/kanjidic2.xml.gz",
    ],
    "kanjivg.xml.gz": [
        "https://github.com/KanjiVG/kanjivg/releases/download/r20220427/kanjivg-20220427.xml.gz",
    ],
    "kanjium_accents.txt": [
        "https://raw.githubusercontent.com/mifunetoshiro/kanjium/master/data/source_files/raw/accents.txt",
    ],
    "tatoeba_jpn_eng.tsv.bz2": [
        "https://downloads.tatoeba.org/exports/per_language/jpn/jpn-eng_links.tsv.bz2",
    ],
    "tatoeba_jpn.tsv.bz2": [
        "https://downloads.tatoeba.org/exports/per_language/jpn/jpn_sentences.tsv.bz2",
    ],
    "tatoeba_eng.tsv.bz2": [
        "https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2",
    ],
}

OPTIONAL_SOURCES = {
    "JMnedict.xml.gz": [
        "http://ftp.edrdg.org/pub/Nihongo/JMnedict.xml.gz",
    ],
}

def download_with_fallback(urls: list[str], dest: Path) -> bool:
    if dest.exists() and dest.stat().st_size > 0:
        print(f"[skip] {dest.name} already exists ({dest.stat().st_size / 1_048_576:.1f} MB)")
        return True
    for url in urls:
        try:
            print(f"[fetch] {url} -> {dest.name} ...")
            req = urllib.request.Request(url, headers={"User-Agent": "DaiJishow-CorpusBuilder/1.1"})
            with urllib.request.urlopen(req, timeout=90) as resp, open(dest, "wb") as out:
                total = 0
                while True:
                    chunk = resp.read(65536)
                    if not chunk:
                        break
                    out.write(chunk)
                    total += len(chunk)
            print(f"[done]  {dest.name} ({total / 1_048_576:.1f} MB)")
            return True
        except (urllib.error.URLError, TimeoutError) as exc:
            print(f"[warn]  Failed {url}: {exc}")
            if dest.exists():
                dest.unlink()
    return False

def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch upstream Dai-Jishow corpora")
    parser.add_argument("--include-names", action="store_true", help="Also download JMnedict (~35 MB gz)")
    args = parser.parse_args()

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for filename, urls in CORE_SOURCES.items():
        download_with_fallback(urls, RAW_DIR / filename)

    if args.include_names:
        for filename, urls in OPTIONAL_SOURCES.items():
            download_with_fallback(urls, RAW_DIR / filename)

if __name__ == "__main__":
    main()
