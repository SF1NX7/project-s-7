extends Node2D

func _ready() -> void:
	var player: Node2D = find_child("Player", true, false) as Node2D
	var spawn: Node2D = get_node_or_null("spawn_0") as Node2D

	if Global.next_spawn_id != "":
		spawn = find_child(Global.next_spawn_id, true, false) as Node2D

	if player != null and spawn != null:
		player.global_position = spawn.global_position
	else:
		push_warning("world_2.gd: Player or spawn not found. player=%s spawn=%s" % [player, spawn])

	Global.next_spawn_id = ""

	var fade: Node = get_node_or_null("FadeLayer")
	if fade != null and fade.has_method("fade_in"):
		fade.call("fade_in")
