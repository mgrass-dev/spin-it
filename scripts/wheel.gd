extends Node2D

const WHEEL_ITEM_SCENE = preload("res://scenes/wheel_item.tscn")

@export var spin_duration: float = 5.0
@export var item_count: int = 20
@export var item_radius: float = 145.0

@onready var _spinning_part: Node2D = $SpinningPart

var _tween: Tween
var _halo_tween: Tween
var _spin_speed: float = 0.0
var _halo: Line2D

signal spin_completed(item: WheelItem)

func _ready() -> void:
	_setup_halo()
	_setup_items()

func _process(delta: float) -> void:
	if _spin_speed != 0.0:
		_spinning_part.rotation += _spin_speed * delta

func _setup_halo() -> void:
	_halo = Line2D.new()
	_halo.width = 14.0
	_halo.default_color = Color(1.0, 0.85, 0.2, 0.9)
	_halo.z_index = 10
	var segments: int = 64
	var radius: float = 265.0
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle: float = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	_halo.points = points
	_halo.visible = false
	add_child(_halo)

func _setup_items() -> void:
	var angle_step: float = TAU / item_count

	var equipped_by_pos: Dictionary = {}
	var used_positions: Array[int] = []
	for eq in GameState.equipped_wheel_slots:
		var p: int = eq.get("position", -1)
		if p >= 0 and p < item_count:
			equipped_by_pos[p] = eq
			used_positions.append(p)

	var unplaced: Array[Dictionary] = []
	for eq in GameState.equipped_wheel_slots:
		var p: int = eq.get("position", -1)
		if p < 0 or p >= item_count:
			unplaced.append(eq)

	for eq in unplaced:
		var p: int = randi() % item_count
		while p in used_positions:
			p = randi() % item_count
		equipped_by_pos[p] = eq
		used_positions.append(p)

	var default_values: Array = Array(range(1, item_count + 1))
	default_values.shuffle()

	for i in item_count:
		var item: WheelItem = WHEEL_ITEM_SCENE.instantiate()
		var angle: float = i * angle_step
		item.position = Vector2(cos(angle), sin(angle)) * item_radius
		item.rotation = angle + PI / 2
		item.z_index = 1
		if i in equipped_by_pos:
			var eq: Dictionary = equipped_by_pos[i]
			item.slot_color = WheelItem.SlotColor.BLACK if eq.get("slot_color", "black") == "black" else WheelItem.SlotColor.RED
			item.modifier = eq.get("value", 1)
		else:
			item.slot_color = WheelItem.SlotColor.BLACK if i % 2 == 0 else WheelItem.SlotColor.RED
			item.modifier = default_values[i]
		_spinning_part.add_child(item)

func get_wheel_items() -> Array[WheelItem]:
	var result: Array[WheelItem] = []
	for child in _spinning_part.get_children():
		if child is WheelItem:
			result.append(child)
	return result

func get_wheel_item_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in _spinning_part.get_children():
		if child is WheelItem:
			result.append({
				"index": result.size(),
				"value": child.modifier,
				"slot_color": "black" if child.slot_color == WheelItem.SlotColor.BLACK else "red",
				"position": child.position,
				"rotation": child.rotation,
			})
	return result

func replace_slot(index: int, value: int, slot_color_str: String) -> void:
	var items := get_wheel_items()
	if index < 0 or index >= items.size():
		return
	var item: WheelItem = items[index]
	var color_enum: WheelItem.SlotColor = WheelItem.SlotColor.BLACK if slot_color_str == "black" else WheelItem.SlotColor.RED
	item.slot_color = color_enum
	item.modifier = value

func start_spinning() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_spin_speed = TAU * 3.5

func stop_spinning() -> void:
	_spin_speed = 0.0
	if _tween and _tween.is_valid():
		_tween.kill()

func stop_on_random_item() -> Dictionary:
	var current_speed: float = _spin_speed
	_spin_speed = 0.0
	if _tween and _tween.is_valid():
		_tween.kill()

	var items: Array = get_wheel_items()
	if items.is_empty():
		return {}

	var target: WheelItem = items[randi() % items.size()]
	var item_angle: float = target.position.angle()

	var base: float = -PI / 2.0 - item_angle
	var current_r: float = _spinning_part.rotation
	var n: int = ceili((current_r + 3.0 * TAU - base) / TAU)
	var target_r: float = base + n * TAU
	var distance: float = target_r - current_r

	var computed_duration: float
	if current_speed > 0.1:
		computed_duration = clamp(3.0 * distance / current_speed, 3.0, 10.0)
	else:
		computed_duration = spin_duration

	_tween = create_tween()
	_tween.tween_property(_spinning_part, "rotation", target_r, computed_duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	_tween.finished.connect(func(): spin_completed.emit(target))

	return {
		"item": target,
		"target_r": target_r,
		"initial_r": current_r,
	}

func set_highlight(enabled: bool) -> void:
	_halo.visible = enabled
	if _halo_tween and _halo_tween.is_valid():
		_halo_tween.kill()
	if enabled:
		_halo_tween = create_tween().set_loops()
		_halo_tween.tween_property(_halo, "modulate:a", 0.25, 0.5)
		_halo_tween.tween_property(_halo, "modulate:a", 1.0, 0.5)
	else:
		_halo.modulate.a = 1.0

func get_item_world_radius() -> float:
	return item_radius * scale.x

func get_spinning_rotation() -> float:
	return _spinning_part.rotation
