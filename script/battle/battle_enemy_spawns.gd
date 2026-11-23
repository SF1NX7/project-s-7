extends Node2D
## Spawns independent enemy units from child Marker2D points.
## New EnemySpawnPoint nodes choose their own enemy resource or catalog ID.
## Legacy plain Marker2D nodes remain compatible with older battle maps.

@export_group("References")
@export var units_path: NodePath = ^"../Units"
@export var enemy_catalog: EnemyCatalog = preload("res://data/items/enemy_data.tres")

@export_group("First Enemy (Legacy)")
@export var spawn_first_enemy: bool = true
@export var first_enemy_id: StringName = &"goblin"
@export var first_marker_path: NodePath = ^"EnemySpawn1"

@export_group("Additional Enemies")
@export var spawn_additional_enemies: bool = true

@export_group("Debug")
@export var warn_on_occupied_cell: bool = true
@export_range(8, 128, 1) var cell_size: int = 32


func _ready() -> void:
	if not spawn_first_enemy:
		return

	var units := get_node_or_null(units_path) as Node2D
	if units == null:
		push_error("EnemySpawns: Units Path does not point to Units.")
		return

	var first_marker := get_node_or_null(first_marker_path) as Marker2D
	if first_marker == null:
		push_error("EnemySpawns: First Marker Path is missing.")
		return

	var used_markers: Array[Marker2D] = [first_marker]
	var counter: int = 1

	_spawn_from_marker(units, first_marker, first_enemy_id, counter)

	if not spawn_additional_enemies:
		return

	for node in get_children():
		if not (node is Marker2D):
			continue
		var marker := node as Marker2D
		if used_markers.has(marker):
			continue
		# Scripted spawn points work under any name. Keep old EnemySpawnN markers.
		if not (marker is EnemySpawnPoint) and not marker.name.begins_with("EnemySpawn"):
			continue
		counter += 1
		_spawn_from_marker(units, marker, first_enemy_id, counter)


func _spawn_from_marker(
		units: Node2D, marker: Marker2D, fallback_id: StringName, number: int
) -> void:
	var enemy_entry: EnemyData = null
	var selected_id: StringName = fallback_id

	if marker is EnemySpawnPoint:
		var point := marker as EnemySpawnPoint
		if not point.spawn_enabled:
			return
		enemy_entry = point.enemy_data
		selected_id = point.enemy_id

	if enemy_entry == null:
		if enemy_catalog == null:
			push_error("EnemySpawns: Enemy Catalog is missing for %s." % marker.name)
			return
		enemy_entry = enemy_catalog.find_enemy(selected_id) as EnemyData

	if enemy_entry == null:
		push_error("EnemySpawns: enemy '%s' not found for %s." % [
			String(selected_id), marker.name
		])
		return
	if enemy_entry.scene == null:
		push_error("EnemySpawns: Scene is missing for enemy at %s." % marker.name)
		return

	_spawn_enemy_at(units, marker, enemy_entry, number)


func _spawn_enemy_at(
		units: Node2D, marker: Marker2D, enemy_entry: EnemyData, number: int
) -> void:
	var cell := _cell(marker.global_position)
	for child in units.get_children():
		var other := child as Node2D
		if other != null and _cell(other.global_position) == cell:
			if warn_on_occupied_cell:
				push_warning("EnemySpawns: %s is occupied by %s." % [
					marker.name, other.name
				])
			return

	var instance := enemy_entry.scene.instantiate() as Node2D
	if instance == null:
		push_error("EnemySpawns: enemy scene root must be Node2D.")
		return

	instance.name = "Enemy_%s_%d" % [String(enemy_entry.enemy_id), number]
	units.add_child(instance)
	instance.global_position = marker.global_position
	instance.set_meta("enemy_id", String(enemy_entry.enemy_id))
	instance.set_meta("enemy_data", enemy_entry)
	instance.add_to_group(&"battle_enemies")


func _cell(world: Vector2) -> Vector2i:
	return Vector2i(
		floori(world.x / float(cell_size)),
		floori(world.y / float(cell_size))
	)
