extends Node2D
## Автономный тест FightScene. Не изменяет HP и не обращается к BattleCombat.

@export_group("Ноды")
## Путь к AnimatedSprite2D героя.
@export var hero_path: NodePath = ^"HeroAnchor/HeroVisual/Body"
## Путь к AnimatedSprite2D противника.
@export var enemy_path: NodePath = ^"EnemyAnchor/EnemyVisual/Body"
## Путь к тексту нижнего окна.
@export var text_path: NodePath = ^"HUD/DialoguePanel/BattleText"

@export_group("Названия анимаций")
## Зацикленная стойка ожидания, два кадра.
@export var idle_animation: StringName = &"idle"
## Атака, четыре кадра, без зацикливания.
@export var attack_animation: StringName = &"attack"
## Однокадровая поза уклонения.
@export var evasion_animation: StringName = &"evasion"

@export_group("Тестирование")
## Разрешить клавиши E, R, Q, T, H при отдельном запуске FightScene.
@export var test_keyboard: bool = true
## Сколько секунд удерживать позу уклонения.
@export_range(0.1, 3.0, 0.05) var evasion_hold_seconds: float = 0.45
## Длительность мигания и дрожания при попадании.
@export_range(0.1, 2.0, 0.05) var hit_seconds: float = 0.36
## Амплитуда горизонтального дрожания спрайта в пикселях.
@export_range(0.0, 12.0, 0.5) var hit_shake_pixels: float = 3.0
## Спрятать отдельный Weapon, пока меч уже нарисован в Body.
@export var hide_weapon_layer: bool = true

var _hero: AnimatedSprite2D
var _enemy: AnimatedSprite2D
var _battle_text: RichTextLabel
var _fight_panel: Node
var _busy: bool = false


func _ready() -> void:
	_hero = get_node_or_null(hero_path) as AnimatedSprite2D
	_enemy = get_node_or_null(enemy_path) as AnimatedSprite2D
	_battle_text = get_node_or_null(text_path) as RichTextLabel
	_fight_panel = get_node_or_null(^"HUD/FightPanel")
	if _fight_panel != null and _fight_panel.has_method("reset_emotions"):
		_fight_panel.call("reset_emotions")

	if _hero == null or _enemy == null:
		push_error("FightScene: проверь пути Hero/Enemy Body в Inspector.")
		return

	if hide_weapon_layer:
		var weapon: CanvasItem = get_node_or_null(^"HeroAnchor/HeroVisual/Weapon") as CanvasItem
		if weapon != null:
			weapon.hide()

	_play_idle(_hero)
	_play_idle(_enemy)
	_show_message("E: Макс атакует | R: гоблин атакует | Q: уворот гоблина | T: уворот Макса | H: попадание")


func _unhandled_key_input(event: InputEvent) -> void:
	if not test_keyboard or _busy or _hero == null or _enemy == null:
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var accepted: bool = true
	match key_event.physical_keycode:
		KEY_E:
			_attack_sequence(_hero, _enemy, "Макс", "Гоблин")
		KEY_R:
			_attack_sequence(_enemy, _hero, "Гоблин", "Макс")
		KEY_Q:
			_evasion_sequence(_enemy, "Гоблин")
		KEY_T:
			_evasion_sequence(_hero, "Макс")
		KEY_H:
			_hit_sequence(_hero, "Макс")
		_:
			accepted = false

	if accepted:
		get_viewport().set_input_as_handled()


func _show_message(message: String) -> void:
	if _battle_text != null:
		_battle_text.text = message


func _has_animation(sprite: AnimatedSprite2D, animation_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name)


func _play_idle(sprite: AnimatedSprite2D) -> void:
	if _has_animation(sprite, idle_animation):
		sprite.play(idle_animation)


func _attack_sequence(attacker: AnimatedSprite2D, defender: AnimatedSprite2D, actor_name: String, target_name: String) -> void:
	if not _has_animation(attacker, attack_animation):
		push_warning("FightScene: анимация attack не найдена у %s." % actor_name)
		return
	_busy = true
	_set_test_emotion("trigger_attack", attacker == _hero)
	_show_message("%s атакует!" % actor_name)

	attacker.stop()
	attacker.play(attack_animation)
	if attacker.sprite_frames.get_animation_loop(attack_animation):
		push_warning("FightScene: отключи Loop у attack; используется таймер.")
		var frames: int = attacker.sprite_frames.get_frame_count(attack_animation)
		var speed: float = maxf(attacker.sprite_frames.get_animation_speed(attack_animation) * absf(attacker.speed_scale), 0.01)
		await get_tree().create_timer(float(frames) / speed).timeout
	else:
		await attacker.animation_finished

	_play_idle(attacker)
	_set_test_emotion("trigger_idle", attacker == _hero)
	_show_message("%s получает удар! (тест без изменения HP)" % target_name)
	_set_test_emotion("trigger_hit", defender == _hero)
	await _hit_flash(defender)
	_set_test_emotion("trigger_idle", defender == _hero)
	_play_idle(defender)
	_busy = false


func _evasion_sequence(sprite: AnimatedSprite2D, actor_name: String) -> void:
	if not _has_animation(sprite, evasion_animation):
		push_warning("FightScene: анимация evasion не найдена у %s." % actor_name)
		return
	_busy = true
	_show_message("%s уклоняется!" % actor_name)
	sprite.play(evasion_animation)
	sprite.stop()
	sprite.frame = 0
	await get_tree().create_timer(evasion_hold_seconds).timeout
	_play_idle(sprite)
	_busy = false


func _hit_sequence(sprite: AnimatedSprite2D, actor_name: String) -> void:
	_busy = true
	_show_message("%s получает удар! (тест)" % actor_name)
	_play_idle(sprite)
	_set_test_emotion("trigger_hit", sprite == _hero)
	await _hit_flash(sprite)
	_set_test_emotion("trigger_idle", sprite == _hero)
	_busy = false


func _set_test_emotion(method: String, is_hero: bool) -> void:
	if is_instance_valid(_fight_panel) and _fight_panel.has_method(method):
		_fight_panel.call(method, is_hero)


func _hit_flash(sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(sprite):
		return
	var original_position: Vector2 = sprite.position
	var original_modulate: Color = sprite.modulate
	var step_seconds: float = hit_seconds / 6.0
	for step in range(6):
		var direction: float = 1.0 if step % 2 == 0 else -1.0
		sprite.position = original_position + Vector2(hit_shake_pixels * direction, 0.0)
		var tint: Color = original_modulate
		tint.a = original_modulate.a * (0.3 if step % 2 == 0 else 1.0)
		sprite.modulate = tint
		await get_tree().create_timer(step_seconds).timeout
	sprite.position = original_position
	sprite.modulate = original_modulate
