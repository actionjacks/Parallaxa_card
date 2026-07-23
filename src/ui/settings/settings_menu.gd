class_name SettingsMenu
extends CanvasLayer
##
## In-game settings overlay, dressed as a Void_OS terminal window: VIDEO / AUDIO / INPUT / GAME
## tabs over a paused game.
##
## Why the whole tree is built in `_ready()` instead of being authored in the .tscn:
## this module is written in parallel with the managers it talks to, and a hand-authored
## scene drifts silently from the script that drives it (renamed node, changed order,
## a widget wired to nothing). Building the tree in code keeps exactly one source of
## truth, so a widget cannot exist without the handler that owns it.
##
## Why every manager is fetched with `get_node_or_null("/root/<Name>")` instead of the
## global autoload identifier: a missing or broken autoload would turn a direct reference
## into a hard parse/runtime failure and take the game down with it. The settings menu is
## an overlay -- it must degrade to "tab present, section disabled, warning logged" rather
## than crash the level it is drawn over.
##
## Apply semantics are deliberate: editing a widget only writes into `Settings`
## (`set_value` does not persist), so nothing touches the engine mid-edit. `Apply` is what
## saves and pushes the values into the engine. The status line counts the pending edits, so
## the state is never silently ambiguous. The one exception is audio: volume sliders preview
## live, because a volume slider you cannot hear is useless.
##
## Presentation notes:
##
## * The screen reads as a config file, not a game menu: every row is `key  # description`
##   with the value on the right. The left column shows the LITERAL `settings.cfg` key. That
##   is deliberate and not a missing translation -- a player who opens the file by hand sees
##   the same identifiers, and a bug report can name a key unambiguously in any language.
##   The human-readable name is the translated `#` comment next to it.
## * Colours come from `assets/ui/theme/ui_theme.tres` (installed globally via
##   `gui/theme/custom`). This script only adds local overrides for the window chrome the
##   theme has no control type for; it never assigns a theme of its own, which would cut the
##   whole subtree off from the project theme.
##

signal closed()

# --- Void_OS window chrome ---------------------------------------------------------------

## Title-bar text. A file path, not prose, so it is intentionally not a translation key --
## it names the backing store (`user://settings.cfg`) in the OS fiction and must read the
## same in every language, exactly like the config keys in the left column.
const WINDOW_TITLE := "[VOID_OS] /etc/settings.conf"

## Tab identifiers, shown verbatim as terminal cards. Same reasoning as WINDOW_TITLE: these
## are the tab names in the fiction; their translated captions live in the tooltips.
const TAB_IDS: Array[String] = ["video", "audio", "input", "game"]

## Translated caption per tab, index-aligned with TAB_IDS.
const TAB_LABEL_KEYS: Array[String] = [
	"SETTINGS_TAB_VIDEO", "SETTINGS_TAB_AUDIO", "SETTINGS_TAB_CONTROLS", "SETTINGS_TAB_GAME",
]

## Terminal caret blink period. Roughly a real VT cursor; slow enough not to draw the eye.
const CARET_BLINK_SECONDS := 0.53
const CARET_SIZE := Vector2(7, 14)

## Comment marker used in front of every human-readable description, like a real .conf file.
const COMMENT_PREFIX := "# "

## Indent in front of a key, so keys sit under their section header the way an INI file reads.
const KEY_INDENT := "  "

# --- Palette (from assets/ui/theme/ui_theme.tres -- do not invent new colours) -------------

const COLOR_WINDOW_BG := Color(0.118, 0.118, 0.118)
const COLOR_CHROME_BG := Color(0.145, 0.145, 0.145)
const COLOR_ACCENT := Color(0.0, 0.95, 1.0)
const COLOR_TEXT := Color(0.95, 0.95, 0.95)
## Comments and inactive chrome. Same hue as the text, just quieter -- a second colour here
## would fight the theme.
const COLOR_MUTED := Color(0.95, 0.95, 0.95, 0.45)
const COLOR_KEY := Color(0.0, 0.95, 1.0, 0.85)

## Alpha applied to a row whose master toggle is off, so a dead slider looks dead.
const DISABLED_ROW_ALPHA := 0.35

# --- Layout --------------------------------------------------------------------------------

const WINDOW_MIN_SIZE := Vector2(880, 620)
const VALUE_COLUMN_WIDTH := 300.0
const VALUE_LABEL_WIDTH := 64.0

## Suffix appended to the Apply button label while unsaved changes exist.
const DIRTY_MARK := "*"

## Internal render target height of the pixel-art path. Resolutions that are an integer
## multiple of it scale without moire, and the UI marks them (it never hides the others).
const INTEGER_SCALE_BASE_HEIGHT := 360

## Fallback list used only when `Settings.RESOLUTIONS` cannot be read.
const FALLBACK_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const MAX_FPS_PRESETS: Array[int] = [0, 30, 60, 75, 120, 144, 240]

const RENDER_SCALE_MIN := 0.5
const RENDER_SCALE_MAX := 2.0
const RENDER_SCALE_STEP := 0.05

## Value renderers for float sliders. The format is part of the row spec so the same slider
## builder serves render scale (`1.25x`), effect amounts (`45%`) and grades (`1.10`).
const FORMAT_SCALE := "scale"
const FORMAT_PERCENT := "percent"
const FORMAT_FACTOR := "factor"

## Bus name per audio settings key. Keys match the contract's `audio` section.
const AUDIO_ROWS: Array[Dictionary] = [
	{"key": "master", "bus": &"Master", "label": "SETTINGS_AUDIO_MASTER", "default": 1.0},
	{"key": "music", "bus": &"Music", "label": "SETTINGS_AUDIO_MUSIC", "default": 0.8},
	{"key": "sfx", "bus": &"SFX", "label": "SETTINGS_AUDIO_SFX", "default": 1.0},
]

var _settings: Node = null
var _localization: Node = null
var _audio: Node = null
var _input_manager: Node = null

# --- Widgets we need to read/write after construction. ---
var _root: Control = null
var _dim: ColorRect = null
var _title_label: Label = null
var _tabs: TabContainer = null
var _tab_strip: HBoxContainer = null
var _tab_buttons: Array[Button] = []
var _caret: ColorRect = null
var _caret_timer: Timer = null

var _status_hint: Label = null
var _status_version: Label = null
var _status_state: Label = null

var _resolution_option: OptionButton = null
var _integer_scale_hint: Label = null
var _window_mode_option: OptionButton = null
var _vsync_option: OptionButton = null
var _max_fps_option: OptionButton = null
var _msaa_option: OptionButton = null
var _shadow_option: OptionButton = null
var _language_option: OptionButton = null

