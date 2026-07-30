#!/usr/bin/env python3
"""Cut the FIGURE out of a Rider-Waite plate and animate it like an engraving.

The arena used to show a tarot CARD. The player asked for the opponent: if the foe is a
cultist, they want a cultist standing there, moving. The RWS court cards already depict
exactly those figures -- the game's whole conceit is that its enemies ARE the court cards --
so the character is extracted from the public-domain plate rather than invented.

Pipeline per foe:
  1. crop away the white margin, the printed frame and the title banner
  2. flood-fill the sky from the top corners to alpha (RWS skies are near-flat)
  3. fade the ground out from below, so the figure stands in mist instead of on a cut edge
  4. trim to the figure and emit an ENGRAVING ANIMATION: N frames of gentle mesh-free warps
     (breath, sway, a lean) baked into one horizontal sprite sheet

Limited framerate is the point: an engraving that moves smoothly reads as a photo with a
filter, an engraving that moves in 8 steps reads as a woodcut brought to life.

Run: python3 tools/gen/gen_foe_figures.py
Out: assets/foes/<name>.png  (sprite sheet, FRAMES columns)
"""
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    sys.exit("Pillow required")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MINOR = os.path.join(ROOT, "assets", "cards", "minor")
MAJOR = os.path.join(ROOT, "assets", "cards", "arcana")
OUT = os.path.join(ROOT, "assets", "foes")

FRAMES = 8                 ## frames per idle loop
SHEET_H = 320              ## every figure is normalised to this height
SKY_FUZZ = 46              ## flood-fill tolerance for the sky (RWS skies are near-flat)


def _inner_crop(img):
    """Drop the white margin, the printed rule and the title banner at the foot."""
    w, h = img.size
    return img.crop((int(w * 0.085), int(h * 0.065), int(w * 0.915), int(h * 0.86)))


def _kill_sky(img):
    """Flood-fill the background inward from the top edge, then from the top corners."""
    rgba = img.convert("RGBA")
    flat = rgba.convert("RGB")
    magic = (255, 0, 255)
    w, h = flat.size
    # Seed from EVERY border pixel down to the horizon, not from a handful of corners: the RWS
    # skies carry printing speckle and a residual frame line, and a few seeds leave both behind
    # as confetti around the cut-out figure.
    seeds = []
    for x in range(0, w, 2):
        seeds.append((x, 1))
        seeds.append((x, 2))
    for y in range(1, int(h * 0.80), 2):
        seeds.append((1, y))
        seeds.append((2, y))
        seeds.append((w - 2, y))
        seeds.append((w - 3, y))
    for s in seeds:
        try:
            ImageDraw.floodfill(flat, s, magic, thresh=SKY_FUZZ)
        except Exception:
            pass
    px_src = flat.load()
    px_dst = rgba.load()
    for y in range(h):
        for x in range(w):
            if px_src[x, y] == magic:
                px_dst[x, y] = (0, 0, 0, 0)
    return rgba


def _fade_ground(img, keep=0.72):
    """The lower scenery is not the character: fade it to nothing so the figure emerges."""
    w, h = img.size
    a = img.getchannel("A")
    px = a.load()
    start = int(h * keep)
    for y in range(start, h):
        t = (y - start) / max(1, h - start)
        k = int(255 * (1.0 - t) ** 1.6)
        for x in range(w):
            v = px[x, y]
            if v:
                px[x, y] = min(v, k)
    img.putalpha(a)
    return img


def _largest_blob(img, thresh=60):
    """Keep ONLY the biggest connected shape and drop everything else.

    After the sky is gone, what survives is the figure plus whatever the flood fill could not
    reach: a bush at the foot of the plate, a distant mountain, printing speckle, and the inner
    frame rule the fill cannot cross. All of those are separate islands; the character is the
    one big one. Picking the largest component removes them all without a per-card mask.
    """
    from collections import deque
    w, h = img.size
    a = img.getchannel("A")
    px = a.load()
    seen = bytearray(w * h)
    comps = []
    best = None
    best_n = 0
    for sy in range(h):
        for sx in range(w):
            i = sy * w + sx
            if seen[i] or px[sx, sy] <= thresh:
                continue
            q = deque([(sx, sy)])
            seen[i] = 1
            comp = []
            while q:
                x, y = q.popleft()
                comp.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and px[nx, ny] > thresh:
                            seen[j] = 1
                            q.append((nx, ny))
            comps.append(comp)
            if len(comp) > best_n:
                best_n = len(comp)
                best = comp
    if best is None:
        return img
    # Keep every island of comparable size, not just the biggest one: some plates stage a SCENE
    # (the Devil towers over two chained figures) and each body is its own island. Cutting to the
    # single largest one decapitated the Devil from his own card.
    keep = bytearray(w * h)
    for comp in comps:
        if len(comp) >= max(120, int(best_n * 0.16)):
            for x, y in comp:
                keep[y * w + x] = 1
    for y in range(h):
        for x in range(w):
            if not keep[y * w + x]:
                px[x, y] = 0
    img.putalpha(a)
    return img


