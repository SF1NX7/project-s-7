extends Control
class_name CrossMenuNameHint

# CrossMenuNameHint v5
# Uses your editor placement as the "shown" position automatically.
# Then hides by sliding by an OFFSET, so it will appear exactly where you placed it in the viewport.
#
# Place NameHint where you want it to be VISIBLE in the editor.
# This script will:
# - remember that as shown_pos
# - move it to shown_pos + hidden_offset when hidden
# - slide between those two positions when the cross menu opens/closes
#
# It also updates the label text from menu_ui.selected_index.
# It auto-finds menu_ui by walking up parents and looking for properties:
#   is_open (bool) and selected_index (int).

@export_group("Links")
@export var menu_ui_path: NodePath  # optional

@export_group("Text")
@export var names: Array[String] = ["Inventory", "Equip", "Status", "Magic"]

@export_group("Animation")
@export var hidden_offset: Vector2 = Vector2(120, 0)  # move right when hidden
@export_range(0.05, 1.0, 0.01) var slide_time: float = 0.18

@export_group("Nodes")
@export var label_path: NodePath  # optional; default finds child NameLabel

var _menu: Node = null
var _label: Label = null
var _last_open: bool = false
var _last_index: int = -1
var _tween: Tween = null

var _shown_pos: Vector2
var _hidden_pos: Vector2


func _ready() -> void:
	_menu = _find_menu()
	_label = _find_label()

	# Use editor placement as shown position
	_shown_pos = position
	_hidden_pos = _shown_pos + hidden_offset

	# Start hidden
	visible = false
	position = _hidden_pos

	_sync(true)


func _process(_delta: float) -> void:
	_sync(false)


func _find_menu() -> Node:
	# 1) Explicit path
	if menu_ui_path != NodePath(" ") and menu_ui_path != NodePath(""):
		var n := get_node_or_null(menu_ui_path)
		if n != null:
			return n

	# 2) Walk up parents
	var p: Node = self
	while p != null:
		if ("is_open" in p) and ("selected_index" in p):
			return p
		p = p.get_parent()

	# 3) Fallback search
	var root: Node = get_tree().current_scene
	if root != null:
		var found := root.find_child("menu_ui", true, false)
		if found != null and ("is_open" in found) and ("selected_index" in found):
			return found

	return null


func _find_label() -> Label:
	if label_path != NodePath(" ") and label_path != NodePath(""):
		var n := get_node_or_null(label_path)
		if n is Label:
			return n as Label
	var found := find_child("NameLabel", true, false)
	if found is Label:
		return found as Label
	return null


func _sync(force: bool) -> void:
	if _menu == null:
		_menu = _find_menu()
		if _menu == null:
			if visible:
				_hide()
			return

	var open_now: bool = bool(_menu.is_open) if ("is_open" in _menu) else false
	var idx_now: int = int(_menu.selected_index) if ("selected_index" in _menu) else 0

	if force or open_now != _last_open:
		_last_open = open_now
		if open_now:
			_show()
		else:
			_hide()

	if open_now:
		if force or idx_now != _last_index:
			_last_index = idx_now
			_update_text(idx_now)


func _update_text(idx: int) -> void:
	if _label == null:
		return
	if names.size() <= 0:
		_label.text = ""
		return
	var max_idx: int = max(names.size() - 1, 0)
	var safe_idx: int = int(clamp(idx, 0, max_idx))
	_label.text = names[safe_idx]


func _show() -> void:
	visible = true
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", _shown_pos, slide_time)


func _hide() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "position", _hidden_pos, slide_time)
	_tween.tween_callback(func(): visible = false)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
