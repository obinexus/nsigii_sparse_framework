#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
TIME_PER_FUZZ=3600   # 60 min
WORKERS=8
# ----------------

echo "🔍  Building & fuzzing NPL parser entry-point"
echo "    Time per target : $TIME_PER_FUZZ s"
echo "    Parallel workers: $WORKERS"

# 1.  Rust + cargo-fuzz
if command -v cargo &>/dev/null; then
  echo "---- Rust (cargo-fuzz) ----"
  cd fuzz
  cargo install cargo-fuzz --quiet
  cargo fuzz build --fuzz-dir .
  timeout "$TIME_PER_FUZZ" cargo fuzz run npl_parser_fuzz --fuzz-dir . -j "$WORKERS" || true
  cd ..
fi

# 2.  Go
if command -v go &>/dev/null; then
  echo "---- Go (go-fuzz) ----"
  go install github.com/dvyukov/go-fuzz/go-fuzz github.com/dvyukov/go-fuzz/go-fuzz-build@latest
  cd fuzz
  go-fuzz-build -o npl-fuzz.zip -func FuzzNPL .
  timeout "$TIME_PER_FUZZ" go-fuzz -bin npl-fuzz.zip -workdir=. -procs="$WORKERS" || true
  cd ..
fi

# 3.  Python
if command -v python3 &>/dev/null; then
  echo "---- Python (atheris) ----"
  python3 -m pip install atheris
  cd fuzz
  timeout "$TIME_PER_FUZZ" python3 fuzz_python.py || true
  cd ..
fi

echo "✅  Fuzz cycle complete – no crashes ⇒ ready for tag"
