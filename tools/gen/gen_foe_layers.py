#!/usr/bin/env python3
"""Split every cut-out foe figure into DEPTH LAYERS for parallax.

The complaint this answers: the opponent read as a flat picture lifted off a card. The fix is the
one animated-card games use -- the figure is not one image but several, sitting at different
distances, drifting at different rates. The eye reads that difference as volume; a single plane,
however well cut out, can never read as anything but a plane.

The layers are derived, not authored, because there are 44 figures and there will be more:

  back   the whole silhouette, darkened and blurred, grown a few pixels -- the body's own mass,
         sitting behind everything. This is what gives the figure a "thickness" when the camera
         drifts: the halo slides out from behind the shoulders.
  mid    the plate as cut. The figure proper.
  fore   only the ENGRAVED DETAIL -- the dark hatching lines and the bright highlights, isolated by
         local contrast. On a woodcut this is exactly the material that should sit closest to the
         viewer, and pulling it forward turns the linework into relief instead of texture.

Why local contrast and not a luminance band: splitting a woodcut by brightness shatters it into
speckle, because the ink IS the shading. Contrast finds the lines themselves.

In:  assets/foes/<name>.png          (horizontal sprite sheet, FRAMES columns)
Out: assets/foes/layers/<name>_back.png, _mid.png, _fore.png   (same sheet geometry)

Run: python3 tools/gen/gen_foe_layers.py
"""
import os
import sys
from PIL import Image, ImageFilter, ImageChops, ImageOps

SRC = "assets/foes"
OUT = "assets/foes/layers"

BACK_DARK = 0.30      ## how far the mass behind the figure is pushed toward black
BACK_BLUR = 3.0       ## soft, because it is meant to be felt and not seen
BACK_GROW = 2         ## pixels the silhouette is dilated by, so it peeks out at the edges
FORE_GAIN = 2.2       ## how hard the isolated linework is pushed
FORE_FLOOR = 26       ## contrast below this is texture, not relief -- discarded


def _alpha_of(img):
    return img.split()[3]


def _back_layer(img):
    """The body's mass: dilated, blurred, darkened. Alpha only where the figure is."""
    a = _alpha_of(img)
    grown = a.filter(ImageFilter.MaxFilter(BACK_GROW * 2 + 1))
    grown = grown.filter(ImageFilter.GaussianBlur(BACK_BLUR))
    rgb = img.convert("RGB").point(lambda v: int(v * BACK_DARK))
    out = rgb.convert("RGBA")
    out.putalpha(grown)
    return out


def _fore_layer(img):
    """The engraved line-work alone, isolated by LOCAL CONTRAST (|img - blur(img)|).

    A woodcut carries its shading in the ink, so a brightness threshold would only shred it. The
    difference against a blurred copy keeps exactly the strokes and highlights and drops the flat
    fills -- which is the material that should stand proudest of the plate.
    """
    grey = ImageOps.grayscale(img.convert("RGB"))
    soft = grey.filter(ImageFilter.GaussianBlur(2.0))
    edge = ImageChops.difference(grey, soft)
    edge = edge.point(lambda v: 0 if v < FORE_FLOOR else min(255, int(v * FORE_GAIN)))
    # never invent detail outside the figure
    edge = ImageChops.multiply(edge, _alpha_of(img))
    out = img.convert("RGBA").copy()
    out.putalpha(edge)
    return out


def main():
    if not os.path.isdir(SRC):
        print("gen_foe_layers: no %s" % SRC)
        return 1
    os.makedirs(OUT, exist_ok=True)
    names = sorted(f for f in os.listdir(SRC) if f.endswith(".png"))
    made = 0
    for f in names:
        src = os.path.join(SRC, f)
        img = Image.open(src).convert("RGBA")
        stem = f[:-4]
        _back_layer(img).save(os.path.join(OUT, "%s_back.png" % stem))
        img.save(os.path.join(OUT, "%s_mid.png" % stem))
        _fore_layer(img).save(os.path.join(OUT, "%s_fore.png" % stem))
        made += 1
        print("  %-24s %dx%d -> 3 warstwy" % (stem, img.size[0], img.size[1]))
    print("gen_foe_layers: %d figur -> %s" % (made, OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
