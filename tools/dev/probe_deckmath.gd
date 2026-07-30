extends SceneTree
## Balance probe: simulates fights on the REAL engine (Poker.evaluate + Scoring.score +
## CombatController draw/recycle rules), so deck changes are measured, never guessed.
## The question it answers: "what hand does the player actually get to play, and how much
## does the damage SWING?" -- a flat damage curve is what makes a deckbuilder feel dead.
##
## Run: Godot_v4.7 --headless --path . -s res://tools/dev/probe_deckmath.gd
## Env: PD_DECK=classic|reaper|gardener|oracle   PD_FIGHTS=2000   PD_TURNS=6

const HAND_NAMES := ["HIGH", "PAIR", "2PAIR", "THREE", "STRAIGHT", "FLUSH", "FULL",
	"FOUR", "STR_FLUSH", "FIVE", "MAGNUM"]

var _rng := RandomNumberGenerator.new()
var _grave_size := 0     ## cards in the used pile right now (ZNIWO scales on this)
var _plays_made := 0

func _initialize() -> void:
	OS.set_environment("TEST_PROFILE", "bot")

func _process(_d: float) -> bool:
	var fights: int = int(OS.get_environment("PD_FIGHTS")) if OS.get_environment("PD_FIGHTS") != "" else 1500
	var turns: int = int(OS.get_environment("PD_TURNS")) if OS.get_environment("PD_TURNS") != "" else 6
	var deck_id: String = OS.get_environment("PD_DECK")
	if deck_id == "":
		deck_id = "classic"
	# PD_SYNTH="aspects x maxrank" (e.g. "5x7") builds a candidate grid deck in memory, so a
	# balance question can be answered BEFORE any .tres is written.
	var deck: Array = []
	var synth: String = OS.get_environment("PD_SYNTH")
	if synth.begins_with("rot"):
		# ROTATED GRID: R ranks x 4 copies, each rank SKIPPING one aspect (the skipped aspect
		# rotates). Gives real-poker rank multiplicity (4, not 5) while keeping five colours,
		# so full houses stop drowning out two pair.
		var ranks: int = int(synth.substr(3)) if synth.length() > 3 else 10
		for r in range(1, ranks + 1):
			for a in 5:
				if a == (r - 1) % 5:
					continue   # this rank is absent from this Aspect
				var c := CardData.new()
				c.rank = r
				c.aspect = a as Aspects.Id
				deck.append(c)
		deck_id = "SYNTH " + synth
	elif synth != "":
		var parts: PackedStringArray = synth.split("x")
		var aspects: int = int(parts[0])
		var maxrank: int = int(parts[1]) if parts.size() > 1 else 7
		for a in aspects:
			for r in range(1, maxrank + 1):
				var c := CardData.new()
				c.rank = r
				c.aspect = a as Aspects.Id
				deck.append(c)
		deck_id = "SYNTH " + synth
	else:
		deck = DeckLibrary.starter_deck_by_id(deck_id)
	print("[deckmath] deck '%s': %d cards" % [deck_id, deck.size()])
	_describe(deck)
	_run(deck, fights, turns)
	quit()
	return true

func _describe(deck: Array) -> void:
	var asp := {}
	var rank := {}
	for c: CardData in deck:
		asp[c.aspect] = int(asp.get(c.aspect, 0)) + 1
		rank[c.rank] = int(rank.get(c.rank, 0)) + 1
	var an: Array = []
	for a in [0, 1, 2, 3, 4]:
		an.append("%s=%d" % [Aspects.NAME_KEYS[a].replace("ASPECT_", ""), int(asp.get(a, 0))])
	print("[deckmath] aspects: " + ", ".join(an))
	var keys: Array = rank.keys()
	keys.sort()
	var rn: Array = []
	for k in keys:
		rn.append("%d x%d" % [k, rank[k]])
	print("[deckmath] ranks: " + ", ".join(rn))

## Best scoring subset of up to 5 cards, measured with the REAL Scoring pipeline.
func _best_play(hand: Array) -> Dictionary:
	var best := {"idx": [], "dmg": -1, "hand": 0}
	var n: int = hand.size()
	# enumerate every subset of size 1..5 via bitmask (n <= 8 -> 255 masks)
	for mask in range(1, 1 << n):
		var bits: int = 0
		var m: int = mask
		while m > 0:
			bits += m & 1
			m >>= 1
		if bits > 5:
			continue
		var cards: Array = []
		var idx: Array = []
		for i in n:
			if mask & (1 << i):
				cards.append(hand[i])
				idx.append(i)
		# The grave MUST be in the context: ZNIWO scores mult += value * grave, so a probe with an
		# empty ctx silently under-reports the whole tail of the damage curve.
		var res: Dictionary = Scoring.score(cards, [], {"grave": _grave_size, "plays": _plays_made})
		var dmg: int = int(res.get("damage", 0))
		if dmg > best["dmg"]:
			best = {"idx": idx, "dmg": dmg, "hand": Poker.evaluate(cards)}
	return best