## Generic float rows, keyed by "section/key". `_float_specs` drives the refresh loop, so a
## new slider needs exactly one `_add_slider_row` call and nothing else.
var _float_specs: Array[Dictionary] = []
var _float_sliders: Dictionary = {}       # String id -> HSlider
var _float_value_labels: Dictionary = {}  # String id -> Label
var _float_formats: Dictionary = {}       # String id -> one of the FORMAT_* constants

## Generic bool rows, same idea.
var _bool_specs: Array[Dictionary] = []
var _bool_checks: Dictionary = {}         # String id -> CheckBox

## Controls that only do something while `video/crt_enabled` is on. Greyed out otherwise:
## a slider that visibly moves but changes nothing reads as a broken menu.
var _crt_dependents: Array[Control] = []
## The sliders inside those rows, kept apart so they can be made read-only without being
## modulated a second time through their parent box.
var _crt_sliders: Array[HSlider] = []

var _audio_sliders: Dictionary = {}      # String key -> HSlider
var _audio_value_labels: Dictionary = {} # String key -> Label
var _binding_buttons: Dictionary = {}    # StringName action -> Button

var _apply_button: Button = null
var _reset_button: Button = null
var _close_button: Button = null

## Labels that are plain static translations, kept so a language switch can re-run them.
## Maps Control -> {"key": String, "prefix": String}.
var _static_texts: Dictionary = {}
## Control -> translation key, for tooltips that must survive a language switch.
var _static_tooltips: Dictionary = {}

## Guards the widget -> Settings -> widget feedback loop while we push values into the UI.
var _updating := false
## Set while this menu is the one writing to Settings, so our own `changed` echo does not
## re-read the value back into the widget the user is currently dragging.
var _writing := false
## Pending (unsaved) edits as a set of "section/key". A set rather than a flag, because the
## status line reports HOW MANY options are modified.
var _dirty_keys: Dictionary = {}

## Action currently waiting for a key press, or &"" when not rebinding.
var _rebinding_action: StringName = &""

var _is_open := false
var _pause_state_before_open := false
var _mouse_mode_before_open := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	# The overlay must keep running (and keep receiving input) while the tree is paused,
	# otherwise opening the menu would freeze the menu itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	_resolve_managers()
	_build_ui()
	_connect_managers()

	visible = false
	_is_open = false
	_refresh_texts()  # also populates options and pushes current values into the widgets


func _exit_tree() -> void:
	# A menu freed while open must not leave the game paused forever.
	if _is_open:
		var tree := get_tree()
		if tree != null:
			tree.paused = _pause_state_before_open


# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true

	var tree := get_tree()
	if tree != null:
		# Remember the previous pause state instead of assuming `false`: another system
		# (cutscene, dialogue) may already have paused the game.
		_pause_state_before_open = tree.paused
		tree.paused = true

	_mouse_mode_before_open = Input.mouse_mode
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_refresh_values()
	_set_caret_blinking(true)
	if _tabs != null:
		_tabs.grab_focus()


func close() -> void:
	if not _is_open:
		return
	_cancel_rebind()
	_is_open = false
	visible = false
	_set_caret_blinking(false)

	var tree := get_tree()
	if tree != null:
		tree.paused = _pause_state_before_open

	if Input.mouse_mode != _mouse_mode_before_open:
		Input.mouse_mode = _mouse_mode_before_open

	closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


# -----------------------------------------------------------------------------
# Input
# -----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Rebind capture runs in `_input` (before UI and before `_unhandled_input`) so the
	# pressed key is swallowed here and never reaches a focused button or the toggle below.
	if _rebinding_action == &"":
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		get_viewport().set_input_as_handled()
		if key_event.keycode == KEY_ESCAPE:
			_cancel_rebind()
		else:
			_finish_rebind(key_event)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		get_viewport().set_input_as_handled()
		_finish_rebind(mouse_event)
	elif event is InputEventJoypadButton:
		var pad_event := event as InputEventJoypadButton
		if not pad_event.pressed:
			return
		get_viewport().set_input_as_handled()
		_finish_rebind(pad_event)


func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_action != &"":
		return
	if not InputMap.has_action(&"ui_settings"):
		return
	if event.is_action_pressed(&"ui_settings"):
		get_viewport().set_input_as_handled()
		toggle()


# -----------------------------------------------------------------------------
# Manager access
# -----------------------------------------------------------------------------

func _resolve_managers() -> void:
	_settings = get_node_or_null(^"/root/Settings")
	_localization = get_node_or_null(^"/root/Localization")
	_audio = get_node_or_null(^"/root/AudioManager")
	_input_manager = get_node_or_null(^"/root/InputManager")

	if _settings == null:
		push_warning("SettingsMenu: autoload 'Settings' not found; settings will not persist.")
	if _localization == null:
		push_warning("SettingsMenu: autoload 'Localization' not found; showing raw keys.")
	if _audio == null:
		push_warning("SettingsMenu: autoload 'AudioManager' not found; audio tab is inert.")
	if _input_manager == null:
		push_warning("SettingsMenu: autoload 'InputManager' not found; controls tab is empty.")


func _connect_managers() -> void:
	if _localization != null and _localization.has_signal(&"language_changed"):
		_localization.language_changed.connect(_on_language_changed)
	if _settings != null and _settings.has_signal(&"changed"):
		_settings.changed.connect(_on_settings_changed)
	if _input_manager != null and _input_manager.has_signal(&"rebound"):
		_input_manager.rebound.connect(_on_action_rebound)


## Translation helper that survives a missing Localization autoload by echoing the key --
## a visible key is a usable bug report; an empty label is not.
func _t(key: String, args: Array = []) -> String:
	if _localization != null and _localization.has_method(&"t"):
		return String(_localization.t(key, args))
	if args.is_empty():
		return key
	return key % args


func _setting(section: String, key: String, fallback: Variant) -> Variant:
	if _settings == null or not _settings.has_method(&"get_value"):
		return fallback
	var value: Variant = _settings.get_value(section, key, fallback)
	if value == null:
		return fallback
	return value


## Type-checked reads. `user://settings.cfg` is deliberately hand-editable, so a value of
## the wrong type is a realistic input -- it must fall back, not raise an invalid cast.
func _setting_int(section: String, key: String, fallback: int) -> int:
	var value: Variant = _setting(section, key, fallback)
	if value is int or value is float or value is bool:
		return int(value)
	push_warning("SettingsMenu: %s/%s is not a number; using %d." % [section, key, fallback])
	return fallback


