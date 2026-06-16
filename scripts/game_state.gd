extends Node

const SAVE_PATH := "user://save.json"
const INVENTORY_PATH := "user://inventory.json"
const ALL_ITEMS_PATH := "res://data/items/all_items.json"

const _InventoryItem = preload("res://scripts/inventory_item.gd")

var current_level: int = 1
var level_seed: int = 0
var level_data: Dictionary = {}
var completed_nodes: Array[String] = []
var current_combat_node_id: String = ""

var player_hp: int = 0
var player_max_hp: int = 0

var inventory: Array[Dictionary] = []
var equipped_wheel_slots: Array[Dictionary] = []
var _all_items: Array[Dictionary] = []

var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_name: String = ""
var enemy_gold: int = 0

func _ready() -> void:
	_load_all_items()

func _load_all_items() -> void:
	var file := FileAccess.open(ALL_ITEMS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data = json.get_data()
	if data is Array:
		_all_items.clear()
		for entry in data:
			if entry is Dictionary:
				_all_items.append(entry)

func get_all_items() -> Array[Dictionary]:
	return _all_items.duplicate()

func start_combat(node_id: String, level_data: Dictionary) -> void:
	current_combat_node_id = node_id
	if player_max_hp == 0:
		var p: Dictionary = level_data.get("player", {})
		player_max_hp = p.get("max_hp", 50)
		player_hp = p.get("hp", player_max_hp)

	var enemy_data: Dictionary
	for nd in level_data.get("nodes", []):
		if nd["id"] == node_id:
			if nd.get("type", "") == "boss":
				enemy_data = level_data.get("boss", {})
			else:
				var eid: String = nd.get("enemy_id", "")
				if eid.is_empty():
					var enemies: Dictionary = level_data.get("enemies", {})
					if not enemies.is_empty():
						eid = enemies.keys()[0]
				enemy_data = level_data.get("enemies", {}).get(eid, {})
			break
	if enemy_data.is_empty():
		var enemies: Dictionary = level_data.get("enemies", {})
		if not enemies.is_empty():
			enemy_data = enemies[enemies.keys()[0]]
	enemy_max_hp = enemy_data.get("max_hp", 50)
	enemy_hp = enemy_data.get("hp", enemy_max_hp)
	enemy_name = enemy_data.get("name", "Enemy")
	enemy_gold = enemy_data.get("gold", 0)

func complete_current_combat() -> void:
	if current_combat_node_id != "" and current_combat_node_id not in completed_nodes:
		completed_nodes.append(current_combat_node_id)
	current_combat_node_id = ""
	save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func add_item(data: Dictionary) -> void:
	inventory.append(_InventoryItem.create(data))

func remove_item(item_id: String) -> void:
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == item_id:
			inventory.remove_at(i)
			return

func get_item(item_id: String) -> Dictionary:
	for item in inventory:
		if item.get("id", "") == item_id:
			return item
	return {}

func has_item(item_id: String) -> bool:
	for item in inventory:
		if item.get("id", "") == item_id:
			return true
	return false

func get_gold() -> int:
	for item in inventory:
		if item.get("id", "") == "gold":
			return item.get("effects", {}).get("quantity", 0)
	return 0

func set_gold(amount: int) -> void:
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == "gold":
			inventory[i]["effects"]["quantity"] = amount
			return
	add_item({
		"id": "gold",
		"name": "Pièces d'or",
		"description": "La monnaie du royaume.",
		"type": "other",
		"icon_path": "",
		"rarity": "commun",
		"effects": {"quantity": amount},
	})

func add_gold(amount: int) -> void:
	set_gold(get_gold() + amount)

func spend_gold(amount: int) -> bool:
	var current := get_gold()
	if current < amount:
		return false
	set_gold(current - amount)
	return true

func get_modifier_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in inventory:
		if item.get("type", "") == "modifier":
			result.append(item)
	return result

func equip_wheel_slot(item_data: Dictionary) -> void:
	if equipped_wheel_slots.size() >= 20:
		return
	var effects: Dictionary = item_data.get("effects", {})
	equipped_wheel_slots.append({
		"item_id": item_data.get("id", ""),
		"value": effects.get("value", 1),
		"slot_color": effects.get("slot_color", "black"),
	})

func replace_slot(position: int, value: int, slot_color: String, item_id: String) -> void:
	for i in range(equipped_wheel_slots.size()):
		if equipped_wheel_slots[i].get("position", -1) == position:
			equipped_wheel_slots.remove_at(i)
			break
	equipped_wheel_slots.append({
		"item_id": item_id,
		"value": value,
		"slot_color": slot_color,
		"position": position,
	})

func get_slot_at_position(position: int) -> Dictionary:
	for eq in equipped_wheel_slots:
		if eq.get("position", -1) == position:
			return eq
	return {}

func find_node_data(node_id: String) -> Dictionary:
	if level_data.is_empty():
		return {}
	for nd in level_data.get("nodes", []):
		if nd["id"] == node_id:
			return nd
	return {}

func save_inventory() -> void:
	var data := {
		"inventory": inventory,
		"equipped_wheel_slots": equipped_wheel_slots,
	}
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_inventory() -> void:
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data = json.get_data()
	if data is Dictionary:
		inventory.clear()
		for entry in data.get("inventory", []):
			if entry is Dictionary:
				inventory.append(entry)
		equipped_wheel_slots.clear()
		for entry in data.get("equipped_wheel_slots", []):
			if entry is Dictionary:
				equipped_wheel_slots.append(entry)

func save_game() -> void:
	var data := {
		"current_level": current_level,
		"level_seed": level_seed,
		"level_data": level_data,
		"completed_nodes": completed_nodes,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
	save_inventory()

func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data: Dictionary = json.get_data()
	current_level = data.get("current_level", 1)
	level_seed = data.get("level_seed", 0)
	level_data = data.get("level_data", {})
	completed_nodes.clear()
	for s in data.get("completed_nodes", []):
		completed_nodes.append(str(s))
	player_hp = data.get("player_hp", 0)
	player_max_hp = data.get("player_max_hp", 0)
	load_inventory()

func reset_game() -> void:
	current_level = 1
	level_seed = randi()
	level_data = {}
	completed_nodes = []
	current_combat_node_id = ""
	player_hp = 0
	player_max_hp = 0
	enemy_hp = 0
	enemy_max_hp = 0
	inventory = []
	equipped_wheel_slots = []
	var dir := DirAccess.open("user://")
	if dir:
		if dir.file_exists("save.json"):
			dir.remove("save.json")
		if dir.file_exists("inventory.json"):
			dir.remove("inventory.json")
	add_item({
		"id": "bille",
		"name": "Bille",
		"description": "La bille blanche, votre outil de combat principal.",
		"type": "ball",
		"icon_path": "res://sprites/balls/ball_white.png",
		"rarity": "commun",
	})
