extends Node2D
## Visual-only snapshot of the current AnimatedSprite2D frame.
## One instance per death; no changes to combat state or shared resources.

var _texture: ImageTexture
var _flash_texture: ImageTexture
var _parts: Array[Dictionary] = []
var _origin: Vector2
var _progress: float = 0.0
var _flash: float = 0.0
var _scatter: float = 0.0
var _fade: float = 1.0


func play(sprite: AnimatedSprite2D, settings: Dictionary) -> bool:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		queue_free()
		return false
	if not sprite.sprite_frames.has_animation(sprite.animation):
		queue_free()
		return false
	var frame_texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if frame_texture == null:
		queue_free()
		return false
	var image: Image = frame_texture.get_image()
	if image == null or image.is_empty():
		queue_free()
		return false
	if image.is_compressed() and image.decompress() != OK:
		queue_free()
		return false
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var block: int = maxi(1, int(settings.get("pixel_size", 3)))
	# Bound the number of fragments for large boss textures.
	block = maxi(block, ceili(sqrt(float(width * height) / 4096.0)))
	_texture = ImageTexture.create_from_image(image)
	_scatter = maxf(0.0, float(settings.get("scatter", 22.0)))
	_fade = clampf(float(settings.get("fade", 1.0)), 0.0, 1.0)
	_origin = -Vector2(width, height) * 0.5 if sprite.centered else Vector2.ZERO
	position = sprite.offset
	scale = Vector2(-1.0 if sprite.flip_h else 1.0, -1.0 if sprite.flip_v else 1.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for y in range(0, height, block):
		for x in range(0, width, block):
			var w: int = mini(block, width - x)
			var h: int = mini(block, height - y)
			var occupied: bool = false
			for py in range(y, y + h):
				for px in range(x, x + w):
					if image.get_pixel(px, py).a > 0.0:
						occupied = true
						break
				if occupied:
					break
			if not occupied:
				continue
			var center: Vector2 = Vector2(x + w * 0.5, y + h * 0.5)
			var direction: Vector2 = (center - Vector2(width, height) * 0.5).normalized()
			direction += Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
			_parts.append({
				"rect": Rect2(x, y, w, h),
				"velocity": direction.normalized() * rng.randf_range(0.45, 1.25),
				"delay": rng.randf_range(0.0, 0.55)
			})
	if _parts.is_empty():
		queue_free()
		return false

	# self_modulate hides only the original sprite; children remain visible.
	sprite.pause()
	var hidden: Color = sprite.self_modulate
	self_modulate = hidden
	hidden.a = 0.0
	sprite.self_modulate = hidden
	if bool(settings.get("flash", true)):
		var mask: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
		for y in range(height):
			for x in range(width):
				mask.set_pixel(x, y, Color(1.0, 1.0, 1.0, image.get_pixel(x, y).a))
		_flash_texture = ImageTexture.create_from_image(mask)
		_flash = 1.0
		queue_redraw()
		var flash_tween: Tween = create_tween()
		flash_tween.tween_method(_set_flash, 1.0, 0.0, 0.12)
		await flash_tween.finished
	var tween: Tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, maxf(0.05, float(settings.get("duration", 0.9))))
	await tween.finished
	var hold: float = maxf(0.0, float(settings.get("hold", 0.0)))
	if hold > 0.0:
		var hold_tween: Tween = create_tween()
		hold_tween.tween_interval(hold)
		await hold_tween.finished
	queue_free()
	return true


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	if _texture == null or _progress >= 1.0:
		return
	for part in _parts:
		var source: Rect2 = part["rect"]
		var delay: float = float(part["delay"])
		var t: float = clampf((_progress - delay) / (1.0 - delay), 0.0, 1.0)
		if t >= 1.0:
			continue
		var velocity: Vector2 = part["velocity"]
		var displacement: Vector2 = velocity * _scatter * t
		var alpha: float = 1.0 - pow(t, lerpf(4.0, 0.65, _fade))
		var destination := Rect2(_origin + source.position + displacement, source.size)
		draw_texture_rect_region(_texture, destination, source, Color(1.0, 1.0, 1.0, alpha), false, true)
	if _flash_texture != null and _flash > 0.0:
		draw_texture(_flash_texture, _origin, Color(1.0, 1.0, 1.0, _flash))
