extends Node2D

## Seven editable deployment points for a tactical battle.
## This stage spawns the leader only; other party members are not spawned yet.

@export_group("Deployment")
@export var units_path: NodePath = ^"../Units"
@export var leader_scene: PackedScene = preload("res://scene/battle/BattleHero.tscn")
@export var spawn_leader: bool = true
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

    if not spawn_leader or leader_scene == null:
        return

    var leader_point: Marker2D = points[0]
    var leader_cell := _cell_for_world_position(leader_point.global_position)
    if occupied_cells.has(leader_cell):
        push_warning("BattleSpawns: Spawn1 is occupied.")
        return

    var leader := leader_scene.instantiate() as Node2D
    if leader == null:
        push_error("BattleSpawns: Leader Scene must have a Node2D root.")
        return
    units.add_child(leader)
    leader.global_position = leader_point.global_position
    leader.name = "Max"
    occupied_cells[leader_cell] = leader


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
