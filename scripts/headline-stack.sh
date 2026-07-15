#!/usr/bin/env bash
# headline-stack.sh — animate 2–4 article headlines staggered in, then out in order.
#
# Each headline slides up and fades in, offset horizontally for visual rhythm.
# They hold briefly, then fade out in the order they appeared.
# Output: a transparent WebM overlay (or opaque MP4 if --opaque).
#
# Usage:
#   ./scripts/headline-stack.sh [options] "Headline 1" "Headline 2" "Headline 3"
#
# Options:
#   --slug <slug>       Project slug (default: auto from date)
#   --hold 1.5          Seconds each headline holds before exit (default: 1.5)
#   --stagger 0.5       Seconds between headline entrances (default: 0.5)
#   --opaque            Render with dark background (default: transparent WebM)
#   --source <logo.png> Optional source/outlet logo shown above headlines
#
# Example:
#   ./scripts/headline-stack.sh \
#     --slug 2026-07-14-clip \
#     "State AGs move to block Paramount-Warner merger" \
#     "Studios face $110B antitrust battle" \
#     "DOJ opens parallel investigation"

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HF="$REPO_ROOT/tools/hyperframes"

SLUG=""
HOLD="1.5"
STAGGER="0.5"
OPAQUE=false
SOURCE_LOGO=""
HEADLINES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)    SLUG="$2";         shift 2 ;;
    --hold)    HOLD="$2";         shift 2 ;;
    --stagger) STAGGER="$2";      shift 2 ;;
    --opaque)  OPAQUE=true;       shift ;;
    --source)  SOURCE_LOGO="$2";  shift 2 ;;
    *) HEADLINES+=("$1");         shift ;;
  esac
done

