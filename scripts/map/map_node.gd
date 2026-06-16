extends Node2D
class_name MapNode

signal node_selected(map_node: MapNode)

const ICON_TEXTURES := {
	"combat": "res://sprites/map/icon_combat.png",
	"boss": "res://sprites/map/icon_boss.png",
	"merchant": "res://sprites/map/icon_merchant.png",
	"start": "res://sprites/map/icon_start.png",
}

const NODE_RADIUS := 48.0
const HALO_RADIUS := 60.0

var node_id: String = ""
var node_type: String = "combat"
var is_available: bool = false
var is_completed: bool = false

var _halo: Line2D
var _halo_tween: Tween

func setup(id: String, type: String, pos: Vector2) -> void:
	node_id = id
	node_type = type
	position = pos

	var sprite := Sprite2D.new()
	sprite.texture = load(ICON_TEXTURES.get(type, ICON_TEXTURES["combat"]))
	add_child(sprite)

	_setup_halo()

func _setup_halo() -> void:
	_halo = Line2D.new()
	_halo.width = 14.0
	_halo.default_color = Color(1.0, 0.85, 0.2, 0.9)
	_halo.z_index = 10
	var segments: int = 64
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle: float = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * HALO_RADIUS)
	_halo.points = points
	_halo.visible = false
	add_child(_halo)

func set_selected(enabled: bool) -> void:
	_halo.visible = enabled
	if _halo_tween and _halo_tween.is_valid():
		_halo_tween.kill()
	if enabled:
		_halo_tween = create_tween().set_loops()
		_halo_tween.tween_property(_halo, "modulate:a", 0.25, 0.5)
		_halo_tween.tween_property(_halo, "modulate:a", 1.0, 0.5)
	else:
		_halo.modulate.a = 1.0

func set_state(available: bool, completed: bool) -> void:
	is_available = available
	is_completed = completed
	if completed:
		modulate = Color(0.5, 0.5, 0.5, 0.85)
	elif available:
		modulate = Color.WHITE
	else:
		modulate = Color(0.35, 0.35, 0.35, 0.65)

func _unhandled_input(event: InputEvent) -> void:
	if not is_available:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_local_mouse_position().length() <= NODE_RADIUS:
		node_selected.emit(self)
		get_viewport().set_input_as_handled()
