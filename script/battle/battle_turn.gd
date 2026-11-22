extends Node
## First battle turn prototype. Reads existing HeroData and living units on the map.
## No battle actions, artificial enemies or permanent save mutations yet.

@export_group("References")
@export var units_path: NodePath = ^"../Units"
@export var cursor_path: NodePath = ^"../BattleCursor"
@export var party: PartyData = preload("res://data/items/party_data.tres")
@export var menu_path: NodePath = ^"../BattleMenu"
## Путь к уже существующему контроллеру физического урона.
@export var combat_path: NodePath = ^"../BattleCombat"

@export_group("Turn Rules")
@export var focus_cursor_on_active_unit: bool = true
@export var higher_speed_acts_first: bool = true

@export_group("Attack Targeting")
## Дальность обычной атаки в клетках (по горизонтали и вертикали).
@export_range(1, 12, 1) var hero_attack_range: int = 1
## Текст подсказки, если рядом с героем нет подходящей цели.
@export var no_targets_message: String = "Некого атаковать"
## Сколько секунд показывать сообщение об отсутствии целей.
@export_range(0.5, 5.0, 0.1) var no_targets_duration: float = 1.5

@export_group("Turn Indicator")
@export var show_turn_indicator: bool = true
@export var indicator_position: Vector2 = Vector2(8, 8)
@export_range(100, 360, 1) var indicator_width: int = 180
@export var indicator_background: Color = Color(0.09, 0.14, 0.25, 0.92)
@export var indicator_text_color: Color = Color.WHITE

signal active_unit_changed(unit: Node2D, hero: HeroData)
signal turn_completed(unit: Node2D, hero: HeroData)
signal enemy_turn_started(unit: Node2D, enemy_data: Resource)
signal attack_preview_finished
## Stage 1: validated selection; no MP/HP/turn mutation.
signal battle_spell_selected(unit: Node2D, hero: HeroData, spell: SpellData)
## Stage 2: confirmed target queue; no combat mutation yet.
signal battle_spell_targets_confirmed(unit: Node2D, hero: HeroData, spell: SpellData, center: Vector2i, targets: Array[Node2D])

@export_group("Magic Targeting")
@export var magic_range_color: Color = Color(0.25, 0.55, 1.0, 0.18)
@export var magic_area_color: Color = Color(1.0, 0.55, 0.12, 0.35)
@export var magic_enemy_outline: Color = Color(1.0, 0.25, 0.15, 1.0)
@export var magic_center_outline: Color = Color(1.0, 0.9, 0.35, 1.0)
@export_range(0.5, 4.0, 0.5) var magic_outline_width: float = 1.5


@export_group("Magic Highlight Effects")
@export var magic_enable_pulse: bool = true
@export_range(0.0, 5.0, 0.05) var magic_pulse_speed: float = 1.25
@export_range(0.0, 0.9, 0.05) var magic_pulse_strength: float = 0.28
@export var magic_enable_rounded_corners: bool = true
@export_range(0.0, 12.0, 1.0) var magic_corner_radius: float = 4.0
@export_range(0.0, 6.0, 0.5) var magic_cell_inset: float = 1.0
@export_range(0.0, 1.0, 0.05) var magic_fill_opacity: float = 0.8
@export var magic_enable_glow: bool = true
@export_range(0.0, 1.0, 0.05) var magic_glow_strength: float = 0.65
@export var magic_enable_animated_border: bool = true
@export var magic_enable_particles: bool = true
@export_range(0, 16, 1) var magic_particle_amount: int = 5
@export_range(0.0, 32.0, 0.5) var magic_particle_speed: float = 8.0
@export_range(-10, 10, 1) var magic_overlay_z_index: int = 0

var _magic_fx_clock: float = 0.0

var _spell_targeting: bool = false
var _pending_spell: SpellData
var _spell_centers: Array[Vector2i] = []
var _spell_single_cells: Array[Vector2i] = []
var _spell_center: Vector2i
var _spell_overlay: Node2D
var _spell_saved_mode: bool
var _spell_saved_move_process: bool
var _spell_saved_move_input: bool
var _spell_saved_cursor_input: bool
var _spell_saved_menu_input: bool

var active_unit: Node2D
var active_hero: HeroData
var active_enemy_data: Resource
var _units: Node2D
var _cursor: Node2D
var _label: Label
var _panel: PanelContainer
var _roster: Array[Dictionary] = []
var _turn_index: int = -1
var _menu: Node
var _combat: Node
var _is_switching: bool = false
var _battle_stopped: bool = false
var _death_presentation_active: bool = false
var _enemy_turn_end_pending: bool = false
var _attack_targeting_active: bool = false
var _attack_targets: Array[Node2D] = []
var _attack_target_index: int = 0
var _attack_message_serial: int = 0

const BATTLE_MAGIC_SCENE: PackedScene = preload("res://scene/ui/MagicScreen.tscn")
var _battle_magic_layer: CanvasLayer
var _battle_magic: MagicScreen
var _battle_magic_open: bool = false
var _battle_spell_chosen: SpellData
var _magic_move_process: bool
var _magic_move_input: bool
var _magic_cursor_input: bool
var _magic_menu_input: bool

const BATTLE_INVENTORY_SCENE: PackedScene = preload("res://scene/ui/InventoryScreen.tscn")
var _battle_inventory_layer: CanvasLayer
var _battle_inventory: InventoryScreen
var _battle_item_chosen: ItemData
var _battle_inventory_open: bool = false
var _battle_move_was_processing: bool = false
var _battle_move_was_listening: bool = false

# Stage 2: item targeting shares the existing battle cursor / BattleHover.
# The item is NOT consumed and no HP/XP/turn data is changed here.
var _item_targeting_active: bool = false
var _item_targets: Array[Node2D] = []
var _item_target_index: int = 0
var _pending_battle_item: ItemData = null


func _ready() -> void:
	_units = get_node_or_null(units_path) as Node2D
	_cursor = get_node_or_null(cursor_path) as Node2D
	if _units == null or _cursor == null:
		push_error("BattleTurn: Check Units Path and Cursor Path.")
		return
	_menu = get_node_or_null(menu_path)
	_combat = get_node_or_null(combat_path)
	if _combat == null:
		push_warning("BattleTurn: BattleCombat не найден; атака героев будет недоступна.")
	if _menu != null and _menu.has_signal("command_selected"):
		_menu.connect("command_selected", Callable(self, "_on_command_selected"))
	else:
		push_warning("BattleTurn: BattleMenu command signal not found. Check Menu Path.")
	_create_indicator()
	call_deferred("_start_first_turn")

# При прицеливании курсор скрыт: цель отмечается пульсацией BattleHover.
# Отдельная _process для принудительного показа рамки больше не нужна.

