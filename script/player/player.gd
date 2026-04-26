extends CharacterBody2D

var tile_size: int = 32
var move_speed: float = 128.0
var moving: bool = false
var target_position: Vector2
var can_move: bool = true
var last_direction: Vector2 = Vector2.DOWN

# Reservation: while moving, we reserve the target cell.
var reserved_cell_valid: bool = false
var reserved_cell: Vector2i = Vector2i.ZERO

@onready var blocked_layer = get_node_or_null("../../Blocked")
@onready var anim = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	if blocked_layer == null:
		blocked_layer = _find_blocked_layer()
	target_position = global_position
	play_idle_animation()

func _process(delta: float) -> void:
	var menu_ui = get_tree().current_scene.get_node_or_null("Menu_ui")
	var menu_blocks: bool = menu_ui != null and menu_ui.has_method("is_ui_blocking") and menu_ui.is_ui_blocking()

	var dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")
	var dialogue_blocks: bool = dialogue_ui != null and dialogue_ui.is_active

	# If something blocks input while the player is already between tiles,
	# finish the current step first. Do not freeze between cells.
	if menu_blocks or dialogue_blocks or not can_move:
		if moving:
			_finish_current_step(delta, true)
		else:
			play_idle_animation()
		return

	if moving:
		_finish_current_step(delta, false)
		return

	try_move()

	if not moving:
		play_idle_animation()


func _finish_current_step(delta: float, force_idle: bool = false) -> void:
	if not moving:
		return

	global_position = global_position.move_toward(target_position, move_speed * delta)

	if global_position.distance_to(target_position) < 1.0:
		global_position = target_position
		moving = false
		reserved_cell_valid = false

		# Do not switch to idle between grid steps while a movement key is still held.
		# Otherwise the walk animation restarts every tile and only 1-2 frames are visible.
		if force_idle or not _is_any_move_pressed():
			play_idle_animation()


func _is_any_move_pressed() -> bool:
	return (
		Input.is_action_pressed("move_right")
		or Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_down")
		or Input.is_action_pressed("move_up")
	)


func try_move() -> void:
	if Input.is_action_pressed("move_right"):
		start_move(Vector2.RIGHT)
	elif Input.is_action_pressed("move_left"):
		start_move(Vector2.LEFT)
	elif Input.is_action_pressed("move_down"):
		start_move(Vector2.DOWN)
	elif Input.is_action_pressed("move_up"):
		start_move(Vector2.UP)

func start_move(direction: Vector2) -> void:
	if moving:
		return

	last_direction = direction

	var next_position = global_position + direction * tile_size
	var next_feet_position = $CollisionShape2D.global_position + direction * tile_size
	var cell = world_to_cell(next_feet_position)

	if is_npc_on_tile(next_feet_position):
		play_idle_animation()
		return

	if is_chest_on_tile(next_feet_position):
		play_idle_animation()
		return

	if is_closed_door_on_tile(next_feet_position):
		play_idle_animation()
		return

	if blocked_layer != null and blocked_layer.get_cell_source_id(cell) != -1:
		play_idle_animation()
		return
		
	play_walk_animation(direction)

	target_position = next_position
	reserved_cell = cell
	reserved_cell_valid = true
	moving = true

func _unhandled_input(event: InputEvent) -> void:
	
	var menu_ui = get_tree().current_scene.get_node_or_null("Menu_ui")
	if menu_ui != null and menu_ui.has_method("is_ui_blocking") and menu_ui.is_ui_blocking(): 
		return
	if event.is_action_pressed("action"):
		var dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")

		if dialogue_ui != null and dialogue_ui.is_active:
			dialogue_ui.next_line()
			return

		if moving:
			return

		var interaction_area = get_node_or_null("InteractionArea")
		if interaction_area == null:
			return

		for area in interaction_area.get_overlapping_areas():
			var node = area
			while node != null:
				if node.has_method("interact"):
					var can_interact: bool = false

					if node.has_method("can_interact_from_any_side") and bool(node.call("can_interact_from_any_side")):
						can_interact = true
					elif is_in_front_of_player(area.global_position):
						can_interact = true

					if can_interact:
						_call_interact_safely(node)
						return

					break
				node = node.get_parent()

