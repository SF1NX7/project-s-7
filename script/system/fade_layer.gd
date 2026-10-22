extends CanvasLayer
class_name FadeLayer

# FadeLayer v3
# Same timing for entrance and exit fades.
#
# Put this script on FadeLayer in every location.
#
# fade_in()  = black -> transparent
# fade_out() = transparent -> black
#
# Both use fade_duration by default.

@export_group("Fade Timing")
@export var fade_duration: float = 0.65

@export_group("Fade")
@export var fade_in_on_ready: bool = true
@export var fade_color: Color = Color.BLACK
@export var start_scene_black: bool = true

@export_group("Debug")
@export var print_debug: bool = false

var _rect: ColorRect = null
var _tween: Tween = null


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = _find_or_create_rect()

	if start_scene_black:
		_set_alpha(1.0)
	else:
		_set_alpha(0.0)

	if fade_in_on_ready:
		call_deferred("fade_in")


func fade_in(duration: float = -1.0) -> void:
	var d: float = fade_duration if duration < 0.0 else duration

	if print_debug:
		print("FadeLayer: fade_in duration=", d)

	_ensure_rect()
	_set_alpha(1.0)
	await _tween_alpha(0.0, d)


func fade_out(duration: float = -1.0) -> void:
	var d: float = fade_duration if duration < 0.0 else duration

	if print_debug:
		print("FadeLayer: fade_out duration=", d)

	_ensure_rect()
	_set_alpha(_rect.color.a)
	await _tween_alpha(1.0, d)


func instant_black() -> void:
	_ensure_rect()
	_set_alpha(1.0)


func instant_clear() -> void:
	_ensure_rect()
	_set_alpha(0.0)


func _find_or_create_rect() -> ColorRect:
	for child in get_children():
		if child is ColorRect:
			var cr := child as ColorRect
			_prepare_rect(cr)
			return cr

	var cr := ColorRect.new()
	cr.name = "FadeRect"
	add_child(cr)
	_prepare_rect(cr)
	return cr


func _prepare_rect(cr: ColorRect) -> void:
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.offset_left = 0
	cr.offset_top = 0
	cr.offset_right = 0
	cr.offset_bottom = 0
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.process_mode = Node.PROCESS_MODE_ALWAYS
	cr.color = fade_color


func _ensure_rect() -> void:
	if _rect == null:
		_rect = _find_or_create_rect()


func _set_alpha(a: float) -> void:
	_ensure_rect()
	var c: Color = fade_color
	c.a = clampf(a, 0.0, 1.0)
	_rect.color = c
	_rect.visible = a > 0.001


func _tween_alpha(target_alpha: float, duration: float) -> void:
	_ensure_rect()

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_rect.visible = true

	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_rect, "color:a", clampf(target_alpha, 0.0, 1.0), max(duration, 0.0))

	await _tween.finished

	if target_alpha <= 0.001:
		_rect.visible = false
