class_name WheelItem
extends Area2D

enum SlotColor { BLACK, RED }

@export var slot_color: SlotColor = SlotColor.BLACK:
	set(value):
		slot_color = value
		if is_node_ready():
			_update_sprite()

@export var modifier: int = 0:
	set(value):
		modifier = value
		if is_node_ready() and _label != null:
			_label.text = str(modifier)

signal ball_hit(item: Area2D)

const TEXTURES: Dictionary = {
	SlotColor.BLACK: preload("res://sprites/roue/slot_black.png"),
	SlotColor.RED: preload("res://sprites/roue/slot_red.png"),
}

@onready var _sprite: Sprite2D = $Sprite2D
var _label: Label

func _ready() -> void:
	_update_sprite()
	body_entered.connect(_on_body_entered)
	_label = Label.new()
	_label.text = str(modifier)
	_label.add_theme_font_size_override("font_size", 22)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_size(Vector2(64.0, 40.0))
	_label.position = Vector2(-32.0, -60.0)
	_label.z_index = 1
	add_child(_label)

func _update_sprite() -> void:
	_sprite.texture = TEXTURES[slot_color]

func _on_body_entered(_body: Node2D) -> void:
	ball_hit.emit(self)
