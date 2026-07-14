#!/usr/bin/env bash
# Video studio bootstrap — idempotent, run any time to update or repair.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
TOOLS="$REPO_ROOT/tools"

# ── 1. video-use (Python / uv) ────────────────────────────────────────────────
VIDEO_USE="$TOOLS/video-use"
if [ -d "$VIDEO_USE/.git" ]; then
  echo "[video-use] pulling latest…"
  git -C "$VIDEO_USE" pull --ff-only
else
  echo "[video-use] cloning…"
  mkdir -p "$TOOLS"
  git clone https://github.com/browser-use/video-use "$VIDEO_USE"
fi

echo "[video-use] installing Python deps…"
if command -v uv >/dev/null 2>&1; then
  (cd "$VIDEO_USE" && uv sync)
else
  (cd "$VIDEO_USE" && pip install -e .)
fi

# ── 2. hyperframes (Node / Bun) ───────────────────────────────────────────────
HYPERFRAMES="$TOOLS/hyperframes"
if [ -d "$HYPERFRAMES/.git" ]; then
  echo "[hyperframes] pulling latest…"
  git -C "$HYPERFRAMES" pull --ff-only
else
  echo "[hyperframes] cloning (includes git-lfs assets)…"
  command -v git-lfs >/dev/null 2>&1 || { echo "ERROR: git-lfs not found — run: brew install git-lfs && git lfs install"; exit 1; }
  git clone https://github.com/heygen-com/hyperframes "$HYPERFRAMES"
fi

if ! command -v bun >/dev/null 2>&1; then
  echo "[hyperframes] bun not found — installing via npm…"
  npm install -g bun
fi

echo "[hyperframes] installing Node deps…"
(cd "$HYPERFRAMES" && bun install)

echo "[hyperframes] building packages…"
(cd "$HYPERFRAMES" && bun run build 2>&1 | tail -5)

# ── 3. ffmpeg check ───────────────────────────────────────────────────────────
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg not found."
  echo "  macOS:  brew install ffmpeg"
  echo "  Ubuntu: sudo apt-get install -y ffmpeg"
  exit 1
fi
echo "[ffmpeg] $(ffmpeg -version 2>&1 | head -1)"

# ── 4. ElevenLabs API key check ───────────────────────────────────────────────
DOTENV="$VIDEO_USE/.env"
if [ -n "${ELEVENLABS_API_KEY:-}" ]; then
  echo "[elevenlabs] key found in environment."
elif grep -q '^ELEVENLABS_API_KEY=..' "$DOTENV" 2>/dev/null; then
  echo "[elevenlabs] key found in $DOTENV."
else
  echo ""
  echo "WARNING: ELEVENLABS_API_KEY not set."
  echo "  Set it in tools/video-use/.env:"
  echo "    echo 'ELEVENLABS_API_KEY=your_key' > $DOTENV && chmod 600 $DOTENV"
  echo "  Or export it in your shell before editing."
fi

# ── 5. Smoke tests ────────────────────────────────────────────────────────────
echo ""
echo "[verify] video-use helpers…"
(cd "$VIDEO_USE" && uv run python helpers/timeline_view.py --help >/dev/null) && echo "  ✓ timeline_view.py"

echo "[verify] ffprobe…"
ffprobe -version 2>&1 | head -1 | grep -q ffprobe && echo "  ✓ ffprobe"

echo ""
echo "Setup complete. Drop footage into projects/<YYYY-MM-DD-slug>/raw/ and say 'edit this'."
