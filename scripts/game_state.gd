extends Node

var current_level: int = 1
var completed_nodes: Array[String] = []
var current_combat_node_id: String = ""

# Player HP persists across combats in the same run
var player_hp: int = 0
var player_max_hp: int = 0

# Enemy HP resets each combat
var enemy_hp: int = 0
var enemy_max_hp: int = 0

func start_combat(node_id: String, level_data: Dictionary) -> void:
	current_combat_node_id = node_id
	# Init player HP only once per run
	if player_max_hp == 0:
		var p: Dictionary = level_data.get("player", {})
		player_max_hp = p.get("max_hp", 50)
		player_hp = p.get("hp", player_max_hp)
	# Reset enemy HP for each combat
	var e: Dictionary = level_data.get("enemies", {}).get("default_combat", {})
	enemy_max_hp = e.get("max_hp", 50)
	enemy_hp = e.get("hp", enemy_max_hp)

func complete_current_combat() -> void:
	if current_combat_node_id != "" and current_combat_node_id not in completed_nodes:
		completed_nodes.append(current_combat_node_id)
	current_combat_node_id = ""
