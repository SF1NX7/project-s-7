extends Node

# This is NOT a full player replacement.
# Add this as a temporary child node of Player.
#
# Tree:
# Player
#   InteractionDebugProbe (Node) <- this script
#
# It prints what Player/InteractionArea sees when you press E/action.

@export var action_name: String = "action"
@export var interaction_area_path: NodePath = NodePath("../InteractionArea")
@export var print_every_action: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(action_name):
		return

	var area := get_node_or_null(interaction_area_path) as Area2D
	if area == null:
		print("InteractionDebugProbe: InteractionArea NOT FOUND at path: ", interaction_area_path)
		return

	print("=== InteractionDebugProbe ACTION ===")
	print("InteractionArea path: ", area.get_path())
	print("monitoring: ", area.monitoring)
	print("monitorable: ", area.monitorable)
	print("collision_layer: ", area.collision_layer)
	print("collision_mask: ", area.collision_mask)

	var overlaps := area.get_overlapping_areas()
	print("overlapping areas count: ", overlaps.size())

	for a in overlaps:
		if a == null:
			continue

		print("- area: ", a.name, " path=", a.get_path(), " layer=", a.collision_layer, " mask=", a.collision_mask)

		var node: Node = a
		var depth := 0
		while node != null and depth < 8:
			print("  check node: ", node.name, " class=", node.get_class(), " has interact=", node.has_method("interact"), " has any_side=", node.has_method("can_interact_from_any_side"))

			if node.has_method("interact"):
				print("  FOUND interact() on: ", node.get_path())
				break

			node = node.get_parent()
			depth += 1

	print("====================================")
