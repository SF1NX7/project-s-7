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
