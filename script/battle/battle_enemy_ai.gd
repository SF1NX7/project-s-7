extends Node
## Tactical enemy turns: Inspector-configurable behavior and intelligence.
## Keeps the existing BattleCursor camera, HUD and movement timing.

@export_group("References")
@export var turn_path: NodePath = ^"../BattleTurn"
@export var units_path: NodePath = ^"../Units"
@export var cursor_path: NodePath = ^"../BattleCursor"
@export var blocked_path: NodePath = ^"../Blocked"

@export_group("AI")
@export var enable_ai: bool = true
@export var fallback_profile: EnemyAIProfile
@export_range(0, 24, 1) var fallback_mov: int = 4
@export_range(1, 24, 1) var fallback_detection_range: int = 8
@export_range(1, 12, 1) var fallback_attack_range: int = 1
@export_range(0.03, 0.8, 0.01) var step_duration: float = 0.17
@export_range(0.0, 2.0, 0.05) var think_delay: float = 0.25
@export var debug_attack_in_output: bool = true

@export_group("Turn Presentation")
@export_range(0.0, 3.0, 0.05) var camera_arrival_delay: float = 0.75
@export_range(0.0, 3.0, 0.05) var end_turn_pause: float = 0.50

@export_group("Debug Provocation")
@export var debug_provoke_on_first_turn: bool = false
@export var debug_provoke_hero_name: String = "Max"

var _turn: Node
var _units: Node2D
var _cursor: Node2D
var _blocked: TileMapLayer
var _busy: bool = false
var _directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
# instance_id -> {"post": Vector2i, "target": WeakRef, "turns": int}
var _enemy_state: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_turn = get_node_or_null(turn_path)
	_units = get_node_or_null(units_path) as Node2D
	_cursor = get_node_or_null(cursor_path) as Node2D
	_blocked = get_node_or_null(blocked_path) as TileMapLayer
	if _turn == null or _units == null or _cursor == null or _blocked == null:
		push_error("BattleEnemyAI: invalid reference paths.")
		return
	if _turn.has_signal("enemy_turn_started"):
		_turn.connect("enemy_turn_started", Callable(self, "_on_enemy_turn"))
	else:
		push_error("BattleEnemyAI: enemy_turn_started missing in BattleTurn.")

## Call from damage logic later; already usable from another GDScript.
func notify_enemy_attacked(enemy: Node2D, attacker: Node2D) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(attacker):
		return
	var state: Dictionary = _state_for(enemy)
	var profile: EnemyAIProfile = _profile_for(enemy)
	if profile != null and not profile.remember_attacker:
		return
	var old_ref: WeakRef = state.get("target")
	if profile != null and not profile.retarget_on_hit and old_ref != null and old_ref.get_ref() != null:
		return
	state["target"] = weakref(attacker)
	state["turns"] = profile.memory_turns if profile != null else 3
	_enemy_state[enemy.get_instance_id()] = state

func _on_enemy_turn(unit: Node2D, data: Resource) -> void:
	if not _busy:
		_run_enemy_turn.call_deferred(unit, data)

