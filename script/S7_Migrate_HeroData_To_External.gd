@tool
extends EditorScript

## Однократный перенос встроенных HeroData из PartyData в отдельные .tres.
## Перед запуском сохраните изменения в Godot и остановите игру.
const PARTY_PATH: String = "res://data/items/party_data.tres"
const HERO_DIR: String = "res://data/heroes"
const BACKUP_SUFFIX: String = ".s7_before_external_heroes.bak"

func _run() -> void:
	var party: PartyData = ResourceLoader.load(
		PARTY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as PartyData
	if party == null:
		push_error("S7: Не удалось загрузить PartyData: " + PARTY_PATH)
		return
	if party.heroes.is_empty():
		push_error("S7: Отряд пуст. Перенос отменён.")
		return

	var external_count: int = 0
	for hero in party.heroes:
		if hero == null:
			push_error("S7: В отряде найден пустой HeroData. Перенос отменён.")
			return
		if hero.resource_path.begins_with("res://") and not hero.resource_path.contains("::"):
			external_count += 1

	if external_count == party.heroes.size():
		print("S7: Все герои уже имеют отдельные ресурсы. Ничего менять не нужно.")
		return
	if external_count > 0:
		push_error("S7: В PartyData смешаны встроенные и внешние герои. "
			+ "Автоматический перенос отменён, чтобы не затереть существующие файлы.")
		return

	var absolute_hero_dir: String = ProjectSettings.globalize_path(HERO_DIR)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_hero_dir)
	if dir_error != OK:
		push_error("S7: Не удалось создать папку: " + HERO_DIR)
		return

	var destinations: Array[String] = []
	for i in range(party.heroes.size()):
		var hero: HeroData = party.heroes[i]
		var safe_name: String = ""
		for ch in hero.hero_name.to_lower():
			if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
				safe_name += ch
			elif ch == " " or ch == "_":
				safe_name += "_"
		if safe_name.is_empty():
			safe_name = "character"
		var dest: String = "%s/hero_%02d_%s.tres" % [HERO_DIR, i + 1, safe_name]
		if FileAccess.file_exists(dest):
			push_error("S7: Файл уже существует: " + dest + ". Перенос отменён.")
			return
		destinations.append(dest)

	var absolute_party: String = ProjectSettings.globalize_path(PARTY_PATH)
	var absolute_backup: String = absolute_party + BACKUP_SUFFIX
	if FileAccess.file_exists(absolute_backup):
		push_error("S7: Резервная копия уже существует: "
			+ absolute_backup + ". Перенос отменён.")
		return
	var backup_error: Error = DirAccess.copy_absolute(absolute_party, absolute_backup)
	if backup_error != OK:
		push_error("S7: Не удалось создать резервную копию PartyData.")
		return

	var external_heroes: Array[HeroData] = []
	for i in range(party.heroes.size()):
		var original: HeroData = party.heroes[i]
		# Копируем только верхний ресурс; ссылки на портреты,
		# дерево магии и вложенные характеристики сохраняются.
		var copy: HeroData = original.duplicate(false) as HeroData
		if copy == null:
			push_error("S7: Не удалось скопировать HeroData: " + original.hero_name)
			return
		var save_error: Error = ResourceSaver.save(
			copy, destinations[i], ResourceSaver.FLAG_CHANGE_PATH
		)
		if save_error != OK:
			push_error("S7: Ошибка сохранения " + destinations[i]
				+ ". Исходный PartyData не изменён, резервная копия сохранена.")
			return
		external_heroes.append(copy)
		print("S7: Создан ", destinations[i],
			" | MOV=", copy.base_movement, " + ", copy.movement_modifier)

	party.heroes = external_heroes
	var party_error: Error = ResourceSaver.save(party, PARTY_PATH)
	if party_error != OK:
		push_error("S7: Не удалось обновить PartyData. "
			+ "Восстановите его из .bak-файла.")
		return

	print("S7: ГОТОВО. В PartyData теперь ссылки на внешние HeroData.")
	print("S7: Резервная копия: ", absolute_backup)
	print("S7: Закройте и заново откройте Godot, затем редактируйте MOV "
		+ "в отдельных файлах res://data/heroes/ и сохраняйте изменения.")
