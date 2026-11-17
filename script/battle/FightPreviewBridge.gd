extends Node
## Проигрывает заранее рассчитанные события BattleCombat без повторного RNG.
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

@export_group("Критический удар — вспышки")
## Включить две вспышки при заранее рассчитанном критическом попадании.
@export var critical_flash_enabled: bool = true
## Цвет обеих вспышек. По умолчанию ярко-красный.
@export var critical_flash_color: Color = Color(1.0, 0.08, 0.08, 1.0)
## Максимальная непрозрачность первой короткой вспышки (0–1).
@export_range(0.0, 1.0, 0.05) var critical_flash_one_alpha: float = 0.8
## Скорость появления первой вспышки.
@export_range(0.01, 0.5, 0.01, "suffix:s") var critical_flash_one_in: float = 0.04
## Длительность затухания первой вспышки.
@export_range(0.01, 1.0, 0.01, "suffix:s") var critical_flash_one_out: float = 0.07
## Пауза между двумя вспышками.
@export_range(0.0, 0.5, 0.01, "suffix:s") var critical_flash_gap: float = 0.06
## Максимальная непрозрачность второй, более долгой вспышки (0–1).
@export_range(0.0, 1.0, 0.05) var critical_flash_two_alpha: float = 0.45
## Скорость появления второй вспышки.
@export_range(0.01, 0.5, 0.01, "suffix:s") var critical_flash_two_in: float = 0.08
## Длительность затухания второй вспышки.
@export_range(0.01, 1.0, 0.01, "suffix:s") var critical_flash_two_out: float = 0.2

@export_group("Критический удар — встряска")
## Включить лёгкую встряску FightScene при критическом попадании.
@export var critical_shake_enabled: bool = true
## Амплитуда встряски в экранных пикселях; 0 полностью убирает смещение.
@export_range(0.0, 10.0, 0.5, "suffix:px") var critical_shake_pixels: float = 2.0
## Число коротких колебаний при критическом ударе.
@export_range(1, 12, 1) var critical_shake_steps: int = 6
## Общая длительность встряски.
@export_range(0.02, 1.0, 0.01, "suffix:s") var critical_shake_seconds: float = 0.22

var _combat: Node
var _queue: Array[Dictionary] = []
var _showing: bool = false
var _overlay: CanvasLayer
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _critical_layer: CanvasLayer
var _critical_rect: ColorRect
var _waiting_for_advance: bool = false
var _typing_message: bool = false
var _skip_typing: bool = false
var _pause_before_exchange: bool = false

signal advance_requested
signal preview_finished


func _ready() -> void:
	# Обрабатываем подтверждение даже при приостановленной BattleMap.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_combat = get_node_or_null(combat_path)
	if _combat == null:
		push_error("FightPreviewBridge: BattleCombat не найден. Проверь Combat Path.")
		return
	if not _combat.has_signal("exchange_planned"):
		push_error("FightPreviewBridge: нужен новый BattleCombat со сигналом exchange_planned.")
		return
	_combat.connect("exchange_planned", Callable(self, "_on_exchange_planned"))


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