func _setting_float(section: String, key: String, fallback: float) -> float:
	var value: Variant = _setting(section, key, fallback)
	if value is int or value is float or value is bool:
		return float(value)
	push_warning("SettingsMenu: %s/%s is not a number; using %f." % [section, key, fallback])
	return fallback


func _setting_bool(section: String, key: String, fallback: bool) -> bool:
	var value: Variant = _setting(section, key, fallback)
	if value is bool or value is int or value is float:
		return bool(value)
	push_warning("SettingsMenu: %s/%s is not a bool; using %s." % [section, key, str(fallback)])
	return fallback


func _setting_vector2i(section: String, key: String, fallback: Vector2i) -> Vector2i:
	var value: Variant = _setting(section, key, fallback)
	if value is Vector2i:
		return value as Vector2i
	if value is Vector2:
		return Vector2i(value as Vector2)
	push_warning("SettingsMenu: %s/%s is not a Vector2i; using %s." % [section, key, fallback])
	return fallback


## Writes through to Settings without persisting, and records the edit for the status line.
func _set_setting(section: String, key: String, value: Variant) -> void:
	if _updating:
		return
	if _settings != null and _settings.has_method(&"set_value"):
		_writing = true
		_settings.set_value(section, key, value)
		_writing = false
	_mark_dirty(section + "/" + key)


## Reads a constant off an autoload's script. Going through the constant map (instead of
## `node.CONST`) means a manager that was rewritten without that constant degrades to the
## fallback instead of raising a runtime error.
func _script_constant(node: Node, constant_name: String, fallback: Variant) -> Variant:
	if node == null:
		return fallback
	var script := node.get_script() as Script
	if script == null:
		return fallback
	var constants := script.get_script_constant_map()
	if not constants.has(constant_name):
		return fallback
	var value: Variant = constants[constant_name]
	if value == null:
		return fallback
	return value


# -----------------------------------------------------------------------------
# UI construction
# -----------------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks meant for the game below
	add_child(_root)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var window := PanelContainer.new()
	window.name = "Window"
	window.custom_minimum_size = WINDOW_MIN_SIZE
	window.add_theme_stylebox_override("panel", _make_window_style())
	center.add_child(window)

	var column := VBoxContainer.new()
	column.name = "Column"
	# Zero separation: the title bar and status line must sit flush against the window edge
	# the way real window chrome does, and the sections below add their own spacing.
	column.add_theme_constant_override("separation", 0)
	window.add_child(column)

	column.add_child(_build_title_bar())
	column.add_child(_build_tab_strip())

	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The terminal cards above ARE the tab bar; the built-in one would be a second, differently
	# styled row of the same thing.
	_tabs.tabs_visible = false
	# Explicit focus mode: `open()` grabs focus here for keyboard navigation, and grabbing
	# focus on a FOCUS_NONE control logs an error every time the menu is opened.
	_tabs.focus_mode = Control.FOCUS_ALL
	_tabs.add_theme_stylebox_override("panel", _make_body_style())
	column.add_child(_tabs)

	_build_video_tab(_tabs)
	_build_audio_tab(_tabs)
	_build_controls_tab(_tabs)
	_build_game_tab(_tabs)

	column.add_child(_build_action_bar())
	column.add_child(_build_status_bar())

	_caret_timer = Timer.new()
	_caret_timer.name = "CaretBlink"
	_caret_timer.wait_time = CARET_BLINK_SECONDS
	_caret_timer.timeout.connect(_on_caret_blink)
	_root.add_child(_caret_timer)

	_set_current_tab(0)


# --- Window chrome ---------------------------------------------------------------------

func _make_window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_WINDOW_BG
	style.border_color = COLOR_ACCENT
	style.set_border_width_all(1)
	# Square corners on purpose: this is a tiling-WM window, and a rounded game panel would
	# undo the whole Void_OS read.
	style.set_corner_radius_all(0)
	style.set_content_margin_all(0)
	return style