func _run_enemy_turn(unit: Node2D, data: Resource) -> void:
	if _busy:
		return
	_busy = true
	if camera_arrival_delay > 0.0:
		await get_tree().create_timer(camera_arrival_delay).timeout
	if not enable_ai or not is_instance_valid(unit):
		await _finish()
		return
	if think_delay > 0.0:
		await get_tree().create_timer(think_delay).timeout
	if not is_instance_valid(unit):
		await _finish()
		return
	var start: Vector2i = _cell(unit.global_position)
	var state: Dictionary = _state_for(unit)
	var post: Vector2i = state["post"]
	var profile: EnemyAIProfile = _profile_for(unit, data)
	var behavior: int = profile.behavior if profile != null else 2
	var intelligence: int = profile.intelligence_level if profile != null else 0
	if behavior == 4:
		intelligence = maxi(1, intelligence) # Tactical behavior values weak targets even at Basic level.
	var mov: int = clampi(_data_int(data, ["base_movement", "movement", "mov"], fallback_mov), 0, 24)
	if data != null and data.has_method("get_movement"):
		mov = clampi(int(data.call("get_movement")), 0, 24)
	var detect: int = profile.detection_range if profile != null else _data_int(data, ["detection_range"], fallback_detection_range)
	var attack_range: int = maxi(1, profile.attack_range if profile != null else _data_int(data, ["attack_range"], fallback_attack_range))
	var leash: int = profile.leash_range if profile != null else _data_int(data, ["leash_range"], 8)

	var heroes: Array[Node2D] = []
	for child in _units.get_children():
		var candidate := child as Node2D
		if candidate != null and candidate != unit and not candidate.is_in_group(&"battle_enemies") and _is_hero(candidate):
			heroes.append(candidate)

	if debug_provoke_on_first_turn and not bool(state.get("debugged", false)):
		for hero in heroes:
			if hero.name == debug_provoke_hero_name:
				notify_enemy_attacked(unit, hero)
				state = _state_for(unit)
				state["debugged"] = true
				break

	var distances: Dictionary = {}
	var previous: Dictionary = {}
	_flood(start, unit, distances, previous)
	var target: Node2D = _select_target(unit, heroes, profile, intelligence, detect, state)
	var memory_target: Node2D = _memory_target(state)
	# Pursuer locks a spotted target for several personal turns.
	if behavior == 3 and target != null and memory_target == null:
		state["target"] = weakref(target)
		state["turns"] = profile.memory_turns if profile != null else 3
		_enemy_state[unit.get_instance_id()] = state
		memory_target = target
	var from_memory: bool = target != null and target == memory_target
	var destination: Vector2i = start
	var has_destination: bool = false

	if target != null:
		var target_cell: Vector2i = _cell(target.global_position)
		# Guard and patrol enemies may not leave their home territory.
		var chase_limit: int = leash if behavior == 0 or behavior == 1 else -1
		var pursuit_limit: int = profile.pursuit_range if profile != null else 14
		if from_memory and pursuit_limit > 0 and _manhattan(post, target_cell) > pursuit_limit:
			target = null
		else:
			var lowest: float = INF
			for candidate_cell in distances.keys():
				var tile: Vector2i = candidate_cell
				var steps: int = int(distances[tile])
				if steps > mov or (chase_limit >= 0 and _manhattan(post, tile) > chase_limit):
					continue
				var gap: int = _manhattan(tile, target_cell)
				var score: float = float(maxi(0, gap - attack_range)) * 1000.0 + float(steps) * 0.1
				if intelligence >= 2:
					score += float(_manhattan(post, tile)) * 0.08
				if profile != null:
					score += _rng.randf_range(0.0, profile.randomness) * 2.0
				if score < lowest:
					lowest = score
					destination = tile
					has_destination = true
	if target == null:
		# Sentry guards the post; patrol wanders; others remain idle.
		if behavior == 1 and profile != null:
			if _rng.randf() <= profile.patrol_move_chance:
				destination = _choose_patrol_destination(start, post, distances, mov, profile)
				has_destination = destination != start
		elif behavior == 0 and profile != null and profile.return_to_post:
			destination = _closest_to_post(start, post, distances, mov)
			has_destination = destination != start

	if has_destination:
		var route: Array[Vector2i] = []
		var current: Vector2i = destination
		while current != start and previous.has(current):
			route.push_front(current)
			current = previous[current]
		for tile in route:
			if not is_instance_valid(unit):
				break
			var origin: Vector2i = _cell(unit.global_position)
			var direction: Vector2i = tile - origin
			if unit.has_method("play_walk"):
				unit.call("play_walk", direction)
			var tween := create_tween()
			tween.tween_property(unit, "global_position", unit.global_position + Vector2(direction) * float(_cell_size()), step_duration)
			await tween.finished
	if is_instance_valid(unit):
		if unit.has_method("play_idle"):
			unit.call("play_idle")
		if target != null and is_instance_valid(target) and _manhattan(_cell(unit.global_position), _cell(target.global_position)) <= attack_range:
			# Only the acting unit faces its target.
			_face_acting_unit(unit, target)
			if debug_attack_in_output:
				print("[BattleEnemyAI] %s attacks %s (DEBUG ONLY; no damage yet)" % [unit.name, target.name])
		if profile != null and profile.print_decisions:
			print("[BattleEnemyAI] %s mode=%d intelligence=%d target=%s moved=%s" % [unit.name, behavior, intelligence, target.name if is_instance_valid(target) else "none", str(destination != start)])
	if int(state.get("turns", 0)) > 0:
		state["turns"] = int(state["turns"]) - 1
		_enemy_state[unit.get_instance_id()] = state
	await _finish()

