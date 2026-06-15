extends Node2D

signal picked_up
signal released(world_pos: Vector2)

enum State { IDLE, HELD, ROLLING }

var _state := State.IDLE
var _origin: Vector2
var _click_offset: Vector2

# Spring/ragdoll physics
var _spring_offset: Vector2 = Vector2.ZERO
var _spring_velocity: Vector2 = Vector2.ZERO
var _prev_mouse_pos: Vector2 = Vector2.ZERO
const SPRING_STIFFNESS := 280.0
const SPRING_DAMPING := 14.0
const DRAG_INFLUENCE := 0.08
const MAX_SQUISH := 0.35

@onready var _sprite: Sprite2D = $Sprite2D
var _tween: Tween

func _ready() -> void:
	_origin = global_position

func is_held() -> bool:
	return _state == State.HELD

func _input(event: InputEvent) -> void:
	if _state == State.ROLLING:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_viewport().get_mouse_position()
		if event.pressed and _state == State.IDLE:
			if (mouse_pos - global_position).length() < 20.0:
				_state = State.HELD
				_click_offset = global_position - mouse_pos
				_prev_mouse_pos = mouse_pos
				_spring_offset = Vector2.ZERO
				_spring_velocity = Vector2.ZERO
				_do_pickup_squish()
				picked_up.emit()
		elif not event.pressed and _state == State.HELD:
			_state = State.IDLE
			_do_drop_bounce()
			released.emit(global_position)

	if event is InputEventMouseMotion and _state == State.HELD:
		global_position = get_viewport().get_mouse_position() + _click_offset

func _process(delta: float) -> void:
	if _state != State.HELD:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var mouse_vel: Vector2 = (mouse_pos - _prev_mouse_pos) / maxf(delta, 0.001)
	_prev_mouse_pos = mouse_pos

	# Spring physics — sprite trails behind movement
	var spring_force := -_spring_offset * SPRING_STIFFNESS
	_spring_velocity += spring_force * delta
	_spring_velocity -= _spring_velocity * SPRING_DAMPING * delta
	_spring_velocity += mouse_vel * DRAG_INFLUENCE
	_spring_offset += _spring_velocity * delta

	_sprite.position = _spring_offset

	# Stretch in direction of movement
	var speed := mouse_vel.length()
	var squish: float = clampf(speed / 600.0, 0.0, MAX_SQUISH)
	if speed > 15.0:
		_sprite.rotation = mouse_vel.angle()
		_sprite.scale = Vector2(1.0 + squish, 1.0 - squish * 0.6)
	else:
		_sprite.rotation = lerp_angle(_sprite.rotation, 0.0, 12.0 * delta)
		_sprite.scale = _sprite.scale.lerp(Vector2.ONE, 12.0 * delta)

func _do_pickup_squish() -> void:
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "scale", Vector2(1.25, 0.75), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.25)

func _do_drop_bounce() -> void:
	_kill_tween()
	var release_vel := _spring_velocity
	_spring_offset = Vector2.ZERO
	_spring_velocity = Vector2.ZERO

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sprite, "rotation", 0.0, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

func start_rolling() -> void:
	_state = State.ROLLING
	_kill_tween()
	_spring_offset = Vector2.ZERO
	_spring_velocity = Vector2.ZERO
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2.ONE
	_sprite.rotation = 0.0

func return_to_slot() -> void:
	_state = State.IDLE
	global_position = _origin
	_kill_tween()
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2.ONE
	_sprite.rotation = 0.0