func _make_chrome_style(border_bottom: int, border_top: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CHROME_BG
	style.border_color = COLOR_ACCENT
	style.border_width_bottom = border_bottom
	style.border_width_top = border_top
	style.set_corner_radius_all(0)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _make_body_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_WINDOW_BG
	style.set_corner_radius_all(0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _make_tab_card_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_WINDOW_BG if active else COLOR_CHROME_BG
	style.border_color = COLOR_ACCENT
	# Only the active card gets the underline, so the selection is readable at a glance
	# without relying on the text colour alone.
	style.border_width_bottom = 2 if active else 0
	style.set_corner_radius_all(0)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _build_title_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "TitleBar"
	bar.add_theme_stylebox_override("panel", _make_chrome_style(1, 0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = WINDOW_TITLE
	_title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title_label)

	# Minimise/maximise are chrome, not features: this overlay has one size and one way out.
	# They are drawn muted so they read as part of the window frame rather than dead buttons.
	for glyph: String in ["[-]", "[o]"]:
		var decoration := Label.new()
		decoration.text = glyph
		decoration.add_theme_color_override("font_color", COLOR_MUTED)
		decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(decoration)

	var close_glyph := Button.new()
	close_glyph.name = "TitleClose"
	close_glyph.text = "[x]"
	close_glyph.flat = true
	close_glyph.add_theme_color_override("font_color", COLOR_TEXT)
	close_glyph.add_theme_color_override("font_hover_color", COLOR_ACCENT)
	close_glyph.pressed.connect(close)
	_register_tooltip(close_glyph, "SETTINGS_CLOSE")
	row.add_child(close_glyph)

	return bar


func _build_tab_strip() -> Control:
	var bar := PanelContainer.new()
	bar.name = "TabStrip"
	bar.add_theme_stylebox_override("panel", _make_chrome_style(1, 0))

	_tab_strip = HBoxContainer.new()
	_tab_strip.add_theme_constant_override("separation", 4)
	bar.add_child(_tab_strip)

	var prompt := Label.new()
	prompt.text = "tab:"
	prompt.add_theme_color_override("font_color", COLOR_MUTED)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_strip.add_child(prompt)

	_tab_buttons.clear()
	for i: int in TAB_IDS.size():
		if i > 0:
			var pipe := Label.new()
			pipe.text = "|"
			pipe.add_theme_color_override("font_color", COLOR_MUTED)
			pipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_tab_strip.add_child(pipe)

		var card := Button.new()
		card.name = "Tab_" + TAB_IDS[i]
		card.text = TAB_IDS[i]
		card.focus_mode = Control.FOCUS_NONE  # the TabContainer owns keyboard focus
		card.pressed.connect(_set_current_tab.bind(i))
		_register_tooltip(card, TAB_LABEL_KEYS[i])
		_tab_strip.add_child(card)
		_tab_buttons.append(card)

	# The blinking block marks which card is live. It is a ColorRect and not a text glyph
	# because the pixel font has no guaranteed full-block character.
	_caret = ColorRect.new()
	_caret.name = "Caret"
	_caret.color = COLOR_ACCENT
	_caret.custom_minimum_size = CARET_SIZE
	_caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_strip.add_child(_caret)

	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_strip.add_child(filler)

	return bar


func _build_action_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "Actions"
	bar.add_theme_stylebox_override("panel", _make_chrome_style(0, 1))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	_reset_button = Button.new()
	_reset_button.pressed.connect(_on_reset_pressed)
	row.add_child(_reset_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_apply_button = Button.new()
	_apply_button.pressed.connect(_on_apply_pressed)
	row.add_child(_apply_button)

	_close_button = Button.new()
	_close_button.pressed.connect(close)
	row.add_child(_close_button)

	return bar


func _build_status_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "StatusBar"
	bar.add_theme_stylebox_override("panel", _make_chrome_style(0, 1))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	_status_hint = Label.new()
	_status_hint.add_theme_color_override("font_color", COLOR_MUTED)
	_status_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status_hint)

	_status_version = Label.new()
	_status_version.text = _build_version_text()
	_status_version.add_theme_color_override("font_color", COLOR_MUTED)
	row.add_child(_status_version)

	_status_state = Label.new()
	_status_state.add_theme_color_override("font_color", COLOR_ACCENT)
	row.add_child(_status_state)

	return bar


## Version string for the status line. A build identifier, not prose -- never translated.
func _build_version_text() -> String:
	var raw: Variant = ProjectSettings.get_setting("application/config/version", "")
	var version := String(raw)
	if version.is_empty():
		return "v0"
	return "v" + version


# --- Rows and sections -----------------------------------------------------------------

## Every tab is a scrollable column of sections. Scrolling is not optional here: the video
## tab alone is over twenty rows and would clip on a 720p window.
func _make_tab_page(parent: TabContainer, node_name: String) -> VBoxContainer:
	var page := ScrollContainer.new()
	page.name = node_name
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(page)

	var column := VBoxContainer.new()
	column.name = "Sections"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	page.add_child(column)
	return column


## Opens an INI-style section (`[display]  # Display`) and returns the grid its rows go into.
func _begin_section(column: VBoxContainer, section_id: String, label_key: String) -> GridContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)

	var name_label := Label.new()
	name_label.text = "[%s]" % section_id
	name_label.add_theme_color_override("font_color", COLOR_ACCENT)
	header.add_child(name_label)

	var comment := Label.new()
	comment.add_theme_color_override("font_color", COLOR_MUTED)
	comment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_register_text(comment, label_key, COMMENT_PREFIX)
	header.add_child(comment)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	return grid


## Adds `  key  # description` on the left and `control` on the right. Returns every control
## in the row so callers can grey the whole line out together.
func _add_row(grid: GridContainer, key_name: String, label_key: String, control: Control) -> Array[Control]:
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var key_label := Label.new()
	key_label.text = KEY_INDENT + key_name
	key_label.add_theme_color_override("font_color", COLOR_KEY)
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(key_label)

	var comment := Label.new()
	comment.add_theme_color_override("font_color", COLOR_MUTED)
	comment.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	comment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_register_text(comment, label_key, COMMENT_PREFIX)
	left.add_child(comment)

	grid.add_child(left)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, VALUE_COLUMN_WIDTH)
	grid.add_child(control)

	var row: Array[Control] = [key_label, comment, control]
	return row


## Spans a single control across both grid columns (hints, empty-state notices).
func _add_full_width(grid: GridContainer, control: Control) -> void:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(spacer)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


## Builds a float row and registers it for the generic refresh loop.
func _add_slider_row(
	grid: GridContainer,
	section: String,
	key: String,
	label_key: String,
	minimum: float,
	maximum: float,
	step: float,
	value_format: String,
	fallback: float
) -> Array[Control]:
	var id := section + "/" + key

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_float_slider_changed.bind(id))
	box.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = VALUE_LABEL_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(value_label)

	_float_sliders[id] = slider
	_float_value_labels[id] = value_label
	_float_formats[id] = value_format
	_float_specs.append({
		"id": id,
		"section": section,
		"key": key,
		"min": minimum,
		"max": maximum,
		"default": fallback,
	})

	var row := _add_row(grid, key, label_key, box)
	row.append(slider)
	row.append(value_label)
	return row


## Builds a bool row and registers it for the generic refresh loop.
func _add_check_row(
	grid: GridContainer, section: String, key: String, label_key: String, fallback: bool
) -> Array[Control]:
	var id := section + "/" + key

	var check := CheckBox.new()
	# The caption sits in the left column like every other row; a second label on the box
	# itself would print the same name twice.
	check.text = ""
	check.toggled.connect(_on_bool_toggled.bind(id))

	_bool_checks[id] = check
	_bool_specs.append({"id": id, "section": section, "key": key, "default": fallback})

	return _add_row(grid, key, label_key, check)


