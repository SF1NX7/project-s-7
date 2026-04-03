extends Control

@export var slot_scene: PackedScene
@onready var grid: GridContainer = $Content/left/Scroll/Grid

func _ready() -> void:
	_spawn_test_slots()

func _spawn_test_slots() -> void:
	for c in grid.get_children():
		c.queue_free()

	for i in range(20): # 5×4
		var slot = slot_scene.instantiate()
		grid.add_child(slot)
		slot.name = "Slot_%02d" % i
