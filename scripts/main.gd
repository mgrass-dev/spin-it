extends Node2D

@onready var player_wheel: Node2D = $PlayerWheel
@onready var ball: Node2D = $Ball

# Roue_fond.png is 500x500, so visual radius = 250px; PlayerWheel scale = 0.65
const WHEEL_VISUAL_RADIUS := 250.0

func _ready() -> void:
	ball.picked_up.connect(_on_ball_picked_up)
	ball.released.connect(_on_ball_released)

func _on_ball_picked_up() -> void:
	player_wheel.start_spinning()

func _on_ball_released(world_pos: Vector2) -> void:
	var dist: float = (world_pos - player_wheel.global_position).length()
	if dist <= WHEEL_VISUAL_RADIUS * player_wheel.scale.x:
		player_wheel.stop_on_random_item()