func _start_first_turn() -> void:
	var roster: Array[Dictionary] = []
	if party == null:
		push_warning("BattleTurn: Party resource is missing.")
		return
	for child in _units.get_children():
		var unit := child as Node2D
		if unit == null:
			continue
		for hero in party.heroes:
			if hero != null and hero.hero_name == unit.name and int(hero.hp_current) > 0:
				var speed: int = 0
				if hero.base_stats != null:
					speed = hero.base_stats.speed
				roster.append({"unit": unit, "hero": hero, "enemy": null, "speed": speed})
				break
	for child in _units.get_children():
		var enemy_unit := child as Node2D
		if enemy_unit == null or not enemy_unit.is_in_group(&"battle_enemies") or bool(enemy_unit.get_meta("battle_defeated", false)):
			continue
		var enemy_entry: Resource = enemy_unit.get_meta("enemy_data", null) as Resource
		var enemy_speed: int = _enemy_int(enemy_entry, ["speed"], 1)
		roster.append({"unit": enemy_unit, "hero": null, "enemy": enemy_entry, "speed": enemy_speed})
	if roster.is_empty():
		push_warning("BattleTurn: No deployed heroes found in Units.")
		return
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["speed"] == b["speed"]:
			return _party_index(a["hero"]) < _party_index(b["hero"])
		if higher_speed_acts_first:
			return a["speed"] > b["speed"]
		return a["speed"] < b["speed"]
	)
	_roster = roster
	_turn_index = 0
	_activate_current_turn()

func _on_command_selected(command: String) -> void:
	if _battle_stopped or _death_presentation_active or _is_switching or not is_instance_valid(active_unit) or active_enemy_data != null:
		return
	if _menu == null or _menu.get("is_open") != true:
		return
	if _battle_magic_open or _spell_targeting:
		return
	if command == "magic":
		_open_battle_magic()
		return
	if command == "item":
		_open_battle_inventory()
		return
	if command == "attack":
		_start_attack_targeting()
		return
	if command != "defend":
		return
	_is_switching = true
	if _menu.has_method("close_menu"):
		_menu.call("close_menu")
	turn_completed.emit(active_unit, active_hero)
	call_deferred("_next_turn")





## Open the existing global inventory UI, using its real grid/tabs/cursor.
## Stage 1: USE selects an item; target selection and effects are not implemented here.
func _open_battle_magic() -> void:
	if _battle_magic_open or _battle_inventory_open or active_hero == null:
		return
	var movement: Node = get_node_or_null(^"../BattleMove")
	if movement != null and bool(movement.get("_animating")):
		return
	var screen: MagicScreen = BATTLE_MAGIC_SCENE.instantiate() as MagicScreen
	if screen == null:
		push_error("BattleTurn: MagicScreen root is invalid.")
		return
	_battle_magic_open = true
	_battle_spell_chosen = null
	_battle_magic = screen
	_magic_menu_input = _menu.is_processing_input()
	_menu.call("close_menu")
	_menu.set_process_input(false)
	if movement != null:
		_magic_move_process = movement.is_processing()
		_magic_move_input = movement.is_processing_unhandled_key_input()
		movement.set("_direction", Vector2i.ZERO)
		movement.set_process(false)
		movement.set_process_unhandled_key_input(false)
	if _cursor != null:
		_magic_cursor_input = _cursor.is_processing_unhandled_key_input()
		_cursor.set("_held_direction", Vector2i.ZERO)
		_cursor.set_process_unhandled_key_input(false)
	_battle_magic_layer = CanvasLayer.new()
	_battle_magic_layer.name = "BattleMagicLayer"
	_battle_magic_layer.layer = 40
	add_child(_battle_magic_layer)
	screen.party = party
	_battle_magic_layer.add_child(screen)
	screen.battle_spell_selected.connect(_on_battle_spell_selected)
	screen.closed.connect(_on_battle_magic_closed)
	screen.open_battle(party, active_hero)

func _on_battle_spell_selected(spell: SpellData) -> void:
	if _battle_magic_open and active_hero != null and spell != null:
		if active_hero.mp_current >= maxi(0, spell.mp_cost):
			_battle_spell_chosen = spell

func _on_battle_magic_closed() -> void:
	if not _battle_magic_open:
		return
	# Deferred: the closing key must not reach BattleMenu or Battlefield.
	call_deferred("_finish_battle_magic_close")

func _finish_battle_magic_close() -> void:
	if not _battle_magic_open:
		return
	var chosen: SpellData = _battle_spell_chosen
	_battle_spell_chosen = null
	_battle_magic_open = false
	if is_instance_valid(_battle_magic_layer):
		_battle_magic_layer.queue_free()
	_battle_magic_layer = null
	_battle_magic = null
	var movement: Node = get_node_or_null(^"../BattleMove")
	if movement != null:
		movement.set_process(_magic_move_process)
		movement.set_process_unhandled_key_input(_magic_move_input)
	if is_instance_valid(_cursor):
		_cursor.set_process_unhandled_key_input(_magic_cursor_input)
	if is_instance_valid(_menu):
		_menu.set_process_input(_magic_menu_input)
		if chosen == null and not _battle_stopped and not _is_switching:
			_menu.call("open_menu")
	if movement != null and movement.has_method("_apply_input_mode"):
		movement.call("_apply_input_mode")
	if chosen != null and active_hero != null and is_instance_valid(active_unit) and not _battle_stopped:
		battle_spell_selected.emit(active_unit, active_hero, chosen)
		_start_spell_targeting(chosen)


# Magic Stage 2: targeting only. Uses the same cell convention as physical attacks.
func is_spell_targeting() -> bool:
	return _spell_targeting


func is_spell_target_unit(unit: Node2D) -> bool:
	return _spell_targeting and _spell_targets_at(_spell_center).has(unit)


func _spell_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _spell_targets_at(center: Vector2i) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if _pending_spell == null or _units == null:
		return targets
	for child in _units.get_children():
		var enemy: Node2D = child as Node2D
		if not is_instance_valid(enemy) or not enemy.is_in_group(&"battle_enemies") or not _unit_is_alive(enemy):
			continue
		if _spell_distance(center, _attack_world_to_cell(enemy.global_position)) <= maxi(0, _pending_spell.area_radius):
			targets.append(enemy)
	# Center first, then map order. Each unit appears only once.
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var ca: Vector2i = _attack_world_to_cell(a.global_position)
		var cb: Vector2i = _attack_world_to_cell(b.global_position)
		var da: int = _spell_distance(center, ca)
		var db: int = _spell_distance(center, cb)
		if da != db:
			return da < db
		if ca.y != cb.y:
			return ca.y < cb.y
		if ca.x != cb.x:
			return ca.x < cb.x
		return a.get_index() < b.get_index()
	)
	return targets


