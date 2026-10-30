extends Node2D
## Separate enemy spawn points, independent from ally Spawn1..Spawn7.
## Enemy units are added as siblings of deployed heroes under Units.
## At this stage enemy units occupy cells but DO NOT enter BattleTurn.

@export_group("References")
@export var units_path: NodePath = ^"../Units"
@export var enemy_catalog: EnemyCatalog = preload("res://data/items/enemy_data.tres")

@export_group("First Enemy")
@export var spawn_first_enemy: bool = true
@export var first_enemy_id: StringName = &"goblin"
@export var first_marker_path: NodePath = ^"EnemySpawn1"

@export_group("Debug")
@export var warn_on_occupied_cell: bool = true
@export_range(8, 128, 1) var cell_size: int = 32


func _ready() -> void:
	if not spawn_first_enemy:
		return
	var units := get_node_or_null(units_path) as Node2D
	var marker := get_node_or_null(first_marker_path) as Marker2D
	if units == null or marker == null:
		push_error("EnemySpawns: check Units Path and First Marker Path.")
		return
	if enemy_catalog == null:
		push_error("EnemySpawns: Enemy Catalog missing.")
		return
	var entry := enemy_catalog.find_enemy(first_enemy_id)
	if entry == null:
		push_error("EnemySpawns: enemy_id '%s' not found in catalog." % String(first_enemy_id))
		return
	if entry.scene == null:
		push_error("EnemySpawns: assign Scene for '%s' in enemy_data.tres." % String(first_enemy_id))
		return
	var cell := _cell(marker.global_position)
	for child in units.get_children():
		var other := child as Node2D
		if other != null and _cell(other.global_position) == cell:
			if warn_on_occupied_cell:
				push_warning("EnemySpawns: EnemySpawn1 is occupied by %s." % other.name)
			return
	var instance := entry.scene.instantiate() as Node2D
	if instance == null:
		push_error("EnemySpawns: enemy scene root must be Node2D.")
		return
	instance.name = "Enemy_%s" % String(entry.enemy_id)
	units.add_child(instance)
	instance.global_position = marker.global_position
	instance.set_meta("enemy_id", String(entry.enemy_id))
	instance.set_meta("enemy_data", entry)
	instance.add_to_group(&"battle_enemies")


func _cell(world: Vector2) -> Vector2i:
	# Uses global grid coordinates, matching the other 32 px tile positions.
	return Vector2i(floori(world.x / float(cell_size)), floori(world.y / float(cell_size)))
