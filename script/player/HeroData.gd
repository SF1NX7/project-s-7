extends Resource
class_name HeroData

@export_group("Identity")
@export var hero_name: String = "Hero"
@export var profession_name: String = "Class"
@export var portrait: Texture2D

@export_group("Equipment Permissions")
@export_flags("AXE","SWORD","MACE","BOW","STAFF","DAGGER","ROBE","LIGHT_ARMOR","HEAVY_ARMOR")
var allowed_profs_mask: int = 0

@export_group("Base Stats")
@export var base_stats: StatsBonus = StatsBonus.new()

@export_group("Progress")
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next: int = 100
@export var hp_current: int = 0
@export var mp_current: int = 0

@export_group("Talent")
@export var talent_icon: Texture2D
@export var talent_name: String = ""
@export_multiline var talent_desc: String = ""

@export_group("Magic")
@export var magic_tree: HeroMagicTree
