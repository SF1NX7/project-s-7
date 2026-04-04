extends Control
class_name InventoryScreen

signal closed

@export var slot_scene: PackedScene
@onready var grid: GridContainer = $Root/Content/left/Scroll/Grid
@onready var preview_icon: TextureRect = $Root/Content/Right/PreviewPanel/PreviewIcon
@onready var desc_label: RichTextLabel = $Root/Content/Right/DescPanel/DescLabel
@onready var btn_use: Button = $Root/Content/left/Action/BtnUse
@onready var btn_drop: Button = $Root/Content/left/Action/BtnDrop
@export var default_item_count := 32  # для теста, потом заменишь на реальный items.size()
@onready var scroll: ScrollContainer = $Root/Content/left/Scroll
var _slot_count := 0

const COLS := 8
const ROWS := 4
const MIN_SLOTS := COLS * ROWS

var slots: Array[InventorySlot] = []

var selected_slot: int = -1

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

	var count := item_count
	if count < 0:
		count = default_item_count

	_build_slots(count)
	_select_slot(clamp(selected_slot if selected_slot >= 0 else 0, 0, count - 1))

func close() -> void:
	visible = false
	selected_slot = -1
	emit_signal("closed")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Закрыть инвентарь по Esc или Tab (menu)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()
		return

	# Если слотов нет — нечего выбирать
	if _slot_count <= 0:
		return

	var cols: int = max(grid.columns, 1)  # у тебя сейчас 8
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

	# Закрыть инвентарь по Esc или Tab (menu)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()
		return

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
		# ... как у тебя ...
		return

	selected_slot = clamp(i, 0, total - 1)

	for j in range(slots.size()):
		slots[j].set_selected(j == selected_slot and slots[j].visible)

	scroll.ensure_control_visible(slots[selected_slot])

	# Пока тест: просто показываем текст. Иконку подключим когда появятся ItemData.
	desc_label.text = "[b]Selected Slot:[/b] %d\n\nОписание появится после ItemData." % selected_slot
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