func _call_interact_safely(node: Node) -> void:
	if node == null or not node.has_method("interact"):
		return

	var arg_count: int = 0
	for method_info in node.get_method_list():
		if not method_info.has("name"):
			continue
		if str(method_info["name"]) != "interact":
			continue

		if method_info.has("args"):
			var args: Array = method_info["args"]
			arg_count = args.size()
		break

	if arg_count <= 0:
		node.call("interact")
	else:
		node.call("interact", self)


func get_feet_world_pos(node: Node2D) -> Vector2:
	return node.get_node("CollisionShape2D").global_position

func world_to_cell(world_pos: Vector2) -> Vector2i:
	if blocked_layer != null:
		var local_pos = blocked_layer.to_local(world_pos)
		return blocked_layer.local_to_map(local_pos)
	return Vector2i(int(round(world_pos.x / tile_size)), int(round(world_pos.y / tile_size)))

func is_npc_on_tile(world_pos: Vector2) -> bool:
	var target_cell = world_to_cell(world_pos)

	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == null or not (npc is Node2D):
			continue

		var npc_cell = world_to_cell(get_feet_world_pos_safe(npc as Node2D))
		if npc_cell == target_cell:
			return true

		if "reserved_cell_valid" in npc and "reserved_cell" in npc:
			if npc.reserved_cell_valid and npc.reserved_cell == target_cell:
				return true

	return false


func get_feet_world_pos_safe(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO

	var cs = node.get_node_or_null("CollisionShape2D")
	if cs != null and cs is CollisionShape2D:
		return (cs as CollisionShape2D).global_position

	return node.global_position


func _find_blocked_layer() -> TileMapLayer:
	var scene = get_tree().current_scene
	if scene != null:
		var found = scene.find_child("Blocked", true, false)
		if found != null and found is TileMapLayer:
			return found as TileMapLayer
	return null


func is_chest_on_tile(world_pos: Vector2) -> bool:
	var target_cell = world_to_cell(world_pos)

	for chest in get_tree().get_nodes_in_group("chests"):
		if chest == null:
			continue
		# Chests are Node2D. Use their global_position as the tile anchor.
		if chest is Node2D:
			var chest_cell = world_to_cell((chest as Node2D).global_position)
			if chest_cell == target_cell:
				return true

	return false

func play_walk_animation(direction: Vector2) -> void:
	var anim_name := ""

	if direction == Vector2.RIGHT:
		anim_name = "Right"
	elif direction == Vector2.LEFT:
		anim_name = "Left"
	elif direction == Vector2.DOWN:
		anim_name = "Down"
	elif direction == Vector2.UP:
		anim_name = "Up"

	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)

func play_idle_animation() -> void:
	if last_direction == Vector2.RIGHT:
		anim.play("Idle_right")
	elif last_direction == Vector2.LEFT:
		anim.play("Idle_left")
	elif last_direction == Vector2.DOWN:
		anim.play("Idle_down")
	elif last_direction == Vector2.UP:
		anim.play("Idle_up")
		
func is_closed_door_on_tile(world_pos: Vector2) -> bool:
	var target_cell = world_to_cell(world_pos)

	for door in get_tree().get_nodes_in_group("doors"):
		if door.is_open:
			continue

		var door_cell = world_to_cell(door.global_position)
		if door_cell == target_cell:
			return true

	return false
	
func is_in_front_of_player(target_pos: Vector2) -> bool:
	var front_pos = global_position + last_direction * tile_size
	return world_to_cell(target_pos) == world_to_cell(front_pos)
