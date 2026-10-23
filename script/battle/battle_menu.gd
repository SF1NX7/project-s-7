extends CanvasLayer
## Battle cross menu matching the adventure MenuRoot layout and editor workflow.
signal command_selected(command: String)

@export_group("Connections")
@export var cursor_path: NodePath = ^"../BattleCursor"
@export var turn_path: NodePath = ^"../BattleTurn"

@export_group("Cross Menu Slide")
@export_range(0.05, 1.0, 0.01) var cross_menu_slide_time: float = 0.18
@export var cross_menu_hidden_offset: Vector2 = Vector2(0, 220)

@export_group("Selection")
@export var selected_outline_color: Color = Color(1, 1, 1, 1)
@export_range(1, 5, 1) var selected_outline_width: int = 2

const COMMANDS: Array[String] = ["attack", "magic", "item", "defend"]

@onready var menu_root: Control = $UiRoot/MenuRoot
@onready var panel_attack: Control = $UiRoot/MenuRoot/AttackPanel
@onready var panel_magic: Control = $UiRoot/MenuRoot/MagicPanel
@onready var panel_item: Control = $UiRoot/MenuRoot/ItemPanel
@onready var panel_defend: Control = $UiRoot/MenuRoot/DefendPanel

var is_open: bool = false
var selected_index: int = 0
var _cursor: Node
var _turn: Node
var _panels: Array[Control] = []
var _selection_frame: Panel
var _shown_position: Vector2
var _hidden_position: Vector2
var _tween: Tween

func _ready() -> void:
	_cursor = get_node_or_null(cursor_path)
	_turn = get_node_or_null(turn_path)
	_panels = [panel_attack, panel_magic, panel_item, panel_defend]
	_shown_position = menu_root.position
	_hidden_position = _shown_position + cross_menu_hidden_offset
	menu_root.position = _hidden_position
	menu_root.visible = false

	_selection_frame = Panel.new()
	_selection_frame.name = "SelectionFrame"
	_selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(selected_outline_width)
	style.border_color = selected_outline_color
	_selection_frame.add_theme_stylebox_override("panel", style)
	menu_root.add_child(_selection_frame)
	_update_visuals()

	if _cursor == null or _turn == null:
		push_warning("BattleMenu: Check Cursor Path and Turn Path in Inspector.")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.physical_keycode
	if key == KEY_NONE:
		key = key_event.keycode

	if is_open:
		match key:
			KEY_W, KEY_UP:
				selected_index = 0
			KEY_A, KEY_LEFT:
				selected_index = 1
			KEY_D, KEY_RIGHT:
				selected_index = 2
			KEY_S, KEY_DOWN:
				selected_index = 3
			KEY_TAB, KEY_ESCAPE:
				close_menu()
				get_viewport().set_input_as_handled()
				return
			KEY_E:
				command_selected.emit(COMMANDS[selected_index])
				get_viewport().set_input_as_handled()
				return
			_:
				return
		_update_visuals()
		get_viewport().set_input_as_handled()
		return

	if key == KEY_E and _is_cursor_on_active_hero():
		open_menu()
		get_viewport().set_input_as_handled()

func _is_cursor_on_active_hero() -> bool:
	if _cursor == null or _turn == null:
		return false
	var active := _turn.get("active_unit") as Node2D
	if active == null or not is_instance_valid(active):
		return false
	var cell_size: int = int(_cursor.get("cell_size"))
	if cell_size <= 0:
		return false
	var selected: Vector2i = _cursor.get("selected_cell")
	var first: Vector2i = _cursor.get("first_cell")
	var origin: Vector2 = _cursor.get("grid_origin")
	var top_left: Vector2 = _cursor.get_parent().to_global(origin + Vector2(selected - first) * float(cell_size))
	return Rect2(top_left, Vector2.ONE * float(cell_size)).grow(0.01).has_point(active.global_position)

func open_menu() -> void:
	if is_open or _cursor == null:
		return
	is_open = true
	selected_index = 0
	_cursor.set("_held_direction", Vector2i.ZERO)
	_cursor.set_process_unhandled_key_input(false)
	menu_root.visible = true
	_animate(true)
	_update_visuals()

func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	if _cursor != null:
		_cursor.set("_held_direction", Vector2i.ZERO)
		_cursor.set_process_unhandled_key_input(true)
	_animate(false)
	_update_visuals()

func _animate(opening: bool) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	_tween.tween_property(menu_root, "position", _shown_position if opening else _hidden_position, cross_menu_slide_time)
	if not opening:
		_tween.tween_callback(func() -> void: menu_root.visible = false)

func _update_visuals() -> void:
	for i in range(_panels.size()):
		var panel := _panels[i]
		if panel.has_method("set_selected"):
			panel.call("set_selected", is_open and i == selected_index)
	var selected_panel: Control = _panels[selected_index]
	_selection_frame.position = selected_panel.position
	_selection_frame.size = selected_panel.size
	_selection_frame.visible = is_open
