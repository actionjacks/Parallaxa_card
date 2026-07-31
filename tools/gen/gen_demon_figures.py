#!/usr/bin/env python3
"""Turn Dictionnaire Infernal plates into arena figures.

Same destination as gen_foe_figures.py -- an 8-frame sheet in assets/foes/ -- but a different
front end, because these are BOOK plates, not tarot cards. The card pipeline crops a printed rule
and a title banner that do not exist here, and floods a "sky" that is actually a cream page. Both
of those assumptions would eat the demon.

What changes:
  crop   a thin, symmetric bite: page margin only, plus a little more off the foot where the
         engraver's caption sits
  page   flood the near-white paper from every edge pixel, with a wider tolerance than a tarot
         sky needs -- the paper is foxed and uneven after 160 years
  keep   every island above a share of the largest, exactly as the card pipeline does, because a
         demon's wings and staff are separate blobs from its body

Everything downstream (warp frames, trim, normalise) is the card pipeline's, reused as-is.

Run: python3 tools/gen/gen_demon_figures.py
Then: python3 tools/gen/gen_foe_layers.py     (parallax layers for the new figures)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_foe_figures as G
from PIL import Image, ImageFilter

ROOT = G.ROOT
SRC = os.path.join(ROOT, "assets", "foes_src")
OUT = G.OUT
PAPER_MIN = 150         ## a clean plate's median luminance IS its paper; darker = reject the scan
INK_DROP = 55           ## how far below the paper a pixel must sit to count as ink
COVER_MIN, COVER_MAX = 0.04, 0.62   ## a figure covers this share of the crop; more is a slab
CLOSE = 7               ## morphological close, in pixels: fills hatching, keeps the outline


def _plate_crop(img):
    w, h = img.size
    return img.crop((int(w * 0.04), int(h * 0.03), int(w * 0.96), int(h * 0.90)))


def _ink_key(img):
    """Keep the INK, drop the paper.

    Flood-filling the page from the edges is what the card pipeline does, and on these plates it
    fails two ways: a printed border stops the fill dead (the page survives as a white slab), or a
    figure touching the frame drains the whole image (the demon vanishes). Twelve of twenty plates
    came out wrong that way.

    An engraving is black ink on white paper, so the ink IS the figure -- a luminance key is both
    simpler and far more robust. The interior is hatched, meaning paper shows between the strokes,
    so the mask is CLOSED (dilate then erode) to fill the demon in without fattening its outline.
    """
    from PIL import ImageOps, ImageFilter as F
    grey = ImageOps.grayscale(img)
    # ADAPTIVE, and willing to say no. A fixed threshold turned five of twenty plates into solid
    # black slabs: some scans are photographs of a page with a dark surround, where "darker than
    # 176" is simply the whole rectangle. The paper is the dominant bright tone, so the median IS
    # the paper -- and a plate whose median is dark is not a clean line engraving at all.
    hist = grey.histogram()
    total = sum(hist)
    acc = 0
    median = 255
    for v, c in enumerate(hist):
        acc += c
        if acc >= total * 0.5:
            median = v
            break
    if median < PAPER_MIN:
        return None
    mask = grey.point(lambda v: 255 if v < median - INK_DROP else 0)
    mask = mask.filter(F.MaxFilter(CLOSE))      # bridge the hatching
    mask = mask.filter(F.MinFilter(CLOSE))      # ...without growing the silhouette
    mask = mask.filter(F.GaussianBlur(0.8))
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def build(src_path):
    img = Image.open(src_path).convert("RGB")
    keyed = _ink_key(_plate_crop(img))
    if keyed is None:
        return None, 0
    a = keyed.getchannel("A")
    cover = sum(i * c for i, c in enumerate(a.histogram())) / (255.0 * a.size[0] * a.size[1])
    if not (COVER_MIN <= cover <= COVER_MAX):
        return None, 0
    fig = G._largest_blob(keyed)
    fig = G._trim(fig)
    if fig.size[0] < 8 or fig.size[1] < 8:
        return None, 0
    ratio = G.SHEET_H / float(fig.size[1])
    fig = fig.resize((max(1, int(fig.size[0] * ratio)), G.SHEET_H), Image.LANCZOS)
    fig.putalpha(fig.getchannel("A").filter(ImageFilter.GaussianBlur(0.6)))
    cells = [G._warp(fig, 2.0 * math.pi * i / G.FRAMES) for i in range(G.FRAMES)]
    cw = max(c.size[0] for c in cells)
    sheet = Image.new("RGBA", (cw * G.FRAMES, G.SHEET_H), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.paste(c, (i * cw + (cw - c.size[0]) // 2, 0), c)
    return sheet, cw


def main():
    if not os.path.isdir(SRC):
        sys.exit("brak %s -- najpierw tools/gen/fetch_demons.py" % SRC)
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for f in sorted(os.listdir(SRC)):
        if not f.lower().endswith((".jpg", ".png")):
            continue
        stem = "demon_" + os.path.splitext(f)[0]
        sheet, cw = build(os.path.join(SRC, f))
        if sheet is None:
            print("  odrzucone (nie jest czysta rycina): %s" % stem)
            continue
        sheet.save(os.path.join(OUT, stem + ".png"))
        made += 1
        print("  %-40s cell %dx%d x%d" % (stem, cw, G.SHEET_H, G.FRAMES))
    print("gen_demon_figures: %d figur -> %s" % (made, OUT))


if __name__ == "__main__":
    main()
