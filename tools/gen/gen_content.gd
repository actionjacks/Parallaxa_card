extends SceneTree
## Content generator: writes authorable card .tres + starter deck + reward pool .tres.
## Run once (headless): tools/dev/run_hidden.sh is NOT needed; use:
##   godot --headless -s res://tools/gen/gen_content.gd
## Re-run to regenerate. Outputs are editor-first resources you can then tweak by hand.

const A := Aspects.Id
const KW := CardData.Keyword
const CARD_DIR := "res://data/cards/"
const DECK_DIR := "res://data/decks/"

func _initialize() -> void:
	_ensure(CARD_DIR)
	_ensure(DECK_DIR)
	var starter := _make(_starter(), "s")
	var pool := _make(_pool(), "p")
	_deck("starter", "DECK_STARTER", starter)
	_deck("reward_pool", "DECK_REWARD_POOL", pool)
	print("gen_content: starter=%d pool=%d cards written" % [starter.size(), pool.size()])
	quit(0)

func _ensure(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p):
		DirAccess.make_dir_recursive_absolute(p)

func _make(specs: Array, prefix: String) -> Array:
	var out: Array = []
	for i in specs.size():
		var s: Array = specs[i]
		var c := CardData.new()
		c.rank = s[0]
		c.aspect = s[1]
		c.keyword = s[2]
		c.keyword_value = s[3]
		var path := "%s%s_%02d.tres" % [CARD_DIR, prefix, i]
		ResourceSaver.save(c, path)
		out.append(load(path))
	return out

func _deck(id: String, name_key: String, cards: Array) -> void:
	var d := DeckData.new()
	d.name_key = name_key
	var typed: Array[CardData] = []
	for c in cards:
		typed.append(c)
	d.cards = typed
	ResourceSaver.save(d, "%s%s.tres" % [DECK_DIR, id])

func _starter() -> Array:
	return [
		[7, A.DEATH, KW.GNICIE, 3], [7, A.DEATH, KW.NONE, 0], [9, A.DEATH, KW.GNICIE, 4],
		[4, A.DEATH, KW.NONE, 0], [14, A.DEATH, KW.GNICIE, 5], [2, A.DEATH, KW.NONE, 0],
		[7, A.CHAOS, KW.NONE, 0], [5, A.CHAOS, KW.FURIA, 0], [9, A.CHAOS, KW.FURIA, 0],
		[12, A.CHAOS, KW.SPALENIE, 6],
		[7, A.LIFE, KW.OSLONA, 6], [3, A.LIFE, KW.NONE, 0], [14, A.LIFE, KW.OSLONA, 8],
		[6, A.LIFE, KW.OPATRZNOSC, 5],
		[7, A.MIND, KW.ECHO, 4], [8, A.NATURE, KW.BUJNOSC, 20],
	]

func _pool() -> Array:
	return [
		[10, A.DEATH, KW.ZNIWO, 1], [8, A.DEATH, KW.GNICIE, 4], [13, A.DEATH, KW.ZNIWO, 2],
		[6, A.CHAOS, KW.SPALENIE, 8], [10, A.CHAOS, KW.FURIA, 0], [6, A.CHAOS, KW.SPALENIE, 10],
		[5, A.LIFE, KW.OSLONA, 7], [9, A.LIFE, KW.OPATRZNOSC, 6],
		[11, A.MIND, KW.ECHO, 6], [13, A.MIND, KW.ECHO, 8],
		[7, A.NATURE, KW.BUJNOSC, 25], [10, A.NATURE, KW.BUJNOSC, 30],
	]
