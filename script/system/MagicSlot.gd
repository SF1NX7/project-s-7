extends TextureButton
class_name MagicSlot

@export var locked_texture: Texture2D
@export var empty_texture: Texture2D

@onready var icon: TextureRect = $Icon
@onready var lock: TextureRect = $Lock

var spell: SpellData = null
var locked: bool = true
var exists: bool = false

func set_state(p_spell: SpellData, p_exists: bool, p_locked: bool) -> void:
	spell = p_spell
	exists = p_exists
	locked = p_locked

	if not exists:
		icon.texture = empty_texture
		lock.texture = locked_texture
		lock.visible = true
		return

	if locked:
		icon.texture = null
		lock.texture = locked_texture
		lock.visible = true
		return

	lock.visible = false
	icon.texture = spell.icon if spell != null else null
