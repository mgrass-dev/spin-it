class_name Modifier
extends Node2D

# Modifier value (0 = no effect, max N to be defined).
@export var value: int = 0

# Called by the Wheel when a ball hits the linked WheelItem.
# Receives the wheel so it can alter its behaviour (speed, direction, etc.).
func apply(wheel: Node2D) -> void:
	match value:
		0:
			pass
		_:
			pass  # TODO: implement effects per value
