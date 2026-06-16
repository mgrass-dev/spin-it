class_name LevelGenerator

const CENTER_X := 515.0
const START_Y := 600.0
const BOSS_Y := 150.0
const MIN_NODE_SPACING := 80.0

static func generate(params: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = params.get("seed", randi())

	var level_id: int = params.get("level_id", 1)
	var num_combat: int = params.get("max_combat", 4)
	var num_merchant: int = params.get("max_merchant", 1)

	var enemies: Dictionary = params.get("enemies", {
		"default_combat": {"name": "Gobelin", "hp": 25, "max_hp": 25, "gold": 4}
	})
	var enemy_ids: Array[String] = []
	for k in enemies:
		enemy_ids.append(k)
	var boss_data: Dictionary = params.get("boss", {"name": "Démon", "hp": 500, "max_hp": 500, "gold": 20})
	var player_data: Dictionary = params.get("player", {"hp": 50, "max_hp": 50})

	var type_list: Array[String] = []
	for i in num_combat:
		type_list.append("combat")
	for i in num_merchant:
		type_list.append("merchant")
	type_list.shuffle()

	var nodes: Array[Dictionary] = []

	nodes.append({
		"id": "start",
		"type": "start",
		"position": [CENTER_X, START_Y],
		"connections": []
	})

	nodes.append({
		"id": "boss",
		"type": "boss",
		"position": [CENTER_X, BOSS_Y],
		"connections": []
	})

	if type_list.is_empty():
		nodes[0]["connections"].append("boss")
		return _build_level(level_id, boss_data, player_data, nodes, enemies, enemy_ids)

	var layers: Array[Array] = _build_layers(type_list, rng)

	var layer_nodes: Array[Array] = []
	var next_id := 0
	for layer in layers:
		var layer_entries: Array[Dictionary] = []
		for nd_type in layer:
			next_id += 1
			layer_entries.append({
				"id": "n%d" % next_id,
				"type": nd_type
			})
		layer_nodes.append(layer_entries)

	var num_layers := layer_nodes.size()
	for li in range(num_layers):
		var entries: Array = layer_nodes[li]
		var y: float = lerp(START_Y, BOSS_Y, float(li + 1) / (num_layers + 1))
		var count: int = entries.size()
		var spread: float = maxf(MIN_NODE_SPACING, count * MIN_NODE_SPACING)
		var start_x: float = CENTER_X - spread / 2.0
		for ni in range(count):
			var x: float = CENTER_X if count == 1 else start_x + (spread / (count - 1)) * ni
			var nd: Dictionary = {
				"id": entries[ni]["id"],
				"type": entries[ni]["type"],
				"position": [x, y],
				"connections": []
			}
			if entries[ni]["type"] == "combat" and not enemy_ids.is_empty():
				nd["enemy_id"] = enemy_ids[rng.randi_range(0, enemy_ids.size() - 1)]
			nodes.append(nd)

	for nd in layer_nodes[0]:
		_connect_nodes(nodes, "start", nd["id"])

	for li in range(num_layers - 1):
		_connect_layers(nodes, layer_nodes[li], layer_nodes[li + 1], rng)

	for nd in layer_nodes[num_layers - 1]:
		_connect_nodes(nodes, nd["id"], "boss")

	return _build_level(level_id, boss_data, player_data, nodes, enemies, enemy_ids)


static func _build_layers(type_list: Array[String], rng: RandomNumberGenerator) -> Array[Array]:
	var pool := type_list.duplicate()
	var layers: Array[Array] = []
	while not pool.is_empty():
		var max_size: int = mini(3, pool.size())
		var size: int = rng.randi_range(1, max_size)
		var layer: Array[String] = []
		for i in range(size):
			layer.append(pool.pop_front())
		layers.append(layer)
	return layers


static func _connect_nodes(nodes: Array[Dictionary], from_id: String, to_id: String) -> void:
	for nd in nodes:
		if nd["id"] == from_id:
			if to_id not in nd["connections"]:
				nd["connections"].append(to_id)
			return


static func _has_connection(nodes: Array[Dictionary], from_id: String, to_id: String) -> bool:
	for nd in nodes:
		if nd["id"] == from_id:
			return to_id in nd["connections"]
	return false


static func _connect_layers(nodes: Array[Dictionary], layer_a: Array[Dictionary], layer_b: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for nd_b in layer_b:
		var from: Dictionary = layer_a[rng.randi_range(0, layer_a.size() - 1)]
		_connect_nodes(nodes, from["id"], nd_b["id"])

	for nd_a in layer_a:
		var extra: int = rng.randi_range(0, 1)
		for e in range(extra):
			var candidates: Array[Dictionary] = []
			for nd_b in layer_b:
				if not _has_connection(nodes, nd_a["id"], nd_b["id"]):
					candidates.append(nd_b)
			if not candidates.is_empty():
				var target: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
				_connect_nodes(nodes, nd_a["id"], target["id"])


static func _build_level(level_id: int, boss_data: Dictionary, player_data: Dictionary, nodes: Array[Dictionary], enemies: Dictionary, enemy_ids: Array[String]) -> Dictionary:
	return {
		"id": level_id,
		"boss": boss_data,
		"player": player_data,
		"nodes": nodes,
		"enemies": enemies,
	}

static func get_enemy_id_for_node(node_data: Dictionary) -> String:
	return node_data.get("enemy_id", "")

static func get_enemy_data(level_data: Dictionary, node_data: Dictionary) -> Dictionary:
	var enemy_id := get_enemy_id_for_node(node_data)
	if enemy_id.is_empty():
		var enemies: Dictionary = level_data.get("enemies", {})
		if enemies.is_empty():
			return {"name": "Unknown", "hp": 25, "max_hp": 25, "gold": 0}
		enemy_id = enemies.keys()[0]
	return level_data.get("enemies", {}).get(enemy_id, {})
