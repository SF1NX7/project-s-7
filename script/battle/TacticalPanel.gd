@tool
extends Control

## Project S-7. Левая часть панели и подписи закреплены.
## Изменяется только длина шкал и ПРАВЫЙ край фона.

@export_group("Персонаж")
@export var character_name: String = "Max":
	set(v):
		character_name = v
		_refresh_if_ready()

@export_range(1, 999, 1) var character_level: int = 53:
	set(v):
		character_level = maxi(1, v)
		_refresh_if_ready()

@export_group("HP и MP")
@export_range(1, 9999, 1) var max_hp: int = 10:
	set(v):
		max_hp = maxi(1, v)
		hp = mini(hp, max_hp)
		_refresh_if_ready()

@export_range(0, 9999, 1) var hp: int = 10:
	set(v):
		hp = clampi(v, 0, max_hp)
		_refresh_if_ready()

@export_range(0, 9999, 1) var max_mp: int = 9:
	set(v):
		max_mp = maxi(0, v)
		mp = mini(mp, max_mp)
		_refresh_if_ready()

@export_range(0, 9999, 1) var mp: int = 9:
	set(v):
		mp = clampi(v, 0, max_mp)
		_refresh_if_ready()

@export_group("Длина шкалы HP")
## Максимальное HP, после которого физическая длина шкалы не растёт.
@export_range(1, 9999, 1) var full_bar_at_hp: int = 100:
	set(v):
		full_bar_at_hp = maxi(1, v)
		_refresh_if_ready()

@export_range(12, 512, 1) var min_hp_width: int = 32:
	set(v):
		min_hp_width = maxi(12, v)
		_refresh_if_ready()

@export_range(12, 512, 1) var max_hp_width: int = 160:
	set(v):
		max_hp_width = maxi(12, v)
		_refresh_if_ready()

@export_group("Цветные слои HP")
## Если включено, каждые HP Per Layer единиц образуют отдельный цветной слой.
## Внешняя ширина шкалы по-прежнему зависит от Max HP и Full Bar At HP.
## Оттенок незаполненной части первого слоя HP.
## Рамка Texture Over при этом не изменяется.
@export var hp_empty_color: Color = Color("#10263b"):
	set(v):
		hp_empty_color = v
		_refresh_if_ready()

@export var hp_layers_enabled: bool = true:
	set(v):
		hp_layers_enabled = v
		_refresh_if_ready()

## Количество здоровья в одном слое. Например, 100: красный 1–100, золотой 101–200, синий 201–300.
@export_range(1, 9999, 1) var hp_per_layer: int = 100:
	set(v):
		hp_per_layer = maxi(1, v)
		_refresh_if_ready()

## Последовательность цветов: базовый слой, второй, третий и т. д.
## Список можно расширять в Inspector. Если слоёв больше цветов, цвета повторяются.
@export var hp_layer_colors: Array[Color] = [
	Color("#d90000"),
	Color("#d3a33d"),
	Color("#317de3"),
	Color("#a364db"),
	Color("#39b77b")
]:
	set(v):
		hp_layer_colors = v
		_refresh_if_ready()

@export_group("Длина шкалы MP")
## Максимальное MP, после которого физическая длина шкалы не растёт.
@export_range(1, 9999, 1) var full_bar_at_mp: int = 100:
	set(v):
		full_bar_at_mp = maxi(1, v)
		_refresh_if_ready()

@export_range(12, 512, 1) var min_mp_width: int = 24:
	set(v):
		min_mp_width = maxi(12, v)
		_refresh_if_ready()

@export_range(12, 512, 1) var max_mp_width: int = 160:
	set(v):
		max_mp_width = maxi(12, v)
		_refresh_if_ready()

@export_group("Оформление")
## Свободное место между цифрами и правой границей рамки.
@export_range(2, 64, 1) var right_padding: int = 12:
	set(v):
		right_padding = maxi(2, v)
		_refresh_if_ready()

## Минимальная ширина окна: портрет и надписи никогда не сжимаются.
@export_range(180, 800, 1) var min_panel_width: int = 235:
	set(v):
		min_panel_width = maxi(180, v)
		_refresh_if_ready()

