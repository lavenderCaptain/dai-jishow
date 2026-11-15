# Dai-Jishow Corpus Builder (`tools/corpus-builder`)

Offline ETL compiler that fetches open linguistic corpora and builds `daijishow.db`.
Uses only the Python 3 standard library (no mandatory `pip` dependencies).

## Quick Start

### 1. Instant Smoke-Test Build (5 seconds, offline)
Generates a realistic mini `daijishow.db` with sample entries (`称`, `称賛`, `愛称`, `食べる`, `猫の手も借りたい`, `開く`/`開ける`) so you can immediately test SQLite queries and start writing the C++20 `core/` engine:

```bash
python3 tools/corpus-builder/build_corpus.py --sample --out build/daijishow.db
```

### 2. Full Production Corpus Build
Downloads JMdict, KANJIDIC2, KanjiVG, and Tatoeba into `tools/corpus-builder/raw_data/` and compiles the full database:

```bash
python3 tools/corpus-builder/fetch_sources.py
python3 tools/corpus-builder/build_corpus.py --out build/daijishow.db
```
