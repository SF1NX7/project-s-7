extends Control
## Standalone F6 test scene. No combat or save-manager calls.
const Visual = preload("res://script/battle/magic_spell_visual.gd")
const Fight = preload("res://scene/battle/FightScene.tscn")

var _caster: Resource
var _target: Resource
var _spell: SpellData
var _paths: Dictionary = {}
var _catalog_indices: Dictionary = {}
var _catalog_popup: PopupMenu
var _pending_catalog: Resource
var _pending_path: String = ""
var _pending_role: String = ""
var _controls: Dictionary = {}
var _sliders: Dictionary = {}
var _view: SubViewport
var _fight: Node2D
var _hero: AnimatedSprite2D
var _enemy: AnimatedSprite2D
var _markers: Node2D
var _visual
var _status: Label
var _fields: VBoxContainer
var _dialog: FileDialog
var _selecting: String = ""
var _syncing: bool = false
var _playing: bool = false
var _drag: String = ""
var _show_points: bool = true
var _show_path: bool = true
var _loop: bool = false
var _preview_hold: float = 1.5

func _ready() -> void:
	var root := HBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	_view = SubViewport.new()
	_view.size = Vector2i(640, 360)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_view)
	# A TextureRect displays the viewport scaled to fit without changing combat coordinates.
	var preview := TextureRect.new()
	preview.texture = _view.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_STOP
	left.add_child(preview)
	preview.gui_input.connect(_preview_input.bind(preview))
	# Keep the playback action directly below the scene viewport.
	var play_button := Button.new()
	play_button.text = "▶  Play Preview"
	play_button.tooltip_text = "Play the currently selected spell effect"
	play_button.custom_minimum_size.y = 32.0
	play_button.add_theme_font_size_override("font_size", 13)
	play_button.pressed.connect(_play)
	left.add_child(play_button)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Select caster, target and spell resources."
	left.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 370
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_fields = VBoxContainer.new()
	_fields.add_theme_constant_override("separation", 3)
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fields)
	for key: String in ["Caster", "Target", "Spell"]:
		var b := _button("Select " + key, _pick.bind(key))
		_controls[key] = b
	_button("Save Settings (.tres)", _save)
	_button("Move shared points into selected spell (once)", _migrate_shared_points)
	_toggle("Loop Preview", false, func(v: bool): _loop = v)
	_toggle("Show Attachment Points", true, _toggle_points)
	_toggle("Show Trajectory", true, _toggle_path)
	_section("Spell-specific trajectory (each .tres separately)")
	_section("Spell identity and battle values")
	_text_input("ID", "id")
	_text_input("Title", "title")
	_text_input("Description", "description")
	_texture_button("Icon", "icon")
	_dropdown("Element", "element", ["None", "Fire", "Ice", "Lightning", "Earth", "Wind", "Water", "Light", "Dark"])
	_dropdown("Effect Type", "effect_type", ["Damage", "Heal", "Buff", "Debuff", "Revive", "Utility"])
	_number("MP Cost", "mp_cost", 0, 999, 1)
	_number("Damage Min", "damage_min", 0, 9999, 1)
	_number("Damage Max", "damage_max", 0, 9999, 1)
	_number("Heal Min", "heal_min", 0, 9999, 1)
	_number("Heal Max", "heal_max", 0, 9999, 1)
	_number("Accuracy", "accuracy", 0, 100, 1)
	_number("Range Tiles", "range_tiles", 0, 50, 1)
	_number("Area Radius", "area_radius", 0, 30, 1)
	_section("Projectile / trajectory")
	_dropdown("Visual Mode", "visual_mode", ["Projectile", "Target Effect", "Falling", "Full Screen"])
	_texture_button("Projectile Sheet", "projectile_sheet")
	_number("Projectile Frames", "projectile_frames", 1, 64, 1)
	_number("Projectile FPS", "projectile_fps", 1, 60, 0.5)
	_number("Projectile Speed", "projectile_speed", 20, 1500, 10)
	_number("Projectile Scale", "projectile_scale", 0.1, 8, 0.1)
	_number("Projectile Rotation (deg)", "projectile_rotation_degrees", -360, 360, 1)
	_spell_toggle("Rotate Along Path", "rotate_along_path")
	_number("Spell Cast Offset X", "scx", -500, 500, 1)
	_number("Spell Cast Offset Y", "scy", -500, 500, 1)
	_number("Spell Impact Offset X", "six", -500, 500, 1)
	_number("Spell Impact Offset Y", "siy", -500, 500, 1)
	_number("Arc Height", "arc_height", 0, 150, 1)
	_number("Wave Amplitude", "wave_amplitude", 0, 150, 1)
	_number("Wave Count", "wave_count", 0, 8, 0.5)
	_section("Impact / transitions")
	_texture_button("Impact Sheet", "impact_sheet")
	_number("Impact Frames", "impact_frames", 1, 64, 1)
	_number("Impact FPS", "impact_fps", 1, 60, 0.5)
	_number("Impact Scale", "impact_scale", 0.1, 8, 0.1)
	_number("Screen Darkness", "screen_darkness", 0, 0.9, 0.05)
	_number("Darken Duration", "darken_duration", 0.05, 2, 0.05)
	_number("Target Slide Duration", "target_slide_duration", 0.05, 2, 0.05)
	_section("Lingering Effects / persistent ground fire")
	_spell_toggle("Has Lingering Effect", "has_lingering_effect")
	_texture_button("Lingering Sheet", "lingering_sheet")
	_number("Lingering Frames", "lingering_frames", 1, 64, 1)
	_number("Lingering FPS", "lingering_fps", 1, 60, 0.5)
	_number("Lingering Offset X", "lingering_x", -500, 500, 1)
	_number("Lingering Offset Y", "lingering_y", -500, 500, 1)
	_number("Lingering Scale", "lingering_scale", 0.1, 8, 0.1)
	_number("Lingering Start Delay", "lingering_start_delay", 0, 2, 0.05)
	_spell_toggle("Play Main Effect Once", "play_main_effect_once")
	_spell_toggle("Keep Between Targets", "keep_effect_between_targets")
	_number("Preview Fire Hold", "preview_hold", 0.1, 10, 0.1)
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_RESOURCES
	_dialog.filters = PackedStringArray(["*.tres ; Godot resource"])
	add_child(_dialog)
	_dialog.file_selected.connect(_selected)
	_catalog_popup = PopupMenu.new()
	add_child(_catalog_popup)
	_catalog_popup.id_pressed.connect(_catalog_chosen)
	_fight = Fight.instantiate() as Node2D
	_fight.set_script(null)
	var hud := _fight.get_node_or_null("HUD")
	if hud != null:
		_fight.remove_child(hud)
		hud.free()
	_view.add_child(_fight)
	_hero = _fight.get_node("HeroAnchor/HeroVisual/Body") as AnimatedSprite2D
	_enemy = _fight.get_node("EnemyAnchor/EnemyVisual/Body") as AnimatedSprite2D
	_idle(_hero)
	_idle(_enemy)
	_markers = Node2D.new()
	_markers.z_index = 101
	_fight.add_child(_markers)
	_markers.draw.connect(_draw_markers)
	_spell = SpellData.new()
	_sync()

