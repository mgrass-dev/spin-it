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

func start_spinning() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var speed := max_spins / spin_duration
	var spin_count := 30.0
	_tween = create_tween()
	_tween.tween_property(_spinning_part, "rotation",
		_spinning_part.rotation + TAU * spin_count,
		spin_count / speed)\
		.set_trans(Tween.TRANS_LINEAR)

func stop_on_random_item() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	var items: Array = []
	for child in _spinning_part.get_children():
		if child is WheelItem:
			items.append(child)
	if items.is_empty():
		return

	var target: WheelItem = items[randi() % items.size()]
	var item_angle := target.position.angle()

	# Align target item to the top pointer (-PI/2 in Godot's Y-down system)
	var base := -PI / 2.0 - item_angle
	var current_r := _spinning_part.rotation
	var n := ceili((current_r + TAU - base) / TAU)
	var target_r := base + n * TAU

	_tween = create_tween()
	_tween.tween_property(_spinning_part, "rotation", target_r, spin_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
