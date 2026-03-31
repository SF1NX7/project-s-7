extends Node2D

func _ready() -> void:
	var player = $Player
	var spawn = get_node_or_null("spawn_0")

	if Global.next_spawn_id != "":
		spawn = get_node_or_null(Global.next_spawn_id)

	if spawn != null:
		player.global_position = spawn.global_position

	Global.next_spawn_id = ""

	var fade = get_node_or_null("FadeLayer")
	if fade != null:
		fade.fade_rect.color.a = 1.0
		fade.fade_in()
