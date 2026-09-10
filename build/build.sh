#!/usr/bin/env bash
#
# Full build: freeze the backend, collect binaries, bundle the installer.
#
# Run from the project root:  ./build/build.sh
#
# Produces a single installer per platform in src-tauri/target/release/bundle/.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

# Tauri names sidecars <name>-<target-triple>, and refuses to bundle one
# whose triple does not match the host.
TRIPLE=$(rustc -vV | awk '/^host:/ {print $2}')
echo "target triple: $TRIPLE"

# Homebrew installs llama-server read-only and cp preserves the mode, so a
# leftover from the previous build cannot be overwritten. Start clean.
BIN_DIR="src-tauri/binaries"
rm -rf "$BIN_DIR"
mkdir -p "$BIN_DIR"

# ---------------------------------------------------------------- 1. backend
echo
echo "==> freezing the backend"
.venv/bin/python -m pip install --quiet pyinstaller
.venv/bin/python -m PyInstaller --noconfirm --clean \
    --distpath build/dist --workpath build/work \
    build/backend.spec

# One-file mode puts the executable directly in dist/, not in a subfolder.
FROZEN="build/dist/workbench-backend"
[ -f "$FROZEN" ] || { echo "freeze failed — no $FROZEN"; exit 1; }

# ---------------------------------------------------------------- 2. sidecars
echo
echo "==> collecting sidecars"

cp "$FROZEN" "$BIN_DIR/workbench-backend-$TRIPLE"
chmod +x "$BIN_DIR/workbench-backend-$TRIPLE"

LLAMA=$(command -v llama-server || true)
if [ -z "$LLAMA" ]; then
    echo "llama-server not on PATH — install it (brew install llama.cpp) before building"
    exit 1
fi
LLAMA=$(readlink -f "$LLAMA" 2>/dev/null || python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "$LLAMA")
cp "$LLAMA" "$BIN_DIR/llama-server-$TRIPLE"
chmod +w "$BIN_DIR/llama-server-$TRIPLE"
chmod +x "$BIN_DIR/llama-server-$TRIPLE"

# llama-server is dynamically linked against libllama, libggml and friends.
# Copying only the executable produces a binary that cannot start, so the
# shared libraries ship as resources and the backend points dyld at them.
LIB_SRC="$(dirname "$LLAMA")/../lib"
LIB_DST="src-tauri/resources/lib"
rm -rf "$LIB_DST"
mkdir -p "$LIB_DST"
if [ -d "$LIB_SRC" ]; then
    find "$LIB_SRC" -maxdepth 1 \( -name "*.dylib" -o -name "*.so*" -o -name "*.dll" \) \
        -exec cp {} "$LIB_DST/" \; 2>/dev/null || true
    chmod -R u+w "$LIB_DST"
fi
COUNT=$(ls -1 "$LIB_DST" 2>/dev/null | wc -l | tr -d " ")
echo "    bundled $COUNT llama.cpp shared libraries"
if [ "$COUNT" = "0" ]; then
    echo "    WARNING: no shared libraries found in $LIB_SRC"
    echo "    llama-server may fail to start in the packaged app"
fi

# ---------------------------------------------------------------- 3. frontend
echo
echo "==> building the frontend"
npm --prefix web ci --silent || npm --prefix web install --silent
npm --prefix web run build

# ---------------------------------------------------------------- 4. installer
echo
echo "==> bundling"
cd src-tauri
cargo tauri build

echo
echo "done. installers are in src-tauri/target/release/bundle/"
