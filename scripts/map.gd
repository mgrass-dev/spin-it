extends Node2D

const LEVEL_PATH := "res://data/levels/level_%d.json"
const MAP_NODE_SCENE := preload("res://scenes/map_node.tscn")

const PATH_COLOR := Color(0.78, 0.55, 0.18)
const PATH_WIDTH := 14.0
const DASH_LEN := 18.0
const GAP_LEN := 12.0

@onready var paths_layer: Node2D = $PathsLayer
@onready var nodes_layer: Node2D = $NodesLayer
@onready var boss_hp_bar: ProgressBar = $UILayer/BossSection/HPBar
@onready var info_panel: Control = $UILayer/InfoPanel
@onready var node_label: Label = $UILayer/InfoPanel/NodeLabel
@onready var start_button: Button = $UILayer/InfoPanel/StartButton

var level_data: Dictionary = {}
var map_nodes: Dictionary = {}
var selected_node: MapNode = null

func _ready() -> void:
	_style_hp_bar()
	info_panel.visible = false
	start_button.pressed.connect(_on_start_pressed)
	_load_level(GameState.current_level)

func _style_hp_bar() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.1, 0.1)
	fill.set_corner_radius_all(4)
	boss_hp_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.05, 0.05)
	bg.set_corner_radius_all(4)
	boss_hp_bar.add_theme_stylebox_override("background", bg)

func _load_level(level_id: int) -> void:
	var path := LEVEL_PATH % level_id
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot load level: " + path)
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	level_data = json.get_data()
	file.close()
	_build_map()

func _build_map() -> void:
	if "boss" in level_data:
		boss_hp_bar.max_value = level_data["boss"]["max_hp"]
		boss_hp_bar.value = level_data["boss"]["hp"]
	_draw_paths()
	_create_nodes()
	_apply_state()

func _draw_paths() -> void:
	for node_data in level_data["nodes"]:
		var from := Vector2(node_data["position"][0], node_data["position"][1])
		for target_id: String in node_data["connections"]:
			var target := _find_node_data(target_id)
			if target.is_empty():
				continue
			var to := Vector2(target["position"][0], target["position"][1])
			_draw_dashed_line(from, to)

func _draw_dashed_line(from: Vector2, to: Vector2) -> void:
	var total := from.distance_to(to)
	var dir := (to - from).normalized()
	var drawn := 0.0
	var step := DASH_LEN + GAP_LEN
	while drawn < total:
		var p0 := from + dir * drawn
		var p1 := from + dir * minf(drawn + DASH_LEN, total)
		var seg := Line2D.new()
		seg.width = PATH_WIDTH
		seg.default_color = PATH_COLOR
		seg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		seg.end_cap_mode = Line2D.LINE_CAP_ROUND
		seg.add_point(p0)
		seg.add_point(p1)
		paths_layer.add_child(seg)
		drawn += step

func _create_nodes() -> void:
	for node_data in level_data["nodes"]:
		var mn := MAP_NODE_SCENE.instantiate() as MapNode
		nodes_layer.add_child(mn)
		var pos := Vector2(node_data["position"][0], node_data["position"][1])
		mn.setup(node_data["id"], node_data["type"], pos)
		mn.node_selected.connect(_on_node_selected)
		map_nodes[node_data["id"]] = mn

func _apply_state() -> void:
	for id: String in map_nodes:
		var mn := map_nodes[id] as MapNode
		mn.set_state(
			_is_node_available(id),
			id in GameState.completed_nodes
		)

func _is_node_available(node_id: String) -> bool:
	if node_id in GameState.completed_nodes:
		return false
	if node_id == "start":
		return false
	for node_data in level_data["nodes"]:
		if node_id in node_data.get("connections", []):
			var parent_id: String = node_data["id"]
			if parent_id == "start" or parent_id in GameState.completed_nodes:
				return true
	return false

func _find_node_data(id: String) -> Dictionary:
	for node_data in level_data["nodes"]:
		if node_data["id"] == id:
			return node_data
	return {}

func _on_node_selected(mn: MapNode) -> void:
	selected_node = mn
	info_panel.visible = true
	node_label.text = _type_label(mn.node_type)

func _type_label(type: String) -> String:
	match type:
		"combat": return "Combat"
		"boss": return "Boss Final"
		"merchant": return "Marchand"
		_: return ""

func _on_start_pressed() -> void:
	if selected_node == null:
		return
	GameState.start_combat(selected_node.node_id)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