## Which hands are merely AVAILABLE in the drawn hand (the ceiling the player could reach).
func _available(hand: Array) -> Dictionary:
	var seen := {}
	var n: int = hand.size()
	for mask in range(1, 1 << n):
		var bits: int = 0
		var m: int = mask
		while m > 0:
			bits += m & 1
			m >>= 1
		if bits != 5:
			continue
		var cards: Array = []
		for i in n:
			if mask & (1 << i):
				cards.append(hand[i])
		seen[Poker.evaluate(cards)] = true
		# Pentagram probe: five cards, five different Aspects (todo.md's secret hand)
		var asp := {}
		for c: CardData in cards:
			asp[c.aspect] = true
		if asp.size() == 5:
			seen[-1] = true      # -1 marks PENTAGRAM
		var ranks := {}
		for c: CardData in cards:
			ranks[c.rank] = true
		if ranks.has(11) and ranks.has(12) and ranks.has(13) and ranks.has(14):
			seen[-2] = true      # -2 marks FULL COURT
	return seen

func _run(deck: Array, fights: int, turns: int) -> void:
	var played := {}
	var avail := {}
	var dmgs: Array = []
	var pent := 0
	var court := 0
	var hands_seen := 0
	for f in fights:
		_rng.seed = f + 1
		var d: Array = deck.duplicate()
		_shuffle(d)
		var draw: Array = d
		var used: Array = []
		var hand: Array = []
		hand = _refill(hand, draw, used)
		var discards := 3
		for t in turns:
			if hand.is_empty():
				break
			hands_seen += 1
			var av := _available(hand)
			for k in av:
				avail[k] = int(avail.get(k, 0)) + 1
			if av.has(-1):
				pent += 1
			if av.has(-2):
				court += 1
			_grave_size = used.size()
			_plays_made = t
			var best := _best_play(hand)
			# a decent player digs once when the hand is junk
			if discards > 0 and int(best["hand"]) <= Poker.Hand.PAIR:
				var keep := _keep_set(hand)
				var toss: Array = []
				for i in hand.size():
					if not keep.has(i):
						toss.append(i)
				if toss.size() > 0:
					toss = toss.slice(0, 5)
					toss.sort()
					toss.reverse()
					for i in toss:
						used.append(hand[i])
						hand.remove_at(i)
					hand = _refill(hand, draw, used)
					discards -= 1
					_grave_size = used.size()
					best = _best_play(hand)
			played[int(best["hand"])] = int(played.get(int(best["hand"]), 0)) + 1
			dmgs.append(int(best["dmg"]))
			var idx: Array = (best["idx"] as Array).duplicate()
			idx.sort()
			idx.reverse()
			for i in idx:
				used.append(hand[i])
				hand.remove_at(i)
			hand = _refill(hand, draw, used)
	_report(played, avail, dmgs, hands_seen, pent, court, turns)

## Keep the biggest aspect group and every card whose rank is paired -- the obvious dig.
func _keep_set(hand: Array) -> Dictionary:
	var asp := {}
	var rank := {}
	for i in hand.size():
		var c: CardData = hand[i]
		asp[c.aspect] = int(asp.get(c.aspect, 0)) + 1
		rank[c.rank] = int(rank.get(c.rank, 0)) + 1
	var top_a := -1
	var top_n := -1
	for a in asp:
		if int(asp[a]) > top_n:
			top_n = int(asp[a])
			top_a = int(a)
	var keep := {}
	for i in hand.size():
		var c: CardData = hand[i]
		if c.aspect == top_a or int(rank.get(c.rank, 0)) >= 2:
			keep[i] = true
	return keep

func _refill(hand: Array, draw: Array, used: Array) -> Array:
	while hand.size() < CombatController.HAND_SIZE:
		if draw.is_empty():
			if used.is_empty():
				break
			draw.append_array(used)      # deterministic recycle, order preserved
			used.clear()
		hand.append(draw.pop_front())
	return hand

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

func _report(played: Dictionary, avail: Dictionary, dmgs: Array, hands_seen: int,
		pent: int, court: int, turns: int) -> void:
	dmgs.sort()
	var n: int = dmgs.size()
	print("\n[deckmath] %d plays over %d turns/fight" % [n, turns])
	print("%-11s %10s %12s" % ["hand", "PLAYED", "AVAILABLE"])
	for h in Poker.Hand.values():
		var p: int = int(played.get(h, 0))
		var a: int = int(avail.get(h, 0))
		if p > 0 or a > 0:
			print("%-11s %9.2f%% %11.2f%%" % [HAND_NAMES[h], 100.0 * p / maxi(n, 1),
				100.0 * a / maxi(hands_seen, 1)])
	print("%-11s %9s   %11.2f%%" % ["PENTAGRAM", "-", 100.0 * pent / maxi(hands_seen, 1)])
	print("%-11s %9s   %11.2f%%" % ["FULL_COURT", "-", 100.0 * court / maxi(hands_seen, 1)])
	if n > 0:
		var p05: int = dmgs[int(0.05 * (n - 1))]
		var p50: int = dmgs[int(0.50 * (n - 1))]
		var p95: int = dmgs[int(0.95 * (n - 1))]
		print("\n[deckmath] damage/play: p05=%d  median=%d  p95=%d  max=%d" % [p05, p50, p95, dmgs[n - 1]])
		print("[deckmath] SWING p95/median = %.2fx   (a flat curve is a dead deckbuilder)" % (float(p95) / maxf(p50, 1.0)))
		print("[deckmath] 5-turn fight at the median: %d damage" % (5 * p50))
