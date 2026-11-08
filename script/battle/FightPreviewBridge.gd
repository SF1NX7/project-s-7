extends Node
## Показывает FightScene поверх тактической карты после физической атаки.
## Первый этап интеграции: не рассчитывает и не изменяет HP.
## Добавить как Node с именем FightPreviewBridge непосредственно в BattleMap.

@export_group("Ссылки")
## Существующая нода BattleCombat в той же боевой сцене.
@export var combat_path: NodePath = ^"../BattleCombat"
## Готовая визуальная сцена с HeroAnchor, EnemyAnchor и BattleText.
@export var fight_scene: PackedScene = preload("res://scene/battle/FightScene.tscn")

@export_group("Показ столкновения")
## Включить показ FightScene после физической атаки.
@export var preview_enabled: bool = true
## Если включено, каждое сообщение ожидает подтверждения клавишей или кнопкой геймпада.
## Отключи для автоматического показа с заданными ниже паузами.
@export var advance_on_input: bool = true
## Автоматическая пауза после объявления атаки (если Advance On Input выключен).
@export_range(0.1, 5.0, 0.1, "suffix:s") var announcement_seconds: float = 1.0
## Автоматическая пауза после сообщения об уроне (если Advance On Input выключен).
@export_range(0.1, 10.0, 0.1, "suffix:s") var result_hold_seconds: float = 2.0
## Сколько длится визуальная реакция на попадание.
@export_range(0.1, 2.0, 0.05, "suffix:s") var hit_seconds: float = 0.3
## Амплитуда дрожания спрайта при попадании.
@export_range(0.0, 12.0, 0.5, "suffix:px") var hit_shake_pixels: float = 3.0
## Блокировать тактическую карту во время показа FightScene.
@export var freeze_battle_during_preview: bool = true
## Слой интерфейса поверх BattleMap.
@export_range(1, 120, 1) var overlay_layer: int = 80
## Печатать диагностические сообщения в Output.
@export var debug_preview: bool = false

@export_group("Печатающая машинка")
## Показывать объявления, урон и сообщение о победе посимвольно.
@export var typewriter_enabled: bool = true
## Скорость появления текста в символах в секунду.
@export_range(5.0, 120.0, 1.0, "suffix:симв/с") var typewriter_chars_per_second: float = 35.0
## Во время печати нажатие любой клавиши показывает строку целиком.
## Следующее нажатие подтверждает сообщение.
@export var press_to_reveal_full_text: bool = true

@export_group("Переходы FightScene")
## Включить плавное затемнение при входе в FightScene и выходе из неё.
@export var fade_enabled: bool = true
## Время закрытия экрана перед сменой представления, в секундах.
@export_range(0.05, 2.0, 0.05, "suffix:s") var fade_out_seconds: float = 0.3
## Время открытия нового представления, в секундах.
@export_range(0.05, 2.0, 0.05, "suffix:s") var fade_in_seconds: float = 0.3
## Цвет затемнения; обычно чёрный.
@export var fade_color: Color = Color.BLACK

var _combat: Node
var _queue: Array[Dictionary] = []
var _showing: bool = false
var _overlay: CanvasLayer
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _waiting_for_advance: bool = false
var _typing_message: bool = false
var _skip_typing: bool = false

signal advance_requested


func _ready() -> void:
	# Обрабатываем подтверждение даже при приостановленной BattleMap.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_combat = get_node_or_null(combat_path)
	if _combat == null:
		push_error("FightPreviewBridge: BattleCombat не найден. Проверь Combat Path.")
		return
	if not _combat.has_signal("combat_resolved"):
		push_error("FightPreviewBridge: сигнал combat_resolved отсутствует.")
		return
	_combat.connect("combat_resolved", Callable(self, "_on_combat_resolved"))


func _input(event: InputEvent) -> void:
	if not _waiting_for_advance and not _typing_message:
		return
	var accepted: bool = false
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		accepted = key.pressed and not key.echo
	elif event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event as InputEventJoypadButton
		accepted = button.pressed
	if not accepted:
		return
	get_viewport().set_input_as_handled()
	if _typing_message:
		if press_to_reveal_full_text:
			_skip_typing = true
		# Первое нажатие во время печати никогда не пропускает сообщение.
		return
	if _waiting_for_advance:
		_waiting_for_advance = false
		advance_requested.emit()