func _on_exchange_planned(exchange: Dictionary) -> void:
	if not preview_enabled or fight_scene == null:
		if fight_scene == null:
			push_warning("FightPreviewBridge: Fight Scene не назначена — применяем результат без показа.")
		if _combat != null and _combat.has_method("commit_pending_exchange"):
			_combat.call_deferred("commit_pending_exchange")
		return
	_queue.append(exchange)
	if not _showing:
		_showing = true
		# Синхронно блокируем карту до выхода из physical_attack().
		_pause_before_exchange = get_tree().paused
		if freeze_battle_during_preview:
			get_tree().paused = true
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
	if str(entry.get("kind", "")) == "item_heal":
		await _show_one_heal_preview(entry)
		return
	if fight_scene == null:
		push_warning("FightPreviewBridge: Fight Scene не назначена.")
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var was_paused: bool = _pause_before_exchange
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
	var portraits: Node = fight.get_node_or_null("HUD/FightPanel")
	if portraits != null and portraits.has_method("reset_emotions"):
		portraits.call("reset_emotions")
	# Перед первым ударом читаем актуальные HP и MP обоих юнитов.
	# Оформление, портреты и рамки FightPanel не изменяем.
	_sync_fight_panel_stats(portraits, entry)
	if hero == null or enemy == null:
		push_warning("FightPreviewBridge: в FightScene отсутствует Body героя или врага.")
		_cleanup_preview()
		if _combat != null and _combat.has_method("commit_pending_exchange"):
			_combat.call("commit_pending_exchange")
		tree.paused = was_paused
		preview_finished.emit()
		return

	var result: Dictionary = entry.get("result", {})
	var actions: Array = result.get("actions", [])
	if output != null:
		output.text = ""

	if fade_enabled:
		await _fade_to(0.0, fade_in_seconds, tree)
	for action_value in actions:
		var action: Dictionary = action_value as Dictionary
		var attacking_enemy: bool = bool(action.get("source_is_enemy", false))
		var attacker_sprite: AnimatedSprite2D = enemy if attacking_enemy else hero
		var target_sprite: AnimatedSprite2D = hero if attacking_enemy else enemy
		var actor_name: String = str(action.get("source_name", "Атакующий"))
		var victim_name: String = str(action.get("target_name", "Цель"))
		var kind: String = str(action.get("kind", "attack"))
		var announcement: String = "%s атакует!" % actor_name
		if kind == "counter":
			announcement = "%s контратакует!" % actor_name
		elif kind == "extra":
			announcement = "%s атакует повторно!" % actor_name
		# Сначала сообщение: портрет остаётся Idle.
		await _show_message(output, announcement, tree, announcement_seconds)
		# Эмоция Attack начинается вместе с анимацией самого удара.
		_set_portrait_emotion(portraits, &"trigger_attack", not attacking_enemy)
		await _play_attack(attacker_sprite, tree)
		_set_portrait_emotion(portraits, &"trigger_idle", not attacking_enemy)
		if bool(action.get("dodged", false)):
			await _play_dodge(target_sprite, tree)
			await _show_message(output, "%s уклоняется!" % victim_name, tree, result_hold_seconds)
		else:
			# Реакция Hit не вызывается при уклонении.
			_set_portrait_emotion(portraits, &"trigger_hit", attacking_enemy)
			_play_hit(target_sprite, tree)
			# Анимируем только визуальное HP жертвы по готовому damage.
			# Применение настоящего HP остаётся в commit_pending_exchange().
			if is_instance_valid(portraits) and portraits.has_method("animate_damage"):
				await portraits.call("animate_damage", attacking_enemy, int(action.get("damage", 0)))
			if bool(action.get("critical", false)):
				await _play_critical_effect(tree)
			var message: String = "%s получает %d ед. урона." % [victim_name, int(action.get("damage", 0))]
			if bool(action.get("critical", false)):
				message = "Критический удар! " + message
			await _show_message(output, message, tree, result_hold_seconds)
			if not bool(action.get("defeated", false)):
				_set_portrait_emotion(portraits, &"trigger_idle", attacking_enemy)
		if bool(action.get("defeated", false)):
			_set_portrait_emotion(portraits, &"trigger_defeat", attacking_enemy)
			_set_portrait_emotion(portraits, &"trigger_victory", not attacking_enemy)
			await _show_message(output, "%s повержен!" % victim_name, tree, result_hold_seconds)

	# Сначала закрываем FightScene затемнением, потом убираем её из дерева.
	if fade_enabled:
		await _fade_to(1.0, fade_out_seconds, tree)
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	# HP, смерть и исход боя применяются только после всех показанных событий.
	if _combat != null and is_instance_valid(_combat) and _combat.has_method("commit_pending_exchange"):
		_combat.call("commit_pending_exchange")
	# Прозрачная поверхность открывает прежнюю тактическую карту.
	if fade_enabled:
		await _fade_to(0.0, fade_in_seconds, tree)
	_cleanup_fade()
	_cleanup_critical_effect()
	tree.paused = was_paused
	preview_finished.emit()
	if debug_preview:
		print("S7 FIGHT PREVIEW: последовательность событий завершена")


