extends Node2D
## Animation bridge for the tactical unit. Movement remains in BattleMove.

@export_group("Visuals")
@export var sprite_path: NodePath = ^"AnimatedSprite2D"
@export_range(1.0, 24.0, 0.5) var walking_fps: float = 8.0
@export var initial_facing: Vector2i = Vector2i.DOWN

var _facing: Vector2i = Vector2i.DOWN
var _moving: bool = false
@onready var _sprite: AnimatedSprite2D = get_node_or_null(sprite_path) as AnimatedSprite2D

func _ready() -> void:
    _facing = initial_facing
    play_idle()

func _direction_name(direction: Vector2i) -> StringName:
    if direction == Vector2i.UP:
        return &"Up"
    if direction == Vector2i.DOWN:
        return &"Down"
    if direction == Vector2i.LEFT:
        return &"Left"
    return &"Right"

func play_walk(direction: Vector2i) -> void:
    if _sprite == null or direction == Vector2i.ZERO:
        return
    _facing = direction
    _moving = true
    var animation: StringName = _direction_name(direction)
    if not _sprite.sprite_frames.has_animation(animation):
        return
    _sprite.sprite_frames.set_animation_speed(animation, walking_fps)
    if _sprite.animation != animation or not _sprite.is_playing():
        _sprite.play(animation)

func play_idle() -> void:
    if _sprite == null:
        return
    _moving = false
    var animation: StringName = StringName("Idle_" + String(_direction_name(_facing)).to_lower())
    if _sprite.sprite_frames.has_animation(animation):
        _sprite.play(animation)
