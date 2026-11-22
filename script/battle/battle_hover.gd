extends Node
## Battle map hover UI. Attach to a child Node named BattleHover.
## Does not control turns, actions, or movement.

@export_group("Connections")
@export var cursor_path: NodePath = ^"../BattleCursor"
@export var units_path: NodePath = ^"../Units"
@export var movement_path: NodePath = ^"../BattleMove"
## Нода очереди ходов: показывает атакующего героя во время выбора цели.
@export var turn_path: NodePath = ^"../BattleTurn"
@export var party: PartyData = preload("res://data/items/party_data.tres")

@export_group("Highlight")
@export var highlight_enabled: bool = true
@export var highlight_color: Color = Color(1.0, 0.86, 0.35, 1.0)
@export_range(0.0, 1.0, 0.01) var highlight_strength: float = 0.55
@export_range(0.0, 12.0, 0.1) var pulse_speed: float = 3.0

@export_group("Подсветка цели атаки")
## Цвет пульсации выбранной цели при атаке.
@export var attack_pulse_color: Color = Color(1.0, 0.3, 0.3, 1.0)
## Насколько заметна красная подсветка (0 — нет, 1 — максимально).
@export_range(0.0, 1.0, 0.01) var attack_pulse_strength: float = 0.78
## Скорость пульсации выбранной цели.
@export_range(0.1, 10.0, 0.1) var attack_pulse_speed: float = 2.6

@export_group("Info Panel")
@export var show_panel: bool = true
## Перетащи TacticalPanel.tscn из FileSystem в это поле.
@export var tactical_panel_scene: PackedScene
@export_range(80, 320, 1) var panel_width: int = 200
@export_range(48, 220, 1) var panel_height: int = 92
@export_range(0, 80, 1) var panel_margin: int = 10
@export_range(24, 96, 1) var portrait_size: int = 64
@export var panel_background: Color = Color(0.09, 0.14, 0.25, 0.94)
@export var text_color: Color = Color.WHITE

@export_group("Шрифт карточек")
## Шрифт для имени, HP и MP обеих карточек. Если не назначен, используется шрифт темы Godot.
@export var card_font: Font
## Размер текста имени, HP и MP в пикселях.
@export_range(8, 48, 1) var card_font_size: int = 16

@export_group("Card Slide Animation")
## Включить выезд и уход карточек справа за пределы экрана.
@export var slide_enabled: bool = true
## Время появления новой карточки в секундах.
@export_range(0.05, 1.5, 0.01) var slide_in_duration: float = 0.22
## Время ухода предыдущей карточки вправо в секундах.
@export_range(0.05, 1.5, 0.01) var slide_out_duration: float = 0.16
## Дополнительный отступ за правой границей экрана в пикселях.
@export_range(0, 128, 1) var slide_offscreen_padding: int = 12

var _cursor: Node2D
var _units: Node2D
var _movement: Node
var _turn: Node
var _last_attack_targeting: bool = false
var _target_hud: Control
var _hovered: Node2D
var _hovered_sprite: CanvasItem
var _original_modulate: Color = Color.WHITE
var _elapsed: float = 0.0
var _last_movement_mode: bool = false
var _hud: Control

var _panel_keys: Dictionary = {"top": "", "bottom": ""}
var _panel_tweens: Dictionary = {}


func _ready() -> void:
	_cursor = get_node_or_null(cursor_path) as Node2D
	_units = get_node_or_null(units_path) as Node2D
	_movement = get_node_or_null(movement_path)
	_turn = get_node_or_null(turn_path)
	if _cursor == null or _units == null:
		push_error("BattleHover: Check Cursor Path and Units Path in Inspector.")
		set_process(false)
		return
	_build_hud()
	if _cursor.has_signal("cell_changed"):
		_cursor.connect("cell_changed", Callable(self, "_on_cell_changed"))
	call_deferred("_refresh_hover")