## Лечебное действие использует ту же FightScene и HUD, что и обычная атака.
## Оба участника могут быть союзниками. HP изменяет только BattleCombat.commit_pending_exchange().
func _show_one_heal_preview(entry: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var was_paused: bool = _pause_before_exchange
	if freeze_battle_during_preview:
		tree.paused = true
	if fade_enabled:
		_create_fade_overlay(tree)
		await _fade_to(1.0, fade_out_seconds, tree)

	_overlay = CanvasLayer.new()
	_overlay.name = "FightHealOverlay"
	_overlay.layer = overlay_layer
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(_overlay)
	var fight: Node = fight_scene.instantiate()
	fight.process_mode = Node.PROCESS_MODE_ALWAYS
	if _has_property(fight, "test_keyboard"):
		fight.set("test_keyboard", false)
	_overlay.add_child(fight)
	var hud: CanvasLayer = fight.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.layer = overlay_layer + 1

	var left_sprite: AnimatedSprite2D = fight.get_node_or_null("HeroAnchor/HeroVisual/Body") as AnimatedSprite2D
	var right_sprite: AnimatedSprite2D = fight.get_node_or_null("EnemyAnchor/EnemyVisual/Body") as AnimatedSprite2D
	var output: RichTextLabel = fight.get_node_or_null("HUD/DialoguePanel/BattleText") as RichTextLabel
	var panel: Node = fight.get_node_or_null("HUD/FightPanel")
	var actor: Node2D = entry.get("attacker") as Node2D
	var recipient: Node2D = entry.get("target") as Node2D
	var result: Dictionary = entry.get("result", {})
	var actions: Array = result.get("actions", [])
	var action: Dictionary = actions[0] if not actions.is_empty() else {}
	# Для лечения врагом врага актёр справа (EnemyAnchor), цель слева (HeroAnchor).
	var enemy_actor: bool = is_instance_valid(actor) and actor.is_in_group(&"battle_enemies")
	var actor_sprite: AnimatedSprite2D = right_sprite if enemy_actor else left_sprite
	var self_heal: bool = actor == recipient
	# При самолечении показываем только лечащего, не создавая его двойника.
	var recipient_sprite: AnimatedSprite2D = actor_sprite if self_heal else (left_sprite if enemy_actor else right_sprite)

	if not is_instance_valid(actor) or not is_instance_valid(recipient) or actor_sprite == null or recipient_sprite == null:
		push_warning("FightPreviewBridge: нет пары юнитов для лечебного действия.")
		_cleanup_preview()
		if _combat != null and _combat.has_method("commit_pending_exchange"):
			_combat.call("commit_pending_exchange")
		tree.paused = was_paused
		preview_finished.emit()
		return

	# Сохраняем исходные кадры до изменения любой стороны.
	var max_frames: SpriteFrames = left_sprite.sprite_frames
	var goblin_frames: SpriteFrames = right_sprite.sprite_frames
	_configure_heal_sprite(actor_sprite, actor, max_frames, goblin_frames)
	if not self_heal:
		_configure_heal_sprite(recipient_sprite, recipient, max_frames, goblin_frames)
	else:
		# Вторая сторона сцены скрыта только для этого экземпляра FightScene.
		var unused_visual: Node2D
		if enemy_actor:
			unused_visual = fight.get_node_or_null("HeroAnchor/HeroVisual") as Node2D
		else:
			unused_visual = fight.get_node_or_null("EnemyAnchor/EnemyVisual") as Node2D
		if unused_visual != null:
			unused_visual.hide()
	_configure_heal_panel_side(panel, not enemy_actor, actor)
	if self_heal:
		var unused_side: Control
		if enemy_actor:
			unused_side = panel.get_node_or_null("HeroSide") as Control
		else:
			unused_side = panel.get_node_or_null("EnemySide") as Control
		if unused_side != null:
			unused_side.hide()
	else:
		_configure_heal_panel_side(panel, enemy_actor, recipient)
	if panel != null and panel.has_method("reset_emotions"):
		panel.call("reset_emotions")
	if output != null:
		output.text = ""
	if fade_enabled:
		await _fade_to(0.0, fade_in_seconds, tree)

	var actor_name: String = str(action.get("source_name", actor.name))
	var recipient_name: String = str(action.get("target_name", recipient.name))
	var item_name: String = str(action.get("item_name", "предмет"))
	var healed: int = int(action.get("heal", 0))
	var xp: int = int(action.get("xp_gain", 0))
	await _show_message(output, "%s применяет %s!" % [actor_name, item_name], tree, announcement_seconds)
	_set_portrait_emotion(panel, &"trigger_attack", not enemy_actor)
	await _play_heal_actor_animation(actor_sprite, tree)
	_set_portrait_emotion(panel, &"trigger_idle", not enemy_actor)
	await _play_heal_flash(recipient_sprite, tree)
	if panel != null and panel.has_method("animate_heal"):
		# При самолечении анимируем HP на стороне самого лечащего.
		await panel.call("animate_heal", (not enemy_actor) if self_heal else enemy_actor, healed)
	var result_text: String = "%s восстановлено %d HP." % [recipient_name, healed]
	if xp > 0:
		result_text += "\n%s получает %d XP." % [actor_name, xp]
	await _show_message(output, result_text, tree, result_hold_seconds)

	if fade_enabled:
		await _fade_to(1.0, fade_out_seconds, tree)
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	# Только теперь применяются реальные HP, XP и расходуется предмет.
	if _combat != null and is_instance_valid(_combat) and _combat.has_method("commit_pending_exchange"):
		_combat.call("commit_pending_exchange")
	if fade_enabled:
		await _fade_to(0.0, fade_in_seconds, tree)
	_cleanup_fade()
	_cleanup_critical_effect()
	tree.paused = was_paused
	preview_finished.emit()


## В FightScene есть боевой Max и Goblin; для Sara используется её готовый
## SpriteFrames из тактической сцены (специальной боевой анимации пока нет).
func _configure_heal_sprite(sprite: AnimatedSprite2D, unit: Node2D, max_frames: SpriteFrames, goblin_frames: SpriteFrames) -> void:
	if unit.name == "Sara":
		sprite.sprite_frames = preload("res://scene/characters/sara_walk.tres")
		sprite.scale = Vector2(3.0, 3.0)
		sprite.animation = &"Idle_right"
	elif unit.is_in_group(&"battle_enemies"):
		if goblin_frames != null:
			sprite.sprite_frames = goblin_frames
		sprite.animation = &"idle"
	else:
		if max_frames != null:
			sprite.sprite_frames = max_frames
		sprite.animation = &"idle"
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		sprite.play(sprite.animation)


func _configure_heal_panel_side(panel: Node, left_side: bool, unit: Node2D) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(_combat) or not is_instance_valid(unit):
		return
	var resource: Resource = null
	if unit.is_in_group(&"battle_enemies"):
		resource = unit.get_meta("enemy_data", null) as Resource
	elif _combat.has_method("_hero_data"):
		resource = _combat.call("_hero_data", unit) as Resource
	var character_name: String = _unit_display_name(unit)
	var level: int = 1
	if resource != null:
		for property_info: Dictionary in resource.get_property_list():
			if str(property_info.get("name", "")) == "level":
				level = int(resource.get("level"))
				break
	var hp: int = int(_combat.call("get_current_hp", unit))
	var max_hp: int = int(_combat.call("get_max_hp", unit))
	var mp: int = int(_combat.call("get_current_mp", unit))
	var max_mp: int = int(_combat.call("get_max_mp", unit))
	if panel.has_method("set_side_portraits_from_data"):
		panel.call("set_side_portraits_from_data", left_side, resource)
	if panel.has_method("set_side_data"):
		panel.call("set_side_data", left_side, character_name, level, hp, max_hp, mp, max_mp)


func _play_heal_actor_animation(sprite: AnimatedSprite2D, tree: SceneTree) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"attack"):
		await _play_attack(sprite, tree)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"Right"):
		# Для Sara отсутствует отдельная battle-attack анимация в исходных ресурсах.
		sprite.play(&"Right")
		await tree.create_timer(0.55, true).timeout
		if is_instance_valid(sprite) and sprite.sprite_frames.has_animation(&"Idle_right"):
			sprite.play(&"Idle_right")
	else:
		await tree.create_timer(0.45, true).timeout


