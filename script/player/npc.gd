extends CharacterBody2D
class_name NPC

## NPC Life Movement v14
## Improvements:
## - Dialogue starts ONLY when NPC is on tile center (queued if you press E mid-step).
## - NPC faces the player when dialogue starts.
## - Robust tile "reservation": NPC reserves its target cell while moving.
##   Player/NPC checks consider BOTH current cells and reserved target cells, preventing two actors
##   from entering the same tile from opposite directions.

@export_group("Dialogue")
@export var dialogue_lines: Array[String] = []
@export var portrait: Texture2D

@export_group("Grid")
@export var tile_size: int = 32
@export var move_speed: float = 96.0
@export var snap_to_grid_on_ready: bool = true
@export var center_epsilon: float = 0.5  # pixels

@export_group("Behavior")
enum BehaviorMode { IDLE, PATROL_LOOP, PATROL_RANDOM, WANDER_RECT }
@export var behavior: BehaviorMode = BehaviorMode.WANDER_RECT
@export var think_interval: float = 0.8
@export var allow_idle_steps: bool = true
@export_range(0.0, 1.0, 0.05) var idle_chance: float = 0.25
@export var patrol_points_path: NodePath
@export var wander_area_path: NodePath

@export_group("Collision")
@export var blocked_layer_path: NodePath = NodePath("../Blocked")
@export var block_player_cell: bool = true

@export_group("Animation")
@export var anim_path: NodePath  # optional

@onready var blocked_layer: TileMapLayer = get_node_or_null(blocked_layer_path) as TileMapLayer
@onready var feet_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var anim: AnimatedSprite2D

var moving := false
var target_position: Vector2
var last_direction: Vector2 = Vector2.DOWN

# Reservation: while moving, this cell is reserved (target cell).
var reserved_cell_valid: bool = false
var reserved_cell: Vector2i = Vector2i.ZERO

var _think_t := 0.0
var _rng := RandomNumberGenerator.new()
var _patrol_cells: Array[Vector2i] = []
var _patrol_index: int = 0

var _in_dialogue := false
var _pending_dialogue := false
var _pending_player: Node2D = null


func _ready() -> void:
	_rng.randomize()
	add_to_group("npcs")

	# Find animation node
	if anim_path != NodePath(""):
		anim = get_node_or_null(anim_path) as AnimatedSprite2D
	if anim == null:
		anim = _find_first_animated_sprite(self)

	# Snap to grid center
	if snap_to_grid_on_ready:
		var cell := _world_to_cell(_feet_world_pos())
		var centered := _cell_to_world_center(cell)
		global_position = centered
		target_position = centered
	else:
		target_position = global_position

	_build_patrol_cells()
	_play_idle()


func _process(delta: float) -> void:
	# Freeze while dialogue is active
	if _dialogue_active() or _in_dialogue:
		moving = false
		reserved_cell_valid = false
		target_position = global_position
		_play_idle()
		return

	# Move towards target
	if moving:
		global_position = global_position.move_toward(target_position, move_speed * delta)
		if global_position.distance_to(target_position) <= center_epsilon:
			global_position = target_position
			moving = false
			reserved_cell_valid = false
			_play_idle()
			if _pending_dialogue:
				_start_dialogue_now()
			return

	# If dialogue is pending but we aren't moving (edge case), start it.
	if _pending_dialogue and not moving and _is_on_tile_center():
		_start_dialogue_now()
		return

	# Decide next move
	_think_t += delta
	if _think_t >= think_interval:
		_think_t = 0.0
		if not moving:
			_decide_next_action()


# Player calls interact(). Dialogue will start only when centered (queued otherwise).
func interact(player: Node = null) -> void:
	if _dialogue_active() or _in_dialogue:
		return

	var pl: Node2D = null
	if player != null and player is Node2D:
		pl = player as Node2D
	else:
		pl = _find_player()

	_pending_player = pl
	_pending_dialogue = true

	# Start immediately only if we are already centered & not moving
	if not moving and _is_on_tile_center():
		_start_dialogue_now()
		return
	# else: let current step finish, then start


