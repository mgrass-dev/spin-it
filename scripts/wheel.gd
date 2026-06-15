extends Node2D

const WHEEL_ITEM_SCENE = preload("res://scenes/wheel_item.tscn")

@export var min_spins: float = 3.0
@export var max_spins: float = 6.0
@export var spin_duration: float = 3.0
@export var item_count: int = 20
@export var item_radius: float = 145.0

@onready var _spinning_part: Node2D = $SpinningPart

var _tween: Tween

func _ready() -> void:
	_setup_items()

func _setup_items() -> void:
	var angle_step = TAU / item_count
	var values = range(item_count)
	values.shuffle()

	for i in item_count:
		var item: WheelItem = WHEEL_ITEM_SCENE.instantiate()
		var angle = i * angle_step
		item.position = Vector2(cos(angle), sin(angle)) * item_radius
		item.rotation = angle + PI / 2
		item.z_index = 1
		item.slot_color = WheelItem.SlotColor.BLACK if i % 2 == 0 else WheelItem.SlotColor.RED
		item.modifier = values[i]
		_spinning_part.add_child(item)
		item.ball_hit.connect(slow_down)

func connect_to_button(button: Button) -> void:
	button.spin_requested.connect(_on_spin_requested)

func _on_spin_requested() -> void:
	var spins = randf_range(min_spins, max_spins)
	_tween = create_tween()
	_tween.tween_property(_spinning_part, "rotation", _spinning_part.rotation + TAU * spins, spin_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func slow_down(item: Area2D) -> void:
	if _tween == null or not _tween.is_valid():
		return
	_tween.kill()
	var mod_node = item.get_node_or_null("Modifier")
	if mod_node and mod_node.has_method("apply"):
		mod_node.apply(self)
	var tween = create_tween()
	tween.tween_property(_spinning_part, "rotation", _spinning_part.rotation + TAU * 0.25, spin_duration * 0.3)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	_tween = tween
