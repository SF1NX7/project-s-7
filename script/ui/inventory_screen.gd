extends Control
class_name InventoryScreen

signal closed

@export var slot_scene: PackedScene
@export var starting_items: Array[ItemData] = []
@onready var grid: GridContainer = $Root/InnerMargin/Content/left/Scroll/Grid
@onready var preview_icon: TextureRect = $Root/InnerMargin/Content/Right/PreviewPanel/PreviewIcon
@onready var title_label: Label = $Root/InnerMargin/Content/Right/DescPanel/TitleLabel
@onready var desc_label: RichTextLabel = $Root/InnerMargin/Content/Right/DescPanel/DescLabel
@onready var btn_use: Button = $Root/InnerMargin/Content/left/Action/BtnUse
@onready var btn_drop: Button = $Root/InnerMargin/Content/left/Action/BtnDrop
@export var default_item_count := 32  # для теста, потом заменишь на реальный items.size()
@onready var scroll: ScrollContainer = $Root/InnerMargin/Content/left/Scroll
var _slot_count := 0

const COLS := 8
const ROWS := 4
const MIN_SLOTS := COLS * ROWS

var slots: Array[InventorySlot] = []

var selected_slot: int = -1

enum UiMode { GRID, ACTION }
var _mode: UiMode = UiMode.GRID
var _action_index: int = 0 # 0 = Use, 1 = Drop

func _ready() -> void:
	visible = false

	btn_use.pressed.connect(_on_use_pressed)
	btn_drop.pressed.connect(_on_drop_pressed)

	btn_use.disabled = true
	btn_drop.disabled = true

func _build_slots(count: int) -> void:
	# Создаём слоты один раз до нужного количества
	while slots.size() < count:
		var s := slot_scene.instantiate() as InventorySlot
		grid.add_child(s)
		slots.append(s)
		_slot_count = count

	# Если слотов больше, чем нужно — скрываем лишние (если потом будет скролл)
	for i in range(slots.size()):
		slots[i].visible = (i < count)

func open(item_count: int = -1) -> void:
	visible = true
	_mode = UiMode.GRID

	var count := item_count
	if count < 0:
		count = default_item_count  # у тебя в инспекторе 32

	_build_slots(count)

	# Разложить иконки по слотам из starting_items (Inspector)
	for i in range(_slot_count):
		var item: ItemData = starting_items[i] if i < starting_items.size() else null
		slots[i].set_icon(item.icon if item != null else null)

	_select_slot(0)

func close() -> void:
	visible = false
	selected_slot = -1
	emit_signal("closed")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Закрыть инвентарь по Esc или Tab
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		if _mode == UiMode.ACTION:
			_exit_action_mode()
		else:
			close()
		get_viewport().set_input_as_handled()
		return

	# ---------- ACTION MODE ----------
	if _mode == UiMode.ACTION:
		if event.is_action_pressed("move_up"):
			_set_action_selected(0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_down"):
			_set_action_selected(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("action"):
			# позже сюда поставим реальное действие
			if _action_index == 0:
				print("USE on slot:", selected_slot)
			else:
				print("DROP on slot:", selected_slot)

			# пока просто возвращаемся в сетку после нажатия
			_exit_action_mode()
			get_viewport().set_input_as_handled()
		return

	# ---------- GRID MODE ----------
	if _slot_count <= 0:
		return

	var cols: int = max(grid.columns, 1)
	var idx: int = selected_slot
	if idx < 0:
		idx = 0

	var row: int = idx / cols
	var col: int = idx % cols
	var moved: bool = false

	if event.is_action_pressed("move_left"):
		if col > 0:
			idx -= 1
			moved = true

	elif event.is_action_pressed("move_right"):
		if col < cols - 1 and idx + 1 < _slot_count:
			idx += 1
			moved = true

	elif event.is_action_pressed("move_up"):
		if row > 0:
			idx -= cols
			moved = true

	elif event.is_action_pressed("move_down"):
		if idx + cols < _slot_count:
			idx += cols
			moved = true

	if moved:
		_select_slot(idx)
		get_viewport().set_input_as_handled()
		return

	# Нажали E в сетке -> если в слоте есть предмет, прыгаем в ACTION
	if event.is_action_pressed("action"):
		var item = starting_items[selected_slot] if selected_slot < starting_items.size() else null
		if item != null:
			_enter_action_mode()
			get_viewport().set_input_as_handled()

func _spawn_test_slots(count: int) -> void:
	for c in grid.get_children():
		c.queue_free()

	for i in range(count):
		var slot: Control = slot_scene.instantiate()
		grid.add_child(slot)
		slot.name = "Slot_%02d" % i

		# Если слот — Button, подключаем нажатие
		if slot is Button:
			(slot as Button).pressed.connect(func(): _select_slot(i))

func _select_slot(i: int) -> void:
	var total := _slot_count
	if total <= 0:
		selected_slot = -1
		preview_icon.texture = null
		desc_label.text = "[b]%s[/b]\n%s"
		btn_use.disabled = true
		btn_drop.disabled = true
		return

	selected_slot = clamp(i, 0, total - 1)

	# Подсветка
	for j in range(slots.size()):
		slots[j].set_selected(j == selected_slot and slots[j].visible)

	# Превью справа: если слот пустой — превью пустое
	var item: ItemData = starting_items[selected_slot] if selected_slot < starting_items.size() else null
	preview_icon.texture = item.preview if item != null else null

	if item != null:
		title_label.text = item.title
		desc_label.text = item.description
	else:
		title_label.text = ""
		desc_label.text = ""

	# (опционально) текст справа
	# desc_label.text = item.description if item != null else ""

	# Автоскролл к выбранному слоту
	scroll.ensure_control_visible(slots[selected_slot])

	btn_use.disabled = false
	btn_drop.disabled = false

func _on_use_pressed() -> void:
	if selected_slot < 0:
		return
	print("USE slot:", selected_slot)

func _on_drop_pressed() -> void:
	if selected_slot < 0:
		return
	print("DROP slot:", selected_slot)
	
func _set_action_selected(idx: int) -> void:
	_action_index = clamp(idx, 0, 1)

	# подсветка простая через self_modulate
	btn_use.self_modulate = Color(1, 1, 1, 1) if _action_index == 0 else Color(0.5, 0.5, 0.5, 1)
	btn_drop.self_modulate = Color(1, 1, 1, 1) if _action_index == 1 else Color(0.5, 0.5, 0.5, 1)

func _enter_action_mode() -> void:
	_mode = UiMode.ACTION
	_set_action_selected(0)

func _exit_action_mode() -> void:
	_mode = UiMode.GRID
	# вернуть кнопки в обычный вид
	btn_use.self_modulate = Color(1, 1, 1, 1)
	btn_drop.self_modulate = Color(1, 1, 1, 1)