func _process(delta: float) -> void:
	var movement_now: bool = _movement != null and _movement.get("_movement_mode") == true
	var attack_now: bool = _is_attack_targeting()
	if movement_now != _last_movement_mode or attack_now != _last_attack_targeting:
		_last_movement_mode = movement_now
		_last_attack_targeting = attack_now
		_refresh_hover()
	if _hovered_sprite == null or not is_instance_valid(_hovered_sprite):
		return
	_elapsed += delta
	if highlight_enabled:
		var choosing_attack: bool = _is_attack_targeting()
		var speed: float = attack_pulse_speed if choosing_attack else pulse_speed
		var strength: float = attack_pulse_strength if choosing_attack else highlight_strength
		var color: Color = attack_pulse_color if choosing_attack else highlight_color
		var wave: float = (sin(_elapsed * speed * TAU) + 1.0) * 0.5
		var amount: float = strength * (0.25 + wave * 0.75)
		_hovered_sprite.modulate = _original_modulate.lerp(color, amount)


func _on_cell_changed(_cell: Vector2i) -> void:
	_refresh_hover()


func _refresh_hover() -> void:
	if not is_instance_valid(_cursor) or not is_instance_valid(_units):
		return
	var cell_size: int = int(_cursor.get("cell_size"))
	var first_cell: Vector2i = _cursor.get("first_cell")
	var selected_cell: Vector2i = _cursor.get("selected_cell")
	var grid_origin: Vector2 = _cursor.get("grid_origin")

	# Logical cell position is independent of the cursor's visual sliding.
	# Grid coordinates are relative to the cursor parent, just like cursor.position.
	var cell_local: Vector2 = grid_origin + Vector2(selected_cell - first_cell) * float(cell_size)
	var cell_world: Vector2 = _cursor.get_parent().to_global(cell_local)
	var cell_rect := Rect2(cell_world, Vector2.ONE * float(cell_size))
	var target: Node2D = null
	var in_movement_mode: bool = _movement != null and _movement.get("_movement_mode") == true and not _is_attack_targeting()
	if in_movement_mode:
		var active: Node2D = _movement.get("_unit") as Node2D
		if is_instance_valid(active):
			target = active
	if not in_movement_mode:
		for child in _units.get_children():
			var unit := child as Node2D
			if unit == null:
				continue
			# Characters occupy the cell under their feet, regardless of sprite height.
			if cell_rect.grow(0.01).has_point(unit.global_position):
				target = unit
				break
	# Magic targeting: allied / unaffected cells never become attack targets.
	if is_instance_valid(_turn) and _turn.has_method("is_spell_targeting") and bool(_turn.call("is_spell_targeting")):
		if target != null and not bool(_turn.call("is_spell_target_unit", target)):
			target = null
	if target != _hovered:
		_clear_highlight()
		_hovered = target
		if _hovered != null:
			_hovered_sprite = _hovered.get_node_or_null("AnimatedSprite2D") as CanvasItem
			if _hovered_sprite == null:
				_hovered_sprite = _hovered.get_node_or_null("Sprite2D") as CanvasItem
			if _hovered_sprite != null:
				_original_modulate = _hovered_sprite.modulate
			_elapsed = 0.0
	var attack_targeting: bool = bool(_cursor.get("attack_targeting"))
	_cursor.set("cursor_visible", not attack_targeting and not in_movement_mode and target == null)
	_cursor.queue_redraw()
	_update_panel()


func _clear_highlight() -> void:
	if _hovered_sprite != null and is_instance_valid(_hovered_sprite):
		_hovered_sprite.modulate = _original_modulate
	_hovered_sprite = null


func _is_attack_targeting() -> bool:
	return is_instance_valid(_cursor) and _cursor.get("attack_targeting") == true


func _find_hero(unit: Node2D) -> HeroData:
	if not is_instance_valid(unit) or party == null:
		return null
	for candidate in party.heroes:
		if candidate != null and candidate.hero_name == unit.name:
			return candidate
	return null


