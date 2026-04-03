extends Button
class_name InventorySlot

@onready var icon_rect: TextureRect = $Icon

func set_icon(tex: Texture2D) -> void:
	icon_rect.texture = tex
