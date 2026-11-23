extends TextureButton
class_name MagicSlot

# Optional textures (set once in Inspector on each slot, or make a MagicSlot scene).
@export var locked_texture: Texture2D
@export var empty_texture: Texture2D

@onready var icon: TextureRect = $Icon
@onready var lock: TextureRect = $Lock

var spell: SpellData = null
var locked: bool = true
var exists: bool = false


func _ready() -> void:
	# All spell icons must fit within their slots, regardless of PNG dimensions.
	# Some MagicScreen slots omit these settings in the .tscn resource.
	if icon != null:
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(p_spell: SpellData, p_exists: bool, p_locked: bool) -> void:
	spell = p_spell
	exists = p_exists
	locked = p_locked

	# Make sure overlays don't steal input (no mouse anyway, but safe)
	if icon:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lock:
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not exists:
		# Slot not used by this hero
		if icon:
			icon.texture = empty_texture
		if lock:
			lock.texture = locked_texture
			lock.visible = true
		return

	if locked:
		if icon:
			icon.texture = null
		if lock:
			lock.texture = locked_texture
			lock.visible = true
		return

	# Unlocked
	if lock:
		lock.visible = false
	if icon:
		icon.texture = spell.icon if spell != null else null