func _start_spell_targeting(spell: SpellData) -> void:
	if spell == null or active_hero == null or not is_instance_valid(active_unit) or _cursor == null or _units == null or _battle_stopped or _is_switching:
		return
	if spell.effect_type != SpellData.EffectType.DAMAGE:
		_show_attack_notice("Пока доступен выбор атакующей магии")
		_restore_after_attack_cancel()
		return
	if active_hero.mp_current < maxi(0, spell.mp_cost):
		_show_attack_notice("Недостаточно MP")
		_restore_after_attack_cancel()
		return
	_pending_spell = spell
	_spell_centers.clear()
	_spell_single_cells.clear()
	var origin: Vector2i = _attack_world_to_cell(active_unit.global_position)
	var first: Vector2i = _cursor.get("first_cell")
	var size: Vector2i = _cursor.get("grid_size")
	for y in range(first.y, first.y + size.y):
		for x in range(first.x, first.x + size.x):
			var cell := Vector2i(x, y)
			if _spell_distance(origin, cell) <= maxi(0, spell.range_tiles):
				_spell_centers.append(cell)
				if spell.area_radius <= 0 and not _spell_targets_at(cell).is_empty():
					_spell_single_cells.append(cell)
	var choices: Array[Vector2i] = _spell_single_cells if spell.area_radius <= 0 else _spell_centers
	if choices.is_empty():
		_pending_spell = null
		_show_attack_notice("Нет целей в дальности магии")
		_restore_after_attack_cancel()
		return
	var initial: Vector2i = choices[0]
	var best: int = 2147483647
	for cell in choices:
		if _spell_targets_at(cell).is_empty():
			continue
		var distance: int = _spell_distance(origin, cell)
		if distance < best:
			best = distance
			initial = cell
	if best == 2147483647 and spell.area_radius > 0 and _spell_centers.has(origin):
		initial = origin
	_spell_targeting = true
	_spell_saved_menu_input = _menu.is_processing_input()
	_spell_saved_cursor_input = _cursor.is_processing_unhandled_key_input()
	_menu.call("close_menu")
	_menu.set_process_input(false)
	var movement: Node2D = get_node_or_null(^"../BattleMove") as Node2D
	if movement != null:
		_spell_saved_mode = bool(movement.get("_movement_mode"))
		_spell_saved_move_process = movement.is_processing()
		_spell_saved_move_input = movement.is_processing_unhandled_key_input()
		movement.set("_movement_mode", false)
		movement.set("_direction", Vector2i.ZERO)
		movement.set_process(false)
		movement.set_process_unhandled_key_input(false)
		movement.queue_redraw()
	_cursor.set_process_unhandled_key_input(false)
	_cursor.set("_held_direction", Vector2i.ZERO)
	_cursor.set("attack_targeting", true)
	_spell_overlay = Node2D.new()
	_spell_overlay.name = "MagicTargetOverlay"
	# Keep the highlight between the terrain and Units, outside their Y-sort.
	var overlay_parent: Node = _units.get_parent()
	overlay_parent.add_child(_spell_overlay)
	overlay_parent.move_child(_spell_overlay, _units.get_index())
	_spell_overlay.z_index = magic_overlay_z_index
	_magic_fx_clock = 0.0
	_spell_overlay.draw.connect(_draw_spell_overlay)
	_set_spell_center(initial)


func _set_spell_center(cell: Vector2i) -> void:
	_spell_center = cell
	_cursor.set("selected_cell", cell)
	_cursor.set("cursor_visible", false)
	_cursor.call("_update_cursor")
	_cursor.emit_signal("cell_changed", cell)
	if is_instance_valid(_spell_overlay):
		_spell_overlay.queue_redraw()
	_attack_message_serial += 1
	if _label != null:
		_label.text = "%s | Целей: %d" % [_pending_spell.title, _spell_targets_at(cell).size()]


func _spell_target_input(key: Key) -> void:
	match key:
		KEY_Q, KEY_ESCAPE:
			_end_spell_targeting(true)
			_open_battle_magic()
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			_confirm_spell_targeting()
		KEY_W, KEY_UP:
			_move_spell_center(Vector2i.UP)
		KEY_S, KEY_DOWN:
			_move_spell_center(Vector2i.DOWN)
		KEY_A, KEY_LEFT:
			_move_spell_center(Vector2i.LEFT)
		KEY_D, KEY_RIGHT:
			_move_spell_center(Vector2i.RIGHT)


func _move_spell_center(step: Vector2i) -> void:
	if _pending_spell == null:
		return
	if _pending_spell.area_radius > 0:
		var next_cell: Vector2i = _spell_center + step
		if _spell_centers.has(next_cell):
			_set_spell_center(next_cell)
	else:
		var index: int = _spell_single_cells.find(_spell_center)
		var increment: int = 1 if step.x + step.y > 0 else -1
		_set_spell_center(_spell_single_cells[posmod(index + increment, _spell_single_cells.size())])



func _process(delta: float) -> void:
	if not _spell_targeting or not is_instance_valid(_spell_overlay):
		return
	if magic_enable_pulse or magic_enable_particles or magic_enable_animated_border:
		_magic_fx_clock += delta
		_spell_overlay.queue_redraw()


func _magic_style(rect: Rect2, fill_color: Color, border_color: Color, width: int) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(width)
	var radius: int = 0
	if magic_enable_rounded_corners:
		radius = mini(roundi(magic_corner_radius), floori(minf(rect.size.x, rect.size.y) * 0.5))
	style.set_corner_radius_all(radius)
	style.anti_aliasing = false
	_spell_overlay.draw_style_box(style, rect)


func _magic_alpha(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(color.a * opacity, 0.0, 1.0))


func _magic_pulse(phase: float) -> float:
	if not magic_enable_pulse:
		return 1.0
	return 1.0 - magic_pulse_strength * (0.5 + 0.5 * sin(_magic_fx_clock * TAU * magic_pulse_speed + phase))


