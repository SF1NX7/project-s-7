extends TextureButton
class_name EquipSlotButton

@export var slot_type: ItemData.EquipSlot = ItemData.EquipSlot.NONE
var equip_slot: String = "NONE"

@export_flags("AXE", "SWORD", "MACE", "BOW", "STAFF", "DAGGER", "ROBE", "LIGHT_ARMOR", "HEAVY_ARMOR")
var required_profs_mask: int = 0
