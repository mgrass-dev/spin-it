extends Node2D

signal picked_up
signal released(world_pos: Vector2)

enum State { IDLE, HELD, ROLLING }

var _state := State.IDLE
var _origin: Vector2
var _click_offset: Vector2

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
				picked_up.emit()
		elif not event.pressed and _state == State.HELD:
			_state = State.IDLE
			released.emit(global_position)

	if event is InputEventMouseMotion and _state == State.HELD:
		global_position = get_viewport().get_mouse_position() + _click_offset

func start_rolling() -> void:
	_state = State.ROLLING

func return_to_slot() -> void:
	_state = State.IDLE
	global_position = _origin
