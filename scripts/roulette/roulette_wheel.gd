class_name RouletteWheel
extends Node2D

const SLOT_SCENE   := preload("res://scenes/roulette/roulette_slot.tscn")
const BG_TEXTURE   := preload("res://sprites/roue/backgroundring.png")
const TEX_RED      := preload("res://sprites/roue/inclinecase.png")
const TEX_BLACK    := preload("res://sprites/roue/inclinecasenoir.png")
const BALL_TEXTURE := preload("res://sprites/balls/ball_white.png")

const SLOT_HALF:  Vector2 = Vector2(48.0, 64.0)
const LABEL_HALF: Vector2 = Vector2(16.0, 10.0)

enum BallState { IDLE, ORBITING, DROPPING, SETTLED }

signal result_ready(slot_number: int)
signal slot_selected(slot_index: int)

# ── Inspector tunables ────────────────────────────────────────────────────────

@export var selection_mode: bool = false
@export var slot_count: int = 20
@export var wheel_scale: float = 0.625
@export var base_scale: float = 2.0
@export var ring_radius: float = 290.0
@export var visual_y_scale: float = 0.50
@export var slot_overlap: float = 10.0
@export var ring_x_offset: float = 0.0
@export var ring_y_offset: float = 0.0
@export var number_font_size: int = 18
@export var number_y_offset: float = -35.0
@export var y_sort_strength: float = 10.0
@export var bg_ring_count: int = 60

@export var center_disc_scale: float = 2.0
@export var center_disc_x_offset: float = 0.0
@export var center_disc_y_offset: float = 0.0

@export var ball_outer_radius: float = 340.0
@export var ball_start_speed: float = 7.0
@export var ball_friction: float = 1.1
@export var ball_drop_threshold: float = 2.0
@export var ball_drop_duration: float = 1.0
@export var min_ball_spin_time: float = 2.0
@export var random_ball_spin_time_min: float = 0.5
@export var random_ball_spin_time_max: float = 2.0
@export var ball_display_size: float = 25.0
@export var ball_landing_local_x: float = 0.0
@export var ball_landing_local_y: float = 40.0
@export var ball_landing_random_x: float = 24.0
@export var ball_landing_random_y: float = 28.0
@export var wheel_launch_speed: float = 5.5

# ── Runtime ───────────────────────────────────────────────────────────────────

## Read by parent to guard against double-launch.
var is_running: bool = false

var _slots:       Array[RouletteSlot] = []
var _slot_labels: Array[Label]        = []
var _spin_angle:  float = 0.0
var _spin_speed:  float = 0.0
var _wheel_tween: Tween

var _ball_state:    BallState = BallState.IDLE
var _ball_angle:    float     = 0.0
var _ball_velocity: float     = 0.0
var _ball_radius:   float     = 0.0
var _ball_time:     float     = 0.0
var _ball_sprite:          Sprite2D
var _winning_slot_index:   int = -1
var _settle_start_time:    float = 0.0
var _settle_progress:      float = 1.0
var _settle_tween:         Tween
var _settle_random_offset: Vector2 = Vector2.ZERO

@onready var _base_sprite:       Sprite2D  = $BaseSprite
@onready var _bg_slot_ring:      Node2D    = $BackgroundSlotRing
@onready var _slot_ring:         Node2D    = $SlotRing
@onready var _center_disc:       Sprite2D  = $CenterDiscParent/CenterDisc
@onready var _pointer:           Polygon2D = $Pointer
@onready var _numbers_container: Control   = $CanvasLayer/NumbersContainer

# ── Init ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	self.scale = Vector2(wheel_scale, wheel_scale)
	_base_sprite.scale = Vector2(base_scale, base_scale)
	for ring in [_bg_slot_ring, _slot_ring]:
		ring.scale    = Vector2(1.0, visual_y_scale)
		ring.position = Vector2(ring_x_offset, ring_y_offset)
	_center_disc.get_parent().scale    = Vector2(1.0, visual_y_scale)
	_center_disc.get_parent().position = Vector2(ring_x_offset, ring_y_offset)
	_center_disc.position = Vector2(center_disc_x_offset, center_disc_y_offset)
	_center_disc.scale    = Vector2(center_disc_scale, center_disc_scale)
	_pointer.position = Vector2(ring_x_offset,
		ring_y_offset - (ring_radius * visual_y_scale + 18.0))
	if not selection_mode:
		_create_ball_sprite()
	_build_wheel()
	if selection_mode:
		load_player_slots()

func _create_ball_sprite() -> void:
	_ball_sprite = Sprite2D.new()
	_ball_sprite.texture        = BALL_TEXTURE
	_ball_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball_sprite.z_index        = 45
	_ball_sprite.visible        = false
	var tex_size: Vector2 = BALL_TEXTURE.get_size()
	var s: float = ball_display_size / maxf(tex_size.x, tex_size.y)
	_ball_sprite.scale = Vector2(s, s)
	add_child(_ball_sprite)

