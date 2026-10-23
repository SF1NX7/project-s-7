extends Node2D
## Tactical movement prototype. Add as BattleMove directly under BattleMap.
## The original turn, menu, camera, hover and cursor scripts remain unchanged.

@export_group("References")
@export var turn_path: NodePath = ^"../BattleTurn"
@export var cursor_path: NodePath = ^"../BattleCursor"
@export var menu_path: NodePath = ^"../BattleMenu"
@export var units_path: NodePath = ^"../Units"
@export var blocked_path: NodePath = ^"../Blocked"

@export_group("Movement")
@export_range(1, 24, 1) var movement_radius: int = 5
@export_range(0.03, 0.75, 0.01) var move_duration: float = 0.14
@export_range(0.03, 0.75, 0.01) var return_step_duration: float = 0.10
@export_range(0.05, 1.0, 0.01) var first_repeat_delay: float = 0.24
@export_range(0.03, 0.5, 0.01) var repeat_interval: float = 0.12
@export var allow_arrow_keys: bool = true

@export_group("Movement Highlight")
@export var show_reachable_cells: bool = true
@export var reachable_color: Color = Color(0.20, 0.54, 0.96, 0.25)
@export var reachable_outline: Color = Color(0.30, 0.73, 1.0, 0.45)
@export_range(0.0, 4.0, 0.25) var outline_width: float = 1.0

@export_group("Testing")
@export var start_in_movement_mode: bool = true

var _turn: Node
var _cursor: Node2D
var _menu: Node
var _units: Node2D
var _blocked: TileMapLayer
var _unit: Node2D
var _start_cell: Vector2i
var _cell: Vector2i
var _reachable: Dictionary = {}
var _movement_mode: bool = true
var _animating: bool = false
var _direction: Vector2i = Vector2i.ZERO
var _repeat_timer: float = 0.0
var _tween: Tween

func _ready() -> void:
    _turn = get_node_or_null(turn_path)
    _cursor = get_node_or_null(cursor_path) as Node2D
    _menu = get_node_or_null(menu_path)
    _units = get_node_or_null(units_path) as Node2D
    _blocked = get_node_or_null(blocked_path) as TileMapLayer
    if _turn == null or _cursor == null or _menu == null or _units == null or _blocked == null:
        push_error("BattleMove: missing node. Check References in Inspector.")
        set_process(false)
        set_process_unhandled_key_input(false)
        return
    _movement_mode = start_in_movement_mode
    if _turn.has_signal("active_unit_changed"):
        _turn.connect("active_unit_changed", Callable(self, "_on_active_unit_changed"))
    call_deferred("_initialize_current_unit")

func _initialize_current_unit() -> void:
    _on_active_unit_changed(_turn.get("active_unit") as Node2D, _turn.get("active_hero"))

func _on_active_unit_changed(unit: Node2D, _hero: Resource) -> void:
    if unit == null or not is_instance_valid(unit):
        return
    _unit = unit
    _start_cell = _world_to_cell(unit.global_position)
    _cell = _start_cell
    _movement_mode = start_in_movement_mode
    _build_reachable()
    _sync_cursor()
    queue_redraw()

func _input_event_direction(event: InputEventKey) -> Vector2i:
    var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
    match key:
        KEY_W: return Vector2i.UP
        KEY_A: return Vector2i.LEFT
        KEY_S: return Vector2i.DOWN
        KEY_D: return Vector2i.RIGHT
        KEY_UP: return Vector2i.UP if allow_arrow_keys else Vector2i.ZERO
        KEY_LEFT: return Vector2i.LEFT if allow_arrow_keys else Vector2i.ZERO
        KEY_DOWN: return Vector2i.DOWN if allow_arrow_keys else Vector2i.ZERO
        KEY_RIGHT: return Vector2i.RIGHT if allow_arrow_keys else Vector2i.ZERO
    return Vector2i.ZERO

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or _unit == null:
        return
    var key_event := event as InputEventKey
    var key: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
    if not key_event.pressed:
        if _direction == _input_event_direction(key_event):
            _direction = Vector2i.ZERO
        return
    if key_event.echo or _menu.get("is_open") == true:
        return
    if key == KEY_TAB:
        if not _animating:
            _movement_mode = not _movement_mode
            _direction = Vector2i.ZERO
            _apply_input_mode()
            if _movement_mode:
                _sync_cursor()
            queue_redraw()
        get_viewport().set_input_as_handled()
        return
    if not _movement_mode:
        return
    if key == KEY_Q:
        if not _animating:
            _return_home()
        get_viewport().set_input_as_handled()
        return
    var direction := _input_event_direction(key_event)
    if direction != Vector2i.ZERO:
        _direction = direction
        _repeat_timer = first_repeat_delay
        if not _animating:
            _attempt_step(direction)
        get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if _cursor == null:
        return
    _apply_input_mode()
    if _menu.get("is_open") == true or not _movement_mode or _animating or _direction == Vector2i.ZERO:
        return
    _repeat_timer -= delta
    if _repeat_timer <= 0.0:
        _attempt_step(_direction)
        _repeat_timer = repeat_interval

func _apply_input_mode() -> void:
    if _cursor == null:
        return
    var cursor_controls: bool = not _movement_mode and not _animating and _menu.get("is_open") != true
    if _cursor.is_processing_unhandled_key_input() != cursor_controls:
        _cursor.set_process_unhandled_key_input(cursor_controls)
        if not cursor_controls:
            _cursor.set("_held_direction", Vector2i.ZERO)

