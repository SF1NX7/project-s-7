extends Control
class_name InventoryScreen

signal closed

@export var slot_scene: PackedScene

@onready var grid: GridContainer = $Root/Content/left/Scroll/Grid
@onready var preview_icon: TextureRect = $Root/Content/Right/PreviewPanel/PreviewIcon
@onready var desc_label: RichTextLabel = $Root/Content/Right/DescPanel/DescLabel
@onready var btn_use: Button = $Root/Content/left/Action/BtnUse
@onready var btn_drop: Button = $Root/Content/left/Action/BtnDrop

var selected_slot: int = -1

func _ready() -> void:
	visible = false

	btn_use.pressed.connect(_on_use_pressed)
	btn_drop.pressed.connect(_on_drop_pressed)

	btn_use.disabled = true
	btn_drop.disabled = true

func open() -> void:
	visible = true
	_spawn_test_slots(20) # 5x4 тест, позже заменим на реальные предметы
	_select_slot(0)

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
	var total := grid.get_child_count()
	if total <= 0:
		selected_slot = -1
		preview_icon.texture = null
		desc_label.text = ""
		btn_use.disabled = true
		btn_drop.disabled = true
		return

	selected_slot = clamp(i, 0, total - 1)

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
