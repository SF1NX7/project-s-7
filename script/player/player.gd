extends CharacterBody2D

var tile_size: int = 32
var move_speed: float = 128.0
var moving: bool = false
var target_position: Vector2
var can_move: bool = true
var last_direction: Vector2 = Vector2.DOWN

@onready var blocked_layer = $"../Blocked"
@onready var anim = $AnimatedSprite2D

func _ready() -> void:
	target_position = global_position
	play_idle_animation()

func _process(delta: float) -> void:
	var menu_ui = get_tree().current_scene.get_node_or_null("MenuUI")
	if menu_ui != null and menu_ui.is_open:
		return
	var dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")
	if dialogue_ui != null and dialogue_ui.is_active:
		return
	if not can_move:
		return

	if moving:
		global_position = global_position.move_toward(target_position, move_speed * delta)

	if global_position.distance_to(target_position) < 1.0:
		global_position = target_position
		moving = false

	try_move()

	if not moving:
		play_idle_animation()
	else:
		try_move()

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

	if is_closed_door_on_tile(next_feet_position):
		play_idle_animation()
		return

	if blocked_layer.get_cell_source_id(cell) != -1:
		play_idle_animation()
		return
		
	play_walk_animation(direction)

	target_position = next_position
	moving = true

func _unhandled_input(event: InputEvent) -> void:
	
	var menu_ui = get_tree().current_scene.get_node_or_null("MenuUI")
	if menu_ui != null and menu_ui.is_open:
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
					if is_in_front_of_player(node.global_position):
						node.interact()
						return
					break
				node = node.get_parent()

func get_feet_world_pos(node: Node2D) -> Vector2:
	return node.get_node("CollisionShape2D").global_position

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos = blocked_layer.to_local(world_pos)
	return blocked_layer.local_to_map(local_pos)

func is_npc_on_tile(world_pos: Vector2) -> bool:
	var target_cell = world_to_cell(world_pos)

	for npc in get_tree().get_nodes_in_group("npcs"):
		var npc_cell = world_to_cell(get_feet_world_pos(npc))
		if npc_cell == target_cell:
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

	if anim.animation != anim_name:
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
