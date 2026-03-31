extends Area2D

@export var closed_texture: Texture2D
@export var open_texture: Texture2D

@export var target_scene: String = ""
@export var target_spawn_id: String = ""

@onready var sprite: Sprite2D = $Sprite2D

var is_opening := false


func _ready() -> void:
	if closed_texture:
		sprite.texture = closed_texture


func open_door() -> void:
	if is_opening:
		return
	
	is_opening = true
	
	if open_texture:
		sprite.texture = open_texture
	
	await get_tree().create_timer(0.2).timeout
	
	Global.next_spawn_id = target_spawn_id
	get_tree().change_scene_to_file(target_scene)
