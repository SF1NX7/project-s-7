@tool
extends Control

## Безопасная версия панели Project S-7.
## Не изменяет координаты, размеры рамок, отступы и расположение нод.
## Старые экспортные настройки геометрии сохранены для совместимости
## со значениями Inspector, но сейчас не применяются.

@export_group("Тестовые показатели")
@export_range(1, 9999, 1) var max_hp: int = 10:
	set(value):
		max_hp = maxi(value, 1)
		hp = mini(hp, max_hp)
		_update_when_ready()

@export_range(0, 9999, 1) var hp: int = 10:
	set(value):
		hp = clampi(value, 0, max_hp)
		_update_when_ready()

@export_range(0, 9999, 1) var max_mp: int = 8:
	set(value):
		max_mp = maxi(value, 0)
		mp = mini(mp, max_mp)
		_update_when_ready()

@export_range(0, 9999, 1) var mp: int = 8:
	set(value):
		mp = clampi(value, 0, max_mp)
		_update_when_ready()

@export_group("Размеры панели")
## После этого количества HP полоса больше не увеличивается.
@export_range(1, 9999, 1) var full_bar_at_hp: int = 100:
	set(value):
		full_bar_at_hp = maxi(value, 1)
		_update_when_ready()

@export_range(16, 512, 1) var min_bar_width: int = 56:
	set(value):
		min_bar_width = value
		_update_when_ready()

@export_range(16, 512, 1) var max_bar_width: int = 160:
	set(value):
		max_bar_width = value
		_update_when_ready()

@export_group("Размеры шкалы MP")
## После этого количества максимальной маны ширина MP больше не увеличивается.
@export_range(1, 9999, 1) var full_bar_at_mp: int = 100:
	set(value):
		full_bar_at_mp = maxi(value, 1)
		_update_when_ready()

## Минимальная длина полоски MP, даже при Max MP = 0.
@export_range(16, 512, 1) var min_mp_bar_width: int = 56:
	set(value):
		min_mp_bar_width = value
		_update_when_ready()

## Максимальная длина полоски MP.
@export_range(16, 512, 1) var max_mp_bar_width: int = 160:
	set(value):
		max_mp_bar_width = value
		_update_when_ready()

@export_group("Внутренние отступы")
## Расстояние от левого края фоновой рамки до портрета.
@export_range(0, 64, 1) var inset_x: int = 8:
	set(value):
		inset_x = value
		_update_when_ready()

## Расстояние от верхнего и нижнего края фоновой рамки до содержимого.
@export_range(0, 64, 1) var inset_y: int = 6:
	set(value):
		inset_y = value
		_update_when_ready()

@export_group("Размеры панели")

## Место для Title, числа Value, отступов и внутренних полей StatusFrame.
@export_range(0, 512, 1) var status_extra_width: int = 112:
	set(value):
		status_extra_width = value
		_update_when_ready()

@export_range(0, 64, 1) var portrait_gap: int = 8:
	set(value):
		portrait_gap = value
		_update_when_ready()

@export_range(20, 256, 1) var panel_height: int = 88:
	set(value):
		panel_height = value
		_update_when_ready()

# В обновлённой сцене MainRow находится внутри Panel.
# PortraitFrame может быть обычным Control или NinePatchRect.
@onready var background_panel: Control = get_node_or_null("Panel") as Control
@onready var main_row: HBoxContainer = get_node_or_null("Panel/MainRow") as HBoxContainer
@onready var portrait_frame: Control = get_node_or_null("Panel/MainRow/PortraitFrame") as Control
@onready var status_frame: Control = get_node_or_null("Panel/MainRow/StatusFrame") as Control
@onready var hp_bar: TextureProgressBar = get_node_or_null("Panel/MainRow/StatusFrame/HP/HPbar") as TextureProgressBar
@onready var mp_bar: TextureProgressBar = get_node_or_null("Panel/MainRow/StatusFrame/MP/MPbar") as TextureProgressBar
@onready var hp_number: Label = get_node_or_null("Panel/MainRow/StatusFrame/HP/Value") as Label
@onready var mp_number: Label = get_node_or_null("Panel/MainRow/StatusFrame/MP/Value") as Label


func _ready() -> void:
	_refresh()


func _update_when_ready() -> void:
	if is_node_ready():
		_refresh()


## Для будущего подключения к BattleCombat без изменения логики панели.
func set_stats(new_hp: int, new_max_hp: int, new_mp: int, new_max_mp: int) -> void:
	max_hp = maxi(new_max_hp, 1)
	hp = clampi(new_hp, 0, max_hp)
	max_mp = maxi(new_max_mp, 0)
	mp = clampi(new_mp, 0, max_mp)
	_update_when_ready()


func _refresh() -> void:
	# Только данные: расположением портрета, фона, текстов и строк
	# управляет сцена. HBoxContainer сам размещает дочерние узлы.
	if hp_bar == null or mp_bar == null or hp_number == null or mp_number == null:
		push_warning("FightStatusPanel: не найдены HPbar, MPbar или Value. Проверьте пути в сцене.")
		return

	var hp_ratio: float = clampf(float(max_hp) / float(maxi(full_bar_at_hp, 1)), 0.0, 1.0)
	var mp_ratio: float = clampf(float(max_mp) / float(maxi(full_bar_at_mp, 1)), 0.0, 1.0)
	var hp_width: float = roundf(lerpf(float(min_bar_width), float(max_bar_width), hp_ratio))
	var mp_width: float = roundf(lerpf(float(min_mp_bar_width), float(max_mp_bar_width), mp_ratio))

	# Не меняем положение и размеры MainRow, PortraitFrame,
	# StatusFrame, Panel и корня — это раньше сдвигало всю сцену.
	hp_bar.custom_minimum_size.x = hp_width
	mp_bar.custom_minimum_size.x = mp_width

	hp_bar.min_value = 0.0
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(hp)
	mp_bar.min_value = 0.0
	mp_bar.max_value = float(maxi(max_mp, 1))
	mp_bar.value = float(mp)

	hp_number.text = "%d/%d" % [hp, max_hp]
	mp_number.text = "%d/%d" % [mp, max_mp]
