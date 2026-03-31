extends CanvasLayer

@onready var fade_rect = $FadeRect

var fade_speed: float = 2.5

func _ready() -> void:
	fade_rect.color.a = 0.0

func fade_out() -> void:
	while fade_rect.color.a < 1.0:
		fade_rect.color.a += fade_speed * get_process_delta_time()
		await get_tree().process_frame

	fade_rect.color.a = 1.0

func fade_in() -> void:
	while fade_rect.color.a > 0.0:
		fade_rect.color.a -= fade_speed * get_process_delta_time()
		await get_tree().process_frame

	fade_rect.color.a = 0.0
