# SpinButton.gd
extends Button

signal spin_requested

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	spin_requested.emit()