func _finish() -> void:
	if end_turn_pause > 0.0:
		await get_tree().create_timer(end_turn_pause).timeout
	_busy = false
	if is_instance_valid(_turn) and _turn.has_method("finish_enemy_turn"):
		_turn.call("finish_enemy_turn")

func _state_for(unit: Node2D) -> Dictionary:
	var id: int = unit.get_instance_id()
	if not _enemy_state.has(id):
		_enemy_state[id] = {"post": _cell(unit.global_position), "target": null, "turns": 0, "debugged": false}
	return _enemy_state[id]

func _memory_target(state: Dictionary) -> Node2D:
	if int(state.get("turns", 0)) <= 0:
		return null
	var ref: WeakRef = state.get("target")
	if ref == null:
		return null
	return ref.get_ref() as Node2D

func _profile_for(unit: Node2D, data: Resource = null) -> EnemyAIProfile:
	if data != null:
		for prop in data.get_property_list():
			if String(prop["name"]) == "ai_profile":
				var p := data.get("ai_profile") as EnemyAIProfile
				if p != null:
					return p
	return fallback_profile

func _select_target(unit: Node2D, heroes: Array[Node2D], profile: EnemyAIProfile, intelligence: int, detect: int, state: Dictionary) -> Node2D:
	var memorized: Node2D = _memory_target(state)
	if memorized != null and heroes.has(memorized):
		return memorized
	var chosen: Node2D
	var best_score: float = INF
	for hero in heroes:
		var distance: int = _manhattan(_cell(unit.global_position), _cell(hero.global_position))
		if distance > detect:
			continue
		var hp_fraction: float = _hero_health_ratio(hero)
		var threat: float = _hero_threat(hero)
		var score: float = float(distance)
		if intelligence >= 1:
			var hp_weight: float = profile.low_hp_weight if profile != null else 3.0
			score -= (1.0 - hp_fraction) * hp_weight * 2.0
		if intelligence >= 2:
			var threat_weight: float = profile.threat_weight if profile != null else 1.0
			score -= threat * threat_weight * 0.2
		if intelligence >= 3:
			# Elite considers whether target can be reached next turn.
			score += float(maxi(0, distance - 4)) * 0.25
		if score < best_score:
			best_score = score
			chosen = hero
	return chosen

func _hero_health_ratio(hero: Node2D) -> float:
	var party: Variant = _turn.get("party")
	if party == null:
		return 1.0
	for data in party.heroes:
		if data == null or data.hero_name != hero.name:
			continue
		var stats: Resource = data.get("base_stats") as Resource
		if stats == null:
			return 1.0
		var raw_max_hp: Variant = stats.get("hp")
		if typeof(raw_max_hp) != TYPE_INT and typeof(raw_max_hp) != TYPE_FLOAT:
			return 1.0
		var max_hp: float = maxf(1.0, float(raw_max_hp))
		var raw_hp: Variant = data.get("hp_current")
		var hp: float = max_hp
		if typeof(raw_hp) == TYPE_INT or typeof(raw_hp) == TYPE_FLOAT:
			hp = float(raw_hp)
		return clampf(hp / max_hp, 0.0, 1.0)
	return 1.0

func _hero_threat(hero: Node2D) -> float:
	var party: Variant = _turn.get("party")
	if party == null:
		return 0.0
	for data in party.heroes:
		if data == null or data.hero_name != hero.name:
			continue
		var stats: Resource = data.get("base_stats") as Resource
		if stats == null:
			return 0.0
		var value: float = 0.0
		for key in ["attack", "magic"]:
			var raw_value: Variant = stats.get(key)
			if typeof(raw_value) == TYPE_INT or typeof(raw_value) == TYPE_FLOAT:
				value += float(raw_value)
		return value
	return 0.0

