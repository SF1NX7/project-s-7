extends Area2D

const PIXEL_TRANSITION: PackedScene = preload("res://scene/battle/PixelTransition.tscn")

@export_file("*.tscn") var battle_scene: String = "res://scene/battle/BattleTest.tscn"

@export_group("Pixel transition")
@export_range(0.1, 3.0, 0.05, "suffix:s") var transition_duration: float = 0.5
@export_range(2.0, 64.0, 1.0, "suffix:px") var pixel_size: float = 8.0
@export var dissolve_color: Color = Color.BLACK

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

	var transition: CanvasLayer = PIXEL_TRANSITION.instantiate()
	get_tree().root.add_child(transition)
	transition.call("play", battle_scene, transition_duration, pixel_size, dissolve_color)
