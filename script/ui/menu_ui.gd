extends CanvasLayer

@onready var menu_root: Control = $MenuRoot
@onready var inventory_panel: Panel = $MenuRoot/InventoryPanel
@onready var magic_panel: Panel = $MenuRoot/MagicPanel
@onready var equip_panel: Panel = $MenuRoot/EquipPanel
@onready var status_panel: Panel = $MenuRoot/StatusPanel

var is_open: bool = false
var selected_index: int = 0
var panels: Array[Panel] = []

var normal_style: StyleBoxFlat
var selected_style: StyleBoxFlat

var shown_position: Vector2
var hidden_position: Vector2

func _ready() -> void:
	panels = [inventory_panel, magic_panel, equip_panel, status_panel]

	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.18, 0.12, 0.08, 0.92)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.35, 0.25, 0.12)

	selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.18, 0.12, 0.08, 0.92)
	selected_style.border_width_left = 3
	selected_style.border_width_top = 3
	selected_style.border_width_right = 3
	selected_style.border_width_bottom = 3
	selected_style.border_color = Color(1.0, 0.9, 0.45)

	selected_index = 0
	update_selection()

	visible = true

	# Позиция, которую ты выставил вручную в сцене
	shown_position = menu_root.position

	# Скрытая позиция: то же X, но ниже экрана
	var viewport_height = get_viewport().get_visible_rect().size.y
	hidden_position = Vector2(shown_position.x, viewport_height + 20.0)

	menu_root.position = hidden_position

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if is_open:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	if event.is_action_pressed("move_up"):
		move_selection_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		move_selection_left()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		move_selection_right()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		move_selection_down()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action"):
		activate_selected()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player != null:
		player.moving = false
	
	if is_open:
		return
	

	is_open = true
	update_selection()

	var tween = create_tween()
	tween.tween_property(menu_root, "position", shown_position, 0.18)

func close_menu() -> void:
	if not is_open:
		return

	is_open = false

	var tween = create_tween()
	tween.tween_property(menu_root, "position", hidden_position, 0.18)

func move_selection_right() -> void:
	selected_index = 2
	update_selection()

func move_selection_left() -> void:
	selected_index = 1
	update_selection()

func move_selection_up() -> void:
	selected_index = 0
	update_selection()

func move_selection_down() -> void:
	selected_index = 3
	update_selection()

func update_selection() -> void:
	for i in range(panels.size()):
		if i == selected_index:
			panels[i].add_theme_stylebox_override("panel", selected_style)
		else:
			panels[i].add_theme_stylebox_override("panel", normal_style)

func activate_selected() -> void:
	match selected_index:
		0:
			print("Inventory selected")
		1:
			print("Magic selected")
		2:
			print("Equip selected")
		3:
			print("Status selected")