func _fill_hero(hero: HeroData, unit: Node2D, panel: Control) -> void:
	if panel == null:
		return
	if hero == null:
		# Не оставляем на карточке данные предыдущего бойца.
		panel.set("character_name", String(unit.name) if is_instance_valid(unit) else "")
		panel.call("set_stats", 0, 1, 0, 0)
		return
	var hp_max: int = 1
	var mp_max: int = 0
	if hero.base_stats != null:
		hp_max = maxi(1, int(hero.base_stats.hp))
		mp_max = maxi(0, int(hero.base_stats.mp))
	var hero_level: int = maxi(1, int(hero.get("level")))
	panel.set("character_name", hero.hero_name)
	panel.set("character_level", hero_level)
	panel.call("set_stats", clampi(hero.hp_current, 0, hp_max), hp_max, clampi(hero.mp_current, 0, mp_max), mp_max)
	_set_portrait(panel, hero.portrait)


func _fill_enemy(unit: Node2D, panel: Control) -> void:
	if not is_instance_valid(unit) or panel == null:
		return
	var data: EnemyData = unit.get_meta("enemy_data", null) as EnemyData
	if data == null:
		panel.set("character_name", unit.name)
		panel.call("set_stats", 0, 1, 0, 0)
		return
	var hp_max: int = maxi(1, data.max_hp)
	var hp_now: int = clampi(int(unit.get_meta("hp_current", hp_max)), 0, hp_max)
	var mp_max: int = maxi(0, data.max_mp)
	var mp_now: int = clampi(int(unit.get_meta("mp_current", mp_max)), 0, mp_max)
	var enemy_level: int = 1  # В EnemyData нет свойства level; безопасное значение по умолчанию.
	panel.set("character_name", data.display_name if not data.display_name.is_empty() else String(data.enemy_id))
	panel.set("character_level", enemy_level)
	panel.call("set_stats", hp_now, hp_max, mp_now, mp_max)
	_set_portrait(panel, data.portrait)


func _set_portrait(panel: Control, texture: Texture2D) -> void:
	var picture := panel.get_node_or_null("Panel/MainRow/PortraitFrame/Portrait") as TextureRect
	if picture != null:
		picture.texture = texture


func _update_panel() -> void:
	if _hud == null:
		return
	var attack: bool = _is_attack_targeting()
	if attack:
		var actor: Node2D = null
		var hero: HeroData = null
		if is_instance_valid(_turn):
			var unit_value: Variant = _turn.get("active_unit")
			if unit_value is Node2D and is_instance_valid(unit_value):
				actor = unit_value as Node2D
			var hero_value: Variant = _turn.get("active_hero")
			if hero_value is HeroData:
				hero = hero_value as HeroData
		if hero == null:
			hero = _find_hero(actor)
		if show_panel and hero != null:
			var actor_key: String = "actor_%d" % hero.get_instance_id()
			_transition_panel(_hud, "top", actor_key, func() -> void:
				_fill_hero(hero, actor, _hud)
			)
		else:
			_hide_panel(_hud, "top")

		var enemy_selected: bool = is_instance_valid(_hovered) and _hovered.is_in_group(&"battle_enemies")
		if show_panel and enemy_selected:
			var selected_enemy: Node2D = _hovered
			_transition_panel(_target_hud, "bottom", "target_%d" % selected_enemy.get_instance_id(), func() -> void:
				if is_instance_valid(selected_enemy):
					_fill_enemy(selected_enemy, _target_hud)
			)
		else:
			_hide_panel(_target_hud, "bottom")
		return

	_hide_panel(_target_hud, "bottom")
	if not show_panel or not is_instance_valid(_hovered):
		_hide_panel(_hud, "top")
		return
	var hovered_now: Node2D = _hovered
	if hovered_now.is_in_group(&"battle_enemies"):
		_transition_panel(_hud, "top", "enemy_%d" % hovered_now.get_instance_id(), func() -> void:
			if is_instance_valid(hovered_now):
				_fill_enemy(hovered_now, _hud)
		)
	else:
		_transition_panel(_hud, "top", "hero_%d" % hovered_now.get_instance_id(), func() -> void:
			if is_instance_valid(hovered_now):
				_fill_hero(_find_hero(hovered_now), hovered_now, _hud)
		)


