extends Control
class_name CrossMenuBlink

# CrossMenuBlink v5
# - 2-frame blink only while selected==true (driven by menu_ui via set_selected()).
# - Dims inactive icons (Bg TextureRect) to dim_color; selected uses active_color.
#
# Required node:
# - Child TextureRect named "Bg" (background image of the option)
#
# Usage:
# - Attach to EquipPanel/MagicPanel/StatusPanel/InventoryPanel.
# - Set Frame A and Frame B textures.
# - Menu will call set_selected(true/false) automatically (with patched menu_ui).

@export_group("Frames")
@export var frame_a: Texture2D
@export var frame_b: Texture2D
@export_range(0.05, 2.0, 0.05) var interval_sec: float = 0.25

@export_group("Colors")
@export var active_color: Color = Color(1, 1, 1, 1)
@export var dim_color: Color = Color(0.55, 0.55, 0.55, 1)

@export_group("Nodes")
@export var bg_path: NodePath  # optional; if empty, finds child named Bg

var selected: bool = false

var _bg: TextureRect
var _timer: Timer
var _toggle: bool = false
var _blinking: bool = false


func _ready() -> void:
	_bg = _get_bg()

	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = interval_sec
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

	_apply_idle()


func set_selected(on: bool) -> void:
	selected = on
	_update_state()


func _get_bg() -> TextureRect:
	if bg_path != NodePath("") and bg_path != NodePath(" "):
		var n := get_node_or_null(bg_path)
		if n is TextureRect:
			return n as TextureRect
	var found := find_child("Bg", true, false)
	if found is TextureRect:
		return found as TextureRect
	return null


func _update_state() -> void:
	if selected and not _blinking:
		_start_blink()
	elif (not selected) and _blinking:
		_stop_blink()
	else:
		_apply_color(selected)


func _start_blink() -> void:
	_blinking = true
	_toggle = false
	_apply_color(true)
	if _bg != null and frame_a != null:
		_bg.texture = frame_a
	_timer.wait_time = interval_sec
	_timer.start()


func _stop_blink() -> void:
	_blinking = false
	if _timer != null:
		_timer.stop()
	_apply_idle()


func _apply_idle() -> void:
	_apply_color(selected)
	if _bg != null and frame_a != null:
		_bg.texture = frame_a


func _apply_color(active: bool) -> void:
	if _bg == null:
		return
	_bg.self_modulate = active_color if active else dim_color


func _on_tick() -> void:
	if _bg == null:
		return
	if not selected:
		_stop_blink()
		return
	_toggle = !_toggle
	if _toggle:
		if frame_b != null:
			_bg.texture = frame_b
	else:
		if frame_a != null:
			_bg.texture = frame_a
