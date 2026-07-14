#!/usr/bin/env bash
# article-composite.sh — highlight text in a news article, composite your video over it.
#
# Usage:
#   ./scripts/article-composite.sh <video.mp4> <url> "<phrase>" [--mode background|overlay] [project-slug]
#
# Modes:
#   background (default) — article fills the top of the frame, you appear below/over it.
#                          Best for: setting the scene, referencing the whole article.
#   overlay              — your footage plays normally; article screenshot slides in as
#                          a picture-in-picture panel with the highlighted text visible.
#                          Best for: mid-edit callouts without replacing your background.
#
# Examples:
#   ./scripts/article-composite.sh raw/take.mp4 https://example.com/story "key phrase"
#   ./scripts/article-composite.sh raw/take.mp4 https://example.com/story "key phrase" --mode overlay

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HF="$REPO_ROOT/tools/hyperframes"

VIDEO="${1:-}"
URL="${2:-}"
PHRASE="${3:-}"
MODE="background"
SLUG=""

# Parse remaining args
shift 3 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    *) SLUG="$1"; shift ;;
  esac
done

if [ -z "$VIDEO" ] || [ -z "$URL" ] || [ -z "$PHRASE" ]; then
  echo "Usage: $0 <video.mp4> <url> \"<phrase>\" [--mode background|overlay] [slug]"
  exit 1
fi

if [[ "$MODE" != "background" && "$MODE" != "overlay" ]]; then
  echo "ERROR: --mode must be 'background' or 'overlay'"
  exit 1
fi

# Resolve slug
if [ -z "$SLUG" ]; then
  SLUG=$(echo "$VIDEO" | sed -n 's|.*projects/\([^/]*\)/.*|\1|p')
  [ -z "$SLUG" ] && SLUG="$(date +%Y-%m-%d)-article"
fi

PROJECT="$REPO_ROOT/projects/$SLUG"
mkdir -p "$PROJECT/edit" "$PROJECT/compositions" "$PROJECT/renders"

VIDEO_ABS="$(cd "$(dirname "$VIDEO")" && pwd)/$(basename "$VIDEO")"
BASENAME="$(basename "$VIDEO" | sed 's/\.[^.]*$//')"
BG="$PROJECT/edit/background.png"
TRANSPARENT="$PROJECT/edit/${BASENAME}.transparent.webm"
COMP="$PROJECT/compositions/article-composite.html"
OUTPUT="$PROJECT/renders/article-composite.mp4"

echo ""
echo "=== article-composite: $BASENAME ==="
echo "  url:    $URL"
echo "  phrase: \"$PHRASE\""
echo "  mode:   $MODE"
echo "  slug:   $SLUG"
echo ""

# ── Step 1: Screenshot article with yellow highlight ──────────────────────────
echo "[1/4] Screenshotting article with highlight…"
node "$REPO_ROOT/scripts/article-highlight.js" "$URL" "$PHRASE" "$BG"

# ── Step 2: Remove background (background mode only) ─────────────────────────
if [ "$MODE" = "overlay" ]; then
  echo ""
  echo "[2/4] Overlay mode — skipping background removal (not needed)."
  # Point REL_VID at the original video for the composition
  REL_VID="../raw/$(basename "$VIDEO_ABS")"
elif [ -f "$TRANSPARENT" ]; then
  echo ""
  echo "[2/4] Transparent video already exists, skipping removal."
  echo "      Delete $TRANSPARENT to force re-run."
else
  echo ""
  echo "[2/4] Removing background from video…"
  echo "      (first run downloads ~168 MB u2net model)"
  (cd "$HF" && node packages/cli/dist/cli.js remove-background "$VIDEO_ABS" \
    --output "$TRANSPARENT" 2>&1) || \
  (cd "$HF" && npx hyperframes remove-background "$VIDEO_ABS" \
    --output "$TRANSPARENT" 2>&1)
  echo "      → $TRANSPARENT"
fi

# ── Step 3: Build HTML composition ───────────────────────────────────────────
echo ""
echo "[3/4] Writing composition…"

