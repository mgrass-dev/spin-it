extends Node2D

@onready var player_wheel: Node2D = $PlayerWheel
@onready var ball: Node2D = $Ball

const WHEEL_VISUAL_RADIUS := 250.0
const BALL_APPROACH_DURATION := 0.5

var _ball_over_wheel := false
var _ball_rolling := false
var _ball_offset_angle := 0.0
var _ball_approach_start := Vector2.ZERO
var _ball_approach_time := 0.0

func _ready() -> void:
	ball.picked_up.connect(_on_ball_picked_up)
	ball.released.connect(_on_ball_released)
	player_wheel.spin_completed.connect(_on_spin_completed)

func _process(delta: float) -> void:
	if ball.is_held():
		var ball_pos: Vector2 = ball.global_position
		var dist: float = (ball_pos - player_wheel.global_position).length()
		var is_over: bool = dist <= WHEEL_VISUAL_RADIUS * player_wheel.scale.x

		if is_over and not _ball_over_wheel:
			_ball_over_wheel = true
			player_wheel.start_spinning()
			player_wheel.set_highlight(true)
		elif not is_over and _ball_over_wheel:
			_ball_over_wheel = false
			player_wheel.stop_spinning()
			player_wheel.set_highlight(false)

	if _ball_rolling:
		var spin_r: float = player_wheel.get_spinning_rotation()
		var radius: float = player_wheel.get_item_world_radius()
		var target_pos: Vector2 = player_wheel.global_position + \
			Vector2(cos(spin_r + _ball_offset_angle), sin(spin_r + _ball_offset_angle)) * radius

		if _ball_approach_time > 0.0:
			_ball_approach_time -= delta
			var t: float = clamp(1.0 - _ball_approach_time / BALL_APPROACH_DURATION, 0.0, 1.0)
			ball.global_position = _ball_approach_start.lerp(target_pos, t)
		else:
			ball.global_position = target_pos

func _on_ball_picked_up() -> void:
	pass

func _on_ball_released(_world_pos: Vector2) -> void:
	if _ball_over_wheel:
		_ball_over_wheel = false
		player_wheel.set_highlight(false)
		_launch_ball_on_wheel()
	else:
		player_wheel.stop_spinning()
		ball.return_to_slot()

func _launch_ball_on_wheel() -> void:
	var spin_info: Dictionary = player_wheel.stop_on_random_item()
	if spin_info.is_empty():
		ball.return_to_slot()
		return

	var target_r: float = float(spin_info["target_r"])

	# Offset so ball ends at world angle -PI/2 (the pointer/top) when spinning_part
	# reaches target_r — which is exactly where the winning wheel_item will be.
	_ball_offset_angle = -PI / 2.0 - target_r
	_ball_approach_start = ball.global_position
	_ball_approach_time = BALL_APPROACH_DURATION

	ball.start_rolling()
	_ball_rolling = true

func _on_spin_completed(item: WheelItem) -> void:
	_ball_rolling = false
	# Small squish to signal the ball landing on the item
	var tween := create_tween()
	tween.tween_property(ball, "scale", Vector2(1.3, 0.7), 0.08)
	tween.tween_property(ball, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	print("Bille sur: %d → %d dégâts infligés à l'ennemi" % [item.modifier, item.modifier])
