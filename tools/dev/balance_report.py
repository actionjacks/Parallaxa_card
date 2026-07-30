#!/usr/bin/env python3
"""Aggregate bot playthrough logs into a balance report.

The probe (tools/dev/probe_deckmath.gd) measures an OPTIMAL player on a static deck. This reads
what actually happened in real runs: which hands a mediocre player reaches once relics, shops and
biome laws are in play, how long fights run, and where runs end.

Run: python3 tools/dev/balance_report.py screenshots/balance/*.txt
"""
import re
import sys
from collections import Counter, defaultdict

TURN = re.compile(r"\[bc\]\s+t(\d+) (.+?) dmg=(\d+) ehp=(\d+) hp=(\d+)")
FIGHT = re.compile(r"\[bc\] fight (\d+) start")
JOURNEY = re.compile(r"journey: (\w+)\s+region=(\d+) fights_won=(\d+) hp=(\d+)/(\d+)")
BIOME = re.compile(r"\[pt2\] biome: (.+?) \(law")
DISCARD = re.compile(r"\[bc\]\s+discard (\d+) junk")


def parse(path):
    runs = {"hands": Counter(), "dmg": [], "fight_turns": [], "discards": 0,
            "result": None, "fights_won": 0, "biome": None, "hp_end": None, "turns": 0,
            "hp_by_fight": [], "hp_trace": []}
    cur = 0
    hp_seen = []
    for line in open(path, encoding="utf-8", errors="replace"):
        m = FIGHT.search(line)
        if m:
            if cur:
                runs["fight_turns"].append(cur)
            if hp_seen:
                # HP the player entered and left this fight on: the gap is what the fight cost
                runs["hp_by_fight"].append((hp_seen[0], hp_seen[-1]))
            hp_seen = []
            cur = 0
            continue
        m = TURN.search(line)
        if m:
            cur = int(m.group(1))
            runs["hands"][m.group(2).strip()] += 1
            runs["dmg"].append(int(m.group(3)))
            runs["turns"] += 1
            hp_seen.append(int(m.group(5)))
            runs["hp_trace"].append(int(m.group(5)))
            continue
        if DISCARD.search(line):
            runs["discards"] += 1
            continue
        m = BIOME.search(line)
        if m:
            runs["biome"] = m.group(1)
            continue
        m = JOURNEY.search(line)
        if m:
            if cur:
                runs["fight_turns"].append(cur)
                cur = 0
            if hp_seen:
                runs["hp_by_fight"].append((hp_seen[0], hp_seen[-1]))
            runs["result"] = m.group(1)
            runs["fights_won"] = int(m.group(3))
            runs["hp_end"] = int(m.group(4))
    if cur:
        runs["fight_turns"].append(cur)
    return runs


def pct(n, d):
    return (100.0 * n / d) if d else 0.0


def main(paths):
    all_hands = Counter()
    all_dmg = []
    all_turns = []
    results = Counter()
    fights_won = []
    print("=" * 66)
    print("RAPORT BALANSU — z prawdziwych przeklikow bota")
    print("=" * 66)
    for p in paths:
        r = parse(p)
        all_hands.update(r["hands"])
        all_dmg += r["dmg"]
        all_turns += r["fight_turns"]
        results[r["result"] or "TIMEOUT"] += 1
        fights_won.append(r["fights_won"])
        name = p.split("/")[-1].replace(".txt", "")
        avg = sum(r["fight_turns"]) / len(r["fight_turns"]) if r["fight_turns"] else 0
        print("  %-12s %-8s walk=%-2d  tur/walke=%.1f  odrzutow=%-3d  biom=%s"
              % (name, r["result"], r["fights_won"], avg, r["discards"], r["biome"] or "-"))

    n = sum(all_hands.values())
    print("\n-- UKLADY, ktore bot REALNIE zagral (%d zagran) --" % n)
    for h, c in all_hands.most_common():
        print("   %-18s %6.2f%%   (%d)" % (h, pct(c, n), c))

    if all_dmg:
        d = sorted(all_dmg)
        q = lambda f: d[int(f * (len(d) - 1))]
        print("\n-- OBRAZENIA na zagranie --")
        print("   p05=%d  mediana=%d  p95=%d  max=%d   rozrzut p95/med=%.2fx"
              % (q(.05), q(.5), q(.95), d[-1], q(.95) / max(q(.5), 1)))
    if all_turns:
        t = sorted(all_turns)
        print("\n-- DLUGOSC WALKI (tury) --")
        print("   min=%d  mediana=%d  max=%d  srednia=%.1f"
              % (t[0], t[len(t) // 2], t[-1], sum(t) / len(t)))
    costs = []
    for p in paths:
        for a, b in parse(p)["hp_by_fight"]:
            costs.append(a - b)
    if costs:
        costs.sort()
        print("\n-- KOSZT WALKI w HP (wejscie minus wyjscie) --")
        print("   mediana=%d  p90=%d  max=%d   (gracz ma 55 HP)"
              % (costs[len(costs) // 2], costs[int(0.9 * (len(costs) - 1))], costs[-1]))
        free = sum(1 for c in costs if c <= 0)
        print("   walk bez strat: %.0f%%" % pct(free, len(costs)))
    print("\n-- ZAKONCZENIA --")
    for k, v in results.most_common():
        print("   %-9s %d/%d" % (k, v, len(paths)))
    print("   walk wygranych: min=%d mediana=%d max=%d"
          % (min(fights_won), sorted(fights_won)[len(fights_won) // 2], max(fights_won)))


if __name__ == "__main__":
    main(sys.argv[1:] or ["screenshots/pt2_log.txt"])