func _draw_magic_cell(rect: Rect2, cell: Vector2i, color: Color, affected: bool) -> void:
	var inset: float = minf(magic_cell_inset, rect.size.x * 0.2)
	var inner: Rect2 = rect.grow(-inset)
	var phase: float = float(cell.x + cell.y) * 0.65
	var pulse: float = _magic_pulse(phase)
	var edge: Color = Color(color.r, color.g, color.b, 0.0)
	if affected:
		edge.a = 0.65 * pulse
		if magic_enable_animated_border:
			edge.a *= 0.6 + 0.4 * (0.5 + 0.5 * sin(_magic_fx_clock * TAU * maxf(0.2, magic_pulse_speed) - phase))
		if magic_enable_glow:
			var glow_color: Color = _magic_alpha(Color(color.r, color.g, color.b, 1.0), magic_glow_strength * 0.18 * pulse)
			_magic_style(inner.grow(1.0), Color.TRANSPARENT, glow_color, 2)
	_magic_style(inner, _magic_alpha(color, pulse * magic_fill_opacity), edge, 1 if affected else 0)
	if not affected or not magic_enable_particles:
		return
	# Deterministic particles; no random flickering between frames.
	var span: Vector2 = inner.size - Vector2(4.0, 4.0)
	if span.x <= 0.0 or span.y <= 0.0:
		return
	for i in range(magic_particle_amount):
		var seed: float = float(cell.x * 73 + cell.y * 137 + i * 29)
		var px: float = fposmod(seed * 0.617, 1.0)
		var life: float = fposmod(seed * 0.173 + _magic_fx_clock * magic_particle_speed / maxf(1.0, span.y), 1.0)
		var point := inner.position + Vector2(2.0 + px * span.x, 2.0 + (1.0 - life) * span.y)
		var spark: Color = color.lerp(Color.WHITE, 0.65)
		spark.a = sin(life * PI) * 0.8
		_spell_overlay.draw_rect(Rect2(point.floor(), Vector2.ONE * (2.0 if i % 3 == 0 else 1.0)), spark)


func _draw_magic_marker(rect: Rect2, color: Color) -> void:
	var pulse: float = _magic_pulse(0.0)
	var width: int = maxi(1, roundi(magic_outline_width))
	if magic_enable_glow:
		_magic_style(rect.grow(1.0), Color.TRANSPARENT, _magic_alpha(color, magic_glow_strength * 0.3 * pulse), width + 1)
	_magic_style(rect, Color.TRANSPARENT, _magic_alpha(color, pulse), width)


func _draw_spell_overlay() -> void:
	if not _spell_targeting or not is_instance_valid(_spell_overlay) or _pending_spell == null:
		return
	var first: Vector2i = _cursor.get("first_cell")
	var size: Vector2i = _cursor.get("grid_size")
	var origin: Vector2 = _cursor.get("grid_origin")
	var cell_size: float = float(_cursor.get("cell_size"))
	var grid_parent: Node2D = _cursor.get_parent() as Node2D
	if grid_parent == null:
		return
	for y in range(first.y, first.y + size.y):
		for x in range(first.x, first.x + size.x):
			var cell := Vector2i(x, y)
			var in_range: bool = _spell_centers.has(cell)
			var in_area: bool = _spell_distance(cell, _spell_center) <= maxi(0, _pending_spell.area_radius)
			if not in_range and not in_area:
				continue
			var p: Vector2 = _spell_overlay.to_local(grid_parent.to_global(origin + Vector2(cell - first) * cell_size))
			var rect := Rect2(p, Vector2.ONE * cell_size)
			if in_range:
				_draw_magic_cell(rect, cell, magic_range_color, false)
			if in_area:
				_draw_magic_cell(rect, cell, magic_area_color, true)
	for enemy in _spell_targets_at(_spell_center):
		var cell: Vector2i = _attack_world_to_cell(enemy.global_position)
		var p: Vector2 = _spell_overlay.to_local(grid_parent.to_global(origin + Vector2(cell - first) * cell_size))
		_draw_magic_marker(Rect2(p, Vector2.ONE * cell_size).grow(-1.0), magic_enemy_outline)
	var center_pos: Vector2 = _spell_overlay.to_local(grid_parent.to_global(origin + Vector2(_spell_center - first) * cell_size))
	_draw_magic_marker(Rect2(center_pos, Vector2.ONE * cell_size).grow(-3.0), magic_center_outline)


func _confirm_spell_targeting() -> void:
	if not _spell_targeting or _pending_spell == null or active_hero == null or _battle_stopped or _is_switching:
		return
	if not _spell_centers.has(_spell_center):
		return
	if active_hero.mp_current < maxi(0, _pending_spell.mp_cost):
		_show_attack_notice("Недостаточно MP")
		return
	var targets: Array[Node2D] = _spell_targets_at(_spell_center)
	if targets.is_empty():
		_show_attack_notice("Нет противников в области")
		return
	if _combat == null or not _combat.has_method("plan_magic_damage") or not _combat.has_method("commit_pending_magic"):
		_show_attack_notice("BattleCombat: отсутствует Stage 3")
		return
	var spell: SpellData = _pending_spell
	var center: Vector2i = _spell_center
	var caster: Node2D = active_unit
	var hero: HeroData = active_hero
	_is_switching = true
	var result: Dictionary = _combat.call("plan_magic_damage", caster, spell, targets)
	if not bool(result.get("ok", false)):
		_is_switching = false
		_show_attack_notice(str(result.get("reason", "Магия недоступна")))
		return
	_end_spell_targeting(true)
	# Do not allow movement or menu input during the batch.
	var movement: Node2D = get_node_or_null(^"../BattleMove") as Node2D
	var move_process: bool = false
	var move_input: bool = false
	if movement != null:
		move_process = movement.is_processing()
		move_input = movement.is_processing_unhandled_key_input()
		movement.set("_movement_mode", false)
		movement.set("_direction", Vector2i.ZERO)
		if movement.has_method("_sync_movement_overlay_visibility"):
			movement.call("_sync_movement_overlay_visibility")
		movement.queue_redraw()
		movement.set_process(false)
		movement.set_process_unhandled_key_input(false)
	_set_player_controls_for_turn(false)
	battle_spell_targets_confirmed.emit(caster, hero, spell, center, targets)
	_show_attack_notice("%s: целей %d, урон %d" % [spell.title, targets.size(), int(result.get("damage", 0))])
	var magic_preview: Node = get_node_or_null(^"../FightPreviewBridge")
	if magic_preview != null and magic_preview.has_method("present_magic"):
		await magic_preview.call("present_magic", caster, spell, result)
	await _combat.call("commit_pending_magic")
	if _battle_stopped or not is_inside_tree() or bool(_combat.call("is_battle_finished")):
		return
	if is_instance_valid(movement):
		movement.set_process(move_process)
		movement.set_process_unhandled_key_input(move_input)
	_complete_hero_attack_after_presentation(caster, hero)


