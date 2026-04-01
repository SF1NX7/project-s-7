extends Area2D

@export var closed_texture: Texture2D
@export var open_texture: Texture2D
@export var is_open: bool = false

@onready var sprite = $Sprite2D

func _ready() -> void:
	update_visual()

func interact() -> void:
	print("DOOR INTERACT")
	if is_open:
		return

	is_open = true
	update_visual()

func update_visual() -> void:
	if is_open:
		sprite.texture = open_texture
	else:
		sprite.texture = closed_texture
		