func _button(label_text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	_fields.add_child(button)
	return button

func _section(title_text: String) -> void:
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.85, 0.79, 0.49))
	_fields.add_child(heading)
	var separator := HSeparator.new()
	_fields.add_child(separator)

func _spell_toggle(label_text: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.add_theme_font_size_override("font_size", 12)
	toggle.toggled.connect(_bool_changed.bind(key))
	_fields.add_child(toggle)
	_controls[key] = toggle

func _bool_changed(value: bool, key: String) -> void:
	if _syncing or _playing: return
	_spell.set(key, value)
	_markers.queue_redraw()

func _dropdown(label_text: String, key: String, values: Array[String]) -> void:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", 12)
	for value in values:
		option.add_item(value)
	option.item_selected.connect(_dropdown_changed.bind(key))
	row.add_child(option)
	_controls[key] = option

func _dropdown_changed(index: int, key: String) -> void:
	if _syncing or _playing: return
	_spell.set(key, index)
	_markers.queue_redraw()

func _texture_button(label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	var button := Button.new()
	button.text = "Select PNG"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(_pick_texture.bind(key))
	row.add_child(button)
	_controls[key] = button

func _pick_texture(key: String) -> void:
	if _playing: return
	_selecting = "Texture:" + key
	_dialog.filters = PackedStringArray(["*.png, *.webp, *.jpg ; Image"])
	_dialog.current_dir = "res://"
	_dialog.popup_centered_ratio(0.9)

func _text_input(label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	_fields.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	edit.text_changed.connect(_text_changed.bind(key))
	row.add_child(edit)
	_controls[key] = edit

func _text_changed(value: String, key: String) -> void:
	if _syncing or _playing: return
	_spell.set(key, value)

func _toggle(label_text: String, initial: bool, action: Callable) -> void:
	var check := CheckButton.new()
	check.text = label_text
	check.add_theme_font_size_override("font_size", 12)
	check.button_pressed = initial
	check.toggled.connect(action)
	_fields.add_child(check)

func _number(label_text: String, key: String, low: float, high: float, step_size: float) -> void:
	# Compact single-row control: short label, draggable slider, exact value.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_fields.add_child(row)
	var label := Label.new()
	label.text = _short_label(label_text)
	label.tooltip_text = label_text
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step_size
	slider.custom_minimum_size.x = 92
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = label_text
	row.add_child(slider)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step_size
	spin.custom_minimum_size.x = 82
	spin.size_flags_horizontal = Control.SIZE_SHRINK_END
	spin.add_theme_font_size_override("font_size", 12)
	spin.tooltip_text = label_text
	row.add_child(spin)
	_controls[key] = spin
	_sliders[key] = slider
	slider.value_changed.connect(_slider_changed.bind(key))
	spin.value_changed.connect(_changed.bind(key))

func _short_label(label_text: String) -> String:
	match label_text:
		"Cast Point X": return "Cast X"
		"Cast Point Y": return "Cast Y"
		"Impact Point X": return "Hit X"
		"Impact Point Y": return "Hit Y"
		"Spell Cast Offset X": return "Cast Offset X"
		"Spell Cast Offset Y": return "Cast Offset Y"
		"Spell Impact Offset X": return "Hit Offset X"
		"Spell Impact Offset Y": return "Hit Offset Y"
		"Arc Height": return "Arc"
		"Wave Amplitude": return "Wave Size"
		"Wave Count": return "Waves"
		"Projectile Speed": return "Speed"
		"Projectile Scale": return "Size"
		"Projectile Rotation (deg)": return "Rotation °"
		"Impact Scale": return "Impact Size"
		"Lingering Offset X": return "Fire Offset X"
		"Lingering Offset Y": return "Fire Offset Y"
		"Lingering Scale": return "Fire Size"
		"Screen Darkness": return "Darkness"
	return label_text

func _slider_changed(value: float, key: String) -> void:
	if _syncing or _playing:
		return
	var spin: SpinBox = _controls[key]
	spin.value = value

func _rotation_toggle() -> void:
	var toggle := CheckButton.new()
	toggle.text = "Rotate Along Path"
	toggle.add_theme_font_size_override("font_size", 12)
	toggle.toggled.connect(_rotation_mode_changed)
	_fields.add_child(toggle)
	_controls["rotate_along_path"] = toggle

func _rotation_mode_changed(enabled: bool) -> void:
	if _syncing or _playing:
		return
	_spell.rotate_along_path = enabled
	_markers.queue_redraw()

func _pick(key: String) -> void:
	if _playing:
		return
	_selecting = key
	_dialog.filters = PackedStringArray(["*.tres ; Godot resource"])
	_dialog.current_dir = "res://data"
	_dialog.popup_centered_ratio(0.9)

func _selected(path: String) -> void:
	if _selecting.begins_with("Texture:"):
		var key: String = _selecting.trim_prefix("Texture:")
		var tex: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if tex == null:
			_status.text = "Not a valid imported image: " + path
			return
		_spell.set(key, tex)
		_status.text = "Texture selected. Save Settings to keep it."
		_sync()
		return
	var data: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _selecting == "Spell":
		if not data is SpellData:
			_status.text = "Select a SpellData resource."
			return
		_spell = data as SpellData
		_paths["Spell"] = path
		var spell_button: Button = _controls["Spell"]
		spell_button.text = "Spell: " + path.get_file().get_basename()
		_status.text = "Spell selected. Save explicitly."
		_sync()
		return
	if data is EnemyCatalog:
		var entries: Array = data.get("enemies")
		_pending_catalog = data
		_pending_path = path
		_pending_role = _selecting
		_catalog_popup.clear()
		for i in range(entries.size()):
			var entry: EnemyData = entries[i] as EnemyData
			if entry != null:
				_catalog_popup.add_item(entry.display_name.strip_edges() if not entry.display_name.strip_edges().is_empty() else String(entry.enemy_id), i)
		if _catalog_popup.item_count == 0:
			_status.text = "Enemy catalog is empty."
			return
		if _catalog_popup.item_count == 1:
			_catalog_chosen(_catalog_popup.get_item_id(0))
		else:
			_catalog_popup.popup_centered(Vector2i(260, 0))
		return
	_accept_character(data, path, _selecting, -1)

func _catalog_chosen(index: int) -> void:
	if _pending_catalog == null:
		return
	var entries: Array = _pending_catalog.get("enemies")
	if index < 0 or index >= entries.size():
		return
	var card: Resource = entries[index] as Resource
	if card == null:
		return
	var card_path: String = card.resource_path
	# External cards can be saved directly; embedded cards must be saved via their catalog.
	if card_path.begins_with("res://") and not card_path.contains("::") and card_path != _pending_path:
		_accept_character(card, card_path, _pending_role, -1)
	else:
		_accept_character(card, _pending_path, _pending_role, index)

func _accept_character(data: Resource, path: String, role: String, catalog_index: int) -> void:
	if not (data is HeroData or data is EnemyData):
		_status.text = "Select a HeroData, EnemyData or EnemyCatalog resource."
		return
	var frames: SpriteFrames = data.get("battle_sprite_frames") as SpriteFrames
	if frames == null or not frames.has_animation(&"idle") or frames.get_frame_count(&"idle") == 0:
		_status.text = "This card needs Battle Sprite Frames with idle."
		return
	var sprite: AnimatedSprite2D = _hero if role == "Caster" else _enemy
	sprite.sprite_frames = frames
	_idle(sprite)
	if role == "Caster":
		_caster = data
	else:
		_target = data
	_paths[role] = path
	_catalog_indices[role] = catalog_index
	var button: Button = _controls[role]
	var display: String = String(data.get("display_name")) if data is EnemyData else String(data.get("hero_name"))
	button.text = role + ": " + display.strip_edges()
	_status.text = "Drag green/red points or change values. Save explicitly."
	_sync()

func _idle(sprite: AnimatedSprite2D) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")

func _extra(card: Resource, field: String) -> Vector2:
	if card == null:
		return Vector2.ZERO
	var point: Vector2 = card.get(field)
	return point

func _sync() -> void:
	_syncing = true
	var c: Vector2 = _extra(_caster, "magic_cast_point")
	var h: Vector2 = _extra(_target, "magic_impact_point")
	for key: String in _sliders:
		var spin: SpinBox = _controls[key]
		match key:
			"scx": spin.value = _spell.cast_offset.x
			"scy": spin.value = _spell.cast_offset.y
			"six": spin.value = _spell.impact_offset.x
			"siy": spin.value = _spell.impact_offset.y
			"lingering_x": spin.value = _spell.lingering_offset.x
			"lingering_y": spin.value = _spell.lingering_offset.y
			"preview_hold": spin.value = _preview_hold
			_: spin.value = float(_spell.get(key))
		var enabled: bool = not _playing
		spin.editable = enabled
		var slider: HSlider = _sliders[key]
		slider.set_value_no_signal(spin.value)
		slider.editable = enabled
	for key: String in ["rotate_along_path", "has_lingering_effect", "play_main_effect_once", "keep_effect_between_targets"]:
		var toggle: CheckButton = _controls[key]
		toggle.set_pressed_no_signal(bool(_spell.get(key)))
		toggle.disabled = _playing
	for key: String in ["visual_mode", "element", "effect_type"]:
		var mode: OptionButton = _controls[key]
		mode.select(int(_spell.get(key)))
		mode.disabled = _playing
	for key: String in ["icon", "projectile_sheet", "impact_sheet", "lingering_sheet"]:
		var button: Button = _controls[key]
		var tex: Texture2D = _spell.get(key) as Texture2D
		button.text = tex.resource_path.get_file() if tex != null else "Select PNG"
		button.disabled = _playing
	for key: String in ["id", "title", "description"]:
		var edit: LineEdit = _controls[key]
		edit.text = str(_spell.get(key))
		edit.editable = not _playing
	_syncing = false
	_markers.queue_redraw()

func _changed(value: float, key: String) -> void:
	if _syncing or _playing:
		return
	var slider: HSlider = _sliders[key]
	slider.set_value_no_signal(value)
	if key == "scx":
		_spell.cast_offset.x = value
	elif key == "scy":
		_spell.cast_offset.y = value
	elif key == "six":
		_spell.impact_offset.x = value
	elif key == "siy":
		_spell.impact_offset.y = value
	elif key == "lingering_x":
		_spell.lingering_offset.x = value
	elif key == "lingering_y":
		_spell.lingering_offset.y = value
	elif key == "preview_hold":
		_preview_hold = value
	else:
		_spell.set(key, value)
	_markers.queue_redraw()

func _start() -> Vector2:
	return Visual.attachment(_hero, _caster, "magic_cast_point", _spell.cast_offset)

func _end() -> Vector2:
	return Visual.attachment(_enemy, _target, "magic_impact_point", _spell.impact_offset)

func _draw_markers() -> void:
	if _spell == null:
		return
	var a := _markers.to_local(_start())
	var b := _markers.to_local(_end())
	if _show_path and _spell.visual_mode in [0, 2]:
		if _spell.visual_mode == 2:
			a = Vector2(b.x, -80)
		var points := PackedVector2Array()
		# Same formula as the running effect.
		for i in range(65):
			var t := float(i) / 64.0
			points.append(Visual._point(a, b, t, _spell))
		_markers.draw_polyline(points, Color(1, 0.78, 0.25), 1.5, true)
	if _show_points:
		_cross(_markers.to_local(_start()), Color(0.2, 1, 0.5))
		_cross(b, Color(1, 0.3, 0.3))

func _cross(pt: Vector2, color: Color) -> void:
	_markers.draw_arc(pt, 9, 0, TAU, 24, color, 2, true)
	_markers.draw_line(pt - Vector2(12, 0), pt + Vector2(12, 0), color, 1.5)
	_markers.draw_line(pt - Vector2(0, 12), pt + Vector2(0, 12), color, 1.5)

func _preview_input(event: InputEvent, preview: TextureRect) -> void:
	if _playing or not _show_points:
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var factor: float = minf(preview.size.x / 640.0, preview.size.y / 360.0)
	if factor <= 0: return
	var origin: Vector2 = (preview.size - Vector2(640, 360) * factor) * 0.5
	var mouse := event as InputEventMouse
	var pt: Vector2 = (mouse.position - origin) / factor
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT: return
		if not click.pressed:
			_drag = ""
			return
		if _caster != null and pt.distance_to(_start()) < 18.0: _drag = "cast"
		elif _target != null and pt.distance_to(_end()) < 18.0: _drag = "hit"
	if event is InputEventMouseMotion and (mouse.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_drag = ""
	if _drag == "cast":
		_spell.cast_offset = _hero.to_local(pt) - _hero.offset - _extra(_caster, "magic_cast_point")
	elif _drag == "hit":
		_spell.impact_offset = _enemy.to_local(pt) - _enemy.offset - _extra(_target, "magic_impact_point")
	else:
		return
	_sync()

func _play() -> void:
	if _playing:
		_loop = false
		return
	if not _paths.has("Spell"):
		_status.text = "Select a spell first."
		return
	if _hero.sprite_frames == null:
		_status.text = "Select caster to play the animation."
		return
	_playing = true
	_sync()
	_status.text = "Preview playing. Press Play again to stop looping."
	while true:
		_visual = Visual.new()
		_visual.setup(_fight)
		await _visual.darken(_spell.screen_darkness, _spell.darken_duration)
		if _hero.sprite_frames.has_animation(&"attack") and _hero.sprite_frames.get_frame_count(&"attack") > 0:
			_hero.play(&"attack")
			var seconds: float = 0.0
			for i in range(_hero.sprite_frames.get_frame_count(&"attack")):
				seconds += _hero.sprite_frames.get_frame_duration(&"attack", i)
			await get_tree().create_timer(seconds / maxf(1.0, _hero.sprite_frames.get_animation_speed(&"attack"))).timeout
			_idle(_hero)
		await _visual.play_spell(_spell, _start(), _end())
		if _spell.has_lingering_effect:
			await _visual.start_lingering(_spell, _end())
			await get_tree().create_timer(_preview_hold).timeout
			_visual.stop_lingering()
		await _visual.darken(0.0, _spell.darken_duration)
		_visual.queue_free()
		await get_tree().process_frame
		if not _loop: break
	_playing = false
	_sync()
	_status.text = "Preview finished. Save if satisfied."

func _migrate_shared_points() -> void:
	# Legacy previews edited the character cards instead of the selected spell.
	# Explicit one-time migration keeps the *current* on-screen trajectory
	# by transferring the character attachment positions into spell offsets.
	if _playing or _spell == null or not _paths.has("Spell"):
		_status.text = "Select a spell first."
		return
	if _caster == null or _target == null:
		_status.text = "Select both caster and target before migrating."
		return
	var cast_shared: Vector2 = _extra(_caster, "magic_cast_point")
	var hit_shared: Vector2 = _extra(_target, "magic_impact_point")
	if cast_shared.is_zero_approx() and hit_shared.is_zero_approx():
		_status.text = "Character shared points are already zero. Nothing to transfer."
		return
	_spell.cast_offset += cast_shared
	_spell.impact_offset += hit_shared
	_caster.set("magic_cast_point", Vector2.ZERO)
	_target.set("magic_impact_point", Vector2.ZERO)
	_sync()
	_status.text = "Transferred shared points into this spell. Save Settings now. Other spells will use their own offsets."

func _save() -> void:
	if _playing: return
	var errors := PackedStringArray()
	var loaded: Dictionary = {}
	for role: String in ["Caster", "Target", "Spell"]:
		if not _paths.has(role):
			continue
		var path: String = _paths[role]
		if not loaded.has(path):
			loaded[path] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var root: Resource = loaded[path] as Resource
		if root == null:
			errors.append(path)
			continue
		var card: Resource = root
		var index: int = int(_catalog_indices.get(role, -1))
		if index >= 0:
			if not root is EnemyCatalog:
				errors.append(path)
				continue
			var entries: Array = root.get("enemies")
			if index >= entries.size():
				errors.append(path)
				continue
			card = entries[index] as Resource
			var expected: Resource = _caster if role == "Caster" else _target
			if not card is EnemyData or card.get("enemy_id") != expected.get("enemy_id"):
				errors.append(path + " (catalog changed)")
				continue
		match role:
			"Caster":
				card.set("magic_cast_point", _caster.get("magic_cast_point"))
			"Target":
				card.set("magic_impact_point", _target.get("magic_impact_point"))
			"Spell":
				for key: String in ["id", "title", "description", "icon", "element", "effect_type", "mp_cost", "damage_min", "damage_max", "heal_min", "heal_max", "accuracy", "range_tiles", "area_radius", "visual_mode", "projectile_sheet", "projectile_frames", "projectile_fps", "projectile_speed", "projectile_scale", "projectile_rotation_degrees", "rotate_along_path", "cast_offset", "impact_offset", "arc_height", "wave_amplitude", "wave_count", "impact_sheet", "impact_frames", "impact_fps", "impact_scale", "screen_darkness", "darken_duration", "target_slide_duration", "has_lingering_effect", "lingering_sheet", "lingering_frames", "lingering_fps", "lingering_offset", "lingering_scale", "lingering_start_delay", "play_main_effect_once", "keep_effect_between_targets"]:
					card.set(key, _spell.get(key))
	for path: String in loaded:
		var root: Resource = loaded[path] as Resource
		if root == null or ResourceSaver.save(root, path) != OK:
			errors.append(path)
	_status.text = "Saved selected .tres files." if errors.is_empty() else "Save failed: " + ", ".join(errors)

func _toggle_points(value: bool) -> void:
	_show_points = value
	_markers.queue_redraw()

func _toggle_path(value: bool) -> void:
	_show_path = value
	_markers.queue_redraw()