func _start_dialogue_now() -> void:
	_pending_dialogue = false

	# Snap to center just in case
	var cell := _world_to_cell(_feet_world_pos())
	target_position = _cell_to_world_center(cell)
	global_position = target_position
	moving = false
	reserved_cell_valid = false

	if _pending_player != null:
		_face_node(_pending_player)

	var dialogue_ui := _get_dialogue_ui()
	if dialogue_ui == null:
		return

	_in_dialogue = true
	_play_idle()

	if dialogue_ui.has_method("start_dialogue"):
		dialogue_ui.start_dialogue(dialogue_lines, portrait)

		if dialogue_ui.has_signal("finished"):
			await dialogue_ui.finished
		else:
			while _dialogue_active():
				await get_tree().process_frame

	_in_dialogue = false
	_pending_player = null


# ---------- Behavior ----------

func _decide_next_action() -> void:
	if allow_idle_steps and _rng.randf() < idle_chance:
		_play_idle()
		return

	match behavior:
		BehaviorMode.IDLE:
			_play_idle()
		BehaviorMode.PATROL_LOOP:
			_patrol_step(true)
		BehaviorMode.PATROL_RANDOM:
			_patrol_step(false, true)
		BehaviorMode.WANDER_RECT:
			_wander_step()


func _patrol_step(loop: bool = true, random_pick: bool = false) -> void:
	if _patrol_cells.is_empty():
		_play_idle()
		return

	if random_pick:
		_patrol_index = _rng.randi_range(0, _patrol_cells.size() - 1)

	var target_cell: Vector2i = _patrol_cells[_patrol_index]
	_patrol_index += 1
	if _patrol_index >= _patrol_cells.size():
		_patrol_index = 0 if loop else _patrol_index

	_move_toward_cell_one_step(target_cell)


func _wander_step() -> void:
	var allowed := _get_wander_allowed_cells()
	var my_cell := _world_to_cell(_feet_world_pos())

	if allowed.is_empty():
		_random_adjacent_step()
		return

	for _i in range(12):
		var dir := _random_cardinal_dir()
		var next := my_cell + Vector2i(dir.x, dir.y)
		if allowed.has(next) and _can_step_to_cell(next):
			_start_move_to_cell(next, dir)
			return

	_play_idle()


func _random_adjacent_step() -> void:
	var my_cell := _world_to_cell(_feet_world_pos())
	for _i in range(12):
		var dir := _random_cardinal_dir()
		var next := my_cell + Vector2i(dir.x, dir.y)
		if _can_step_to_cell(next):
			_start_move_to_cell(next, dir)
			return
	_play_idle()


func _move_toward_cell_one_step(target_cell: Vector2i) -> void:
	var my_cell := _world_to_cell(_feet_world_pos())
	var dx := target_cell.x - my_cell.x
	var dy := target_cell.y - my_cell.y

	var dir := Vector2.ZERO
	if abs(dx) > abs(dy):
		dir = Vector2.RIGHT if dx > 0 else Vector2.LEFT
	elif dy != 0:
		dir = Vector2.DOWN if dy > 0 else Vector2.UP
	elif dx != 0:
		dir = Vector2.RIGHT if dx > 0 else Vector2.LEFT
	else:
		_play_idle()
		return

	var next := my_cell + Vector2i(dir.x, dir.y)
	if _can_step_to_cell(next):
		_start_move_to_cell(next, dir)
	else:
		_play_idle()


# ---------- Grid helpers ----------

func _start_move_to_cell(cell: Vector2i, direction: Vector2) -> void:
	if moving or _pending_dialogue:
		return

	last_direction = direction
	_play_walk(direction)
	target_position = _cell_to_world_center(cell)

	# Reserve target cell for the whole step
	reserved_cell = cell
	reserved_cell_valid = true

	moving = true


func _feet_world_pos() -> Vector2:
	return feet_shape.global_position if feet_shape != null else global_position


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	if blocked_layer != null:
		var local_pos := blocked_layer.to_local(world_pos)
		return blocked_layer.local_to_map(local_pos)
	return Vector2i(int(round(world_pos.x / tile_size)), int(round(world_pos.y / tile_size)))


func _cell_to_world_center(cell: Vector2i) -> Vector2:
	if blocked_layer != null:
		var local := blocked_layer.map_to_local(cell)
		return blocked_layer.to_global(local)
	return Vector2(cell.x * tile_size, cell.y * tile_size)


func _is_on_tile_center() -> bool:
	var cell := _world_to_cell(_feet_world_pos())
	return global_position.distance_to(_cell_to_world_center(cell)) <= center_epsilon


