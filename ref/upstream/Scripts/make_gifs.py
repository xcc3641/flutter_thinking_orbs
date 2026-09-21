#!/usr/bin/env python3
"""Turns the PNG sequences MediaTests renders into seamless looping GIFs.

Each clip folder carries a clip.json: `loop` frames, plus `seam` frames
rendered past the end. The overhang is crossfaded into the opening frames,
so the last frame flows straight into the first. Designs that truly repeat
are rendered as exactly one cycle with no seam.

usage: make_gifs.py <frames dir> <assets dir>
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

FRAME_MS = 30          # must match MediaTests.frameStep

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(dst, "designs"), exist_ok=True)

for clip in sorted(os.listdir(src)):
    folder = os.path.join(src, clip)
    if not os.path.isdir(folder):
        continue
    with open(os.path.join(folder, "clip.json")) as f:
        spec = json.load(f)
    names = sorted(n for n in os.listdir(folder) if n.endswith(".png"))
    frames = [np.asarray(Image.open(os.path.join(folder, n)).convert("RGB")).astype(np.float32) for n in names]
    loop, seam = spec["loop"], spec["seam"]
    assert len(frames) == loop + seam, f"{clip}: {len(frames)} frames, expected {loop + seam}"
    out = []
    for i in range(loop):
        if i < seam:
            s = i / seam
            out.append((1 - s) * frames[i + loop] + s * frames[i])
        else:
            out.append(frames[i])

    is_design = not (clip.startswith("banner") or clip.startswith("labels"))
    target = os.path.join(dst, "designs" if is_design else "", clip + ".gif")
    with tempfile.TemporaryDirectory() as tmp:
        for i, f in enumerate(out):
            Image.fromarray(np.clip(f + 0.5, 0, 255).astype(np.uint8)).save(os.path.join(tmp, f"{i:04d}.png"))
        pattern = os.path.join(tmp, "%04d.png")
        subprocess.run([
            "ffmpeg", "-v", "error", "-y", "-framerate", f"1000/{FRAME_MS}", "-i", pattern,
            "-filter_complex",
            "[0:v]split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=none",
            "-loop", "0", target,
        ], check=True)
    if shutil.which("gifsicle"):  # lossless re-optimisation, a few percent
        subprocess.run(["gifsicle", "-O3", "--batch", target], check=True)
    print(f"{os.path.getsize(target) / 1024:8.0f} KB  {os.path.relpath(target, dst)}")
