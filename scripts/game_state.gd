extends Node

var current_level: int = 1
var completed_nodes: Array[String] = []
var current_combat_node_id: String = ""

func start_combat(node_id: String) -> void:
	current_combat_node_id = node_id

func complete_current_combat() -> void:
	if current_combat_node_id != "" and current_combat_node_id not in completed_nodes:
		completed_nodes.append(current_combat_node_id)
	current_combat_node_id = ""
