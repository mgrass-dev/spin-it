extends Node2D

@export var min_tours: float = 3.0
@export var max_tours: float = 6.0
@export var duree_spin: float = 3.0

func connect_to_button(button: Button) -> void:
	button.spin_requested.connect(_on_spin_requested)

func _on_spin_requested() -> void:
	var tours = randf_range(min_tours, max_tours)
	var tween = create_tween()
	tween.tween_property(self, "rotation", rotation + TAU * tours, duree_spin)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
