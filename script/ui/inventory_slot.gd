extends Button
class_name InventorySlot

@onready var icon_rect: TextureRect = $Icon

func set_icon(tex: Texture2D) -> void:
	icon_rect.texture = tex
func set_selected(v: bool) -> void:
	modulate = Color(0.311, 0.476, 0.135, 1.0) if v else Color(0.437, 0.932, 0.316, 1.0)
