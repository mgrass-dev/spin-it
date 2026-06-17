extends Node2D

const MAP_NODE_SCENE := preload("res://scenes/map/map_node.tscn")

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
	var path := "res://data/levels/level_%d.json" % level_id
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json := JSON.new()
		json.parse(file.get_as_text())
		file.close()
		var data = json.get_data()
		if data is Dictionary and data.get("nodes") != null:
			return {
				"id": level_id,
				"boss": data.get("boss", {}),
				"player": data.get("player", {}),
				"nodes": data.get("nodes", []),
				"enemies": data.get("enemies", {}),
			}
	return _fallback_params(level_id)

static func _fallback_params(level_id: int) -> Dictionary:
	match level_id:
		1:
			return {
				"max_combat": 4,
				"max_merchant": 1,
				"enemies": {
					"slime": {"name": "Slime", "hp": 18, "max_hp": 18, "gold": 1},
					"goblin": {"name": "Gobelin", "hp": 25, "max_hp": 25, "gold": 4},
					"orc": {"name": "Orc", "hp": 100, "max_hp": 100, "gold": 12},
				},
				"boss": {"name": "Démon", "hp": 500, "max_hp": 500, "gold": 20},
				"player": {"hp": 50, "max_hp": 50},
			}
		_:
			return _fallback_params(1)

@onready var paths_layer: Node2D = $MapContainer/PathsLayer
@onready var nodes_layer: Node2D = $MapContainer/NodesLayer
@onready var legend_panel: Sprite2D = $LegendPanel
@onready var boss_hp_bar: HPBar = $UILayer/BossHPBar
@onready var info_panel: Control = $UILayer/InfoPanel
@onready var mob_hp_bar: HPBar = $UILayer/InfoPanel/Margins/Layout/MobHPBar
@onready var start_button: Button = $UILayer/InfoPanel/Margins/Layout/StartButton
@onready var wheel_preview_btn: Button = $UILayer/WheelPreviewBtn
@onready var map_container: Node2D = $MapContainer

# Pixel bounds of the brown panel inside the 1920×1080 map_legend.png sprite
const _BROWN_RECT := Rect2(1575, 363, 265, 416)

var level_data: Dictionary = {}
var map_nodes: Dictionary = {}
var selected_node: MapNode = null

const PANEL_SHIFT_X := -144.0
var _map_tween: Tween
var _map_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	_fit_info_panel()
	info_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	info_panel.visible = false
	legend_panel.visible = false
	start_button.pressed.connect(_on_start_pressed)
	start_button.get_node("ButtonLabel").add_theme_color_override("font_color", Color.WHITE)
	wheel_preview_btn.pressed.connect(_on_wheel_preview_pressed)
	wheel_preview_btn.get_node("ButtonLabel").text = "Roue"
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
		if params.has("nodes"):
			GameState.level_data = params
		else:
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
	_center_map()
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
	if selected_node == mn:
		selected_node.set_selected(false)
		selected_node = null
		info_panel.visible = false
		legend_panel.visible = false
		_shift_map(false)
		return
	if selected_node != null:
		selected_node.set_selected(false)
	selected_node = mn
	selected_node.set_selected(true)
	info_panel.visible = true
	legend_panel.visible = true
	_shift_map(true)
	if mn.node_type == "merchant":
		start_button.visible = true
		start_button.get_node("ButtonLabel").text = "Visit"
	else:
		start_button.visible = mn.node_type != "start"
		start_button.get_node("ButtonLabel").text = "Start"

	var icon_tex: Texture2D = load(_NODE_ICONS.get(mn.node_type, _NODE_ICONS["combat"]))

	match mn.node_type:
		"combat":
			var node_data := _find_node_data(mn.node_id)
			var e: Dictionary = LevelGenerator.get_enemy_data(level_data, node_data)
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
	if selected_node.node_type == "merchant":
		_open_merchant()
		return
	GameState.start_combat(selected_node.node_id, level_data)
	get_tree().change_scene_to_file("res://scenes/combat/combat.tscn")

func _on_wheel_preview_pressed() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var wheel := preload("res://scenes/combat/wheel.tscn").instantiate()
	wheel.position = Vector2(640, 340)
	wheel.scale = Vector2(0.85, 0.85)
	overlay.add_child(wheel)

	var close_btn := preload("res://scenes/ui/button.tscn").instantiate()
	close_btn.get_node("ButtonLabel").text = "Fermer"
	close_btn.size = Vector2(160, 40)
	close_btn.position = Vector2(640 - 80, 650)
	close_btn.pressed.connect(func():
		overlay.queue_free()
	)
	overlay.add_child(close_btn)

func _open_merchant() -> void:
	var reward = load("res://scripts/combat/reward_popup.gd").new()
	reward.is_merchant_mode = true
	add_child(reward)
	reward.closed.connect(_on_merchant_closed)

func _on_merchant_closed() -> void:
	if selected_node:
		GameState.completed_nodes.append(selected_node.node_id)
		GameState.save_game()
		selected_node.set_selected(false)
		selected_node = null
		info_panel.visible = false
		legend_panel.visible = false
		_shift_map(false)
	_apply_state()

func _shift_map(show: bool) -> void:
	if _map_tween and _map_tween.is_valid():
		_map_tween.kill()
	_map_tween = create_tween()
	var target_x := _map_center.x + (PANEL_SHIFT_X if show else 0.0)
	_map_tween.tween_property(map_container, "position:x", target_x, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _center_map() -> void:
	if map_nodes.is_empty():
		return
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for mn in map_nodes.values():
		min_x = min(min_x, mn.position.x)
		max_x = max(max_x, mn.position.x)
		min_y = min(min_y, mn.position.y)
		max_y = max(max_y, mn.position.y)
	var center := Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
	_map_center = Vector2(640, 360) - center
	map_container.position = _map_center
