# Ian Grant — Reel Production Master Prompt

Copy-paste this at the start of any new editing session.

---

## WHO I AM

Ian Grant (@greenlit_xyz), founder of Greenlit (greenlit.io) — AI back-office for filmmakers.
I make 9:16 vertical commentary reels about the indie film business (TikTok / Instagram Reels / YouTube Shorts).
Talking head to camera, 1–3 min, direct industry-insider POV. Audience = indie producers, directors, dealmakers.

---

## WHAT I WANT IN ONE SHOT

**Edit this footage into a finished reel that looks exactly like my style — first try, no back and forth.**

My style checklist (hit every one):

### Pacing
- Cut ALL fillers: "um", "uh", "like", "you know", false starts, retakes
- If I look like I'm searching for my next word — cut it
- Aggressive pacing. If in doubt, cut it.

### Captions — SORA / Instagram Reels style (background box, no outline)
- Word by word, 1 word at a time
- UPPERCASE, bold, BIG (font size 90 in ASS = XL on 1080×1920)
- Font: **Montserrat ExtraBold** (fallback: Lato Bold)
- Style: **background box** (BorderStyle=4) — NOT outline captions
- Context words (prev/next): **white box, black text** (light studio default)
- Current word: **Greenlit Blue box (#1791f6), white text**
- Visibility rule: light wall → white box/black text; dark scene → black box/white text
- Position: y≈1340 (MarginV=580 in ASS), centered — Position C
- Burn LAST in the pipeline — after all graphic overlays
- Font size guide: 80=large, 90=XL (default), 100=XXL

### Hook text (opening 3 seconds)
- Short punchy line (3–6 words, provocative question or surprising fact)
- White pill-shaped background, TikTok Sans 800
- Top of frame, y≈290
- Transparent background
- Pop-in animation (scale 0.94→1, back.out ease)
- Applied as Pass 2 PNG overlay (not HyperFrames)

### Hook Cover Image (for social upload "Cover" field)
- Extract a frame from the PiP segment (or best talking-head frame if no PiP)
- Composite the hook text PNG over it as a static image
- No render needed — this is a screengrab saved to `edit/verify/hook/cover.png`
- Use when: reel doesn't start with PiP, or I need a thumbnail showing the article + hook

### Motion graphics — always suggest these after approved cut
After every cut, propose 2–3 of these:
1. **Greenlit stat card** — y:1310, 1020×230px, #0f172a bg, gradient accent bar (#1791f6→#30c4d7→#4bf1b7)
2. **Article screenshot card** — find and screenshot the article I reference, Playwright + yellow highlight injection
3. **Pull-quote or concept text** — kinetic, white pill or ink background

### PiP (article as background)
Use `scripts/pip-composite.py` with birefnet-general model.
- Ian: 640px wide, centered horizontally, 60px from bottom of frame
- Source must be base cut only — never a file with overlays/subs baked in
- Splice with trim+concat, never overlay+enable=
- Audio always from base cut (pip clips have no audio)

### Safe zones (check EVERY reel before compositing)
```
Platform dead zones:
  Top:    y < 120   (back button, username)
  Bottom: y > 1560  (likes, comments, share, progress bar)
  Right:  x > 1000  (action button column)

My overlay zones:
  Hook text:    y 80–300
  Stat/article: y 1310–1540  ← lower card zone
  Captions:     y ≈ 1340
```
Extract frames at 2s, 10s, 22s, 33s and draw the safe-zone grid before building graphics.

---

## TOOLCHAIN

```
render.py:      tools/video-use/helpers/render.py  (patched — uses ffmpeg-full, format=auto)
ffmpeg:         /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg  (libass + ProRes 4444 alpha)
HyperFrames:    npx --yes hyperframes render . --format mov  (ALWAYS --format mov for alpha)
PiP:            uv run python scripts/pip-composite.py
Article SS:     scripts/node_modules playwright (or scripts/article-composite.sh)
Font:           Lato Bold → /tmp/Lato-Bold.ttf (copy before libass burn)
```

---

## TWO-PASS RENDER PIPELINE

```
Pass 1 — render.py:
  EDL cuts + night_shoot grade + HyperFrames MOV overlays (Greenlit cards, PiP splice)

Pass 2 — ffmpeg-full:
  Hook PNG composite (enable='between(t,0,3)':format=auto)
  → ASS karaoke subtitles burned LAST (libass)
  → output: renders/final.mp4
```

---

## PROJECT STRUCTURE

```
projects/YYYY-MM-DD-slug/
  raw/              ← drop footage here
  edit/
    base.mp4        ← clean cut (no overlays)
    edl.json
    captions.ass
    verify/
      ig-safezone/  ← safe-zone frame grabs (run every reel)
      hook/         ← hook overlay previews + cover.png
      article/      ← article screenshots
      overlays/     ← composite previews before render
  compositions/     ← HyperFrames HTML files
  renders/
    final.mp4
    .final          ← write ONLY when Ian explicitly signs off
  brief/
    approved-script.md
```

---

## BRAND COLORS

```
Blue:  #1791f6  (primary, current-word highlight)
Cyan:  #30c4d7
Mint:  #4bf1b7
Ink:   #0f172a  (card backgrounds)
Gradient: #1791f6 → #30c4d7 → #4bf1b7 (left→right)
```

---

## APPROVAL GATES (do not skip)

1. **Show proposed cut list** — wait for "go" / "do it" / "ok"
2. **Show safe-zone frame grabs** — confirm no graphics in dead zones
3. **Show static preview frame** for every overlay before compositing
4. **Mark final** (`renders/.final`) only when I say the reel is approved

---

## HOW TO START

Drop footage in `raw/`, then just say **"edit this"** — the video-studio skill takes it from there.

Or for a specific reel:
```
"Edit this. 90s version. Article: [URL]. Hook: [your hook text]."
```

---

## WHAT NOT TO DO

- Do not render before I approve the cut list
- Do not downscale footage
- Do not add music, color effects, or transitions unless asked (night_shoot grade is the default)
- Do not commit .env, raw footage, or final renders
- Do not write renders/.final until I explicitly sign off
- Do not use HyperFrames --format mp4 or --format webm (alpha will break)
- Do not use overlay+enable= for PiP splice (use trim+concat)
- Do not use u2net model for background removal (use birefnet-general)