# Имена и пути совместимы с FightStatusPanel.tscn.
@onready var panel: Panel = get_node_or_null("Panel") as Panel
@onready var status_frame: Control = get_node_or_null("Panel/MainRow/StatusFrame") as Control
@onready var name_label: Label = get_node_or_null("Panel/MainRow/StatusFrame/Name") as Label
@onready var level_label: Label = get_node_or_null("Panel/MainRow/StatusFrame/Level") as Label
@onready var hp_row: HBoxContainer = get_node_or_null("Panel/MainRow/StatusFrame/HP") as HBoxContainer
@onready var mp_row: HBoxContainer = get_node_or_null("Panel/MainRow/StatusFrame/MP") as HBoxContainer
@onready var hp_title: Label = get_node_or_null("Panel/MainRow/StatusFrame/HP/Title") as Label
@onready var mp_title: Label = get_node_or_null("Panel/MainRow/StatusFrame/MP/Title") as Label
@onready var hp_bar: TextureProgressBar = get_node_or_null("Panel/MainRow/StatusFrame/HP/HPbar") as TextureProgressBar
@onready var mp_bar: TextureProgressBar = get_node_or_null("Panel/MainRow/StatusFrame/MP/MPbar") as TextureProgressBar
@onready var hp_number: Label = get_node_or_null("Panel/MainRow/StatusFrame/HP/Value") as Label
@onready var mp_number: Label = get_node_or_null("Panel/MainRow/StatusFrame/MP/Value") as Label


# Оригинальные ресурсы и оттенки сохранены, чтобы можно было выключить
# многослойность, не теряя сделанную вручную рамку/заливку.
var _hp_original_under: Texture2D
var _hp_original_progress: Texture2D
var _hp_original_under_tint: Color = Color.WHITE
var _hp_original_progress_tint: Color = Color.WHITE
var _hp_white_fill: GradientTexture2D


func _ready() -> void:
	if hp_bar != null:
		_hp_original_under = hp_bar.texture_under
		_hp_original_progress = hp_bar.texture_progress
		_hp_original_under_tint = hp_bar.tint_under
		_hp_original_progress_tint = hp_bar.tint_progress
		_hp_white_fill = _build_white_fill()
	_refresh()


## Белая однотонная текстура позволяет получить любой цвет слоя через tint_progress.
## Декоративная рамка texture_over НЕ меняется.
func _build_white_fill() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.WHITE)
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.width = 128
	fill.height = 12
	return fill


func _hp_color(layer_index: int) -> Color:
	if hp_layer_colors.is_empty():
		return Color("#d90000")
	return hp_layer_colors[layer_index % hp_layer_colors.size()]


func _update_hp_visual() -> void:
	if hp_bar == null:
		return

	# Без цветных слоёв используем исходную шкалу из Inspector.
	if not hp_layers_enabled:
		hp_bar.texture_under = _hp_original_under
		hp_bar.texture_progress = _hp_original_progress
		hp_bar.tint_under = _hp_original_under_tint
		hp_bar.tint_progress = _hp_original_progress_tint
		hp_bar.min_value = 0.0
		hp_bar.max_value = float(maxi(max_hp, 1))
		hp_bar.value = float(hp)
		return

	# Белая текстура гарантирует отображение первого (красного)
	# слоя даже при Max HP > 100. Не восстанавливаем здесь старый
	# texture_progress, который может быть пустым или переопределённым.
	if _hp_white_fill == null:
		_hp_white_fill = _build_white_fill()

	var layer_size: int = maxi(1, hp_per_layer)
	var current_layer: int = maxi(0, ceili(float(hp) / float(layer_size)) - 1)
	var visible_in_layer: int = 0
	if hp > 0:
		visible_in_layer = hp - current_layer * layer_size

	hp_bar.min_value = 0.0
	# Если весь запас HP помещается в первый слой, полная жизнь
	# должна заполнять 100% шкалы: 50/50, 70/70, 100/100.
	# Для многоcлойных персонажей сохраняем прежний шаг в 100 HP.
	var visible_capacity: int = mini(max_hp, layer_size)
	hp_bar.max_value = float(maxi(visible_capacity, 1))
	hp_bar.value = float(visible_in_layer)
	hp_bar.texture_progress = _hp_white_fill
	hp_bar.tint_progress = _hp_color(current_layer)

	if current_layer == 0:
		# На первом слое фон должен быть ТЁМНЫМ, а не красным.
		# В исходной сцене texture_under уже окрашен в красный:
		# иначе 6/8 визуально выглядит как полная красная шкала.
		# Белая текстура и отдельный оттенок дают видимый остаток.
		hp_bar.texture_under = _hp_white_fill
		hp_bar.tint_under = hp_empty_color
	else:
		# У предыдущего слоя всегда полное заполнение. Следующий
		# цвет расходуется поверх него. Over-рамка не меняется.
		hp_bar.texture_under = _hp_white_fill
		hp_bar.tint_under = _hp_color(current_layer - 1)