# ── Wheel construction ────────────────────────────────────────────────────────

func _build_wheel() -> void:
	for slot in _slots:
		if is_instance_valid(slot): slot.queue_free()
	_slots.clear()
	for label in _slot_labels:
		if is_instance_valid(label): label.queue_free()
	_slot_labels.clear()
	for child in _bg_slot_ring.get_children():
		child.queue_free()

	_build_background_ring()

	var data_array := _generate_slot_data()
	for i in slot_count:
		var slot: RouletteSlot = SLOT_SCENE.instantiate()
		_slot_ring.add_child(slot)
		slot.setup(data_array[i])
		slot.clicked.connect(_on_slot_clicked)
		_slots.append(slot)

		var label := Label.new()
		label.text = str(data_array[i]["number"])
		label.add_theme_font_size_override("font_size", number_font_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size  = Vector2(LABEL_HALF.x * 2.0, LABEL_HALF.y * 2.0)
		label.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		_numbers_container.add_child(label)
		_slot_labels.append(label)

	_update_slot_positions()

func _build_background_ring() -> void:
	var angle_step: float       = TAU / bg_ring_count
	var effective_radius: float = ring_radius - slot_overlap
	for i in bg_ring_count:
		var t: float = i * angle_step
		var sprite   := Sprite2D.new()
		sprite.texture        = BG_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position       = Vector2(cos(t), sin(t)) * effective_radius
		sprite.rotation       = t + PI / 2.0
		sprite.z_index        = -1
		_bg_slot_ring.add_child(sprite)

func _generate_slot_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for i in slot_count:
		data.append({
			"index":     i,
			"number":    i + 1,
			"rarity":    "common",
			"effects":   [],
			"modifiers": [],
			"rewards":   [],
			"texture":   TEX_RED if i % 2 == 0 else TEX_BLACK,
		})
	return data

# ── Selection mode ───────────────────────────────────────────────────────────

func load_player_slots() -> void:
	for i in slot_count:
		var slot_data := GameState.get_slot_at_position(i)
		if slot_data.is_empty():
			continue
		var tex := TEX_RED if slot_data.get("slot_color", "black") == "red" else TEX_BLACK
		_slots[i].setup({
			"index":    i,
			"number":   slot_data.get("value", i + 1),
			"rarity":   "common",
			"effects":  [],
			"modifiers": [],
			"rewards":  [],
			"texture":  tex,
		})
		_slot_labels[i].text = str(slot_data.get("value", i + 1))

func _on_slot_clicked(slot_index: int) -> void:
	if selection_mode:
		print("[wheel] _on_slot_clicked slot=", slot_index, " — emitting slot_selected")
		slot_selected.emit(slot_index)
	else:
		print("[wheel] _on_slot_clicked slot=", slot_index, " — ignored (not selection_mode)")

# ── Input (fires before GUI processing — cannot be blocked by overlays) ──────

func _input(event: InputEvent) -> void:
	if not selection_mode:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var mouse_world: Vector2 = get_global_mouse_position()
	for i in _slots.size():
		var local: Vector2 = _slots[i].to_local(mouse_world)
		if abs(local.x) <= SLOT_HALF.x and abs(local.y) <= SLOT_HALF.y:
			print("[wheel] _input click slot=", i, " emitting slot_selected")
			slot_selected.emit(i)
			get_viewport().set_input_as_handled()
			return

# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _spin_speed != 0.0:
		_spin_angle += _spin_speed * delta
		_update_slot_positions()
	_update_hover()
	_process_ball(delta)

func _process_ball(delta: float) -> void:
	match _ball_state:
		BallState.ORBITING:
			_ball_time += delta
			_ball_velocity = move_toward(_ball_velocity, 0.0, ball_friction * delta)
			_ball_angle   += _ball_velocity * delta
			_update_ball_visual()
			if _ball_time >= _settle_start_time:
				_start_ball_drop()
		BallState.DROPPING, BallState.SETTLED:
			_update_ball_visual()

func _update_ball_visual() -> void:
	if _winning_slot_index >= 0:
		var angle_step: float = TAU / slot_count
		var slot: RouletteSlot = _slots[_winning_slot_index]
		_ball_angle = _spin_angle + _winning_slot_index * angle_step
		var raw_x: float = cos(_ball_angle) * _ball_radius + ring_x_offset
		var raw_y: float = sin(_ball_angle) * _ball_radius * visual_y_scale + ring_y_offset
		var raw_pos: Vector2 = Vector2(raw_x, raw_y)
		var local_offset: Vector2 = Vector2(ball_landing_local_x, ball_landing_local_y) + _settle_random_offset
		var target_local: Vector2 = to_local(slot.to_global(local_offset))
		_ball_sprite.position = raw_pos.lerp(target_local, _settle_progress)
	else:
		var bx: float = cos(_ball_angle) * _ball_radius + ring_x_offset
		var by: float = sin(_ball_angle) * _ball_radius * visual_y_scale + ring_y_offset
		_ball_sprite.position = Vector2(bx, by)
	var sin_t: float = sin(_ball_angle)
	_ball_sprite.z_index = int(remap(sin_t, -1.0, 1.0, 5, 45))

# ── Launch sequence ───────────────────────────────────────────────────────────

func launch() -> void:
	if is_running:
		return
	is_running = true
	_winning_slot_index = -1
	_settle_progress = 1.0
	_settle_random_offset = Vector2.ZERO
	_ball_time = 0.0
	_settle_start_time = min_ball_spin_time + randf_range(
		random_ball_spin_time_min, random_ball_spin_time_max
	)

	if _wheel_tween and _wheel_tween.is_valid():
		_wheel_tween.kill()
	_spin_speed = wheel_launch_speed

	_ball_angle    = -PI / 2.0 + randf_range(-0.3, 0.3)
	_ball_velocity = -ball_start_speed
	_ball_radius   = ball_outer_radius
	_ball_state    = BallState.ORBITING
	_ball_sprite.visible = true
	_update_ball_visual()

func _start_ball_drop() -> void:
	_ball_state = BallState.DROPPING
	var effective_radius: float = ring_radius - slot_overlap
	var tween := create_tween()
	tween.tween_method(
		func(r: float): _ball_radius = r,
		_ball_radius, effective_radius, ball_drop_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_ball_settled)

	if _wheel_tween and _wheel_tween.is_valid():
		_wheel_tween.kill()
	_wheel_tween = create_tween()
	_wheel_tween.tween_method(
		func(s: float): _spin_speed = s,
		_spin_speed, 0.0, ball_drop_duration + 3.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_ball_settled() -> void:
	_ball_state  = BallState.SETTLED
	_ball_radius = ring_radius - slot_overlap
	is_running   = false
	var winner := _get_slot_at_angle(_ball_angle)
	if winner:
		_winning_slot_index = winner.slot_index
		_settle_progress = 0.0
		_settle_random_offset = Vector2(
			randf_range(-ball_landing_random_x, ball_landing_random_x),
			randf_range(-ball_landing_random_y, ball_landing_random_y)
		)
		_settle_random_offset.x = clamp(_settle_random_offset.x,
			-SLOT_HALF.x + 8.0 - ball_landing_local_x,
			SLOT_HALF.x - 8.0 - ball_landing_local_x)
		_settle_random_offset.y = clamp(_settle_random_offset.y,
			8.0 - ball_landing_local_y,
			SLOT_HALF.y - 8.0 - ball_landing_local_y)
		if _settle_tween and _settle_tween.is_valid():
			_settle_tween.kill()
		_settle_tween = create_tween()
		_settle_tween.tween_method(
			func(p: float): _settle_progress = p,
			0.0, 1.0, 0.3
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	result_ready.emit(winner.slot_number if winner else -1)

# ── Slot / hover layout ───────────────────────────────────────────────────────

func _update_slot_positions() -> void:
	var angle_step: float       = TAU / slot_count
	var effective_radius: float = ring_radius - slot_overlap
	_center_disc.rotation = _spin_angle
	for i in slot_count:
		var t: float     = _spin_angle + i * angle_step
		var sin_t: float = sin(t)
		_slots[i].position = Vector2(cos(t), sin_t) * effective_radius
		_slots[i].rotation = t + PI / 2.0
		_slots[i].scale    = Vector2(1.0, 1.0)
		_slots[i].z_index  = int(remap(sin_t, -1.0, 1.0, 0.0, y_sort_strength))
		var xform: Transform2D  = _slots[i].get_global_transform_with_canvas()
		var screen_pos: Vector2 = xform * Vector2(0.0, number_y_offset)
		_slot_labels[i].position = screen_pos - LABEL_HALF

func _update_hover() -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	var ball_valid := is_instance_valid(_ball_sprite)
	var ball_visible := ball_valid and _ball_sprite.visible
	var ball_world: Vector2 = _ball_sprite.global_position if ball_visible else Vector2(INF, INF)
	for slot in _slots:
		var local: Vector2 = slot.to_local(mouse_world)
		var hit: bool = abs(local.x) <= SLOT_HALF.x and abs(local.y) <= SLOT_HALF.y
		slot.set_hovered(hit)
		if ball_visible:
			var ball_local: Vector2 = slot.to_local(ball_world)
			var ball_hit: bool = abs(ball_local.x) <= SLOT_HALF.x and abs(ball_local.y) <= SLOT_HALF.y
			slot.set_ball_over(ball_hit)

func _get_slot_at_angle(target_angle: float) -> RouletteSlot:
	var angle_step: float  = TAU / slot_count
	var best: RouletteSlot = null
	var best_dist: float   = INF
	for i in slot_count:
		var t: float    = _spin_angle + i * angle_step
		var diff: float = fmod(t - target_angle + PI, TAU) - PI
		if abs(diff) < best_dist:
			best_dist = abs(diff)
			best = _slots[i]
	return best
