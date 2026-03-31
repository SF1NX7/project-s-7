@tool
extends ColorRect

func _ready():
	if Engine.is_editor_hint():
		visible = false