func _cursor_size() -> int:
    return maxi(1, int(_cursor.get("cell_size")))

func _cell_top_left(cell: Vector2i) -> Vector2:
    var first: Vector2i = _cursor.get("first_cell")
    var origin: Vector2 = _cursor.get("grid_origin")
    return _cursor.get_parent().to_global(origin + Vector2(cell - first) * float(_cursor_size()))

func _world_to_cell(world_pos: Vector2) -> Vector2i:
    var first: Vector2i = _cursor.get("first_cell")
    var origin: Vector2 = _cursor.get_parent().to_global(_cursor.get("grid_origin"))
    var relative: Vector2 = world_pos - origin
    return first + Vector2i(floori(relative.x / _cursor_size()), floori(relative.y / _cursor_size()))

func _cell_center(cell: Vector2i) -> Vector2:
    return _cell_top_left(cell) + Vector2.ONE * (float(_cursor_size()) * 0.5)

func _in_grid(cell: Vector2i) -> bool:
    var first: Vector2i = _cursor.get("first_cell")
    var size: Vector2i = _cursor.get("grid_size")
    return cell.x >= first.x and cell.y >= first.y and cell.x < first.x + size.x and cell.y < first.y + size.y

func _free(cell: Vector2i) -> bool:
    if not _in_grid(cell):
        return false
    var map_cell: Vector2i = _blocked.local_to_map(_blocked.to_local(_cell_center(cell)))
    if _blocked.get_cell_source_id(map_cell) != -1:
        return false
    for child in _units.get_children():
        var other := child as Node2D
        if other != null and other != _unit and _world_to_cell(other.global_position) == cell:
            return false
    return true

func _build_reachable() -> void:
    _reachable.clear()
    _reachable[_start_cell] = 0
    var frontier: Array[Vector2i] = [_start_cell]
    var head: int = 0
    while head < frontier.size():
        var from: Vector2i = frontier[head]
        head += 1
        var depth: int = int(_reachable[from])
        if depth >= movement_radius:
            continue
        for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
            var candidate: Vector2i = from + step
            if _reachable.has(candidate) or not _free(candidate):
                continue
            _reachable[candidate] = depth + 1
            frontier.append(candidate)

func _attempt_step(direction: Vector2i) -> void:
    var destination: Vector2i = _cell + direction
    if not _reachable.has(destination) or not _free(destination):
        return
    _animate_step(destination, move_duration)

func _animate_step(destination: Vector2i, duration: float) -> void:
    _animating = true
    var old_cell: Vector2i = _cell
    _cell = destination
    var delta: Vector2 = _cell_top_left(destination) - _cell_top_left(old_cell)
    var target_pos: Vector2 = _unit.global_position + delta
    _sync_cursor()
    _tween = create_tween()
    _tween.tween_property(_unit, "global_position", target_pos, duration).set_trans(Tween.TRANS_LINEAR)
    _tween.finished.connect(func() -> void:
        _animating = false
        _sync_cursor()
    )

func _sync_cursor() -> void:
    if _cursor == null or _unit == null:
        return
    _cursor.set("selected_cell", _cell)
    if _cursor.has_method("_update_cursor"):
        _cursor.call("_update_cursor")
    if _cursor.has_signal("cell_changed"):
        _cursor.emit_signal("cell_changed", _cell)

func _return_home() -> void:
    _direction = Vector2i.ZERO
    if _cell == _start_cell:
        return
    # Breadth-first search gives a shortest path under present blockers.
    var frontier: Array[Vector2i] = [_cell]
    var previous: Dictionary = {_cell: _cell}
    var head: int = 0
    while head < frontier.size() and not previous.has(_start_cell):
        var from: Vector2i = frontier[head]
        head += 1
        for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
            var next: Vector2i = from + offset
            if previous.has(next) or not _reachable.has(next) or (next != _start_cell and not _free(next)):
                continue
            previous[next] = from
            frontier.append(next)
    if not previous.has(_start_cell):
        push_warning("BattleMove: return path blocked.")
        return
    var path: Array[Vector2i] = []
    var node: Vector2i = _start_cell
    while node != _cell:
        path.push_front(node)
        node = previous[node]
    _follow_return(path)

func _follow_return(path: Array[Vector2i]) -> void:
    if path.is_empty():
        return
    _animating = true
    var tween := create_tween()
    var previous_cell: Vector2i = _cell
    var target_position: Vector2 = _unit.global_position
    for step in path:
        target_position += _cell_top_left(step) - _cell_top_left(previous_cell)
        tween.tween_property(_unit, "global_position", target_position, return_step_duration).set_trans(Tween.TRANS_LINEAR)
        var reached_cell: Vector2i = step
        tween.tween_callback(func() -> void:
            _cell = reached_cell
            _sync_cursor()
        )
        previous_cell = step
    tween.finished.connect(func() -> void:
        _cell = _start_cell
        _animating = false
        _sync_cursor()
    )

func _draw() -> void:
    if not show_reachable_cells or not _movement_mode or _unit == null:
        return
    var size: float = float(_cursor_size())
    for cell in _reachable.keys():
        var top_left: Vector2 = to_local(_cell_top_left(cell))
        var rect := Rect2(top_left, Vector2.ONE * size)
        draw_rect(rect, reachable_color, true)
        if outline_width > 0.0:
            draw_rect(rect, reachable_outline, false, outline_width)