func _end_spell_targeting(restore_cursor: bool) -> void:
	_spell_targeting = false
	_pending_spell = null
	_spell_centers.clear()
	_spell_single_cells.clear()
	if is_instance_valid(_spell_overlay):
		_spell_overlay.hide()
		_spell_overlay.queue_free()
	_spell_overlay = null
	var movement: Node2D = get_node_or_null(^"../BattleMove") as Node2D
	if movement != null:
		movement.set("_movement_mode", _spell_saved_mode)
		movement.set("_direction", Vector2i.ZERO)
		movement.set_process(_spell_saved_move_process)
		movement.set_process_unhandled_key_input(_spell_saved_move_input)
		movement.queue_redraw()
	if is_instance_valid(_menu):
		_menu.set_process_input(_spell_saved_menu_input)
	if is_instance_valid(_cursor):
		_cursor.set("attack_targeting", false)
		_cursor.set("_held_direction", Vector2i.ZERO)
		_cursor.set_process_unhandled_key_input(_spell_saved_cursor_input)
		if restore_cursor:
			_focus_cursor()
		else:
			_cursor.emit_signal("cell_changed", _cursor.get("selected_cell"))
		_cursor.queue_redraw()
	_update_indicator()


func _open_battle_inventory() -> void:
	if _battle_inventory_open or active_hero == null:
		return
	var service: Node = get_node_or_null("/root/Inventory_Service")
	if service == null:
		push_error("BattleTurn: Inventory_Service Autoload not found.")
		return
	var selectable_items: Array[ItemData] = []
	var global_items: Array = service.get("items") as Array
	for candidate in global_items:
		if candidate is ItemData:
			selectable_items.append(candidate)
	if _menu != null and _menu.has_method("close_menu"):
		_menu.call("close_menu")
	if _menu != null:
		_menu.set_process_input(false)
	var movement: Node = get_node_or_null(^"../BattleMove")
	if movement != null:
		_battle_move_was_processing = movement.is_processing()
		_battle_move_was_listening = movement.is_processing_unhandled_key_input()
		movement.set("_direction", Vector2i.ZERO)
		movement.set_process(false)
		movement.set_process_unhandled_key_input(false)
	if _cursor != null:
		_cursor.set("_held_direction", Vector2i.ZERO)
		_cursor.set_process_unhandled_key_input(false)
	_battle_inventory_open = true
	_battle_item_chosen = null
	_battle_inventory_layer = CanvasLayer.new()
	_battle_inventory_layer.layer = 40
	_battle_inventory_layer.name = "BattleInventoryLayer"
	add_child(_battle_inventory_layer)
	_battle_inventory = BATTLE_INVENTORY_SCENE.instantiate() as InventoryScreen
	if _battle_inventory == null:
		push_error("BattleTurn: InventoryScreen.tscn must have InventoryScreen as root.")
		_close_battle_inventory()
		return
	_battle_inventory_layer.add_child(_battle_inventory)
	_battle_inventory.battle_item_selected.connect(_on_battle_item_selected)
	_battle_inventory.closed.connect(_on_battle_inventory_closed)
	_battle_inventory.open_battle(selectable_items)


func _on_battle_item_selected(item: ItemData) -> void:
	_battle_item_chosen = item


func _on_battle_inventory_closed() -> void:
	var chosen: ItemData = _battle_item_chosen
	_close_battle_inventory()
	if chosen != null:
		_start_item_targeting(chosen)
	elif _menu != null and _menu.has_method("open_menu"):
		_menu.call_deferred("open_menu")


func _close_battle_inventory() -> void:
	_battle_inventory_open = false
	_battle_item_chosen = null
	if _battle_inventory_layer != null and is_instance_valid(_battle_inventory_layer):
		_battle_inventory_layer.queue_free()
	_battle_inventory_layer = null
	_battle_inventory = null
	var movement: Node = get_node_or_null(^"../BattleMove")
	if movement != null:
		movement.set_process(_battle_move_was_processing)
		movement.set_process_unhandled_key_input(_battle_move_was_listening)
		if movement.has_method("_apply_input_mode"):
			movement.call("_apply_input_mode")
	if _menu != null:
		_menu.set_process_input(true)


## Выбор получателя предмета. Использует прежние курсор и BattleHover.
## Никаких HP, XP, списаний или завершения хода на этапе 2.
func _start_item_targeting(item: ItemData) -> void:
	if item == null or not item.usable_in_battle or item.use_effect == null:
		_show_attack_notice("Предмет нельзя использовать в бою")
		if _menu != null and _menu.has_method("open_menu"):
			_menu.call_deferred("open_menu")
		return
	if _battle_stopped or _is_switching or not is_instance_valid(active_unit) or active_hero == null or _cursor == null or _units == null:
		return
	var service: Node = get_node_or_null("/root/Inventory_Service")
	if service == null or not (service.get("items") as Array).has(item):
		_show_attack_notice("Предмет отсутствует в инвентаре")
		if _menu != null and _menu.has_method("open_menu"):
			_menu.call_deferred("open_menu")
		return

	var targets: Array[Node2D] = []
	for hero in party.heroes:
		if hero == null or int(hero.hp_current) <= 0:
			continue
		for child in _units.get_children():
			var unit: Node2D = child as Node2D
			if is_instance_valid(unit) and unit.name == hero.hero_name and _unit_is_alive(unit):
				targets.append(unit)
				break
	if targets.is_empty():
		_show_attack_notice("Нет союзников для применения предмета")
		if _menu != null and _menu.has_method("open_menu"):
			_menu.call_deferred("open_menu")
		return

	_pending_battle_item = item
	_item_targets = targets
	_item_target_index = maxi(0, _item_targets.find(active_unit))
	_item_targeting_active = true
	if _menu != null:
		_menu.set_process_input(false)
	var movement: Node = get_node_or_null(^"../BattleMove")
	if movement != null:
		movement.set("_movement_mode", false)
		movement.set("_direction", Vector2i.ZERO)
		if movement.has_method("_apply_input_mode"):
			movement.call("_apply_input_mode")
	_cursor.set("_held_direction", Vector2i.ZERO)
	_cursor.set("attack_targeting", true)
	_cursor.set("cursor_visible", false)
	_focus_item_target()
	print("S7 ITEM TARGET: ", item.title, " -> ", _item_targets[_item_target_index].name)


func _focus_item_target() -> void:
	if not _item_targeting_active or _item_targets.is_empty() or _cursor == null:
		return
	var unit: Node2D = _item_targets[_item_target_index]
	if not is_instance_valid(unit):
		return
	var cell: Vector2i = _attack_world_to_cell(unit.global_position)
	_cursor.set("_held_direction", Vector2i.ZERO)
	_cursor.set("selected_cell", cell)
	if _cursor.has_method("_update_cursor"):
		_cursor.call("_update_cursor")
	if _cursor.has_signal("cell_changed"):
		_cursor.emit_signal("cell_changed", cell)


func _cycle_item_target(step: int) -> void:
	if _item_targeting_active and not _item_targets.is_empty():
		_item_target_index = posmod(_item_target_index + step, _item_targets.size())
		_focus_item_target()