func _refresh_if_ready() -> void:
	if is_node_ready():
		_refresh()


## Интерфейс для будущего подключения к рассчитанным событиям FightScene.
func set_stats(new_hp: int, new_max_hp: int, new_mp: int, new_max_mp: int) -> void:
	max_hp = maxi(1, new_max_hp)
	hp = clampi(new_hp, 0, max_hp)
	max_mp = maxi(0, new_max_mp)
	mp = clampi(new_mp, 0, max_mp)
	_refresh_if_ready()


func _bar_width(max_stat: int, width_at: int, minimum_width: int, maximum_width: int) -> float:
	var amount: float = clampf(float(max_stat) / float(maxi(width_at, 1)), 0.0, 1.0)
	return roundf(lerpf(float(minimum_width), float(maxi(minimum_width, maximum_width)), amount))


func _refresh() -> void:
	if not is_node_ready():
		return
	if panel == null or status_frame == null or hp_row == null or mp_row == null:
		push_warning("FightStatusPanel: не найдена основная нода или строки HP/MP.")
		return
	if name_label == null or level_label == null or hp_bar == null or mp_bar == null or hp_number == null or mp_number == null or hp_title == null or mp_title == null:
		push_warning("FightStatusPanel: не найдены некоторые подписи или полоски.")
		return

	name_label.text = character_name
	level_label.text = "Lv %d" % character_level
	hp_number.text = "%d/%d" % [hp, max_hp]
	mp_number.text = "%d/%d" % [mp, max_mp]

	var hp_width: float = _bar_width(max_hp, full_bar_at_hp, min_hp_width, max_hp_width)
	var mp_width: float = _bar_width(max_mp, full_bar_at_mp, min_mp_width, max_mp_width)

	# Только размеры полосок. Никаких переносов портрета, подписей и строк.
	hp_bar.custom_minimum_size.x = hp_width
	mp_bar.custom_minimum_size.x = mp_width
	_update_hp_visual()
	mp_bar.min_value = 0.0
	mp_bar.max_value = float(maxi(max_mp, 1))
	mp_bar.value = float(mp)

	# HBoxContainer располагает Title / Bar / Value.
	# У самих строк фиксированы левый и верхний края.
	var hp_need: float = hp_title.get_combined_minimum_size().x + hp_width + hp_number.get_combined_minimum_size().x + 2.0 * float(hp_row.get_theme_constant("separation"))
	var mp_need: float = mp_title.get_combined_minimum_size().x + mp_width + mp_number.get_combined_minimum_size().x + 2.0 * float(mp_row.get_theme_constant("separation"))
	hp_row.size.x = hp_need
	mp_row.size.x = mp_need

	var header_end: float = maxf(
		name_label.position.x + name_label.get_combined_minimum_size().x,
		level_label.position.x + level_label.get_combined_minimum_size().x
	)
	var status_end: float = maxf(header_end, maxf(hp_row.position.x + hp_need, mp_row.position.x + mp_need))
	var needed_width: float = ceilf(maxf(float(min_panel_width), status_frame.position.x + status_end + float(right_padding)))

	# КРИТИЧЕСКОЕ ПРАВИЛО: левый край и позиции неизменны.
	# Изменяется только правый край фона.
	size.x = needed_width
	panel.size.x = needed_width
	status_frame.size.x = maxf(0.0, needed_width - status_frame.position.x)
