extends Node2D

signal picked_up
signal released(world_pos: Vector2)

var _dragging := false
var _origin: Vector2
var _click_offset: Vector2

func _ready() -> void:
	_origin = global_position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_viewport().get_mouse_position()
		if event.pressed and not _dragging:
			if (mouse_pos - global_position).length() < 20.0:
				_dragging = true
				_click_offset = global_position - mouse_pos
				picked_up.emit()
		elif not event.pressed and _dragging:
			_dragging = false
			released.emit(global_position)
			global_position = _origin

	if event is InputEventMouseMotion and _dragging:
		global_position = get_viewport().get_mouse_position() + _click_offset