func _panel_on_x(panel: Control) -> float:
	return get_viewport().get_visible_rect().size.x - float(panel_margin) - panel.size.x


func _panel_off_x() -> float:
	return get_viewport().get_visible_rect().size.x + float(slide_offscreen_padding)


func _panel_y(panel: Control, slot: String) -> float:
	if slot == "bottom":
		return get_viewport().get_visible_rect().size.y - float(panel_margin) - panel.size.y
	return float(panel_margin)


func _stop_panel_tween(slot: String) -> void:
	var tw: Tween = _panel_tweens.get(slot) as Tween
	if tw != null and tw.is_running():
		tw.kill()
	_panel_tweens.erase(slot)


func _transition_panel(panel: Control, slot: String, key: String, fill: Callable) -> void:
	if panel == null:
		return
	# Тот же боец: обновляем HP без повторного выезда карточки.
	if _panel_keys.get(slot, "") == key:
		if not _panel_tweens.has(slot):
			fill.call()
			panel.position = Vector2(_panel_on_x(panel), _panel_y(panel, slot))
		return
	_stop_panel_tween(slot)
	_panel_keys[slot] = key
	if not slide_enabled:
		fill.call()
		panel.position = Vector2(_panel_on_x(panel), _panel_y(panel, slot))
		panel.visible = true
		return
	var tween := create_tween()
	_panel_tweens[slot] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if panel.visible:
		tween.tween_property(panel, "position:x", _panel_off_x(), slide_out_duration)
	else:
		panel.position.x = _panel_off_x()
	tween.tween_callback(func() -> void:
		if _panel_keys.get(slot, "") != key:
			return
		fill.call()
		panel.position = Vector2(_panel_off_x(), _panel_y(panel, slot))
		panel.visible = true
	)
	# Конечный X вычисляется ПОСЛЕ обновления длины HP/MP.
	tween.tween_method(_slide_panel.bind(panel), 0.0, 1.0, slide_in_duration)
	tween.tween_callback(func() -> void:
		if _panel_keys.get(slot, "") == key:
			_panel_tweens.erase(slot)
	)


func _slide_panel(progress: float, panel: Control) -> void:
	panel.position.x = lerpf(_panel_off_x(), _panel_on_x(panel), progress)


func _hide_panel(panel: Control, slot: String) -> void:
	if panel == null or _panel_keys.get(slot, "") == "":
		return
	_panel_keys[slot] = ""
	_stop_panel_tween(slot)
	if not slide_enabled:
		panel.visible = false
		return
	var tween := create_tween()
	_panel_tweens[slot] = tween
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "position:x", _panel_off_x(), slide_out_duration)
	tween.tween_callback(func() -> void:
		if _panel_keys.get(slot, "") == "":
			panel.visible = false
			_panel_tweens.erase(slot)
	)


func _make_tactical_panel(root: Control, node_name: String) -> Control:
	if tactical_panel_scene == null:
		push_warning("BattleHover: В Inspector назначь Tactical Panel Scene = TacticalPanel.tscn.")
		return null
	var panel := tactical_panel_scene.instantiate() as Control
	if panel == null:
		push_error("BattleHover: TacticalPanel.tscn должна иметь корень Control.")
		return null
	panel.name = node_name
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse_recursive(panel)
	panel.visible = false
	return panel


func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HoverUI"
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.name = "Overlay"
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud = _make_tactical_panel(root, "InfoPanel")
	_target_hud = _make_tactical_panel(root, "AttackTargetPanel")


func _exit_tree() -> void:
	_clear_highlight()