func _show_message(output: RichTextLabel, message: String, tree: SceneTree, hold_seconds: float) -> void:
	if output != null:
		output.text = message
		output.visible_characters = -1
		if typewriter_enabled:
			output.visible_characters = 0
			_typing_message = true
			_skip_typing = false
			var total: int = output.get_total_character_count()
			var interval: float = 1.0 / maxf(typewriter_chars_per_second, 1.0)
			for character_index in range(total):
				if _skip_typing or not is_instance_valid(output):
					break
				await tree.create_timer(interval, true).timeout
				if _skip_typing or not is_instance_valid(output):
					break
				output.visible_characters = character_index + 1
			if is_instance_valid(output):
				output.visible_characters = -1
			_typing_message = false
			_skip_typing = false
	await _wait_for_message(tree, hold_seconds)


func _wait_for_message(tree: SceneTree, automatic_seconds: float) -> void:
	if not advance_on_input:
		await tree.create_timer(automatic_seconds, true).timeout
		return
	_waiting_for_advance = true
	await advance_requested


func _on_combat_resolved(attacker: Node2D, target: Node2D, result: Dictionary) -> void:
	if not preview_enabled or not bool(result.get("ok", false)):
		return
	# Запоминаем данные, а не живые ссылки: юнит может погибнуть и удалиться.
	var entry: Dictionary = {
		"attacker_is_enemy": attacker.is_in_group("battle_enemies"),
		"attacker_name": _unit_display_name(attacker),
		"target_name": _unit_display_name(target),
		"damage": int(result.get("damage", 0)),
		"defeated": bool(result.get("defeated", false))
	}
	_queue.append(entry)
	if not _showing:
		_showing = true
		call_deferred("_drain_preview_queue")


func _unit_display_name(unit: Node2D) -> String:
	if not is_instance_valid(unit):
		return "Персонаж"
	if unit.has_meta("enemy_data"):
		var data: Variant = unit.get_meta("enemy_data")
		if data is Resource:
			var value: Variant = (data as Resource).get("display_name")
			if value != null and not str(value).is_empty():
				return str(value)
	return str(unit.name)


func _drain_preview_queue() -> void:
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		await _show_one_preview(entry)
	_showing = false


func _show_one_preview(entry: Dictionary) -> void:
	if fight_scene == null:
		push_warning("FightPreviewBridge: Fight Scene не назначена.")
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var was_paused: bool = tree.paused
	# Сначала блокируем боевую карту, чтобы курсор не двигался при переходе.
	if freeze_battle_during_preview:
		tree.paused = true

	# Затемнение — отдельный CanvasLayer под корнем SceneTree.
	# Он не зависит от FightScene и находится выше её HUD.
	if fade_enabled:
		_create_fade_overlay(tree)
		await _fade_to(1.0, fade_out_seconds, tree)

	_overlay = CanvasLayer.new()
	_overlay.name = "FightPreviewOverlay"
	_overlay.layer = overlay_layer
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(_overlay)

	var fight: Node = fight_scene.instantiate()
	# FightScene должна анимироваться даже при остановленной тактической карте.
	fight.process_mode = Node.PROCESS_MODE_ALWAYS
	# Тестовые горячие клавиши не должны срабатывать в реальном бою.
	if _has_property(fight, "test_keyboard"):
		fight.set("test_keyboard", false)
	_overlay.add_child(fight)
	# HUD — отдельный CanvasLayer, располагаем его выше FightScene.
	var fight_hud: CanvasLayer = fight.get_node_or_null("HUD") as CanvasLayer
	if fight_hud != null:
		fight_hud.layer = overlay_layer + 1
	var hero: AnimatedSprite2D = fight.get_node_or_null("HeroAnchor/HeroVisual/Body") as AnimatedSprite2D
	var enemy: AnimatedSprite2D = fight.get_node_or_null("EnemyAnchor/EnemyVisual/Body") as AnimatedSprite2D
	var output: RichTextLabel = fight.get_node_or_null("HUD/DialoguePanel/BattleText") as RichTextLabel
	if hero == null or enemy == null:
		push_warning("FightPreviewBridge: в FightScene отсутствует Body героя или врага.")
		_cleanup_preview()
		tree.paused = was_paused
		return

	var attacking_enemy: bool = bool(entry["attacker_is_enemy"])
	var attacker_sprite: AnimatedSprite2D = enemy if attacking_enemy else hero
	var target_sprite: AnimatedSprite2D = hero if attacking_enemy else enemy
	var actor_name: String = str(entry["attacker_name"])
	var victim_name: String = str(entry["target_name"])
	if output != null:
		output.text = ""

	# Сперва открываем сцену, потом печатаем объявление об атаке.
	if fade_enabled:
		await _fade_to(0.0, fade_in_seconds, tree)
	await _show_message(output, "%s атакует!" % actor_name, tree, announcement_seconds)
	await _play_attack(attacker_sprite, tree)
	await _play_hit(target_sprite, tree)
	# Не скрываем результат, пока игрок не подтвердит (или не пройдёт таймер).
	await _show_message(output, "%s получает %d ед. урона." % [victim_name, int(entry["damage"])], tree, result_hold_seconds)
	if bool(entry["defeated"]):
		await _show_message(output, "%s повержен!" % victim_name, tree, result_hold_seconds)

	# Сначала закрываем FightScene затемнением, потом убираем её из дерева.
	if fade_enabled:
		await _fade_to(1.0, fade_out_seconds, tree)
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	# Прозрачная поверхность открывает прежнюю тактическую карту.
	if fade_enabled:
		await _fade_to(0.0, fade_in_seconds, tree)
	_cleanup_fade()
	tree.paused = was_paused
	if debug_preview:
		print("S7 FIGHT PREVIEW: показ завершён — ", actor_name, " → ", victim_name)


