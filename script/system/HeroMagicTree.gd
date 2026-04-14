extends Resource
class_name HeroMagicTree
# A fixed 4x4 layout for one hero: 4 branches x 4 levels.

@export_group("Tree")
@export var branches: Array[MagicBranch] = []

func get_branch(i: int) -> MagicBranch:
	if i < 0 or i >= branches.size():
		return null
	return branches[i]

func get_unlock(branch_index: int, level_index: int) -> SpellUnlock:
	var b := get_branch(branch_index)
	if b == null:
		return null
	if level_index < 0 or level_index >= b.levels.size():
		return null
	return b.levels[level_index]
