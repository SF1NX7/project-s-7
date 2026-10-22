extends Area2D

@export_file("*.tscn") var battle_scene: String = "res://scene/battle/BattleTest.tscn"

var _starting: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _starting or not body.is_in_group("player"):
		return

	if battle_scene.is_empty():
		push_warning("BattleTrigger: battle_scene is empty.")
		return

	_starting = true
	set_deferred("monitoring", false)

	if "can_move" in body:
		body.can_move = false
	if "moving" in body:
		body.moving = false
	if "target_position" in body:
		body.target_position = body.global_position

	var fade: Node = get_tree().current_scene.get_node_or_null("FadeLayer")
	if fade != null and fade.has_method("fade_out"):
		await fade.fade_out()

	get_tree().change_scene_to_file(battle_scene)
