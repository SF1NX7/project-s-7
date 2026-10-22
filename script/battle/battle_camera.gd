extends Camera2D

@export_group("Follow")
@export var target: Node2D
@export var follow_enabled: bool = true
@export var center_on_cell: bool = true
@export_range(1, 128, 1) var cell_size: int = 32
@export var snap_on_start: bool = true

@export_group("Motion")
@export var smooth_follow: bool = true
@export_range(1.0, 30.0, 0.5) var follow_speed: float = 12.0


func _ready() -> void:
	process_priority = 10
	if target == null:
		push_warning("BattleCamera: assign BattleCursor to Target in Inspector.")
		return
	if follow_enabled and snap_on_start:
		global_position = _target_position()
		reset_smoothing()


func _process(delta: float) -> void:
	if not follow_enabled or not is_instance_valid(target):
		return

	var destination: Vector2 = _target_position()
	if smooth_follow:
		var weight: float = 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(destination, weight)
	else:
		global_position = destination


func _target_position() -> Vector2:
	var destination: Vector2 = target.global_position
	if center_on_cell:
		destination += Vector2.ONE * float(cell_size) * 0.5
	return destination