if [ ${#HEADLINES[@]} -lt 1 ]; then
  echo "Usage: $0 [--slug <slug>] [--hold 1.5] [--stagger 0.5] \"Headline 1\" \"Headline 2\" ..."
  exit 1
fi
if [ ${#HEADLINES[@]} -gt 4 ]; then
  echo "ERROR: max 4 headlines"
  exit 1
fi

[ -z "$SLUG" ] && SLUG="$(date +%Y-%m-%d)-headlines"
PROJECT="$REPO_ROOT/projects/$SLUG"
mkdir -p "$PROJECT/compositions" "$PROJECT/renders"

N=${#HEADLINES[@]}
STAGGER_MS=$(echo "$STAGGER * 1000" | bc | cut -d. -f1)
HOLD_MS=$(echo "$HOLD * 1000" | bc | cut -d. -f1)

# Each headline: enters at i*stagger, exits at i*stagger + hold
# Total duration: (N-1)*stagger + hold + 0.5s tail
TOTAL_S=$(echo "$STAGGER * ($N - 1) + $HOLD + 0.5" | bc)
TOTAL_MS=$(echo "$TOTAL_S * 1000" | bc | cut -d. -f1)

COMP="$PROJECT/compositions/headline-stack.html"

if $OPAQUE; then
  OUTPUT="$PROJECT/renders/headline-stack.mp4"
  BG_STYLE="background: linear-gradient(180deg, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.6) 100%);"
  RENDER_ARGS="--output $OUTPUT --width 1080 --height 1920"
else
  OUTPUT="$PROJECT/renders/headline-stack.webm"
  BG_STYLE="background: transparent;"
  RENDER_ARGS="--output $OUTPUT --width 1080 --height 1920"
fi

echo ""
echo "=== headline-stack ==="
echo "  headlines: ${#HEADLINES[@]}"
echo "  stagger:   ${STAGGER}s"
echo "  hold:      ${HOLD}s"
echo "  duration:  ${TOTAL_S}s"
echo "  output:    $OUTPUT"
echo ""

# ── Build HTML ────────────────────────────────────────────────────────────────
# Horizontal offsets alternate left/right for visual rhythm
OFFSETS=(0 40 -20 60)
# Colors cycle through a warm palette
COLORS=("#FFD700" "#FFFFFF" "#F4A623" "#FFFFFF")

# Build headline CSS + HTML blocks
HL_CSS=""
HL_HTML=""

for i in "${!HEADLINES[@]}"; do
  idx=$i
  HL="${HEADLINES[$i]}"
  OFFSET="${OFFSETS[$((idx % 4))]}"
  COLOR="${COLORS[$((idx % 4))]}"
  ENTER_MS=$(echo "$idx * $STAGGER_MS" | bc | cut -d. -f1)
  EXIT_MS=$(echo "$ENTER_MS + $HOLD_MS" | bc | cut -d. -f1)
  DELAY_EXIT_MS=$(echo "$EXIT_MS" | bc | cut -d. -f1)

  HL_CSS+="
  .hl-${idx} {
    opacity: 0;
    transform: translateY(24px);
    animation:
      hl-in 0.35s ease ${ENTER_MS}ms forwards,
      hl-out 0.25s ease ${DELAY_EXIT_MS}ms forwards;
  }"

  HL_HTML+="
    <div class=\"headline hl-${idx}\" style=\"margin-left:${OFFSET}px;\">
      <span class=\"bar\" style=\"background:${COLOR};\"></span>
      <p style=\"color:${COLOR};\">${HL}</p>
    </div>"
done

cat > "$COMP" <<HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    width: 1080px; height: 1920px;
    overflow: hidden;
    ${BG_STYLE}
    font-family: -apple-system, 'SF Pro Display', 'Helvetica Neue', sans-serif;
  }

  .stage {
    position: absolute;
    bottom: 280px;
    left: 64px;
    right: 64px;
    display: flex;
    flex-direction: column;
    gap: 28px;
  }

  .source-label {
    font-size: 22px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: rgba(255,255,255,0.5);
    margin-bottom: 8px;
    opacity: 0;
    animation: hl-in 0.3s ease 0ms forwards;
  }

  .headline {
    display: flex;
    align-items: flex-start;
    gap: 16px;
  }

  .bar {
    flex-shrink: 0;
    width: 5px;
    height: 100%;
    min-height: 28px;
    border-radius: 3px;
    margin-top: 4px;
  }

  .headline p {
    font-size: 36px;
    font-weight: 700;
    line-height: 1.25;
    letter-spacing: -0.01em;
    text-shadow: 0 2px 12px rgba(0,0,0,0.6);
  }

  @keyframes hl-in {
    from { opacity: 0; transform: translateY(20px); }
    to   { opacity: 1; transform: translateY(0); }
  }
  @keyframes hl-out {
    from { opacity: 1; transform: translateY(0); }
    to   { opacity: 0; transform: translateY(-12px); }
  }

  ${HL_CSS}
</style>
</head>
<body>
<div class="clip" data-duration="${TOTAL_S}">
  <div class="stage">
    $([ -n "$SOURCE_LOGO" ] && echo "<div class=\"source-label\">$(basename "$SOURCE_LOGO" | sed 's/\.[^.]*$//')</div>" || true)
    ${HL_HTML}
  </div>
</div>
</body>
</html>
HTML

echo "[1/2] Composition written → $COMP"
echo ""
echo "[2/2] Rendering…"

(cd "$HF" && node packages/cli/dist/cli.js render "$COMP" \
  $RENDER_ARGS 2>&1 | grep -E "render|frame|error|done|✓" || true) || \
(cd "$HF" && npx hyperframes render "$COMP" \
  $RENDER_ARGS 2>&1 | grep -E "render|frame|error|done|✓" || true)

echo ""
echo "Done. → $OUTPUT"
echo ""
if ! $OPAQUE; then
  echo "To overlay on your cut:"
  echo "  ffmpeg -i your_cut.mp4 -i $OUTPUT \\"
  echo "    -filter_complex \"[0:v][1:v]overlay=0:0:enable='between(t,START,END)'\" \\"
  echo "    -c:v libx264 renders/with-headlines.mp4"
fi
