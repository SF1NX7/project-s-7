extends CharacterBody2D
class_name NPC

## NPC Life Movement v7 (Godot 4.6, TileMapLayer)
## Fixes vs v6:
## - Auto-finds AnimatedSprite2D even if it's named "Sprite2D".
## - Snaps NPC to the CENTER of the nearest cell on ready (prevents "walking on seams").
## - Uses CollisionShape2D position as "feet" for cell checks (better blocking between NPCs).
## - Prevents NPCs from stepping onto the same cell.
##
## Required in your NPC scene:
## - CollisionShape2D (for feet position)
## - AnimatedSprite2D (any name) OR none (then NPC won't animate)

@export_group("Dialogue")
@export var dialogue_lines: Array[String] = []
@export var portrait: Texture2D

@export_group("Grid")
@export var tile_size: int = 32
@export var move_speed: float = 96.0
@export var snap_to_grid_on_ready: bool = true

@export_group("Behavior")
enum BehaviorMode { IDLE, PATROL_LOOP, PATROL_RANDOM, WANDER_RECT }
@export var behavior: BehaviorMode = BehaviorMode.WANDER_RECT
@export var think_interval: float = 0.8
@export var allow_idle_steps: bool = true
@export_range(0.0, 1.0, 0.05) var idle_chance: float = 0.25

# PATROL_*: Node2D with Marker2D children
@export var patrol_points_path: NodePath

# WANDER_RECT: Area2D with CollisionShape2D(RectangleShape2D)
@export var wander_area_path: NodePath

@export_group("Collision")
# In your World tree, Blocked is a TileMapLayer node.
@export var blocked_layer_path: NodePath = NodePath("../Blocked")
@export var block_player_cell: bool = true

@export_group("Animation")
# Leave empty to auto-find the first AnimatedSprite2D under this NPC.
@export var anim_path: NodePath

@onready var blocked_layer: TileMapLayer = get_node_or_null(blocked_layer_path) as TileMapLayer
@onready var feet_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var anim: AnimatedSprite2D

var moving := false
var target_position: Vector2
var last_direction: Vector2 = Vector2.DOWN

var _think_t := 0.0
var _rng := RandomNumberGenerator.new()

var _patrol_cells: Array[Vector2i] = []
var _patrol_index: int = 0


func _ready() -> void:
	_rng.randomize()
	add_to_group("npcs")

	# Find animation node
	if anim_path != NodePath(""):
		anim = get_node_or_null(anim_path) as AnimatedSprite2D
	if anim == null:
		anim = _find_first_animated_sprite(self)

	# Snap to grid center to avoid "walking on seams"
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
	if moving:
		global_position = global_position.move_toward(target_position, move_speed * delta)
		if global_position.distance_to(target_position) < 0.5:
			global_position = target_position
			moving = false
			_play_idle()

	_think_t += delta
	if _think_t >= think_interval:
		_think_t = 0.0
		if not moving:
			_decide_next_action()


func interact() -> void:
	var dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")
	if dialogue_ui == null:
		return
	if dialogue_ui.is_active:
		return
	dialogue_ui.start_dialogue(dialogue_lines, portrait)


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

	# If no zone is set, fallback to random adjacent
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
	if moving:
		return
	last_direction = direction
	_play_walk(direction)
	target_position = _cell_to_world_center(cell)
	moving = true


func _feet_world_pos() -> Vector2:
	return feet_shape.global_position if feet_shape != null else global_position


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	if blocked_layer != null:
		var local_pos := blocked_layer.to_local(world_pos)
		return blocked_layer.local_to_map(local_pos)
	# fallback
	return Vector2i(int(round(world_pos.x / tile_size)), int(round(world_pos.y / tile_size)))


func _cell_to_world_center(cell: Vector2i) -> Vector2:
	if blocked_layer != null:
		# map_to_local gives the center of the cell in local space for TileMapLayer
		var local := blocked_layer.map_to_local(cell)
		return blocked_layer.to_global(local)
	# fallback
	return Vector2(cell.x * tile_size, cell.y * tile_size)


func _can_step_to_cell(cell: Vector2i) -> bool:
	# Blocked tile?
	if blocked_layer != null and blocked_layer.get_cell_source_id(cell) != -1:
		return false

	# Player on that cell?
	if block_player_cell:
		var pl := get_tree().get_first_node_in_group("player")
		if pl == null:
			pl = get_tree().current_scene.get_node_or_null("Player")
		if pl != null and pl is Node2D:
			# Block player's current cell
			var pl_cell := _world_to_cell((pl as Node2D).global_position)
			if pl_cell == cell:
				return false
			# Also block player's target cell while moving (prevents "swap into same cell")
			if "moving" in pl and pl.moving and "target_position" in pl:
				var pl_target_cell := _world_to_cell(pl.target_position)
				if pl_target_cell == cell:
					return false

# Other NPC on that cell?
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == self:
			continue
		if npc is NPC:
			var other_cell := (npc as NPC)._world_to_cell((npc as NPC)._feet_world_pos())
			if other_cell == cell:
				return false
		elif npc is Node2D:
			# fallback: use global_position
			var other_cell2 := _world_to_cell((npc as Node2D).global_position)
			if other_cell2 == cell:
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


# Used by Player.gd to prevent entering the NPC's next cell while the NPC is moving.
func get_reserved_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.append(_world_to_cell(_feet_world_pos()))
	if moving:
		cells.append(_world_to_cell(target_position))
	return cells
