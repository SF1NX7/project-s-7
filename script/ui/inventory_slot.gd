extends Button
class_name InventorySlot

@onready var icon_rect: TextureRect = $Icon

func set_icon(tex: Texture2D) -> void:
	icon_rect.texture = tex
func set_selected(v: bool) -> void:
	self_modulate = Color(1.0, 1.0, 1.0, 0.592) if v else Color(0.005, 0.005, 0.005, 1.0)
