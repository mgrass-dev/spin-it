extends Node2D
class_name MapNode

signal node_selected(map_node: MapNode)

const ICON_TEXTURES := {
	"combat": "res://sprites/map/icone_combat.png",
	"boss": "res://sprites/map/icone_boss.png",
	"merchant": "res://sprites/map/icone_marchand.png",
	"start": "res://sprites/map/icone_départ.png",
}

const NODE_RADIUS := 48.0

var node_id: String = ""
var node_type: String = "combat"
var is_available: bool = false
var is_completed: bool = false

func setup(id: String, type: String, pos: Vector2) -> void:
	node_id = id
	node_type = type
	position = pos

	var sprite := Sprite2D.new()
	sprite.texture = load(ICON_TEXTURES.get(type, ICON_TEXTURES["combat"]))
	add_child(sprite)

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
