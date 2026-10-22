extends CanvasLayer

@onready var cover: ColorRect = $Cover

func play(target_scene: String, duration: float, pixel_size: float, dissolve_color: Color) -> void:
    # Instance-specific material; safe if additional transitions are created later.
    var mat: ShaderMaterial = cover.material.duplicate() as ShaderMaterial
    cover.material = mat
    mat.set_shader_parameter("progress", 0.0)
    mat.set_shader_parameter("pixel_size", pixel_size)
    mat.set_shader_parameter("dissolve_color", dissolve_color)

    var hide_tween: Tween = create_tween()
    hide_tween.tween_method(_set_progress, 0.0, 1.0, maxf(duration, 0.05))
    await hide_tween.finished

    var error: Error = get_tree().change_scene_to_file(target_scene)
    if error != OK:
        push_error("PixelTransition: failed to open scene: " + target_scene)
        queue_free()
        return

    # The transition belongs to the scene tree root, so it survives the switch.
    await get_tree().process_frame
    await get_tree().process_frame

    var reveal_tween: Tween = create_tween()
    reveal_tween.tween_method(_set_progress, 1.0, 0.0, maxf(duration, 0.05))
    await reveal_tween.finished
    queue_free()

func _set_progress(value: float) -> void:
    var mat: ShaderMaterial = cover.material as ShaderMaterial
    mat.set_shader_parameter("progress", value)
