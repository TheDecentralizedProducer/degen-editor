# Degen Editor

Personal AI video-editing studio for Ian Grant — orchestrated by Claude Code.

Transcript-first editing, motion graphics, and overlay automation for 9:16 vertical content. Drop footage, describe the edit, approve the cut, render.

---

## Quickstart

```bash
./setup.sh                          # install/update all tools
./scripts/new-project.sh my-clip    # scaffold project folders
# drop footage into projects/YYYY-MM-DD-my-clip/raw/
claude                              # then say: "edit this"
```

---

## Scripts

### Project

| Script | What it does |
|--------|-------------|
| `./setup.sh` | Clone/update video-use and hyperframes, install all deps, verify ffmpeg + ElevenLabs key. Idempotent. |
| `./scripts/new-project.sh <slug>` | Scaffold `projects/YYYY-MM-DD-slug/` with all subfolders including the full `verify/` tree. Date-prefixes automatically. |

---

### Cutting

| Script | What it does |
|--------|-------------|
| `./scripts/render.py` | Patched render helper (use in place of `tools/video-use/helpers/render.py`). Handles ProRes 4444 alpha and `format=auto` overlay compositing. Copy after setup: `cp scripts/render.py tools/video-use/helpers/render.py` |

---

### Overlays — Article

| Script | What it does |
|--------|-------------|
| `node scripts/article-highlight.js <url> "<phrase>" <output.png>` | Open article in headless Chrome, wrap the phrase in a yellow marker highlight, screenshot full viewport at 1080px wide. |
| `node scripts/article-excerpt.js <url> "<phrase>" <output.png>` | Same as above but crops tightly to just the paragraph containing the phrase — sized for a floating panel overlay, not the whole page. |
| `./scripts/article-composite.sh <video.mp4> <url> "<phrase>" [--mode background\|overlay]` | Highlight phrase → composite your video over the article. `background`: article fills top of frame, transparent cutout below. `overlay`: footage plays full-frame, article slides in as an animated PiP panel. |

---

### Overlays — Video Backgrounds

| Script | What it does |
|--------|-------------|
| `./scripts/bg-composite.sh <video.mp4> <url-or-image>` | Remove background from subject, screenshot a URL or use a local image, composite and render 9:16 MP4. |
| `./scripts/scroll-bg-composite.sh <subject.mp4> <scroll.mp4> [--audio subject\|bg\|both]` | Crop a phone screen-recording to 1080×1920, loop it as a scrolling background, composite your transparent cutout on top. Subject audio only by default. |
| `./scripts/video-bg-composite.sh <subject.mp4> <background.mp4> [--audio both\|subject\|bg]` | Remove background from subject, composite over any video background. `both` mixes audio (bg ducked 30%), `subject` voice only, `bg` background only. |
| `./scripts/voiceover.sh <background.mp4> <voice.mp4> [--audio replace\|mix] [--bg-vol 0.2]` | Lay your talking track over a video — no background removal needed. `replace` swaps audio entirely; `mix` blends with bg ducked to `--bg-vol`. |

---

### Overlays — Motion Graphics

| Script | What it does |
|--------|-------------|
| `./scripts/headline-stack.sh [--slug] [--hold 1.5] [--stagger 0.5] "H1" "H2" "H3"` | Animate 2–4 headlines: each slides in staggered, holds, fades out in order. Outputs transparent WebM for overlaying, or `--opaque` for standalone with dark background. Max 4 headlines. |
| `uv run python scripts/pip-composite.py --base <cut.mp4> --start <t> --end <t> --bg <image.png> --out <clip.mp4>` | Cut subject out of a specific video segment (birefnet model), composite over an article screenshot or any image, produce a ready-to-splice MP4. |

---

## Project Layout

```
projects/
  YYYY-MM-DD-slug/
    raw/                    <- source footage (gitignored)
    raw-test/               <- test clips (gitignored)
    edit/                   <- transcripts, EDL, cut video, fonts
      verify/               <- visual QC (PNGs gitignored, scripts tracked)
        captions/           <- subtitle, font, position checks
        grade/              <- color grade comparisons
        frames/             <- frame extractions from cuts
        hook/               <- hook graphic overlay tests
        article/            <- article background and PiP tests
        overlays/           <- generic overlay mockups and composites
        alpha/              <- transparency / alpha channel checks
        subject/            <- cutout and background-removal checks
        scripts/            <- .mjs helpers that generate verify PNGs (tracked)
    compositions/           <- hyperframes HTML (tracked); renders gitignored
    renders/                <- final MP4s (gitignored)
```

---

## Tools

| Tool | Path | Purpose |
|------|------|---------|
| [video-use](https://github.com/browser-use/video-use) | `tools/video-use/` | Transcription, filler/silence detection, EDL generation, ffmpeg cuts |
| [hyperframes](https://github.com/heygen-com/hyperframes) | `tools/hyperframes/` | HTML to MP4 motion graphics, overlays, background removal |

Both are gitignored — `./setup.sh` clones and builds them.

---

## House Rules

- **Transcript first** — never cut without transcribing. No guessing timecodes.
- **Propose, then wait** — cuts are presented in plain English. Nothing renders until approved.
- **Never downscale** — 1080x1920 is the preview floor. Native resolution for finals.
- **Subtitles burn last** — always the final step in the ffmpeg filter chain.
- **9:16 vertical** — everything outputs portrait.
