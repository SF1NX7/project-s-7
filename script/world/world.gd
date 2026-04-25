extends Node2D
@export var location_display_name: String = "Деревня у реки"

func _ready() -> void:
	if typeof(Save_Manager) != TYPE_NIL:
		Save_Manager.set_location_display_name(location_display_name)

	var player = $YSortObjects/Player
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
