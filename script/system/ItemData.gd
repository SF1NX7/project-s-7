extends Resource
class_name ItemData

@export var icon: Texture2D
@export var preview: Texture2D
@export var title: String = ""
@export_multiline var description: String = ""

enum ItemClass { WPN, ARM, POT, OTH }
@export var item_class: ItemClass = ItemClass.OTH
