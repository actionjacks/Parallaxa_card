#!/usr/bin/env python3
"""Generate the FIFTH suit (NATURE) that Rider-Waite-Smith never drew.

RWS 1909 (public domain) ships four suits; the game's pentagram needs five, so the
Nature suit is DERIVED from the public-domain plates: mirrored so no composition is a
twin of the card it came from, re-inked in a verdant duotone so the suit reads as a
colour at a glance, and stamped with a botanical sigil in both upper corners.

Source : assets/cards/minor/pents_NN.jpg   (public domain, RWS 1909)
Output : assets/cards/minor/nature_NN.jpg  (ranks 01..14)

Run: python3 tools/gen/gen_nature_suit.py
Requires: Pillow (stdlib-only otherwise; this box has no numpy).
"""
import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageEnhance
except ImportError:
    sys.exit("Pillow is required: pip install --user Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MINOR = os.path.join(ROOT, "assets", "cards", "minor")

# Verdant ink ramp: forest shadow -> leaf body -> sunlit highlight. Chosen to sit beside
# the sepia RWS scans without screaming "filter" -- same value structure, different hue.
SHADOW = (16, 36, 23)
MID = (56, 101, 56)
LIGHT = (198, 223, 152)

SIGIL_FILL = (206, 232, 160, 235)
SIGIL_INK = (22, 50, 26, 255)


def duotone(img, shadow, mid, light):
    """Map luminance onto a three-stop ink ramp (keeps the engraving's value structure)."""
    grey = img.convert("L")
    ramp = []
    for i in range(256):
        t = i / 255.0
        if t < 0.5:
            u = t / 0.5
            ramp.append(tuple(int(shadow[k] + (mid[k] - shadow[k]) * u) for k in range(3)))
        else:
            u = (t - 0.5) / 0.5
            ramp.append(tuple(int(mid[k] + (light[k] - mid[k]) * u) for k in range(3)))
    return Image.merge("RGB", tuple(
        grey.point([c[ch] for c in ramp]) for ch in range(3)))


def draw_leaf(draw, cx, cy, r):
    """A pointed leaf with midrib and veins -- legible down to ~14 px."""
    pts = []
    steps = 20
    for i in range(steps + 1):
        t = i / steps
        w = math.sin(math.pi * t) * r * 0.52
        pts.append((cx - w, cy - r + 2 * r * t))
    for i in range(steps + 1):
        t = 1 - i / steps
        w = math.sin(math.pi * t) * r * 0.52
        pts.append((cx + w, cy - r + 2 * r * t))
    draw.polygon(pts, fill=SIGIL_FILL, outline=SIGIL_INK)
    draw.line([(cx, cy - r + 2), (cx, cy + r - 2)], fill=SIGIL_INK, width=1)
    for k in range(1, 5):
        t = k / 5.0
        y = cy - r + 2 * r * t
        w = math.sin(math.pi * t) * r * 0.40
        draw.line([(cx, y), (cx - w, y + r * 0.13)], fill=SIGIL_INK, width=1)
        draw.line([(cx, y), (cx + w, y + r * 0.13)], fill=SIGIL_INK, width=1)


def build_card(rank):
    src = os.path.join(MINOR, "pents_%02d.jpg" % rank)
    img = Image.open(src).convert("RGB")
    # Mirror first: the Nature card must not read as a recoloured twin of the Pentacle
    # it was derived from -- both suits are in the same deck and the same hand.
    img = img.transpose(Image.FLIP_LEFT_RIGHT)
    out = duotone(img, SHADOW, MID, LIGHT)
    out = ImageEnhance.Contrast(out).enhance(1.12)
    d = ImageDraw.Draw(out, "RGBA")
    w, h = out.size
    # The RWS plates carry an engraved TITLE BANNER along the bottom; mirroring turns that
    # lettering into reversed gibberish. Replace the strip with an ink band so the suit reads
    # as deliberately drawn rather than as a flipped scan.
    band_top = int(h * 0.875)
    d.rectangle([0, band_top, w, h], fill=SHADOW + ())
    d.line([(0, band_top), (w, band_top)], fill=SIGIL_INK, width=2)
    draw_leaf(d, w // 2, (band_top + h) // 2, int((h - band_top) * 0.34))
    r = int(h * 0.055)
    for cx in (int(w * 0.13), int(w * 0.87)):
        draw_leaf(d, cx, int(h * 0.085), r)
    return out


def main():
    if not os.path.isdir(MINOR):
        sys.exit("missing source dir: " + MINOR)
    made = 0
    for rank in range(1, 15):
        if not os.path.exists(os.path.join(MINOR, "pents_%02d.jpg" % rank)):
            continue
        card = build_card(rank)
        dst = os.path.join(MINOR, "nature_%02d.jpg" % rank)
        card.save(dst, quality=92)
        made += 1
    print("gen_nature_suit: wrote %d cards to %s" % (made, MINOR))


if __name__ == "__main__":
    main()
