extends Node2D

## Seven editable deployment points for a tactical battle.
## This stage spawns the leader only; other party members are not spawned yet.

@export_group("Deployment")
@export var units_path: NodePath = ^"../Units"
@export var leader_scene: PackedScene = preload("res://scene/battle/BattleHero.tscn")
@export var spawn_leader: bool = true

@export_group("Sara Deployment")
@export var sara_scene: PackedScene
@export var spawn_sara: bool = true
@export_range(1, 128, 1) var cell_size: int = 32

@export_group("Debug")
@export var warn_overlapping_points: bool = true

var occupied_cells: Dictionary = {}


func _ready() -> void:
    var units := get_node_or_null(units_path) as Node2D
    if units == null:
        push_error("BattleSpawns: Units node not found. Check Units Path in Inspector.")
        return

    var points: Array[Marker2D] = []
    for index in range(1, 8):
        var marker := get_node_or_null("Spawn%d" % index) as Marker2D
        if marker == null:
            push_error("BattleSpawns: missing Spawn%d." % index)
            return
        points.append(marker)

    var seen: Dictionary = {}
    for index in range(points.size()):
        var cell := _cell_for_world_position(points[index].global_position)
        if seen.has(cell):
            if warn_overlapping_points:
                push_warning("BattleSpawns: Spawn%d and Spawn%d use the same cell." % [seen[cell], index + 1])
        else:
            seen[cell] = index + 1

    if spawn_leader and leader_scene != null:
        _spawn_named_unit(units, points[0], leader_scene, "Max", 1)

    if spawn_sara and sara_scene != null:
        _spawn_named_unit(units, points[1], sara_scene, "Sara", 2)


func _spawn_named_unit(units: Node2D, point: Marker2D, unit_scene: PackedScene, unit_name: String, spawn_index: int) -> void:
    if units.get_node_or_null(NodePath(unit_name)) != null:
        push_warning("BattleSpawns: %s already exists in Units." % unit_name)
        return

    var cell := _cell_for_world_position(point.global_position)
    if occupied_cells.has(cell):
        push_warning("BattleSpawns: Spawn%d is occupied." % spawn_index)
        return

    # The shared tactical controllers expect a Node2D root.
    var instance := unit_scene.instantiate()
    var unit := instance as Node2D
    if unit == null:
        push_error("BattleSpawns: scene for %s must have a Node2D root." % unit_name)
        if instance != null:
            instance.free()
        return

    unit.name = unit_name
    units.add_child(unit)
    unit.global_position = point.global_position
    occupied_cells[cell] = unit


func _cell_for_world_position(world_pos: Vector2) -> Vector2i:
    var grid_pos: Vector2 = to_local(world_pos)
    return Vector2i(roundi(grid_pos.x / float(cell_size)), roundi(grid_pos.y / float(cell_size)))


## Use these checks later for friendly AND enemy movement.
## Neither team is allowed to enter an occupied cell.
func is_cell_occupied(cell: Vector2i) -> bool:
    return occupied_cells.has(cell)


func can_enter_cell(cell: Vector2i) -> bool:
    return not occupied_cells.has(cell)


func reserve_cell(cell: Vector2i, unit: Node2D) -> bool:
    if occupied_cells.has(cell):
        return false
    occupied_cells[cell] = unit
    return true


func release_cell(cell: Vector2i, unit: Node2D) -> void:
    if occupied_cells.get(cell) == unit:
        occupied_cells.erase(cell)