func _end_item_targeting() -> void:
	_item_targeting_active = false
	_pending_battle_item = null
	_item_targets.clear()
	_item_target_index = 0
	if _cursor != null:
		_cursor.set("attack_targeting", false)
		_cursor.set("_held_direction", Vector2i.ZERO)
		_cursor.queue_redraw()
		if _cursor.has_signal("cell_changed"):
			_cursor.emit_signal("cell_changed", _cursor.get("selected_cell"))
	if _menu != null:
		_menu.set_process_input(true)


func _cancel_item_targeting() -> void:
	var item: ItemData = _pending_battle_item
	_end_item_targeting()
	if item != null:
		_open_battle_inventory()
	else:
		_restore_after_attack_cancel()


func _confirm_item_targeting() -> void:
	if not _item_targeting_active or _battle_stopped or _is_switching or _pending_battle_item == null:
		return
	if _item_targets.is_empty():
		return
	var unit: Node2D = _item_targets[_item_target_index]
	if not is_instance_valid(unit) or not _unit_is_alive(unit):
		_show_attack_notice("Цель больше не доступна")
		return
	var item: ItemData = _pending_battle_item
	var service: Node = get_node_or_null("/root/Inventory_Service")
	if service == null or not (service.get("items") as Array).has(item):
		_show_attack_notice("Предмет отсутствует в инвентаре")
		_end_item_targeting()
		_restore_after_attack_cancel()
		return
	if _combat == null or not _combat.has_method("use_healing_item"):
		push_warning("BattleTurn: BattleCombat.use_healing_item отсутствует.")
		return
	var treating_unit: Node2D = active_unit
	var treating_hero: HeroData = active_hero
	_is_switching = true
	var result: Dictionary = _combat.call("use_healing_item", treating_unit, unit, item)
	if not bool(result.get("ok", false)):
		_is_switching = false
		_show_attack_notice(str(result.get("reason", "Не удалось использовать предмет.")))
		return
	_end_item_targeting()
	print("S7 HEAL: ", treating_unit.name, " -> ", unit.name, ", HP +", int(result.get("healed", 0)))
	# Завершаем ход только после закрытия FightScene и фиксации реального HP.
	_complete_hero_attack_after_presentation(treating_unit, treating_hero)


## Начинает выбор цели, не перемещая героя.
func _start_attack_targeting() -> void:
	if not is_instance_valid(active_unit) or _cursor == null or _units == null:
		return
	var hero_cell: Vector2i = _attack_world_to_cell(active_unit.global_position)
	var targets: Array[Node2D] = []
	for child in _units.get_children():
		var enemy: Node2D = child as Node2D
		if not is_instance_valid(enemy):
			continue
		if not enemy.is_in_group(&"battle_enemies") or bool(enemy.get_meta("battle_defeated", false)):
			continue
		if int(enemy.get_meta("hp_current", 1)) <= 0:
			continue
		var enemy_cell: Vector2i = _attack_world_to_cell(enemy.global_position)
		var distance: int = absi(hero_cell.x - enemy_cell.x) + absi(hero_cell.y - enemy_cell.y)
		if distance <= hero_attack_range:
			targets.append(enemy)
	if targets.is_empty():
		_show_attack_notice(no_targets_message)
		return
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var ca: Vector2i = _attack_world_to_cell(a.global_position)
		var cb: Vector2i = _attack_world_to_cell(b.global_position)
		var da: int = absi(hero_cell.x - ca.x) + absi(hero_cell.y - ca.y)
		var db: int = absi(hero_cell.x - cb.x) + absi(hero_cell.y - cb.y)
		if da == db:
			return a.get_instance_id() < b.get_instance_id()
		return da < db
	)
	_attack_targets = targets
	_attack_target_index = 0
	_attack_targeting_active = true
	if _menu != null and _menu.has_method("close_menu"):
		_menu.call("close_menu")
	var movement: Node = get_node_or_null(^"../BattleMove")
	if movement != null:
		movement.set("_movement_mode", false)
		movement.set("_direction", Vector2i.ZERO)
		if movement.has_method("_apply_input_mode"):
			movement.call("_apply_input_mode")
	_cursor.set("attack_targeting", true)
	_cursor.set("cursor_visible", false)
	_cursor.set("_held_direction", Vector2i.ZERO)
	_cursor.set("selected_cell", _attack_world_to_cell(targets[0].global_position))
	if _cursor.has_method("_update_cursor"):
		_cursor.call("_update_cursor")
	if _cursor.has_signal("cell_changed"):
		_cursor.emit_signal("cell_changed", _cursor.get("selected_cell"))
	_cursor.set_process_unhandled_key_input(true)
	_cursor.queue_redraw()
	print("S7 ATTACK: цель выбрана курсором: ", targets[0].name)


## Переводит мировую позицию персонажа в координаты клетки боевого курсора.
func _attack_world_to_cell(world_position: Vector2) -> Vector2i:
	var cell_size: int = maxi(1, int(_cursor.get("cell_size")))
	var grid_origin: Vector2 = _cursor.get("grid_origin")
	var first_cell: Vector2i = _cursor.get("first_cell")
	var origin_world: Vector2 = _cursor.get_parent().to_global(grid_origin)
	var delta: Vector2 = world_position - origin_world
	return first_cell + Vector2i(floori(delta.x / float(cell_size)), floori(delta.y / float(cell_size)))


## Краткое уведомление в существующем индикаторе хода.
func _show_attack_notice(message: String) -> void:
	_attack_message_serial += 1
	var serial: int = _attack_message_serial
	if _label != null:
		_label.text = message
	print("S7 ATTACK: ", message)
	get_tree().create_timer(no_targets_duration).timeout.connect(func() -> void:
		if is_inside_tree() and serial == _attack_message_serial and not _attack_targeting_active and not _spell_targeting:
			_update_indicator()
	)


## На этапе выбора цели Q или Esc возвращают обычный курсор.
func _input(event: InputEvent) -> void:
	if not (_attack_targeting_active or _item_targeting_active or _spell_targeting) or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		if _spell_targeting:
			get_viewport().set_input_as_handled()
		return
	var key: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
	if _spell_targeting:
		get_viewport().set_input_as_handled()
		_spell_target_input(key)
		return
	if _item_targeting_active:
		match key:
			KEY_Q, KEY_ESCAPE:
				_cancel_item_targeting()
			KEY_E, KEY_ENTER, KEY_KP_ENTER:
				_confirm_item_targeting()
			KEY_D, KEY_S, KEY_RIGHT, KEY_DOWN:
				_cycle_item_target(1)
			KEY_A, KEY_W, KEY_LEFT, KEY_UP:
				_cycle_item_target(-1)
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if key == KEY_Q or key == KEY_ESCAPE:
		_end_attack_targeting()
		_restore_after_attack_cancel()
		get_viewport().set_input_as_handled()
	elif key == KEY_E or key == KEY_ENTER or key == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_confirm_hero_attack()
	elif key == KEY_D or key == KEY_S or key == KEY_RIGHT or key == KEY_DOWN:
		_cycle_attack_target(1)
		get_viewport().set_input_as_handled()
	elif key == KEY_A or key == KEY_W or key == KEY_LEFT or key == KEY_UP:
		_cycle_attack_target(-1)
		get_viewport().set_input_as_handled()