func _build_video_tab(parent: TabContainer) -> void:
	var column := _make_tab_page(parent, "Video")

	# --- display ---
	var display := _begin_section(column, "display", "SETTINGS_SECTION_DISPLAY")

	_resolution_option = OptionButton.new()
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_add_row(display, "resolution", "SETTINGS_VIDEO_RESOLUTION", _resolution_option)

	_integer_scale_hint = Label.new()
	_integer_scale_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_integer_scale_hint.add_theme_color_override("font_color", COLOR_MUTED)
	_register_text(_integer_scale_hint, "SETTINGS_VIDEO_INTEGER_SCALE_HINT", COMMENT_PREFIX)
	_add_full_width(display, _integer_scale_hint)

	_window_mode_option = OptionButton.new()
	_window_mode_option.item_selected.connect(_on_window_mode_selected)
	_add_row(display, "window_mode", "SETTINGS_VIDEO_WINDOW_MODE", _window_mode_option)

	_vsync_option = OptionButton.new()
	_vsync_option.item_selected.connect(_on_vsync_selected)
	_add_row(display, "vsync", "SETTINGS_VIDEO_VSYNC", _vsync_option)

	_max_fps_option = OptionButton.new()
	_max_fps_option.item_selected.connect(_on_max_fps_selected)
	_add_row(display, "max_fps", "SETTINGS_VIDEO_MAX_FPS", _max_fps_option)

	# --- quality ---
	var quality := _begin_section(column, "quality", "SETTINGS_SECTION_QUALITY")

	_msaa_option = OptionButton.new()
	_msaa_option.item_selected.connect(_on_msaa_selected)
	_add_row(quality, "msaa", "SETTINGS_VIDEO_MSAA", _msaa_option)

	_shadow_option = OptionButton.new()
	_shadow_option.item_selected.connect(_on_shadow_quality_selected)
	_add_row(quality, "shadow_quality", "SETTINGS_VIDEO_SHADOW_QUALITY", _shadow_option)

	_add_slider_row(
		quality, "video", "render_scale", "SETTINGS_VIDEO_RENDER_SCALE",
		RENDER_SCALE_MIN, RENDER_SCALE_MAX, RENDER_SCALE_STEP, FORMAT_SCALE, 1.0
	)
	_add_slider_row(
		quality, "video", "sharpen", "SETTINGS_VIDEO_SHARPEN",
		0.0, 1.0, 0.01, FORMAT_PERCENT, 0.0
	)
	_add_check_row(quality, "video", "ssao_enabled", "SETTINGS_VIDEO_SSAO", false)
	_add_check_row(quality, "video", "bloom_enabled", "SETTINGS_VIDEO_BLOOM", true)
	_add_slider_row(
		quality, "video", "bloom_strength", "SETTINGS_VIDEO_BLOOM_STRENGTH",
		0.0, 1.0, 0.01, FORMAT_PERCENT, 0.25
	)
	_add_check_row(quality, "video", "fog_enabled", "SETTINGS_VIDEO_FOG", false)

	# --- crt ---
	# No screen curvature anywhere in this block, by explicit request: scanlines, aperture
	# mask, aberration, vignette and flicker only. The image stays rectangular and full-bleed.
	var crt := _begin_section(column, "crt", "SETTINGS_SECTION_CRT")
	_add_check_row(crt, "video", "crt_enabled", "SETTINGS_VIDEO_CRT_ENABLED", false)

	_crt_dependents.clear()
	_crt_sliders.clear()
	# Untyped on purpose: an `Array[Array]` refuses to hold the `Array[Control]` rows.
	var crt_rows: Array = [
		_add_slider_row(
			crt, "video", "crt_scanlines", "SETTINGS_VIDEO_CRT_SCANLINES",
			0.0, 1.0, 0.01, FORMAT_PERCENT, 0.35
		),
		_add_slider_row(
			crt, "video", "crt_aberration", "SETTINGS_VIDEO_CRT_ABERRATION",
			0.0, 1.0, 0.01, FORMAT_PERCENT, 0.25
		),
		_add_slider_row(
			crt, "video", "crt_vignette", "SETTINGS_VIDEO_CRT_VIGNETTE",
			0.0, 1.0, 0.01, FORMAT_PERCENT, 0.30
		),
		_add_slider_row(
			crt, "video", "crt_mask", "SETTINGS_VIDEO_CRT_MASK",
			0.0, 1.0, 0.01, FORMAT_PERCENT, 0.25
		),
		_add_slider_row(
			crt, "video", "crt_flicker", "SETTINGS_VIDEO_CRT_FLICKER",
			0.0, 1.0, 0.01, FORMAT_PERCENT, 0.15
		),
	]
	# `_add_slider_row` returns [key_label, comment, box, slider, value_label]. Only the first
	# three get modulated: the slider and its readout live inside `box`, and modulating them
	# too would multiply the alpha and fade the row almost to nothing.
	for row: Array in crt_rows:
		for i: int in mini(3, row.size()):
			_crt_dependents.append(row[i] as Control)
		if row.size() > 3 and row[3] is HSlider:
			_crt_sliders.append(row[3] as HSlider)

	# --- color ---
	var color := _begin_section(column, "color", "SETTINGS_SECTION_COLOR")
	_add_slider_row(
		color, "video", "brightness", "SETTINGS_VIDEO_BRIGHTNESS",
		0.5, 1.5, 0.01, FORMAT_FACTOR, 1.0
	)
	_add_slider_row(
		color, "video", "contrast", "SETTINGS_VIDEO_CONTRAST",
		0.5, 1.5, 0.01, FORMAT_FACTOR, 1.0
	)
	_add_slider_row(
		color, "video", "saturation", "SETTINGS_VIDEO_SATURATION",
		0.0, 2.0, 0.01, FORMAT_FACTOR, 1.0
	)


func _build_audio_tab(parent: TabContainer) -> void:
	var column := _make_tab_page(parent, "Audio")
	var grid := _begin_section(column, "audio", "SETTINGS_TAB_AUDIO")

	for row: Dictionary in AUDIO_ROWS:
		var key: String = row["key"]
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 10)

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_volume_changed.bind(key))
		box.add_child(slider)

		var value_label := Label.new()
		value_label.custom_minimum_size.x = VALUE_LABEL_WIDTH
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(value_label)

		_audio_sliders[key] = slider
		_audio_value_labels[key] = value_label
		_add_row(grid, key, String(row["label"]), box)


func _build_controls_tab(parent: TabContainer) -> void:
	var column := _make_tab_page(parent, "Controls")
	var grid := _begin_section(column, "input", "SETTINGS_TAB_CONTROLS")

	var actions := _get_rebindable_actions()
	if actions.is_empty():
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", COLOR_MUTED)
		_register_text(empty, "SETTINGS_CONTROLS_UNAVAILABLE", COMMENT_PREFIX)
		_add_full_width(grid, empty)
		return

	for action: StringName in actions:
		var button := Button.new()
		button.clip_text = true
		button.pressed.connect(_on_rebind_pressed.bind(action))
		_binding_buttons[action] = button
		# Action label keys follow the action name: `move_up` -> SETTINGS_ACTION_MOVE_UP.
		_add_row(grid, String(action), "SETTINGS_ACTION_" + String(action).to_upper(), button)


func _build_game_tab(parent: TabContainer) -> void:
	var column := _make_tab_page(parent, "Game")
	var grid := _begin_section(column, "game", "SETTINGS_TAB_GAME")

	_language_option = OptionButton.new()
	_language_option.item_selected.connect(_on_language_selected)
	_add_row(grid, "language", "SETTINGS_GAME_LANGUAGE", _language_option)


# -----------------------------------------------------------------------------
# Tabs and caret
# -----------------------------------------------------------------------------