func _actor_reserves_cell(actor: Node, cell: Vector2i) -> bool:
	if actor == null:
		return false
	if "reserved_cell_valid" in actor and actor.reserved_cell_valid and "reserved_cell" in actor:
		return actor.reserved_cell == cell
	return false


func _can_step_to_cell(cell: Vector2i) -> bool:
	# Blocked tile?
	if blocked_layer != null and blocked_layer.get_cell_source_id(cell) != -1:
		return false

	# Player current/reserved cell?
	if block_player_cell:
		var pl := _find_player()
		if pl != null:
			var pl_cell := _world_to_cell(pl.global_position)
			if pl_cell == cell:
				return false
			if _actor_reserves_cell(pl, cell):
				return false

	# Other NPC current/reserved cell?
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self:
			continue
		if npc is Node2D:
			var npc_cell := _world_to_cell((npc as Node2D).global_position)
			if npc_cell == cell:
				return false
			if _actor_reserves_cell(npc, cell):
				return false

	return true


func _random_cardinal_dir() -> Vector2:
	match _rng.randi_range(0, 3):
		0: return Vector2.RIGHT
		1: return Vector2.LEFT
		2: return Vector2.DOWN
		_: return Vector2.UP


# ---------- Patrol ----------

func _build_patrol_cells() -> void:
	_patrol_cells.clear()
	if patrol_points_path == NodePath(""):
		return
	var root := get_node_or_null(patrol_points_path)
	if root == null:
		return
	for ch in root.get_children():
		if ch is Node2D:
			_patrol_cells.append(_world_to_cell((ch as Node2D).global_position))


func _get_wander_allowed_cells() -> Array[Vector2i]:
	if wander_area_path == NodePath(""):
		return []
	var a := get_node_or_null(wander_area_path) as Area2D
	if a == null:
		return []
	var cs := a.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return []
	var rect_shape := cs.shape as RectangleShape2D
	if rect_shape == null:
		return []

	var half := rect_shape.size * 0.5
	var top_left := cs.global_position - half
	var bot_right := cs.global_position + half

	var tl := _world_to_cell(top_left)
	var br := _world_to_cell(bot_right)

	var out_cells: Array[Vector2i] = []
	for y in range(min(tl.y, br.y), max(tl.y, br.y) + 1):
		for x in range(min(tl.x, br.x), max(tl.x, br.x) + 1):
			out_cells.append(Vector2i(x, y))
	return out_cells


# ---------- Dialogue helpers ----------

func _get_dialogue_ui() -> Node:
	var dlg := get_tree().current_scene.get_node_or_null("DialogueUI")
	if dlg != null:
		return dlg
	return get_tree().root.find_child("DialogueUI", true, false)


func _dialogue_active() -> bool:
	var dlg := _get_dialogue_ui()
	if dlg == null:
		return false
	if "is_active" in dlg:
		return dlg.is_active
	return false


func _find_player() -> Node2D:
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl is Node2D:
		return pl as Node2D
	var p2 := get_tree().current_scene.get_node_or_null("Player")
	return p2 as Node2D


func _face_node(n: Node2D) -> void:
	var delta := (n.global_position - global_position)
	if abs(delta.x) > abs(delta.y):
		last_direction = Vector2.RIGHT if delta.x > 0 else Vector2.LEFT
	else:
		last_direction = Vector2.DOWN if delta.y > 0 else Vector2.UP
	_play_idle()


# ---------- Anim ----------

func _play_walk(dir: Vector2) -> void:
	if anim == null:
		return
	var name := ""
	if dir == Vector2.RIGHT:
		name = "Right"
	elif dir == Vector2.LEFT:
		name = "Left"
	elif dir == Vector2.DOWN:
		name = "Down"
	elif dir == Vector2.UP:
		name = "Up"
	if name != "" and anim.animation != name:
		anim.play(name)


func _play_idle() -> void:
	if anim == null:
		return
	if last_direction == Vector2.RIGHT:
		anim.play("Idle_right")
	elif last_direction == Vector2.LEFT:
		anim.play("Idle_left")
	elif last_direction == Vector2.DOWN:
		anim.play("Idle_down")
	elif last_direction == Vector2.UP:
		anim.play("Idle_up")


func _find_first_animated_sprite(root: Node) -> AnimatedSprite2D:
	if root is AnimatedSprite2D:
		return root
	for ch in root.get_children():
		var found := _find_first_animated_sprite(ch)
		if found != null:
			return found
	return null