## Вспышка лечения накладывается на цель без изменения её реального HP.
func _play_heal_flash(sprite: AnimatedSprite2D, tree: SceneTree) -> void:
	var original_color: Color = sprite.modulate
	var original_scale: Vector2 = sprite.scale
	var tween: Tween = tree.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(sprite, "modulate", Color(0.5, 1.0, 0.55, 1.0), 0.14)
	tween.parallel().tween_property(sprite, "scale", original_scale * 1.08, 0.14)
	tween.tween_property(sprite, "modulate", original_color, 0.24)
	tween.parallel().tween_property(sprite, "scale", original_scale, 0.24)
	await tween.finished


## Начальные HP/MP читаем из реальных юнитов, а не из Inspector.
## BattleCombat применит итоговый урон после завершения FightScene.
func _sync_fight_panel_stats(panel: Node, exchange: Dictionary) -> void:
	if not is_instance_valid(panel) or not panel.has_method("set_side_data"):
		return
	if not is_instance_valid(_combat):
		return
	if not _combat.has_method("get_current_hp") or not _combat.has_method("get_max_hp"):
		return
	if not _combat.has_method("get_current_mp") or not _combat.has_method("get_max_mp"):
		push_warning("FightPreviewBridge: BattleCombat не поддерживает синхронизацию MP.")
		return

	# Используем ту же синхронизацию HeroData/EnemyData, которая уже
	# работает для лечения: имя, уровень, HP/MP и все эмоции из ресурса.
	# Так при атаке Сары FightPanel не сохраняет портрет Макса из Inspector.
	var attacker: Node2D = exchange.get("attacker") as Node2D
	var target: Node2D = exchange.get("target") as Node2D
	for unit in [attacker, target]:
		if not is_instance_valid(unit):
			continue
		var left_side: bool = not unit.is_in_group(&"battle_enemies")
		_configure_heal_panel_side(panel, left_side, unit)