func _set_current_tab(index: int) -> void:
	if _tabs == null or index < 0 or index >= _tabs.get_tab_count():
		return
	_tabs.current_tab = index

	for i: int in _tab_buttons.size():
		var card := _tab_buttons[i]
		if not is_instance_valid(card):
			continue
		var active := i == index
		var style := _make_tab_card_style(active)
		# All four states get the same box: a card that changes shape under the pointer reads
		# as a button, and these are supposed to read as terminal tabs.
		for state: String in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(state, style)
		card.add_theme_color_override("font_color", COLOR_ACCENT if active else COLOR_MUTED)
		card.add_theme_color_override("font_hover_color", COLOR_ACCENT if active else COLOR_TEXT)
		card.add_theme_color_override("font_pressed_color", COLOR_ACCENT)

	# Park the caret right after the live card, so it reads as a prompt sitting on it.
	if _caret != null and _tab_strip != null and index < _tab_buttons.size():
		var anchor := _tab_buttons[index]
		if is_instance_valid(anchor):
			_tab_strip.move_child(_caret, anchor.get_index() + 1)
		_caret.visible = true


func _set_caret_blinking(active: bool) -> void:
	if _caret_timer == null:
		return
	if active:
		if _caret != null:
			_caret.visible = true
		_caret_timer.start()
	else:
		_caret_timer.stop()


func _on_caret_blink() -> void:
	if _caret != null:
		_caret.visible = not _caret.visible


# -----------------------------------------------------------------------------
# Text refresh (runs on ready and on every language change)
# -----------------------------------------------------------------------------

## Records a label whose text is a translation, optionally behind a fixed prefix such as the
## `#` comment marker. Storing the prefix here keeps `_refresh_texts` a single loop.
func _register_text(control: Control, key: String, prefix: String = "") -> void:
	_static_texts[control] = {"key": key, "prefix": prefix}


func _register_tooltip(control: Control, key: String) -> void:
	_static_tooltips[control] = key


func _refresh_texts() -> void:
	for control: Control in _static_texts.keys():
		if not is_instance_valid(control):
			_static_texts.erase(control)
			continue
		var entry: Dictionary = _static_texts[control]
		var text: String = String(entry["prefix"]) + _t(String(entry["key"]))
		if control is Label:
			(control as Label).text = text
		elif control is Button:
			(control as Button).text = text

	for control: Control in _static_tooltips.keys():
		if not is_instance_valid(control):
			_static_tooltips.erase(control)
			continue
		control.tooltip_text = _t(String(_static_tooltips[control]))

	if _reset_button != null:
		_reset_button.text = _t("SETTINGS_RESET")
	if _close_button != null:
		_close_button.text = _t("SETTINGS_CLOSE")
	if _status_hint != null:
		_status_hint.text = _t("SETTINGS_STATUS_HINT")
	_update_apply_button()
	_update_status_state()

	# Enum item captions are translated strings too, so they must be rebuilt here.
	_populate_static_options()
	_refresh_binding_labels()
	_refresh_values()


func _update_apply_button() -> void:
	if _apply_button == null:
		return
	var text := _t("SETTINGS_APPLY")
	if _dirty_keys.is_empty():
		_apply_button.text = text
		_apply_button.tooltip_text = ""
	else:
		_apply_button.text = text + " " + DIRTY_MARK
		_apply_button.tooltip_text = _t("SETTINGS_UNSAVED")


func _update_status_state() -> void:
	if _status_state == null:
		return
	var count := _dirty_keys.size()
	if count == 0:
		_status_state.text = _t("SETTINGS_STATUS_CLEAN")
		_status_state.add_theme_color_override("font_color", COLOR_MUTED)
	else:
		_status_state.text = _t("SETTINGS_STATUS_MODIFIED", [count])
		_status_state.add_theme_color_override("font_color", COLOR_ACCENT)


func _mark_dirty(id: String) -> void:
	if _dirty_keys.has(id):
		return
	_dirty_keys[id] = true
	_update_apply_button()
	_update_status_state()


func _clear_dirty() -> void:
	if _dirty_keys.is_empty():
		return
	_dirty_keys.clear()
	_update_apply_button()
	_update_status_state()


# -----------------------------------------------------------------------------
# Option population
# -----------------------------------------------------------------------------

func _populate_static_options() -> void:
	_populate_resolutions()
	_populate_enum(_window_mode_option, [
		"SETTINGS_VIDEO_WINDOW_MODE_WINDOWED",
		"SETTINGS_VIDEO_WINDOW_MODE_BORDERLESS",
		"SETTINGS_VIDEO_WINDOW_MODE_FULLSCREEN",
	])
	_populate_enum(_vsync_option, [
		"SETTINGS_VIDEO_VSYNC_DISABLED",
		"SETTINGS_VIDEO_VSYNC_ENABLED",
		"SETTINGS_VIDEO_VSYNC_ADAPTIVE",
		"SETTINGS_VIDEO_VSYNC_MAILBOX",
	])
	_populate_enum(_msaa_option, [
		"SETTINGS_VIDEO_MSAA_OFF",
		"SETTINGS_VIDEO_MSAA_2X",
		"SETTINGS_VIDEO_MSAA_4X",
		"SETTINGS_VIDEO_MSAA_8X",
	])
	_populate_enum(_shadow_option, [
		"SETTINGS_VIDEO_SHADOW_OFF",
		"SETTINGS_VIDEO_SHADOW_LOW",
		"SETTINGS_VIDEO_SHADOW_MEDIUM",
		"SETTINGS_VIDEO_SHADOW_HIGH",
	])
	_populate_max_fps()
	_populate_languages()


## Fills an OptionButton where item index == stored enum value, so no lookup table is
## needed anywhere else in this file.
func _populate_enum(option: OptionButton, keys: Array) -> void:
	if option == null:
		return
	option.clear()
	for i: int in keys.size():
		option.add_item(_t(String(keys[i])), i)


func _populate_resolutions() -> void:
	if _resolution_option == null:
		return
	_resolution_option.clear()
	var resolutions := _get_resolutions()
	for i: int in resolutions.size():
		_add_resolution_item(resolutions[i])


## The selected resolution is read back from item metadata rather than from the item index,
## because `_refresh_values` may append one extra item for a value that is not in the list.
func _add_resolution_item(res: Vector2i) -> void:
	var caption := "%d x %d" % [res.x, res.y]
	if res.y % INTEGER_SCALE_BASE_HEIGHT == 0:
		caption += " " + _t("SETTINGS_VIDEO_INTEGER_SCALE_SUFFIX", [res.y / INTEGER_SCALE_BASE_HEIGHT])
	_resolution_option.add_item(caption)
	_resolution_option.set_item_metadata(_resolution_option.item_count - 1, res)


