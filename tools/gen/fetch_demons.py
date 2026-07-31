#!/usr/bin/env python3
"""Fetch demon engravings from the Dictionnaire Infernal (1863) off Wikimedia Commons.

WHY THIS SOURCE. The opponents were cut out of the RWS tarot plates, which meant every enemy was
literally a card -- the one thing the arena should not look like. These are the alternative that
does not cost the game its identity: Louis Le Breton's 1863 demon woodcuts share the exact
engraving idiom as the tarot plates (same era, same technique, same ink), so they sit in the same
world, while being unmistakably NOT cards. 148 of them are in the public domain on Commons.

Commons etiquette (the hard way, once already): a descriptive User-Agent and a pause between
requests. Anonymous hammering gets the whole project blocked.

Out: assets/foes_src/<name>.jpg  -- raw plates, fed to gen_foe_figures.py like any other source.
Run: python3 tools/gen/fetch_demons.py [count]
"""
import json, os, sys, time, urllib.parse, urllib.request

CAT = "Category:Drawings of demons from Dictionnaire Infernal, 6th edition"
API = "https://commons.wikimedia.org/w/api.php"
UA = "ParallaxaCard/1.0 (public-domain art fetch; netisowy.team@gmail.com)"
OUT = "assets/foes_src"
PAUSE = 1.1


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def _api(params):
    return json.loads(_get(API + "?" + urllib.parse.urlencode(params)))


def main(limit):
    os.makedirs(OUT, exist_ok=True)
    files = []
    cont = None
    while len(files) < limit:
        p = {"action": "query", "format": "json", "list": "categorymembers",
             "cmtitle": CAT, "cmlimit": "50", "cmtype": "file"}
        if cont:
            p["cmcontinue"] = cont
        d = _api(p)
        files += [m["title"] for m in d["query"]["categorymembers"]]
        cont = d.get("continue", {}).get("cmcontinue")
        if not cont:
            break
        time.sleep(PAUSE)
    files = files[:limit]
    got = 0
    for t in files:
        stem = os.path.splitext(t[5:])[0].lower()
        stem = "".join(c if c.isalnum() else "_" for c in stem).strip("_")
        dst = os.path.join(OUT, stem + ".jpg")
        if os.path.exists(dst):
            got += 1
            continue
        info = _api({"action": "query", "format": "json", "prop": "imageinfo",
                     "titles": t, "iiprop": "url", "iiurlwidth": "760"})
        pages = info["query"]["pages"]
        ii = next(iter(pages.values())).get("imageinfo")
        if not ii:
            continue
        url = ii[0].get("thumburl") or ii[0]["url"]
        try:
            data = _get(url)
        except Exception as e:
            print("  SKIP %s (%s)" % (stem, e))
            continue
        open(dst, "wb").write(data)
        got += 1
        print("  %-34s %6d B" % (stem, len(data)))
        time.sleep(PAUSE)
    print("fetch_demons: %d plansz -> %s" % (got, OUT))


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 24)
