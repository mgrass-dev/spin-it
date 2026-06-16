extends Node2D

const MAP_NODE_SCENE := preload("res://scenes/map_node.tscn")

const PATH_COLOR := Color(0.78, 0.55, 0.18)
const PATH_WIDTH := 14.0
const DASH_LEN := 18.0
const GAP_LEN := 12.0

const _NODE_ICONS := {
	"combat": "res://sprites/map/icon_combat.png",
	"boss": "res://sprites/map/icon_boss.png",
	"merchant": "res://sprites/map/icon_merchant.png",
	"start": "res://sprites/map/icon_start.png",
}

static func _level_params(level_id: int) -> Dictionary:
	match level_id:
		1:
			return {
				"max_combat": 4,
				"max_merchant": 1,
				"combat_enemy": {"name": "Gobelin", "hp": 25, "max_hp": 25},
				"boss": {"name": "Démon", "hp": 500, "max_hp": 500},
				"player": {"hp": 50, "max_hp": 50},
			}
		_:
			return _level_params(1)

@onready var paths_layer: Node2D = $PathsLayer
@onready var nodes_layer: Node2D = $NodesLayer
@onready var legend_panel: Sprite2D = $LegendPanel
@onready var boss_hp_bar: HPBar = $UILayer/BossHPBar
@onready var info_panel: Control = $UILayer/InfoPanel
@onready var mob_hp_bar: HPBar = $UILayer/InfoPanel/Margins/Layout/MobHPBar
@onready var start_button: Button = $UILayer/InfoPanel/Margins/Layout/StartButton

# Pixel bounds of the brown panel inside the 1920×1080 map_legend.png sprite
const _BROWN_RECT := Rect2(1600, 363, 290, 426)

var level_data: Dictionary = {}
var map_nodes: Dictionary = {}
var selected_node: MapNode = null

func _ready() -> void:
	_fit_info_panel()
	info_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	info_panel.visible = false
	start_button.pressed.connect(_on_start_pressed)
	_load_level(GameState.current_level)

func _fit_info_panel() -> void:
	var xform := legend_panel.get_global_transform()
	var center := Vector2(960, 540)  # half of 1920×1080
	var tl := xform * (_BROWN_RECT.position - center)
	var br := xform * (_BROWN_RECT.end - center)
	info_panel.offset_left   = tl.x
	info_panel.offset_top    = tl.y
	info_panel.offset_right  = br.x
	info_panel.offset_bottom = br.y

func _load_level(level_id: int) -> void:
	if GameState.level_data.is_empty():
		var params: Dictionary = _level_params(level_id)
		params["level_id"] = level_id
		params["seed"] = GameState.level_seed
		GameState.level_data = LevelGenerator.generate(params)
	level_data = GameState.level_data
	_build_map()

func _build_map() -> void:
	if "boss" in level_data:
		var b: Dictionary = level_data["boss"]
		boss_hp_bar.setup(
			load(_NODE_ICONS["boss"]),
			b.get("name", ""),
			b.get("hp", 0),
			b.get("max_hp", 0)
		)
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
	if selected_node != null:
		selected_node.set_selected(false)
	selected_node = mn
	selected_node.set_selected(true)
	info_panel.visible = true
	start_button.visible = mn.node_type != "start" and mn.node_type != "merchant"

	var icon_tex: Texture2D = load(_NODE_ICONS.get(mn.node_type, _NODE_ICONS["combat"]))

	match mn.node_type:
		"combat":
			var e: Dictionary = level_data.get("enemies", {}).get("default_combat", {})
			mob_hp_bar.setup(icon_tex, e.get("name", "Unknown"), e.get("hp", 0), e.get("max_hp", 0))
		"boss":
			var b: Dictionary = level_data.get("boss", {})
			mob_hp_bar.setup(icon_tex, b.get("name", "Unknown"), b.get("hp", 0), b.get("max_hp", 0))
		"merchant":
			mob_hp_bar.setup(icon_tex, "Merchant", 0, 0)
		_:
			mob_hp_bar.setup(null, "", 0, 0)

func _on_start_pressed() -> void:
	if selected_node == null:
		return
	GameState.start_combat(selected_node.node_id, level_data)
	get_tree().change_scene_to_file("res://scenes/combat.tscn")
