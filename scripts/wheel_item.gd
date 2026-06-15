class_name WheelItem
extends Area2D

enum SlotColor { BLACK, RED }

@export var slot_color: SlotColor = SlotColor.BLACK:
	set(value):
		slot_color = value
		if is_node_ready():
			_update_sprite()

# 0 = no effect; max value to be defined when the Modifier scene is built
@export var modifier: int = 0

signal ball_hit(item: Area2D)

const TEXTURES: Dictionary = {
	SlotColor.BLACK: preload("res://sprites/roue/case_noir.png"),
	SlotColor.RED: preload("res://sprites/roue/case_rouge.png"),
}

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_update_sprite()
	body_entered.connect(_on_body_entered)

func _update_sprite() -> void:
	_sprite.texture = TEXTURES[slot_color]

func _on_body_entered(_body: Node2D) -> void:
	ball_hit.emit(self)
