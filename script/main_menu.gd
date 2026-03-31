extends Control

func _ready() -> void:
	$VBoxContainer/Play.pressed.connect(_on_play_pressed)
	$VBoxContainer/Option.pressed.connect(_on_options_pressed)

	var fade = get_node_or_null("FadeLayer")
	if fade != null:
		fade.fade_rect.color.a = 1.0
		fade.fade_in()

func _on_play_pressed() -> void:
	var fade = get_node_or_null("FadeLayer")
	if fade != null:
		await fade.fade_out()

	Global.next_spawn_id = "spawn_0"
	get_tree().change_scene_to_file("res://scene/World.tscn")

func _on_options_pressed() -> void:
	print("Опции пока не сделаны")
