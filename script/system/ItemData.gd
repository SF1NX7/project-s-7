extends Resource
class_name ItemData

@export_group("Identity")
# Use this as a stable key for quests/dialogues (e.g. "helm_1", "item_key_01").
# It is NOT the filename. You set it manually in the .tres Inspector.
@export var id: String = ""

@export_group("Visual")
@export var icon: Texture2D
@export var preview: Texture2D
@export var pickup_color: Color = Color(0.615, 0.299, 0.373, 1.0)

@export_group("Text")
@export var title: String = ""
@export_multiline var description: String = ""

@export_group("Inventory / Equip")
# Inventory tabs (filter)
enum ItemClass { WPN, ARM, POT, OTH }
@export var item_class: ItemClass = ItemClass.OTH

# Equipment: which slot this item is equipped to
enum EquipSlot { NONE, HEAD, ARMOR, BOOTS, WEAPON, RING }
@export var equip_slot: EquipSlot = EquipSlot.NONE

@export_group("Permissions")
# Professions/permissions required to equip/use (0 = anyone)
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

@export_group("Use in Inventory")
@export var usable_in_inventory: bool = false
@export var use_effect: ItemUseEffect

@export_group("Bonuses (optional)")
@export var bonuses: StatsBonus = StatsBonus.new()
