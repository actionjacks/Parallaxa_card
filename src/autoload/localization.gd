extends Node
## Localization - global language switch and translated-string accessor.
##
## Responsibilities:
##   * own the notion of "the current language" for the whole game,
##   * persist that choice through Settings (section "game", key "language"),
##   * push it into TranslationServer so Godot's automatic `tr()` on Control.text works,
##   * emit `language_changed` so nodes that BUILD strings at runtime can rebuild them.
##
## Why a manager at all, when TranslationServer is already a singleton?
## Three reasons that TranslationServer alone does not cover:
##   1. Persistence - TranslationServer has no memory across runs; Settings does.
##   2. A change notification. Godot re-translates `Control.text` automatically via
##      NOTIFICATION_TRANSLATION_CHANGED, but any string composed in code
##      (e.g. "%d / %d" % [a, b], or a label built from a Resource field) is invisible to
##      that mechanism. `language_changed` is the hook those nodes subscribe to.
##   3. A single validated entry point. Setting an unsupported locale is a silent, very
##      confusing failure (everything falls back to keys); here it is caught and reported.
##
## Why `t()` instead of calling `tr()` everywhere?
## `tr()` cannot format, and a missing key returns the key itself with no diagnostic - the
## text simply looks like SETTINGS_TITLE on screen and nobody knows why. `t()` adds printf
## formatting and warns once per key, so a missing entry in ui.csv surfaces in the log the
## first time it is hit instead of being discovered in a screenshot.
##
## Source of truth for the strings is data/locale/ui.csv (header: keys,en,pl). Godot's
## importer turns it into ui.en.translation / ui.pl.translation, which must be registered in
## project.godot under internationalization/locale/translations. If that registration is
## missing, this manager still runs - every lookup just returns its key and warns.

signal language_changed(code: String)

const LANGUAGES := {"en": "English", "pl": "Polski"}

## Fallback whenever a stored or requested code is not in LANGUAGES.
const DEFAULT_LANGUAGE := "en"

## Settings coordinates for the persisted language. Duplicated as constants rather than
## inlined so a rename shows up in one place and matches the architecture table.
const SETTINGS_SECTION := "game"
const SETTINGS_KEY := "language"

var _language: String = DEFAULT_LANGUAGE

## Keys already reported as missing. Prevents a label inside _process() from spamming the
## log thousands of times per second with the same warning.
var _missing_keys: Dictionary = {}


func _ready() -> void:
	# Localization must keep resolving strings while the tree is paused (the settings menu
	# is typically opened with the game paused, and it is the main consumer of `t()`).
	process_mode = Node.PROCESS_MODE_ALWAYS

	var stored: Variant = _read_stored_language()
	var code := DEFAULT_LANGUAGE
	if stored is String and _is_supported(stored):
		code = stored
	elif stored != null and not (stored is String and stored.is_empty()):
		push_warning("Localization: stored language %s is not supported, falling back to '%s'." % [
			str(stored), DEFAULT_LANGUAGE,
		])

	# Apply without persisting: _ready() reflects what is already on disk, and writing back
	# here would overwrite a hand-edited settings.cfg before the user ever touched the menu.
	_apply_locale(code)
	_language = code
	language_changed.emit(_language)


## Switches the active language, persists it and notifies listeners.
## An unsupported code is refused (warning + no-op) rather than passed through to
## TranslationServer, which would silently leave the whole UI showing raw keys.
func set_language(code: String) -> void:
	if not _is_supported(code):
		push_warning("Localization: unsupported language code '%s'. Supported: %s." % [
			code, ", ".join(PackedStringArray(LANGUAGES.keys())),
		])
		return
	if code == _language:
		return

	_language = code
	_apply_locale(code)
	_write_stored_language(code)

	# A key missing in one language may exist in another, so the "already warned" set is
	# only valid for the language it was collected under.
	_missing_keys.clear()

	language_changed.emit(_language)


func get_language() -> String:
	return _language


## Human-readable name of a language, in that language ("Polski", not "Polish").
## Unknown codes are echoed back so a settings dropdown never renders an empty row.
func get_language_name(code: String) -> String:
	if LANGUAGES.has(code):
		return String(LANGUAGES[code])
	return code


## Translates `key` and applies printf-style formatting with `args`.
##
## Contract:
##   * missing key  -> returns the key itself and warns once (never returns an empty string,
##                     so layout problems never masquerade as translation problems),
##   * empty `args` -> plain translation, no formatting pass (a translation containing a
##                     literal '%' is then safe),
##   * bad format   -> returns the unformatted translation and warns; a malformed CSV entry
##                     must not take down the screen that renders it.
func t(key: String, args: Array = []) -> String:
	if key.is_empty():
		push_warning("Localization: t() called with an empty key.")
		return ""

	var text := String(tr(key))

	# `tr()` returns the key verbatim when no translation matches, which is also how a
	# missing translations entry in project.godot presents itself.
	if text == key and not _missing_keys.has(key):
		_missing_keys[key] = true
		push_warning("Localization: missing translation for key '%s' (locale '%s')." % [key, _language])

	if args.is_empty():
		return text

	# A mismatch between the placeholders in the translation and `args` makes GDScript's `%`
	# operator report an error and yield an empty string. That is treated as "formatting
	# failed" and the raw translation is returned, so the screen still shows something.
	var formatted := text % args
	if formatted.is_empty() and not text.is_empty():
		push_warning("Localization: format mismatch for key '%s' with %d argument(s)." % [key, args.size()])
		return text
	return formatted


## Codes this build can actually display, in declaration order - for the settings dropdown.
func get_supported_languages() -> PackedStringArray:
	var codes := PackedStringArray()
	for code: String in LANGUAGES.keys():
		codes.append(code)
	return codes


func _is_supported(code: String) -> bool:
	return LANGUAGES.has(code)


## Pushes the code into the engine. Kept as its own function because _ready() applies a
## locale WITHOUT persisting it, while set_language() applies AND persists - the difference
## between the two paths is exactly this call.
func _apply_locale(code: String) -> void:
	TranslationServer.set_locale(code)


## Settings is an earlier autoload, but this manager is also loaded by headless test scenes
## that may not have it. Every access is therefore guarded rather than assumed.
func _read_stored_language() -> Variant:
	var settings := _get_settings()
	if settings == null:
		return null
	if not settings.has_method("get_value"):
		push_warning("Localization: Settings autoload has no get_value(); language not restored.")
		return null
	return settings.get_value(SETTINGS_SECTION, SETTINGS_KEY, DEFAULT_LANGUAGE)


func _write_stored_language(code: String) -> void:
	var settings := _get_settings()
	if settings == null:
		return
	if not settings.has_method("set_value"):
		push_warning("Localization: Settings autoload has no set_value(); language not persisted.")
		return
	settings.set_value(SETTINGS_SECTION, SETTINGS_KEY, code)
	# `set_value` deliberately does not write to disk (see architecture contract), so the
	# language change is committed here - otherwise it would be lost on a hard quit.
	if settings.has_method("save_settings"):
		settings.save_settings()


func _get_settings() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Settings")