func _create_fade_overlay(tree: SceneTree) -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "FightPreviewFade"
	_fade_layer.layer = overlay_layer + 2
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.name = "BlackFade"
	_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _fade_to(target_alpha: float, duration: float, tree: SceneTree) -> void:
	if not is_instance_valid(_fade_rect):
		return
	var tween: Tween = tree.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", target_alpha, duration)
	await tween.finished


func _cleanup_fade() -> void:
	if is_instance_valid(_fade_layer):
		_fade_layer.queue_free()
	_fade_layer = null
	_fade_rect = null


func _cleanup_preview() -> void:
	_waiting_for_advance = false
	_typing_message = false
	_skip_typing = false
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_cleanup_fade()

func _play_attack(sprite: AnimatedSprite2D, tree: SceneTree) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"attack"):
		await tree.create_timer(0.45, true).timeout
		return
	sprite.play(&"attack")
	# Таймер вместо бесконечного ожидания сигнала защищает от случайно включённого Loop.
	var frames: int = sprite.sprite_frames.get_frame_count(&"attack")
	var fps: float = sprite.sprite_frames.get_animation_speed(&"attack") * sprite.speed_scale
	var duration: float = clampf(float(frames) / maxf(fps, 0.01), 0.1, 3.0)
	await tree.create_timer(duration, true).timeout
	if is_instance_valid(sprite) and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")


func _play_hit(sprite: AnimatedSprite2D, tree: SceneTree) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
	var original_position: Vector2 = sprite.position
	var original_modulate: Color = sprite.modulate
	var tween: Tween = tree.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var repeats: int = 4
	var interval: float = hit_seconds / float(repeats * 2)
	for i in range(repeats):
		tween.tween_property(sprite, "modulate:a", 0.35, interval)
		tween.parallel().tween_property(sprite, "position:x", original_position.x + hit_shake_pixels, interval)
		tween.tween_property(sprite, "modulate:a", original_modulate.a, interval)
		tween.parallel().tween_property(sprite, "position:x", original_position.x - hit_shake_pixels, interval)
	await tween.finished
	if is_instance_valid(sprite):
		sprite.position = original_position
		sprite.modulate = original_modulate


func _has_property(object: Object, property_name: String) -> bool:
	for prop: Dictionary in object.get_property_list():
		if str(prop.get("name", "")) == property_name:
			return true
	return false


func _exit_tree() -> void:
	_waiting_for_advance = false
	_typing_message = false
	_skip_typing = false
	# Страховка на случай остановки сцены во время показа.
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
	_cleanup_preview()
