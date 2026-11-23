extends Node2D
## Temporary visual layer, owned by the current FightScene.
var _shade: ColorRect
var _lingering_sprite: AnimatedSprite2D

func setup(fight: Node2D) -> void:
	fight.add_child(self)
	z_index = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.size = get_viewport_rect().size
	_shade.color = Color(0, 0, 0, 0)
	add_child(_shade)

func darken(alpha: float, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_shade, "color:a", alpha, seconds)
	await tween.finished

func _make_sprite(sheet: Texture2D, count: int, fps: float, looped: bool, magnification: float) -> AnimatedSprite2D:
	if sheet == null:
		return null
	if sheet.get_width() % count != 0:
		push_warning("Magic visual: PNG width must be divisible by frame count.")
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"effect")
	frames.set_animation_speed(&"effect", fps)
	frames.set_animation_loop(&"effect", looped)
	var width: int = int(float(sheet.get_width()) / float(count))
	for i in range(count):
		var tex: AtlasTexture = AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(i * width, 0, width, sheet.get_height())
		frames.add_frame(&"effect", tex)
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * magnification
	add_child(sprite)
	sprite.play(&"effect")
	return sprite

static func _point(start: Vector2, end: Vector2, phase: float, spell: SpellData) -> Vector2:
	var normal: Vector2 = (end - start).normalized().orthogonal()
	var envelope: float = sin(PI * phase)
	return start.lerp(end, phase) + normal * sin(TAU * spell.wave_count * phase) * spell.wave_amplitude * envelope - Vector2(0, spell.arc_height * envelope)

func _move_sprite(phase: float, sprite: AnimatedSprite2D, start: Vector2, end: Vector2, spell: SpellData) -> void:
	sprite.position = _point(start, end, phase, spell)
	var rotation_offset: float = deg_to_rad(spell.projectile_rotation_degrees)
	if spell.rotate_along_path:
		var a: Vector2 = _point(start, end, maxf(0.0, phase - 0.001), spell)
		var b: Vector2 = _point(start, end, minf(1.0, phase + 0.001), spell)
		if a.distance_squared_to(b) > 0.000001:
			sprite.rotation = (b - a).angle() + rotation_offset
		else:
			sprite.rotation = rotation_offset
	else:
		sprite.rotation = rotation_offset
		sprite.flip_h = end.x < start.x

func play_spell(spell: SpellData, cast_world: Vector2, hit_world: Vector2) -> void:
	var start: Vector2 = to_local(cast_world)
	var end: Vector2 = to_local(hit_world)
	if spell.visual_mode == 2:
		start = Vector2(end.x, -80)
	if spell.visual_mode == 0 or spell.visual_mode == 2:
		var projectile: AnimatedSprite2D = _make_sprite(spell.projectile_sheet, spell.projectile_frames, spell.projectile_fps, true, spell.projectile_scale)
		if projectile != null:
			projectile.position = start
			var duration: float = clampf(start.distance_to(end) / maxf(1.0, spell.projectile_speed), 0.05, 10.0)
			var tween: Tween = create_tween()
			tween.tween_method(_move_sprite.bind(projectile, start, end, spell), 0.0, 1.0, duration)
			await tween.finished
			projectile.queue_free()
	var impact: AnimatedSprite2D = _make_sprite(spell.impact_sheet, spell.impact_frames, spell.impact_fps, false, spell.impact_scale)
	if impact != null:
		impact.position = get_viewport_rect().size * 0.5 if spell.visual_mode == 3 else end
		await get_tree().create_timer(float(spell.impact_frames) / maxf(1.0, spell.impact_fps), true).timeout
		impact.queue_free()
	else:
		await get_tree().create_timer(0.15, true).timeout

## Shared by the real battle and preview. Character points supplement spell offsets.
static func attachment(sprite: AnimatedSprite2D, data: Resource, property_name: String, spell_offset: Vector2) -> Vector2:
	var extra: Vector2 = Vector2.ZERO
	if data != null:
		for info: Dictionary in data.get_property_list():
			if str(info.get("name", "")) == property_name:
				extra = data.get(property_name)
				break
	return sprite.to_global(sprite.offset + extra + spell_offset)

## Start the third (looping) sheet after the initial impact.
## The sprite stays at the first enemy's combat slot while subsequent targets swap in.
func start_lingering(spell: SpellData, hit_world: Vector2) -> void:
	stop_lingering()
	if not spell.has_lingering_effect or spell.lingering_sheet == null:
		return
	if spell.lingering_start_delay > 0.0:
		await get_tree().create_timer(spell.lingering_start_delay, true).timeout
	_lingering_sprite = _make_sprite(spell.lingering_sheet, spell.lingering_frames, spell.lingering_fps, true, spell.lingering_scale)
	if _lingering_sprite == null:
		return
	_lingering_sprite.name = "MagicLingeringEffect"
	_lingering_sprite.position = to_local(hit_world) + spell.lingering_offset
	# Draw the ground effect behind the active enemy character when possible.
	_lingering_sprite.z_index = -1

func stop_lingering() -> void:
	if is_instance_valid(_lingering_sprite):
		_lingering_sprite.queue_free()
	_lingering_sprite = null
