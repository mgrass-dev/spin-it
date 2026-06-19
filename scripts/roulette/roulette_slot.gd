class_name RouletteSlot
extends Node2D

signal clicked(slot_index: int)

var slot_index: int = 0
var slot_number: int = 0
var rarity: String = "common"
var effects: Array = []
var modifiers: Array = []
var rewards: Array = []

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area: Area2D = $ClickArea
@onready var _label: Label = get_node_or_null("Label") as Label

var _hovered: bool = false
var _ball_over: bool = false
var _highlighted: bool = false
var _hover_tween: Tween

func _ready() -> void:
	_update_display()
	# Click detection is handled by RouletteWheel._input() (fires before GUI)
	# Area2D input_event is kept for possible future use but not connected here.

func setup(data: Dictionary) -> void:
	slot_index = data.get("index", 0)
	slot_number = data.get("number", slot_index + 1)
	rarity = data.get("rarity", "common")
	effects = data.get("effects", [])
	modifiers = data.get("modifiers", [])
	rewards = data.get("rewards", [])
	var tex = data.get("texture", null)
	if tex and _sprite:
		_sprite.texture = tex
	if is_node_ready():
		_update_display()

func _update_display() -> void:
	if _label:
		_label.text = str(slot_number)

func _on_click_area_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	# NOTE: not connected by default — use RouletteWheel._input() instead
	pass

# Called by parent each frame with mouse hit-test result.
func set_hovered(hovered: bool) -> void:
	if hovered == _hovered:
		return
	_hovered = hovered
	_sync_highlight()

# Called by parent each frame with ball hit-test result.
func set_ball_over(over: bool) -> void:
	if over == _ball_over:
		return
	_ball_over = over
	_sync_highlight()

func _sync_highlight() -> void:
	var active: bool = _hovered or _ball_over
	if active == _highlighted:
		return
	_highlighted = active
	if active:
		_play_hover_in()
	else:
		_play_hover_out()

func _play_hover_in() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	# DEBUG: very visible effect — scale up and tint bright yellow
	_hover_tween.tween_property(_sprite, "scale", Vector2(1.3, 1.3), 0.1)
	_hover_tween.tween_property(_sprite, "modulate", Color(2.0, 2.0, 0.5, 1.0), 0.1)

func _play_hover_out() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	_hover_tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
