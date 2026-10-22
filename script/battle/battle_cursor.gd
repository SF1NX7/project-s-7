extends Node2D

@export_group("Grid")
@export_range(1, 128, 1) var cell_size: int = 32
@export var grid_origin: Vector2 = Vector2.ZERO
@export var first_cell: Vector2i = Vector2i(0, 0)
@export var grid_size: Vector2i = Vector2i(20, 15)
@export var starting_cell: Vector2i = Vector2i(0, 0)

@export_group("Appearance")
@export var border_color: Color = Color(1.0, 0.95, 0.35, 1.0)
@export var fill_color: Color = Color(1.0, 0.95, 0.35, 0.18)
@export_range(1.0, 8.0, 0.5) var border_width: float = 2.0
@export var cursor_visible: bool = true

@export_group("Controls")
@export var allow_arrow_keys: bool = true
@export_range(0.05, 1.0, 0.01) var first_repeat_delay: float = 0.25
@export_range(0.03, 0.5, 0.01) var repeat_interval: float = 0.10

signal cell_changed(cell: Vector2i)

var selected_cell: Vector2i
var _held_direction: Vector2i = Vector2i.ZERO
var _repeat_timer: float = 0.0


func _ready() -> void:
	grid_size = Vector2i(maxi(1, grid_size.x), maxi(1, grid_size.y))
	selected_cell = _clamp_cell(starting_cell)
	_update_cursor()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var direction: Vector2i = _key_to_direction(event)
	if direction == Vector2i.ZERO:
		return

	if event.pressed:
		if event.echo:
			get_viewport().set_input_as_handled()
			return
		_held_direction = direction
		_repeat_timer = maxf(0.05, first_repeat_delay)
		_move(direction)
	else:
		if _held_direction == direction:
			_held_direction = Vector2i.ZERO
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _held_direction == Vector2i.ZERO:
		return

	_repeat_timer -= delta
	if _repeat_timer <= 0.0:
		_move(_held_direction)
		_repeat_timer = maxf(0.03, repeat_interval)


func _key_to_direction(event: InputEventKey) -> Vector2i:
	var code: Key = event.physical_keycode
	if code == KEY_NONE:
		code = event.keycode
	match code:
		KEY_W:
			return Vector2i.UP
		KEY_S:
			return Vector2i.DOWN
		KEY_A:
			return Vector2i.LEFT
		KEY_D:
			return Vector2i.RIGHT
		KEY_UP:
			if allow_arrow_keys:
				return Vector2i.UP
		KEY_DOWN:
			if allow_arrow_keys:
				return Vector2i.DOWN
		KEY_LEFT:
			if allow_arrow_keys:
				return Vector2i.LEFT
		KEY_RIGHT:
			if allow_arrow_keys:
				return Vector2i.RIGHT
	return Vector2i.ZERO


func _move(direction: Vector2i) -> void:
	var next_cell: Vector2i = _clamp_cell(selected_cell + direction)
	if next_cell == selected_cell:
		return
	selected_cell = next_cell
	_update_cursor()
	cell_changed.emit(selected_cell)


func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, first_cell.x, first_cell.x + grid_size.x - 1),
		clampi(cell.y, first_cell.y, first_cell.y + grid_size.y - 1)
	)


func _update_cursor() -> void:
	position = grid_origin + Vector2((selected_cell - first_cell) * cell_size)
	queue_redraw()


func _draw() -> void:
	if not cursor_visible:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE * float(cell_size))
	draw_rect(rect, fill_color, true)
	draw_rect(rect, border_color, false, border_width)
