#!/usr/bin/env python3
"""
Generate a static hook cover image for social media uploads.

Extracts a frame from a PiP segment (or any video), composites the
hook text PNG overlay over it, and saves a ready-to-upload cover PNG.
No render pass needed — this is a screengrab.

Usage:
  uv run python scripts/hook-cover.py \
    --video  projects/<slug>/edit/pip_m1.mp4 \
    --hook   projects/<slug>/edit/verify/hook/hook_overlay.png \
    --t      1.5 \
    --out    projects/<slug>/edit/verify/hook/cover.png

  --video   Source video to grab frame from (PiP clip recommended)
  --hook    Hook text PNG (transparent background)
  --t       Timestamp in seconds to extract frame from (default: 1.0)
  --out     Output path for cover PNG
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("PIL not found — install with: uv pip install pillow")
    sys.exit(1)


def extract_frame(video: Path, t: float, out: Path) -> None:
    ffmpeg = "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"
    result = subprocess.run(
        [ffmpeg, "-y", "-ss", str(t), "-i", str(video), "-frames:v", "1", str(out)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not out.exists():
        # fallback to system ffmpeg
        subprocess.run(
            ["ffmpeg", "-y", "-ss", str(t), "-i", str(video), "-frames:v", "1", str(out)],
            check=True,
        )


def composite(frame: Path, hook: Path, out: Path) -> None:
    bg = Image.open(frame).convert("RGBA")
    ov = Image.open(hook).convert("RGBA")
    # Scale overlay to match frame if needed
    if ov.size != bg.size:
        ov = ov.resize(bg.size, Image.LANCZOS)
    bg.alpha_composite(ov)
    bg.convert("RGB").save(out, quality=95)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate hook cover PNG")
    parser.add_argument("--video", required=True, help="Source video (PiP clip or base cut)")
    parser.add_argument("--hook", required=True, help="Hook text PNG (transparent bg)")
    parser.add_argument("--t", type=float, default=1.0, help="Frame timestamp in seconds")
    parser.add_argument("--out", required=True, help="Output cover PNG path")
    args = parser.parse_args()

    video = Path(args.video)
    hook = Path(args.hook)
    out = Path(args.out)

    if not video.exists():
        print(f"ERROR: video not found: {video}")
        sys.exit(1)
    if not hook.exists():
        print(f"ERROR: hook PNG not found: {hook}")
        sys.exit(1)

    out.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        frame_path = Path(tmp.name)

    print(f"Extracting frame at t={args.t}s from {video.name}…")
    extract_frame(video, args.t, frame_path)

    print(f"Compositing hook overlay…")
    composite(frame_path, hook, out)

    frame_path.unlink(missing_ok=True)
    print(f"Cover saved → {out}")


if __name__ == "__main__":
    main()