## Переключает выбранного противника без движения невидимого курсора по пустым клеткам.
## Пульсация BattleHover перенесётся на нового врага через сигнал cell_changed.
func _cycle_attack_target(step: int) -> void:
	if not _attack_targeting_active or _attack_targets.is_empty() or _cursor == null:
		return
	_attack_target_index = posmod(_attack_target_index + step, _attack_targets.size())
	var target: Node2D = _attack_targets[_attack_target_index]
	if not is_instance_valid(target):
		return
	_cursor.set("_held_direction", Vector2i.ZERO)
	_cursor.set("selected_cell", _attack_world_to_cell(target.global_position))
	if _cursor.has_method("_update_cursor"):
		_cursor.call("_update_cursor")
	if _cursor.has_signal("cell_changed"):
		_cursor.emit_signal("cell_changed", _cursor.get("selected_cell"))


func _end_attack_targeting() -> void:
	_attack_targeting_active = false
	_attack_targets.clear()
	_attack_target_index = 0
	if _cursor != null:
		_cursor.set("attack_targeting", false)
		_cursor.queue_redraw()

## Возвращает обычный режим после отмены прицеливания.
func _restore_after_attack_cancel() -> void:
	if _menu != null and _menu.has_method("open_menu"):
		_menu.call_deferred("open_menu")
	elif _cursor != null:
		var movement: Node = get_node_or_null(^"../BattleMove")
		if movement != null:
			movement.set("_movement_mode", true)
			if movement.has_method("_apply_input_mode"):
				movement.call("_apply_input_mode")


## Находит живого врага в текущей выбранной клетке.
func _attack_enemy_at_cursor() -> Node2D:
	if _units == null or _cursor == null:
		return null
	var current_cell: Vector2i = _cursor.get("selected_cell")
	for child in _units.get_children():
		var candidate: Node2D = child as Node2D
		if not is_instance_valid(candidate):
			continue
		if not candidate.is_in_group(&"battle_enemies") or bool(candidate.get_meta("battle_defeated", false)):
			continue
		if int(candidate.get_meta("hp_current", 1)) <= 0:
			continue
		if _attack_world_to_cell(candidate.global_position) == current_cell:
			return candidate
	return null


## Применяет урон ровно один раз к выбранному врагу и завершает ход.
func _confirm_hero_attack() -> void:
	if not _attack_targeting_active or _is_switching or _battle_stopped:
		return
	if not is_instance_valid(active_unit) or active_hero == null:
		return
	var target: Node2D = _attack_enemy_at_cursor()
	if target == null:
		_show_attack_notice("Выбери врага для атаки")
		return
	var start_cell: Vector2i = _attack_world_to_cell(active_unit.global_position)
	var target_cell: Vector2i = _attack_world_to_cell(target.global_position)
	var distance: int = absi(start_cell.x - target_cell.x) + absi(start_cell.y - target_cell.y)
	if distance > hero_attack_range:
		_show_attack_notice("Цель слишком далеко")
		return
	if _combat == null or not _combat.has_method("physical_attack"):
		push_warning("BattleTurn: метод BattleCombat.physical_attack не найден.")
		return

	var attacking_unit: Node2D = active_unit
	var attacking_hero: HeroData = active_hero
	_is_switching = true
	# Цель не поворачиваем. Только атакующий смотрит на неё.
	var delta: Vector2i = target_cell - start_cell
	var direction: Vector2i = Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	if absi(delta.y) > absi(delta.x):
		direction = Vector2i.DOWN if delta.y >= 0 else Vector2i.UP
	if attacking_unit.has_method("play_walk"):
		attacking_unit.call("play_walk", direction)
	if attacking_unit.has_method("play_idle"):
		attacking_unit.call("play_idle")

	var result: Dictionary = _combat.call("physical_attack", attacking_unit, target)
	if not bool(result.get("ok", false)):
		_is_switching = false
		_show_attack_notice("Атака не удалась: " + str(result.get("reason", "")))
		return
	_end_attack_targeting()
	print("S7 ATTACK: урон ", int(result.get("damage", 0)), " по ", target.name)
	if _combat.has_method("is_battle_finished") and bool(_combat.call("is_battle_finished")):
		return
	# Завершение хода ждёт конца FightScene, а не только расчёта удара.
	_complete_hero_attack_after_presentation(attacking_unit, attacking_hero)


## Дожидается возврата с FightScene, прежде чем активировать следующего юнита.
## Это не позволяет запускать ход врага, пока тактическая карта на паузе.
func _complete_hero_attack_after_presentation(attacking_unit: Node2D, attacking_hero: HeroData) -> void:
	var preview_bridge: Node = get_node_or_null(^"../FightPreviewBridge")
	if preview_bridge != null and preview_bridge.has_signal("preview_finished") and bool(preview_bridge.get("_showing")):
		# Подписываемся после physical_attack(): показ уже поставлен в очередь.
		preview_bridge.connect("preview_finished", Callable(self, "_on_attack_preview_finished"), CONNECT_ONE_SHOT)
		await attack_preview_finished
	while _death_presentation_active and not _battle_stopped and is_inside_tree():
		await get_tree().process_frame
	if _battle_stopped or not is_inside_tree():
		return
	turn_completed.emit(attacking_unit, attacking_hero)
	call_deferred("_next_turn")


## Локальный сигнал для безопасного ожидания сигнала от узла-моста.
func _on_attack_preview_finished() -> void:
	attack_preview_finished.emit()


func _next_turn() -> void:
	if _spell_targeting:
		_end_spell_targeting(false)
	_end_attack_targeting()
	if _battle_stopped or _death_presentation_active or _roster.is_empty():
		_is_switching = false
		return
	# Skip removed / defeated units without changing the order of survivors.
	for i in range(_roster.size()):
		_turn_index = (_turn_index + 1) % _roster.size()
		var candidate: Variant = _roster[_turn_index].get("unit")
		if _unit_is_alive(candidate):
			_activate_current_turn()
			_is_switching = false
			return
	active_unit = null
	active_hero = null
	active_enemy_data = null
	_update_indicator()
	_is_switching = false


func finish_enemy_turn() -> void:
	if _battle_stopped:
		return
	if _death_presentation_active:
		_enemy_turn_end_pending = true
		return
	if _is_switching or not is_instance_valid(active_unit) or active_enemy_data == null:
		return
	_is_switching = true
	turn_completed.emit(active_unit, null)
	call_deferred("_next_turn")