DURATION=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$VIDEO_ABS" 2>/dev/null | cut -d. -f1)
DURATION="${DURATION:-30}"

REL_BG="../edit/background.png"
REL_VID="../edit/${BASENAME}.transparent.webm"

if [ "$MODE" = "background" ]; then
cat > "$COMP" <<HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { width: 1080px; height: 1920px; overflow: hidden; background: #fff; }
  .frame { position: relative; width: 1080px; height: 1920px; }
  /* Article fills top 55% */
  .bg {
    position: absolute; top: 0; left: 0;
    width: 100%; height: 55%;
    object-fit: cover; object-position: center top;
  }
  .gradient {
    position: absolute; top: 45%; left: 0;
    width: 100%; height: 20%;
    background: linear-gradient(to bottom, transparent, rgba(0,0,0,0.8));
  }
  .base {
    position: absolute; top: 55%; left: 0;
    width: 100%; height: 45%; background: #111;
  }
  /* Transparent subject anchored to bottom */
  .subject {
    position: absolute; bottom: 0; left: 50%;
    transform: translateX(-50%);
    width: 100%; height: auto;
  }
</style>
</head>
<body>
<div class="clip frame" data-duration="${DURATION}">
  <div class="base"></div>
  <img class="bg" src="${REL_BG}" />
  <div class="gradient"></div>
  <video class="subject" src="${REL_VID}" autoplay muted playsinline></video>
</div>
</body>
</html>
HTML

else  # overlay mode — article slides in as a PiP panel over normal footage

cat > "$COMP" <<HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { width: 1080px; height: 1920px; overflow: hidden; background: #000; }
  .frame { position: relative; width: 1080px; height: 1920px; }
  /* Full-frame background video (original footage, not transparent) */
  .subject-full {
    position: absolute; inset: 0;
    width: 100%; height: 100%;
    object-fit: cover;
  }
  /* Article panel: top-right, 55% width, with rounded corners + shadow */
  .article-panel {
    position: absolute;
    top: 80px; right: 32px;
    width: 580px;
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 8px 40px rgba(0,0,0,0.6);
    opacity: 0;
    transform: translateY(-24px);
    animation: slideIn 0.4s ease 0.5s forwards;
  }
  .article-panel img {
    width: 100%; height: auto;
    display: block;
  }
  /* Source label under panel */
  .source-label {
    position: absolute;
    top: calc(80px + var(--panel-h, 420px) + 10px);
    right: 32px;
    color: rgba(255,255,255,0.6);
    font-family: -apple-system, sans-serif;
    font-size: 18px;
    opacity: 0;
    animation: fadeIn 0.3s ease 0.8s forwards;
  }
  @keyframes slideIn {
    to { opacity: 1; transform: translateY(0); }
  }
  @keyframes fadeIn {
    to { opacity: 1; }
  }
</style>
</head>
<body>
<div class="clip frame" data-duration="${DURATION}">
  <!-- In overlay mode the subject video plays at full frame (no bg removal needed) -->
  <video class="subject-full" src="${REL_VID}" autoplay muted playsinline></video>
  <div class="article-panel">
    <img src="${REL_BG}" />
  </div>
</div>
</body>
</html>
HTML

fi

echo "      → $COMP"

# ── Step 4: Render ────────────────────────────────────────────────────────────
echo ""
echo "[4/4] Rendering to MP4…"
(cd "$HF" && node packages/cli/dist/cli.js render "$COMP" \
  --output "$OUTPUT" \
  --width 1080 --height 1920 2>&1) || \
(cd "$HF" && npx hyperframes render "$COMP" \
  --output "$OUTPUT" \
  --width 1080 --height 1920 2>&1)

echo ""
echo "Done. → $OUTPUT"
echo ""
echo "To tweak layout or highlight, edit:"
echo "  $COMP           (composition)"
echo "  $BG             (re-run step 1 to re-screenshot)"
echo ""
echo "Re-render only (skip steps 1-3):"
echo "  cd tools/hyperframes && npx hyperframes render $COMP --output $OUTPUT --width 1080 --height 1920"
