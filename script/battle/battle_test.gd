extends Node2D

const WORLD_2: String = "res://scene/world/World_2.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		# Temporary test return only. No victory is recorded.
		get_tree().change_scene_to_file(WORLD_2)
