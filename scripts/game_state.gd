extends Node

const SAVE_PATH := "user://save.json"

var current_level: int = 1
var completed_nodes: Array[String] = []
var current_combat_node_id: String = ""

var player_hp: int = 0
var player_max_hp: int = 0

var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_name: String = ""

func start_combat(node_id: String, level_data: Dictionary) -> void:
	current_combat_node_id = node_id
	if player_max_hp == 0:
		var p: Dictionary = level_data.get("player", {})
		player_max_hp = p.get("max_hp", 50)
		player_hp = p.get("hp", player_max_hp)
	var e: Dictionary = level_data.get("enemies", {}).get("default_combat", {})
	enemy_max_hp = e.get("max_hp", 50)
	enemy_hp = e.get("hp", enemy_max_hp)
	enemy_name = e.get("name", "Enemy")

func complete_current_combat() -> void:
	if current_combat_node_id != "" and current_combat_node_id not in completed_nodes:
		completed_nodes.append(current_combat_node_id)
	current_combat_node_id = ""
	save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data := {
		"current_level": current_level,
		"completed_nodes": completed_nodes,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data: Dictionary = json.get_data()
	current_level = data.get("current_level", 1)
	completed_nodes.clear()
	for s in data.get("completed_nodes", []):
		completed_nodes.append(str(s))
	player_hp = data.get("player_hp", 0)
	player_max_hp = data.get("player_max_hp", 0)

func reset_game() -> void:
	current_level = 1
	completed_nodes = []
	current_combat_node_id = ""
	player_hp = 0
	player_max_hp = 0
	enemy_hp = 0
	enemy_max_hp = 0
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.remove("save.json")
