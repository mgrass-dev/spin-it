extends CanvasLayer

signal damage_applied(amount: int)

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label

func _ready() -> void:
	_panel.visible = false

# target_global_pos: future use — will be the enemy HP bar world position
# for the "sort" animation flying towards it.
func show_damage(amount: int, _target_global_pos: Vector2 = Vector2.ZERO) -> void:
	_label.text = str(amount)
	_panel.modulate.a = 1.0
	_panel.visible = true
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		_panel.visible = false
		damage_applied.emit(amount)
	)
