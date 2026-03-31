extends Area2D

@export var target_scene: String
@export var target_spawn_id: String

var is_transitioning: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if is_transitioning:
		return

	if body.name != "Player":
		return

	is_transitioning = true

	body.can_move = false
	body.moving = false
	body.target_position = body.global_position

	Global.next_spawn_id = target_spawn_id

	var fade = get_tree().current_scene.get_node_or_null("FadeLayer")
	if fade != null:
		await fade.fade_out()

	get_tree().change_scene_to_file(target_scene)
