extends Resource
class_name ItemData

@export var icon: Texture2D          # 32x32 для слота
@export var preview: Texture2D       # 128x128 для превью справа
@export var title: String = ""
@export_multiline var description: String = ""