def _trim(img, pad=4):
    bbox = img.getbbox()
    if bbox is None:
        return img
    x0, y0, x1, y1 = bbox
    w, h = img.size
    return img.crop((max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad)))


def _warp(img, phase):
    """One animation frame: a slow breath plus a sway, applied as horizontal band shears.

    Band shearing (not a smooth mesh) is deliberate -- it keeps the ink edges crisp and gives
    the stepped, carved motion of a woodcut instead of rubbery tweening.
    """
    w, h = img.size
    out = Image.new("RGBA", (w + 12, h), (0, 0, 0, 0))
    bands = 16
    for i in range(bands):
        y0 = int(h * i / bands)
        y1 = int(h * (i + 1) / bands)
        # bands OVERLAP by a pixel: neighbouring bands shift by different amounts, and a
        # butt-joint leaves a one-pixel transparent seam straight across the figure's face.
        band = img.crop((0, y0, w, min(h, y1 + 1)))
        t = i / (bands - 1.0)              # 0 at the head, 1 at the feet
        # the head sways most, the feet are planted
        sway = math.sin(phase + t * 1.1) * 3.4 * (1.0 - t) ** 1.3
        # breath: the chest lifts a touch on the inhale
        lift = math.sin(phase) * 1.6 * math.exp(-((t - 0.32) ** 2) / 0.05)
        out.paste(band, (6 + int(round(sway)), y0 - int(round(lift))), band)
    return out


def build(src_path, frames=FRAMES, height=SHEET_H):
    img = Image.open(src_path).convert("RGB")
    # order matters: cut the sky, keep only the figure, THEN fade the ground it stands on
    fig = _fade_ground(_largest_blob(_kill_sky(_inner_crop(img))))
    fig = _trim(fig)
    # normalise height, keep aspect
    ratio = height / float(fig.size[1])
    fig = fig.resize((max(1, int(fig.size[0] * ratio)), height), Image.LANCZOS)
    # a whisper of ink bleed hides the flood-fill's stair-stepping
    fig.putalpha(fig.getchannel("A").filter(ImageFilter.GaussianBlur(0.6)))
    cells = [_warp(fig, 2.0 * math.pi * i / frames) for i in range(frames)]
    cw = max(c.size[0] for c in cells)
    sheet = Image.new("RGBA", (cw * frames, height), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.paste(c, (i * cw + (cw - c.size[0]) // 2, 0), c)
    return sheet, cw


def main(specs):
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for name, rel in specs:
        src = os.path.join(ROOT, "assets", "cards", rel)
        if not os.path.exists(src):
            print("  missing:", rel)
            continue
        sheet, cw = build(src)
        sheet.save(os.path.join(OUT, name + ".png"))
        made += 1
        print("  %-22s %dx%d  cell %dx%d x%d" % (name, sheet.size[0], sheet.size[1],
                                                 cw, sheet.size[1], FRAMES))
    print("gen_foe_figures: %d figures -> assets/foes/" % made)


## Every plate the game actually fields as an opponent. The figure file is named after the
## plate, so gen_content only has to point EnemyData.figure at "<same name>.png".
PLATES = [
    "minor/cups_01", "minor/cups_09", "minor/cups_10", "minor/cups_11", "minor/cups_12",
    "minor/cups_13", "minor/cups_14",
    "minor/swords_01", "minor/swords_09", "minor/swords_10", "minor/swords_11",
    "minor/swords_12", "minor/swords_13", "minor/swords_14",
    "minor/wands_01", "minor/wands_09", "minor/wands_10", "minor/wands_11",
    "minor/wands_12", "minor/wands_13", "minor/wands_14",
    "minor/pents_01", "minor/pents_09", "minor/pents_10", "minor/pents_11",
    "minor/pents_12", "minor/pents_13", "minor/pents_14",
    # the Nature plate is our own duotone and has no flat sky to cut -- the Seven of
    # Pentacles (a labourer watching his crop) stands in for the Overgrowth's elite.
    ("minor/nature_09", "minor/pents_07"),
    "arcana/00_fool", "arcana/03_empress", "arcana/07_chariot", "arcana/08_strength",
    "arcana/10_wheel_of_fortune", "arcana/11_justice", "arcana/12_hanged_man",
    "arcana/15_devil", "arcana/16_tower", "arcana/17_star", "arcana/18_moon",
    "arcana/20_judgement", "arcana/21_world",
]

if __name__ == "__main__":
    specs = []
    for entry in PLATES:
        if isinstance(entry, tuple):
            name, src = entry
        else:
            name, src = entry, entry
        specs.append((name.split("/")[-1], src + ".jpg"))
    main(specs)
