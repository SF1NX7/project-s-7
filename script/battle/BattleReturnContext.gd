extends Node
## Сохраняет место начала боя и восстанавливает героя после загрузки исходной сцены.
## Добавьте файл в Project Settings -> Globals -> Autoload под именем BattleReturnContext.

@export_group("Защита от повторной встречи")
## Время после возвращения, когда триггеры боя игнорируют игрока.
@export_range(0.0, 10.0, 0.1, "suffix:s") var encounter_cooldown: float = 1.5

var world_scene_path: String = ""
var player_position: Vector2 = Vector2.ZERO
var player_direction: Vector2 = Vector2.DOWN
var encounter_id: String = ""
var encounter_is_one_time: bool = false
## Завершённые сюжетные встречи в текущей игровой сессии (пока без записи в Save_Manager).
var completed_encounters: Dictionary = {}
var return_pending: bool = false
var _has_context: bool = false
var _blocked_until_msec: int = 0

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)

## Запоминает исходную сцену и фактическую мировую позицию героя.
func capture(scene_path: String, player: Node2D, trigger_id: String = "", one_time: bool = false) -> void:
	if scene_path.is_empty() or not is_instance_valid(player):
		push_warning("BattleReturnContext: не удалось сохранить исходную сцену или игрока.")
		return
	world_scene_path = scene_path
	# Триггер может сработать посреди шага: сохраняем центр целевой клетки,
	# а не промежуточную позицию между клетками.
	player_position = player.global_position
	if "moving" in player and bool(player.get("moving")) and "target_position" in player:
		var step_destination: Variant = player.get("target_position")
		if step_destination is Vector2:
			player_position = step_destination
	player_direction = Vector2.DOWN
	if "last_direction" in player:
		player_direction = player.get("last_direction")
	encounter_id = trigger_id
	encounter_is_one_time = one_time
	_has_context = true
	return_pending = false
	print("S7 RETURN: сохранено ", world_scene_path, " / ", player_position)

## Проверяет, завершена ли конкретная сюжетная встреча победой.
func is_encounter_completed(key: String) -> bool:
	return not key.is_empty() and bool(completed_encounters.get(key, false))

## Отмечает активную сюжетную встречу завершённой. Вызывать только при победе.
func mark_current_encounter_victorious() -> void:
	if not has_context() or not encounter_is_one_time or encounter_id.is_empty():
		return
	completed_encounters[encounter_id] = true
	print("S7 ENCOUNTER: победа сохранена для ", encounter_id)

func has_context() -> bool:
	return _has_context and not world_scene_path.is_empty()

## Открывает сохранённую сцену, затем возвращает игрока на место встречи.
func return_to_saved_world() -> Error:
	if not has_context():
		push_warning("BattleReturnContext: исходная сцена не была сохранена.")
		return ERR_DOES_NOT_EXIST
	if not ResourceLoader.exists(world_scene_path):
		push_error("BattleReturnContext: сцена не найдена: " + world_scene_path)
		return ERR_FILE_NOT_FOUND
	return_pending = true
	print("S7 RETURN: запрос возврата в ", world_scene_path, " / ", player_position)
	_blocked_until_msec = Time.get_ticks_msec() + int(encounter_cooldown * 1000.0)
	var error: Error = get_tree().change_scene_to_file(world_scene_path)
	if error != OK:
		return_pending = false
		push_error("BattleReturnContext: ошибка перехода: " + str(error))
	return error

func is_encounter_blocked() -> bool:
	return return_pending or Time.get_ticks_msec() < _blocked_until_msec

## Подстраховка: после смены сцены проверяем восстановление в следующем кадре.
## Полезно, когда сигнал scene_changed уже прошёл или порядок инициализации изменился.
func _process(_delta: float) -> void:
	if not return_pending:
		return
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != world_scene_path:
		return
	_restore_after_load()


func _on_scene_changed(scene: Node) -> void:
	if not return_pending or scene == null:
		return
	print("S7 RETURN: загружена сцена ", scene.scene_file_path)
	if scene.scene_file_path == world_scene_path:
		_restore_after_load.call_deferred()

func _restore_after_load() -> void:
	if not return_pending:
		return
	var player: Node2D = null
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate is Node2D:
			player = candidate as Node2D
			break
	if player == null:
		push_warning("BattleReturnContext: на загруженной карте не найден узел группы player.")
		return_pending = false
		return
	player.global_position = player_position
	if "target_position" in player:
		player.set("target_position", player_position)
	if "last_direction" in player:
		player.set("last_direction", player_direction)
	if "moving" in player:
		player.set("moving", false)
	if "reserved_cell_valid" in player:
		player.set("reserved_cell_valid", false)
	if "can_move" in player:
		player.set("can_move", true)
	if player.has_method("play_idle_animation"):
		player.call("play_idle_animation")
	return_pending = false
	_has_context = false
	print("S7 RETURN: герой восстановлен в ", player_position, " / ", world_scene_path)