func _choose_patrol_destination(start: Vector2i, post: Vector2i, distances: Dictionary, mov: int, profile: EnemyAIProfile) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for key in distances.keys():
		var cell: Vector2i = key
		if cell == start:
			continue
		if int(distances[cell]) <= mini(mov, profile.patrol_max_steps) and _manhattan(cell, post) <= profile.patrol_radius:
			candidates.append(cell)
	if candidates.is_empty():
		return start
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _closest_to_post(start: Vector2i, post: Vector2i, distances: Dictionary, mov: int) -> Vector2i:
	var best: Vector2i = start
	var best_dist: int = _manhattan(start, post)
	for key in distances.keys():
		var cell: Vector2i = key
		if int(distances[cell]) <= mov and _manhattan(cell, post) < best_dist:
			best = cell
			best_dist = _manhattan(cell, post)
	return best

func _is_hero(unit: Node2D) -> bool:
	var party: Variant = _turn.get("party")
	if party == null:
		return false
	for hero in party.heroes:
		if hero != null and hero.hero_name == unit.name:
			return true
	return false

func _flood(start: Vector2i, mover: Node2D, dist: Dictionary, prev: Dictionary) -> void:
	var queue: Array[Vector2i] = [start]
	dist[start] = 0
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction in _directions:
			var next: Vector2i = cell + direction
			if dist.has(next) or not _free(next, mover):
				continue
			dist[next] = int(dist[cell]) + 1
			prev[next] = cell
			queue.append(next)

func _free(cell: Vector2i, mover: Node2D) -> bool:
	if not _in_grid(cell):
		return false
	var blocked_cell: Vector2i = _blocked.local_to_map(_blocked.to_local(_cell_center(cell)))
	if _blocked.get_cell_source_id(blocked_cell) != -1:
		return false
	for child in _units.get_children():
		var other := child as Node2D
		if other != null and other != mover and _cell(other.global_position) == cell:
			return false
	return true

func _in_grid(cell: Vector2i) -> bool:
	var first: Vector2i = _cursor.get("first_cell")
	var size: Vector2i = _cursor.get("grid_size")
	return cell.x >= first.x and cell.y >= first.y and cell.x < first.x + size.x and cell.y < first.y + size.y

func _cell_size() -> int:
	return maxi(1, int(_cursor.get("cell_size")))

func _cell(world: Vector2) -> Vector2i:
	var origin: Vector2 = _cursor.get_parent().to_global(_cursor.get("grid_origin"))
	var first: Vector2i = _cursor.get("first_cell")
	var relative: Vector2 = world - origin
	return first + Vector2i(floori(relative.x / float(_cell_size())), floori(relative.y / float(_cell_size())))

func _cell_center(cell: Vector2i) -> Vector2:
	var first: Vector2i = _cursor.get("first_cell")
	var origin: Vector2 = _cursor.get_parent().to_global(_cursor.get("grid_origin"))
	return origin + Vector2(cell - first) * float(_cell_size()) + Vector2.ONE * (float(_cell_size()) * 0.5)

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _data_int(data: Resource, names: Array[String], fallback: int) -> int:
	if data == null:
		return fallback
	for name in names:
		for property in data.get_property_list():
			if String(property["name"]) == name:
				var value: Variant = data.get(name)
				if value is int or value is float:
					return int(value)
	return fallback


## Face only the acting enemy. Supports both BattleUnit animation scripts
## and standalone enemy scenes with just an AnimatedSprite2D.
func _face_acting_unit(actor: Node2D, target: Node2D) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return
	if actor.has_method("face_target"):
		actor.call("face_target", target)
	var sprite: AnimatedSprite2D = actor.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		for candidate in actor.find_children("*", "AnimatedSprite2D", true, false):
			sprite = candidate as AnimatedSprite2D
			break
	if sprite == null or sprite.sprite_frames == null:
		return
	var offset: Vector2 = target.global_position - actor.global_position
	if offset.length_squared() < 0.001:
		return
	var facing: String = ""
	if absf(offset.x) > absf(offset.y):
		facing = "right" if offset.x > 0.0 else "left"
	else:
		facing = "down" if offset.y > 0.0 else "up"
	var idle: StringName = StringName("Idle_" + facing)
	if sprite.sprite_frames.has_animation(idle) and sprite.sprite_frames.get_frame_count(idle) > 0:
		sprite.play(idle)
		return
	var walk: StringName = StringName(facing.capitalize())
	if sprite.sprite_frames.has_animation(walk) and sprite.sprite_frames.get_frame_count(walk) > 0:
		sprite.play(walk)
		sprite.pause()
		sprite.set_frame_and_progress(0, 0.0)
