extends Node2D

@onready var spin_button = $CanvasLayer/SpinButton
@onready var wheel = $Wheel

func _ready() -> void:
	
	print("wheel: ", wheel)
	print("spin_button: ", spin_button)

	wheel.connect_to_button(spin_button)