func _set_portrait_emotion(panel: Node, method: StringName, is_hero: bool) -> void:
	# Если FightPanel отсутствует, бой продолжает работать как раньше.
	if is_instance_valid(panel) and panel.has_method(method):
		panel.call(method, is_hero)


func _play_critical_effect(tree: SceneTree) -> void:
	# Визуализация использует готовый action.critical; здесь нет RNG.
	if not critical_flash_enabled and not critical_shake_enabled:
		return

	# Слой вспышки выше HUD, но ниже чёрного Fade-перехода.
	if critical_flash_enabled:
		_create_critical_overlay(tree)
	var flash_tween: Tween
	if critical_flash_enabled and is_instance_valid(_critical_rect):
		flash_tween = tree.create_tween()
		flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		flash_tween.tween_property(_critical_rect, "color:a", critical_flash_one_alpha, critical_flash_one_in)
		flash_tween.tween_property(_critical_rect, "color:a", 0.0, critical_flash_one_out)
		flash_tween.tween_interval(critical_flash_gap)
		flash_tween.tween_property(_critical_rect, "color:a", critical_flash_two_alpha, critical_flash_two_in)
		flash_tween.tween_property(_critical_rect, "color:a", 0.0, critical_flash_two_out)

	var shake_tween: Tween
	if critical_shake_enabled and is_instance_valid(_overlay) and critical_shake_pixels > 0.0:
		var original_offset: Vector2 = _overlay.offset
		shake_tween = tree.create_tween()
		shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		var steps: int = maxi(critical_shake_steps, 1)
		var step_duration: float = critical_shake_seconds / float(steps)
		for step in range(steps):
			var sign_x: float = 1.0 if step % 2 == 0 else -1.0
			var sign_y: float = -1.0 if step % 2 == 0 else 1.0
			var magnitude: float = critical_shake_pixels * (1.0 - float(step) / float(steps))
			shake_tween.tween_property(
				_overlay, "offset",
				original_offset + Vector2(sign_x * magnitude, sign_y * magnitude * 0.5),
				step_duration
			)
		shake_tween.tween_property(_overlay, "offset", original_offset, 0.02)

	# Ждём один раз по максимальной длительности. Нельзя последовательно
	# ожидать сигналы двух параллельных Tween: более короткий уже завершится
	# до второго await, и FightScene зависнет на старом сообщении.
	var flash_duration: float = 0.0
	if flash_tween != null:
		flash_duration = critical_flash_one_in + critical_flash_one_out + critical_flash_gap + critical_flash_two_in + critical_flash_two_out
	var shake_duration: float = 0.0
	if shake_tween != null:
		shake_duration = critical_shake_seconds + 0.02
	var effect_duration: float = maxf(flash_duration, shake_duration)
	if effect_duration > 0.0:
		await tree.create_timer(effect_duration + 0.04, true).timeout
	# Финальное состояние гарантировано, даже если параметры меняли в Inspector.
	if is_instance_valid(_overlay):
		_overlay.offset = Vector2.ZERO
	if is_instance_valid(_critical_rect):
		_critical_rect.color = Color(critical_flash_color.r, critical_flash_color.g, critical_flash_color.b, 0.0)


func _create_critical_overlay(tree: SceneTree) -> void:
	if is_instance_valid(_critical_layer):
		return
	_critical_layer = CanvasLayer.new()
	_critical_layer.name = "CriticalHitFX"
	_critical_layer.layer = overlay_layer + 3
	_critical_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(_critical_layer)
	_critical_rect = ColorRect.new()
	_critical_rect.name = "RedCriticalFlash"
	_critical_rect.color = Color(critical_flash_color.r, critical_flash_color.g, critical_flash_color.b, 0.0)
	_critical_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_critical_layer.add_child(_critical_rect)
	_critical_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _cleanup_critical_effect() -> void:
	if is_instance_valid(_overlay):
		_overlay.offset = Vector2.ZERO
	if is_instance_valid(_critical_layer):
		_critical_layer.queue_free()
	_critical_layer = null
	_critical_rect = null


func _create_fade_overlay(tree: SceneTree) -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "FightPreviewFade"
	_fade_layer.layer = overlay_layer + 4
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
	_cleanup_critical_effect()

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


func _play_dodge(sprite: AnimatedSprite2D, tree: SceneTree) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"evasion"):
		sprite.play(&"evasion")
		sprite.stop()
		sprite.frame = 0
	await tree.create_timer(0.4, true).timeout
	if is_instance_valid(sprite) and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
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
