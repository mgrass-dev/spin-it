extends GutTest

func test_default_values() -> void:
	assert_eq(GameState.current_level, 1)
	assert_eq(GameState.completed_nodes, [])
	assert_eq(GameState.player_hp, 0)
	assert_eq(GameState.player_max_hp, 0)

func test_start_combat_sets_enemy_stats() -> void:
	var level_data := {
		"enemies": {
			"default_combat": {
				"hp": 30,
				"max_hp": 30,
				"name": "Test Goblin"
			}
		}
	}
	GameState.start_combat("c1", level_data)
	assert_eq(GameState.enemy_hp, 30)
	assert_eq(GameState.enemy_max_hp, 30)
	assert_eq(GameState.enemy_name, "Test Goblin")

func test_complete_combat_adds_node() -> void:
	GameState.completed_nodes.clear()
	GameState.current_combat_node_id = "c_test"
	GameState.complete_current_combat()
	assert_true("c_test" in GameState.completed_nodes)
	assert_eq(GameState.current_combat_node_id, "")

func test_reset_game_clears_state() -> void:
	GameState.player_hp = 50
	GameState.player_max_hp = 50
	GameState.completed_nodes = ["c1", "c2"]
	GameState.reset_game()
	assert_eq(GameState.player_hp, 0)
	assert_eq(GameState.completed_nodes, [])
