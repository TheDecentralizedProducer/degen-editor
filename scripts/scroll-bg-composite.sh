#!/usr/bin/env bash
# scroll-bg-composite.sh — play a phone screen-recording as a scrolling 9:16
# background, with the subject cut out and overlaid on top.
#
# Source video is typically a portrait phone screen recording (e.g. 1180×2556).
# It gets cropped to 1080×1920 before compositing.
#
# Usage:
#   ./scripts/scroll-bg-composite.sh <subject.mp4> <scroll-recording.mp4> [project-slug]
#
# Options:
#   --audio both     Mix subject + scroll audio (default)
#   --audio subject  Keep only subject audio
#   --audio bg       Keep only scroll audio (ambient)
#   --no-remove-bg   Skip bg removal — use a pre-existing transparent.webm in edit/
#
# Example:
#   ./scripts/scroll-bg-composite.sh \
#     projects/2026-07-14-clip/raw/take.mp4 \
#     "/Users/iangrant/Downloads/Article Screen recording.MP4"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HF="$REPO_ROOT/tools/hyperframes"

SUBJECT="${1:-}"
SCROLL="${2:-}"
AUDIO_MODE="subject"   # default: voice only — scroll videos usually have no useful audio
SLUG=""
SKIP_REMOVE_BG=false

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --audio) AUDIO_MODE="$2"; shift 2 ;;
    --audio=*) AUDIO_MODE="${1#--audio=}"; shift ;;
    --no-remove-bg) SKIP_REMOVE_BG=true; shift ;;
    *) SLUG="$1"; shift ;;
  esac
done

if [ -z "$SUBJECT" ] || [ -z "$SCROLL" ]; then
  echo "Usage: $0 <subject.mp4> <scroll-recording.mp4> [--audio both|subject|bg] [slug]"
  exit 1
fi

# Resolve slug
if [ -z "$SLUG" ]; then
  SLUG=$(echo "$SUBJECT" | sed -n 's|.*projects/\([^/]*\)/.*|\1|p')
  [ -z "$SLUG" ] && SLUG="$(date +%Y-%m-%d)-scroll-composite"
fi

PROJECT="$REPO_ROOT/projects/$SLUG"
mkdir -p "$PROJECT/edit" "$PROJECT/renders"

SUBJECT_ABS="$(cd "$(dirname "$SUBJECT")" && pwd)/$(basename "$SUBJECT")"
SCROLL_ABS="$(cd "$(dirname "$SCROLL")" && pwd)/$(basename "$SCROLL")"
BASENAME="$(basename "$SUBJECT" | sed 's/\.[^.]*$//')"
TRANSPARENT="$PROJECT/edit/${BASENAME}.transparent.webm"
SCROLL_CROPPED="$PROJECT/edit/scroll_bg_1080x1920.mp4"
OUTPUT="$PROJECT/renders/scroll-bg-composite.mp4"

echo ""
echo "=== scroll-bg-composite ==="
echo "  subject: $SUBJECT_ABS"
echo "  scroll:  $SCROLL_ABS"
echo "  audio:   $AUDIO_MODE"
echo "  slug:    $SLUG"
echo ""

# ── Step 1: Crop scroll recording to 1080×1920 ───────────────────────────────
echo "[1/3] Cropping scroll recording to 1080×1920…"

# Get source dimensions
SRC_W=$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width -of csv=p=0 "$SCROLL_ABS" 2>/dev/null)
SRC_H=$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=height -of csv=p=0 "$SCROLL_ABS" 2>/dev/null)

echo "      source: ${SRC_W}×${SRC_H}"

# Crop to 9:16 from center, scale to 1080×1920
# Skip re-encoding if already correct size
if [ "${SRC_W}x${SRC_H}" = "1080x1920" ]; then
  SCROLL_CROPPED="$SCROLL_ABS"
  echo "      already 1080×1920, using as-is."
else
  CROP_W=$SRC_W
  CROP_H=$(( CROP_W * 16 / 9 ))
  if [ $CROP_H -gt $SRC_H ]; then
    CROP_H=$SRC_H
    CROP_W=$(( CROP_H * 9 / 16 ))
  fi
  OFF_X=$(( (SRC_W - CROP_W) / 2 ))
  OFF_Y=$(( (SRC_H - CROP_H) / 4 ))  # bias slightly toward top (avoid nav bar)

  ffmpeg -y -i "$SCROLL_ABS" \
    -vf "crop=${CROP_W}:${CROP_H}:${OFF_X}:${OFF_Y},scale=1080:1920:flags=lanczos" \
    -c:v libx264 -preset fast -crf 18 -an \
    "$SCROLL_CROPPED" 2>&1 | grep -E "frame|fps|time|error" || true
  echo "      → $SCROLL_CROPPED"
fi

# ── Step 2: Remove background from subject ────────────────────────────────────
if $SKIP_REMOVE_BG; then
  echo ""
  echo "[2/3] --no-remove-bg set, looking for existing transparent webm…"
  if [ ! -f "$TRANSPARENT" ]; then
    echo "ERROR: $TRANSPARENT not found. Run without --no-remove-bg first."
    exit 1
  fi
elif [ -f "$TRANSPARENT" ]; then
  echo ""
  echo "[2/3] Transparent video exists, skipping removal."
else
  echo ""
  echo "[2/3] Removing background from subject…"
  (cd "$HF" && node packages/cli/dist/cli.js remove-background "$SUBJECT_ABS" \
    --output "$TRANSPARENT" 2>&1) || \
  (cd "$HF" && npx hyperframes remove-background "$SUBJECT_ABS" \
    --output "$TRANSPARENT" 2>&1)
  echo "      → $TRANSPARENT"
fi

# ── Step 3: Composite ─────────────────────────────────────────────────────────
echo ""
echo "[3/3] Compositing subject over scroll background…"

case "$AUDIO_MODE" in
  subject)
    ffmpeg -y \
      -stream_loop -1 -i "$SCROLL_CROPPED" \
      -i "$TRANSPARENT" \
      -filter_complex "[0:v][1:v]overlay=0:0[out]" \
      -map "[out]" -map "1:a?" \
      -c:v libx264 -preset slow -crf 18 \
      -shortest "$OUTPUT" 2>&1 | grep -E "frame|fps|time|error" || true
    ;;
  bg)
    ffmpeg -y \
      -stream_loop -1 -i "$SCROLL_CROPPED" \
      -i "$TRANSPARENT" \
      -filter_complex "[0:v][1:v]overlay=0:0[out]" \
      -map "[out]" -map "0:a?" \
      -c:v libx264 -preset slow -crf 18 \
      -shortest "$OUTPUT" 2>&1 | grep -E "frame|fps|time|error" || true
    ;;
  both)
    ffmpeg -y \
      -stream_loop -1 -i "$SCROLL_CROPPED" \
      -i "$TRANSPARENT" \
      -filter_complex \
        "[0:v][1:v]overlay=0:0[out];
         [0:a]volume=0.2[bg_a];
         [bg_a][1:a]amix=inputs=2:duration=shortest[a]" \
      -map "[out]" -map "[a]" \
      -c:v libx264 -preset slow -crf 18 \
      -shortest "$OUTPUT" 2>&1 | grep -E "frame|fps|time|error" || true
    ;;
esac

echo ""
echo "Done. → $OUTPUT"