func _populate_max_fps() -> void:
	if _max_fps_option == null:
		return
	_max_fps_option.clear()
	for i: int in MAX_FPS_PRESETS.size():
		var fps := MAX_FPS_PRESETS[i]
		var caption := _t("SETTINGS_VIDEO_MAX_FPS_UNCAPPED") if fps == 0 else str(fps)
		_max_fps_option.add_item(caption, fps)


func _populate_languages() -> void:
	if _language_option == null:
		return
	_language_option.clear()
	var languages := _get_languages()
	var codes := languages.keys()
	codes.sort()
	for i: int in codes.size():
		var code: String = String(codes[i])
		var display_name := String(languages[code])
		if _localization != null and _localization.has_method(&"get_language_name"):
			var resolved := String(_localization.get_language_name(code))
			if not resolved.is_empty():
				display_name = resolved
		_language_option.add_item(display_name, i)
		_language_option.set_item_metadata(i, code)


func _get_resolutions() -> Array[Vector2i]:
	var raw: Variant = _script_constant(_settings, "RESOLUTIONS", FALLBACK_RESOLUTIONS)
	var out: Array[Vector2i] = []
	if raw is Array:
		for entry: Variant in raw as Array:
			if entry is Vector2i:
				out.append(entry as Vector2i)
	if out.is_empty():
		return FALLBACK_RESOLUTIONS
	return out


func _get_languages() -> Dictionary:
	var raw: Variant = _script_constant(_localization, "LANGUAGES", {})
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		return raw as Dictionary
	return {"en": "English", "pl": "Polski"}


func _get_rebindable_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	if _input_manager == null or not _input_manager.has_method(&"get_rebindable_actions"):
		return out
	var raw: Variant = _input_manager.get_rebindable_actions()
	if raw is Array:
		for entry: Variant in raw as Array:
			out.append(StringName(entry))
	return out


# -----------------------------------------------------------------------------
# Value refresh (Settings -> widgets)
# -----------------------------------------------------------------------------

func _refresh_values() -> void:
	_updating = true

	var resolution := _setting_vector2i("video", "resolution", Vector2i(1280, 720))
	if _resolution_option != null:
		var resolutions := _get_resolutions()
		# Rebuild first: this method runs on every `changed` signal, and appending without
		# resetting would grow the list by one item per refresh.
		if _resolution_option.item_count != resolutions.size():
			_populate_resolutions()
		var index := resolutions.find(resolution)
		# An out-of-list resolution (hand-edited settings.cfg) is shown as-is rather than
		# silently snapped to a neighbour, so the user can see what is actually set.
		if index == -1:
			_add_resolution_item(resolution)
			index = _resolution_option.item_count - 1
		_resolution_option.select(index)

	_select_by_index(_window_mode_option, _setting_int("video", "window_mode", 0))
	_select_by_index(_vsync_option, _setting_int("video", "vsync", 1))
	_select_by_index(_msaa_option, _setting_int("video", "msaa", 0))
	_select_by_index(_shadow_option, _setting_int("video", "shadow_quality", 2))

	if _max_fps_option != null:
		var max_fps := maxi(0, _setting_int("video", "max_fps", 0))
		if _max_fps_option.item_count != MAX_FPS_PRESETS.size():
			_populate_max_fps()
		var fps_index := MAX_FPS_PRESETS.find(max_fps)
		if fps_index == -1:
			# A cap that is not one of our presets stays visible instead of being rounded.
			_max_fps_option.add_item(str(max_fps), max_fps)
			fps_index = _max_fps_option.item_count - 1
		_max_fps_option.select(fps_index)

	for spec: Dictionary in _float_specs:
		var id: String = spec["id"]
		var slider := _float_sliders.get(id) as HSlider
		if slider == null:
			continue
		var value := clampf(
			_setting_float(String(spec["section"]), String(spec["key"]), float(spec["default"])),
			float(spec["min"]),
			float(spec["max"])
		)
		slider.value = value
		_update_float_label(id, value)

	for spec: Dictionary in _bool_specs:
		var id: String = spec["id"]
		var check := _bool_checks.get(id) as CheckBox
		if check == null:
			continue
		check.button_pressed = _setting_bool(
			String(spec["section"]), String(spec["key"]), bool(spec["default"])
		)

	for row: Dictionary in AUDIO_ROWS:
		var key: String = row["key"]
		var slider := _audio_sliders.get(key) as HSlider
		if slider == null:
			continue
		var volume := clampf(_setting_float("audio", key, float(row["default"])), 0.0, 1.0)
		slider.value = volume
		_update_volume_label(key, volume)

	if _language_option != null:
		var current := "en"
		if _localization != null and _localization.has_method(&"get_language"):
			current = String(_localization.get_language())
		else:
			current = String(_setting("game", "language", "en"))
		for i: int in _language_option.item_count:
			if String(_language_option.get_item_metadata(i)) == current:
				_language_option.select(i)
				break

	_updating = false
	_update_crt_dependents()


func _select_by_index(option: OptionButton, index: int) -> void:
	if option == null:
		return
	if index < 0 or index >= option.item_count:
		return
	option.select(index)


func _update_float_label(id: String, value: float) -> void:
	var label := _float_value_labels.get(id) as Label
	if label == null:
		return
	var value_format := String(_float_formats.get(id, FORMAT_FACTOR))
	match value_format:
		FORMAT_SCALE:
			label.text = "%.2fx" % value
		FORMAT_PERCENT:
			label.text = "%d%%" % roundi(value * 100.0)
		_:
			label.text = "%.2f" % value


## Greys out every CRT slider while the master toggle is off. Without this the sliders still
## move and still save, and the effect never appears -- which reads as a broken menu.
func _update_crt_dependents() -> void:
	var enabled := _setting_bool("video", "crt_enabled", false)
	var check := _bool_checks.get("video/crt_enabled") as CheckBox
	if check != null:
		enabled = check.button_pressed
	var alpha := 1.0 if enabled else DISABLED_ROW_ALPHA
	for control: Control in _crt_dependents:
		if is_instance_valid(control):
			control.modulate = Color(1, 1, 1, alpha)
	for slider: HSlider in _crt_sliders:
		if is_instance_valid(slider):
			slider.editable = enabled


func _update_volume_label(key: String, linear: float) -> void:
	var label := _audio_value_labels.get(key) as Label
	if label != null:
		label.text = "%d%%" % roundi(linear * 100.0)


