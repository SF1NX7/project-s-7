extends Resource
class_name ItemData

@export var icon: Texture2D
@export var preview: Texture2D
@export var title: String = ""
@export var pickup_color: Color = Color(0.615, 0.299, 0.373, 1.0)
@export_multiline var description: String = ""

# Вкладки инвентаря (фильтр)
enum ItemClass { WPN, ARM, POT, OTH }
@export var item_class: ItemClass = ItemClass.OTH

# Экипировка: в какой слот надевается предмет
enum EquipSlot { NONE, HEAD, ARMOR, BOOTS, WEAPON, RING }
@export var equip_slot: EquipSlot = EquipSlot.NONE

# "Профессии/владения": что нужно уметь, чтобы носить/использовать предмет.
# 0 = любой герой может использовать (ограничений нет).
@export_flags(
	"AXE",
	"SWORD",
	"MACE",
	"BOW",
	"STAFF",
	"DAGGER",
	"ROBE",
	"LIGHT_ARMOR",
	"HEAVY_ARMOR"
)
var required_profs_mask: int = 0