func _activate_current_turn() -> void:
	if _battle_stopped:
		return
	if _turn_index < 0 or _turn_index >= _roster.size():
		return
	var candidate: Variant = _roster[_turn_index].get("unit")
	if not _unit_is_alive(candidate):
		call_deferred("_next_turn")
		return
	active_unit = candidate as Node2D
	active_hero = _roster[_turn_index]["hero"] as HeroData
	active_enemy_data = _roster[_turn_index]["enemy"] as Resource
	_set_player_controls_for_turn(active_hero != null and active_enemy_data == null)
	_update_indicator()
	if focus_cursor_on_active_unit:
		_focus_cursor()
	active_unit_changed.emit(active_unit, active_hero)
	if active_enemy_data != null:
		enemy_turn_started.emit(active_unit, active_enemy_data)



## Блокирует весь ввод игрока во время хода врага.
## BattleMove отдельно сбрасывает выбранного героя через active_unit_changed.
func _set_player_controls_for_turn(player_turn: bool) -> void:
	if _menu != null:
		# Закрываем открытое меню до отключения _input.
		if not player_turn and bool(_menu.get("is_open")) and _menu.has_method("close_menu"):
			_menu.call("close_menu")
		_menu.set_process_input(player_turn)
	if _cursor != null:
		_cursor.set("_held_direction", Vector2i.ZERO)
		if not player_turn:
			_cursor.set_process_unhandled_key_input(false)
	var movement: Node = get_node_or_null(^"../BattleMove")
	if movement != null:
		movement.set("_direction", Vector2i.ZERO)



## Удержать камеру на погибающем бойце до завершения растворения.
## Пока активен этот режим, ход врага не переключается на следующего.
func begin_death_presentation(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	_death_presentation_active = true
	if focus_cursor_on_active_unit:
		_focus_cursor(unit)


## Отпустить камеру после растворения и дополнительной паузы.
## Если ИИ уже запросил конец хода, выполняем его только сейчас.
func end_death_presentation() -> void:
	_death_presentation_active = false
	if _battle_stopped:
		_enemy_turn_end_pending = false
		return
	if _enemy_turn_end_pending:
		_enemy_turn_end_pending = false
		finish_enemy_turn()

func _party_index(hero: HeroData) -> int:
	if party == null:
		return 999
	return party.heroes.find(hero)

func _focus_cursor(unit_override: Node2D = null) -> void:
	var focused: Node2D = unit_override if is_instance_valid(unit_override) else active_unit
	if not is_instance_valid(focused) or _cursor == null:
		return
	var cell_size: int = int(_cursor.get("cell_size"))
	if cell_size <= 0:
		return
	var origin: Vector2 = _cursor.get("grid_origin")
	var first: Vector2i = _cursor.get("first_cell")
	var base: Vector2 = _cursor.get_parent().to_global(origin)
	var offset: Vector2 = focused.global_position - base
	var cell := first + Vector2i(floori(offset.x / float(cell_size)), floori(offset.y / float(cell_size)))
	var min_cell: Vector2i = first
	var grid_size: Vector2i = _cursor.get("grid_size")
	var max_cell: Vector2i = first + grid_size - Vector2i.ONE
	cell = Vector2i(clampi(cell.x, min_cell.x, max_cell.x), clampi(cell.y, min_cell.y, max_cell.y))
	_cursor.set("selected_cell", cell)
	if _cursor.has_method("_update_cursor"):
		_cursor.call("_update_cursor")
	if _cursor.has_signal("cell_changed"):
		_cursor.emit_signal("cell_changed", cell)

func _create_indicator() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	canvas.name = "TurnUI"
	add_child(canvas)

	_panel = PanelContainer.new()
	_panel.name = "TurnIndicator"
	_panel.position = indicator_position
	_panel.custom_minimum_size = Vector2(float(indicator_width), 34)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = indicator_background
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(_panel)

	_label = Label.new()
	_label.name = "TurnText"
	_label.add_theme_color_override("font_color", indicator_text_color)
	_panel.add_child(_label)
	_update_indicator()

func _update_indicator() -> void:
	if _panel == null or _label == null:
		return
	_panel.visible = show_turn_indicator
	if active_enemy_data != null:
		_label.text = "Ход врага: %s" % active_unit.name
	elif active_hero == null:
		_label.text = "Ожидание хода"
	else:
		var speed: int = active_hero.base_stats.speed if active_hero.base_stats != null else 0
		_label.text = "Ход: %s  |  Speed: %d" % [active_hero.hero_name, speed]

func _enemy_int(entry: Resource, keys: Array[String], fallback: int) -> int:
	if entry == null:
		return fallback
	for key in keys:
		for property in entry.get_property_list():
			if String(property["name"]) == key:
				var value: Variant = entry.get(key)
				if value is int or value is float:
					return int(value)
	var stats: Variant = null
	for property in entry.get_property_list():
		if String(property["name"]) == "base_stats":
			stats = entry.get("base_stats")
			break
	if stats is Resource:
		for key in keys:
			for property in (stats as Resource).get_property_list():
				if String(property["name"]) == key:
					return int((stats as Resource).get(key))
	return fallback

## Вызывается из BattleCombat, когда битва завершилась.
func stop_battle() -> void:
	if _spell_targeting:
		_end_spell_targeting(false)
	if _battle_magic_open:
		_battle_magic_open = false
		_battle_spell_chosen = null
		if is_instance_valid(_battle_magic_layer):
			_battle_magic_layer.visible = false
			_battle_magic_layer.queue_free()
		_battle_magic_layer = null
		_battle_magic = null
		var movement: Node = get_node_or_null(^"../BattleMove")
		if movement != null:
			movement.set_process(_magic_move_process)
			movement.set_process_unhandled_key_input(_magic_move_input)
		_set_player_controls_for_turn(false)
	if _item_targeting_active:
		_end_item_targeting()
	if _battle_inventory_open:
		_close_battle_inventory()
	_battle_stopped = true
	_is_switching = true
	if _menu != null and _menu.has_method("close_menu"):
		_menu.call("close_menu")
	active_unit = null
	active_hero = null
	active_enemy_data = null
	_update_indicator()


## Доступность бойца для участия в следующих ходах.
func _unit_is_alive(unit: Variant) -> bool:
	if not is_instance_valid(unit):
		return false
	if not (unit is Node2D):
		return false
	if not unit.is_inside_tree():
		return false
	if bool(unit.get_meta("battle_defeated", false)):
		return false
	if unit.is_in_group(&"battle_enemies"):
		return int(unit.get_meta("hp_current", 1)) > 0
	if party != null:
		for hero in party.heroes:
			if hero != null and hero.hero_name == unit.name:
				return int(hero.hp_current) > 0
	return false