func _refresh_binding_labels() -> void:
	for action: StringName in _binding_buttons.keys():
		var button := _binding_buttons[action] as Button
		if button == null or not is_instance_valid(button):
			continue
		if action == _rebinding_action:
			continue
		button.text = _binding_label(action)


func _binding_label(action: StringName) -> String:
	if _input_manager != null and _input_manager.has_method(&"get_binding_label"):
		var label := String(_input_manager.get_binding_label(action))
		if not label.is_empty():
			return label
	return _t("SETTINGS_CONTROLS_UNBOUND")


# -----------------------------------------------------------------------------
# Widget handlers (widgets -> Settings)
# -----------------------------------------------------------------------------

func _on_resolution_selected(index: int) -> void:
	if _resolution_option == null or index < 0 or index >= _resolution_option.item_count:
		return
	var value: Variant = _resolution_option.get_item_metadata(index)
	if value is Vector2i:
		_set_setting("video", "resolution", value as Vector2i)


func _on_window_mode_selected(index: int) -> void:
	_set_setting("video", "window_mode", index)


func _on_vsync_selected(index: int) -> void:
	_set_setting("video", "vsync", index)


func _on_msaa_selected(index: int) -> void:
	_set_setting("video", "msaa", index)


func _on_shadow_quality_selected(index: int) -> void:
	_set_setting("video", "shadow_quality", index)


func _on_max_fps_selected(index: int) -> void:
	if _max_fps_option == null or index < 0 or index >= _max_fps_option.item_count:
		return
	# The item id carries the FPS value, so unlisted values added at refresh time work too.
	_set_setting("video", "max_fps", _max_fps_option.get_item_id(index))


func _on_float_slider_changed(value: float, id: String) -> void:
	_update_float_label(id, value)
	if _updating:
		return
	var parts := id.split("/", false, 1)
	if parts.size() != 2:
		push_warning("SettingsMenu: malformed slider id '%s'." % id)
		return
	_set_setting(parts[0], parts[1], value)


func _on_bool_toggled(pressed: bool, id: String) -> void:
	if _updating:
		return
	var parts := id.split("/", false, 1)
	if parts.size() != 2:
		push_warning("SettingsMenu: malformed checkbox id '%s'." % id)
		return
	_set_setting(parts[0], parts[1], pressed)
	if id == "video/crt_enabled":
		_update_crt_dependents()


func _on_volume_changed(value: float, key: String) -> void:
	_update_volume_label(key, value)
	if _updating:
		return
	_set_setting("audio", key, value)
	# Preview immediately: a volume slider with no audible response is unusable.
	if _audio != null and _audio.has_method(&"set_bus_volume"):
		for row: Dictionary in AUDIO_ROWS:
			if row["key"] == key:
				_audio.set_bus_volume(row["bus"], value)
				break


func _on_language_selected(index: int) -> void:
	if _updating or _language_option == null:
		return
	if index < 0 or index >= _language_option.item_count:
		return
	var metadata: Variant = _language_option.get_item_metadata(index)
	if not (metadata is String) or (metadata as String).is_empty():
		return
	var code := metadata as String
	if _localization != null and _localization.has_method(&"set_language"):
		# set_language persists through Settings itself, so this is not a dirty change.
		_localization.set_language(code)
	else:
		_set_setting("game", "language", code)
		_refresh_texts()


# -----------------------------------------------------------------------------
# Rebinding
# -----------------------------------------------------------------------------

func _on_rebind_pressed(action: StringName) -> void:
	if _rebinding_action == action:
		_cancel_rebind()
		return
	# Only one capture at a time; starting a new one restores the previous button's label.
	_cancel_rebind()
	if _input_manager == null or not _input_manager.has_method(&"rebind"):
		push_warning("SettingsMenu: InputManager cannot rebind; ignoring request for '%s'." % action)
		return
	_rebinding_action = action
	var button := _binding_buttons.get(action) as Button
	if button != null:
		button.text = _t("SETTINGS_CONTROLS_PRESS_KEY")
		button.release_focus()  # so the captured key cannot re-trigger this button


func _cancel_rebind() -> void:
	if _rebinding_action == &"":
		return
	var action := _rebinding_action
	_rebinding_action = &""
	var button := _binding_buttons.get(action) as Button
	if button != null and is_instance_valid(button):
		button.text = _binding_label(action)


func _finish_rebind(event: InputEvent) -> void:
	var action := _rebinding_action
	_rebinding_action = &""
	if _input_manager != null and _input_manager.has_method(&"rebind"):
		_input_manager.rebind(action, event)
	# Rebinds go through InputManager, which persists them itself; refresh the label even
	# if the `rebound` signal is missing so the button never stays stuck on "press a key".
	var button := _binding_buttons.get(action) as Button
	if button != null and is_instance_valid(button):
		button.text = _binding_label(action)


func _on_action_rebound(action: StringName) -> void:
	var button := _binding_buttons.get(action) as Button
	if button != null and is_instance_valid(button) and action != _rebinding_action:
		button.text = _binding_label(action)


# -----------------------------------------------------------------------------
# Footer actions
# -----------------------------------------------------------------------------

func _on_apply_pressed() -> void:
	if _settings == null:
		push_warning("SettingsMenu: no Settings autoload; nothing to apply.")
		return
	if _settings.has_method(&"save_settings"):
		_settings.save_settings()
	if _settings.has_method(&"apply_all"):
		_settings.apply_all()
	_clear_dirty()
	_refresh_values()


func _on_reset_pressed() -> void:
	_cancel_rebind()
	if _settings != null and _settings.has_method(&"reset_to_defaults"):
		_settings.reset_to_defaults()
	if _input_manager != null and _input_manager.has_method(&"reset_bindings"):
		_input_manager.reset_bindings()
	# Defaults are written straight to disk and to the engine: "reset" that needs a second
	# click on Apply to take effect reads as a bug.
	if _settings != null and _settings.has_method(&"save_settings"):
		_settings.save_settings()
	if _settings != null and _settings.has_method(&"apply_all"):
		_settings.apply_all()
	_clear_dirty()
	_populate_static_options()
	_refresh_values()
	_refresh_binding_labels()


func _on_settings_changed(_section: String, _key: String, _value: Variant) -> void:
	# Another system may change settings while the menu is open; mirror it, but never
	# while we are the ones writing (that would fight the widget being dragged).
	if _updating or _writing:
		return
	_refresh_values()


func _on_language_changed(_code: String) -> void:
	_refresh_texts()
