extends Node2D

enum Turn { PLAYER, ENEMY }

const VIEWPORT_SIZE := Vector2(1280, 720)
const OVERLAY_ALPHA := 0xA0 / 255.0
const OVERLAY_SPLIT_Y := 315

const ENEMY_SPIN_DELAY := 2.0
const THROWS_PER_TURN := 3

const PLAYER_LOG_POS := Vector2(1022, 510)
const PLAYER_LOG_SIZE := Vector2(250, 200)
const ENEMY_LOG_POS := Vector2(1022, 8)
const ENEMY_LOG_SIZE := Vector2(250, 300)

@onready var player_wheel: RouletteWheel = $PlayerWheel
@onready var enemy_wheel: RouletteWheel = $EnemyWheel
@onready var damage_display: CanvasLayer = $DamageDisplay
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _enemy_hud: Node2D = $UILayer/EnemyHUD
@onready var _enemy_hp_bar: HPBar = $UILayer/EnemyHUD/EnemyHPBar
@onready var _player_hud: Node2D = $UILayer/PlayerHUD
@onready var _player_hp_bar: HPBar = $UILayer/PlayerHUD/PlayerHPBar
@onready var _player_launch_btn: Button = $UILayer/PlayerLaunchButton

var _combat_over := false
var _current_turn: Turn = Turn.PLAYER
var _turn_number: int = 1

var _player_throws_remaining: int = THROWS_PER_TURN
var _enemy_throws_remaining: int = THROWS_PER_TURN
var _player_accumulated_damage: int = 0
var _enemy_accumulated_damage: int = 0

var _player_throws_data: Array[Dictionary] = []

var _enemy_section_overlay: ColorRect
var _player_section_overlay: ColorRect
var _player_log: CombatLogPanel
var _enemy_log: CombatLogPanel
var _throws_label: Label

var _player_damage_counter: Node2D
var _enemy_damage_counter: Node2D
var _player_damage_num: Label
var _enemy_damage_num: Label

func _ready() -> void:
	if not OS.has_feature("editor"):
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_size(screen_size)
		DisplayServer.window_set_position(Vector2i.ZERO)

	player_wheel.result_ready.connect(_on_player_result)
	enemy_wheel.result_ready.connect(_on_enemy_result)
	_player_launch_btn.pressed.connect(_on_player_launch)
	player_wheel.load_player_slots()

	_setup_hp_bars()
	_setup_enemy_name()
	_setup_player_name()
	_setup_effect_labels()
	_setup_section_overlays()
	_setup_logs()
	_setup_throws_label()
	_setup_damage_counters()
	_start_player_turn()

func _setup_hp_bars() -> void:
	if GameState.enemy_max_hp == 0:
		GameState.enemy_max_hp = 50
		GameState.enemy_hp = 50
	if GameState.player_max_hp == 0:
		GameState.player_max_hp = 50
		GameState.player_hp = 50

	_enemy_hp_bar.setup(
		null,
		"",
		GameState.enemy_hp,
		GameState.enemy_max_hp
	)
	_player_hp_bar.setup(null, "", GameState.player_hp, GameState.player_max_hp)
	_player_hp_bar.set_bar_fill_color(Color("#255c9b"))

func _setup_enemy_name() -> void:
	var name_label := Label.new()
	name_label.text = "GOBELIN"
	name_label.position = Vector2(54, 8)
	name_label.size = Vector2(140, 22)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	_enemy_hud.add_child(name_label)

	var title_label := Label.new()
	title_label.text = "Pique-Bourse"
	title_label.position = Vector2(54, 30)
	title_label.size = Vector2(140, 16)
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_enemy_hud.add_child(title_label)

func _setup_player_name() -> void:
	var name_label := Label.new()
	name_label.text = "JOUEUR"
	name_label.position = Vector2(54, 360)
	name_label.size = Vector2(140, 22)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.15, 0.6, 0.85))
	_player_hud.add_child(name_label)

	var title_label := Label.new()
	title_label.text = "Aventurier"
	title_label.position = Vector2(54, 382)
	title_label.size = Vector2(140, 16)
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_player_hud.add_child(title_label)

func _setup_effect_labels() -> void:
	var enemy_label := Label.new()
	enemy_label.text = "EFFET ENNEMI"
	enemy_label.position = Vector2(-30, 238)
	enemy_label.size = Vector2(216, 22)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	enemy_label.add_theme_font_size_override("font_size", 17)
	enemy_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	_enemy_hud.add_child(enemy_label)

	var player_label := Label.new()
	player_label.text = "EFFET JOUEUR"
	player_label.position = Vector2(-30, 590)
	player_label.size = Vector2(216, 22)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	player_label.add_theme_font_size_override("font_size", 17)
	player_label.add_theme_color_override("font_color", Color(0.15, 0.6, 0.85))
	_player_hud.add_child(player_label)

func _setup_section_overlays() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	_enemy_section_overlay = ColorRect.new()
	_enemy_section_overlay.color = Color(0, 0, 0, OVERLAY_ALPHA)
	_enemy_section_overlay.position = Vector2.ZERO
	_enemy_section_overlay.size = Vector2(VIEWPORT_SIZE.x, OVERLAY_SPLIT_Y)
	_enemy_section_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_enemy_section_overlay)

	_player_section_overlay = ColorRect.new()
	_player_section_overlay.color = Color(0, 0, 0, OVERLAY_ALPHA)
	_player_section_overlay.position = Vector2(0, OVERLAY_SPLIT_Y)
	_player_section_overlay.size = Vector2(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y - OVERLAY_SPLIT_Y)
	_player_section_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_player_section_overlay)

func _setup_throws_label() -> void:
	_throws_label = Label.new()
	_throws_label.position = Vector2(920, 670)
	_throws_label.size = Vector2(72, 28)
	_throws_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_throws_label.add_theme_font_size_override("font_size", 24)
	_throws_label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(_throws_label)

func _setup_damage_counters() -> void:
	_player_damage_counter = Node2D.new()
	_player_damage_counter.position = Vector2(920, 480)
	add_child(_player_damage_counter)

	_player_damage_num = Label.new()
	_player_damage_num.text = "0"
	_player_damage_num.position = Vector2(-70, -14)
	_player_damage_num.size = Vector2(140, 36)
	_player_damage_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_damage_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_player_damage_num.add_theme_font_size_override("font_size", 32)
	_player_damage_num.add_theme_color_override("font_color", Color(0.15, 0.6, 0.85))
	_player_damage_counter.add_child(_player_damage_num)

	var player_dmg_label := Label.new()
	player_dmg_label.text = "DÉGÂTS"
	player_dmg_label.position = Vector2(-70, 20)
	player_dmg_label.size = Vector2(140, 20)
	player_dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_dmg_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	player_dmg_label.add_theme_font_size_override("font_size", 14)
	player_dmg_label.add_theme_color_override("font_color", Color(0.15, 0.6, 0.85))
	player_dmg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	player_dmg_label.add_theme_constant_override("outline_size", 2)
	_player_damage_counter.add_child(player_dmg_label)
	_player_damage_counter.visible = false

	_enemy_damage_counter = Node2D.new()
	_enemy_damage_counter.position = Vector2(920, 160)
	add_child(_enemy_damage_counter)

	_enemy_damage_num = Label.new()
	_enemy_damage_num.text = "0"
	_enemy_damage_num.position = Vector2(-70, -14)
	_enemy_damage_num.size = Vector2(140, 36)
	_enemy_damage_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_damage_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_damage_num.add_theme_font_size_override("font_size", 32)
	_enemy_damage_num.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	_enemy_damage_counter.add_child(_enemy_damage_num)

	var enemy_dmg_label := Label.new()
	enemy_dmg_label.text = "DÉGÂTS"
	enemy_dmg_label.position = Vector2(-70, 20)
	enemy_dmg_label.size = Vector2(140, 20)
	enemy_dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_dmg_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	enemy_dmg_label.add_theme_font_size_override("font_size", 14)
	enemy_dmg_label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	enemy_dmg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	enemy_dmg_label.add_theme_constant_override("outline_size", 2)
	_enemy_damage_counter.add_child(enemy_dmg_label)
	_enemy_damage_counter.visible = false

func _setup_logs() -> void:
	_player_log = CombatLogPanel.new()
	_player_log.position = PLAYER_LOG_POS
	_player_log.size = PLAYER_LOG_SIZE
	_ui_layer.add_child(_player_log)

	_enemy_log = CombatLogPanel.new()
	_enemy_log.position = ENEMY_LOG_POS
	_enemy_log.size = ENEMY_LOG_SIZE
	_ui_layer.add_child(_enemy_log)

func _add_player_log(text: String) -> void:
	_player_log.add_line(text, Color(1.0, 0.85, 0.7))

func _add_enemy_log(text: String) -> void:
	_enemy_log.add_line(text, Color(0.7, 0.85, 1.0))

func _update_damage_counter(counter: Node2D, num_label: Label, value: int) -> void:
	num_label.text = str(value)
	if not counter.visible:
		counter.visible = true
	counter.scale = Vector2(1, 1)
	var tween := create_tween()
	tween.tween_property(counter, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(counter, "scale", Vector2(1, 1), 0.08)

func _hide_damage_counters() -> void:
	_player_damage_counter.visible = false
	_enemy_damage_counter.visible = false

func _start_player_turn() -> void:
	_current_turn = Turn.PLAYER
	_player_throws_remaining = THROWS_PER_TURN
	_player_accumulated_damage = 0
	_player_throws_data.clear()
	_enemy_section_overlay.visible = true
	_player_section_overlay.visible = false
	_player_launch_btn.disabled = false
	_update_throws_counter()
	_hide_damage_counters()
	_add_player_log("— Turn %d: your turn —" % _turn_number)

func _start_enemy_turn() -> void:
	_current_turn = Turn.ENEMY
	_enemy_throws_remaining = THROWS_PER_TURN
	_enemy_accumulated_damage = 0
	_enemy_section_overlay.visible = false
	_player_section_overlay.visible = true
	_update_throws_counter()
	_hide_damage_counters()
	_add_enemy_log("— Turn %d: enemy's turn —" % _turn_number)
	_do_enemy_throw()

func _do_enemy_throw() -> void:
	if _combat_over:
		return
	enemy_wheel.launch()

func _input(event: InputEvent) -> void:
	if _combat_over or _current_turn != Turn.PLAYER:
		return
	if event.is_action_pressed("ui_accept"):
		_on_player_launch()

func _on_player_launch() -> void:
	if _combat_over or _current_turn != Turn.PLAYER or _player_throws_remaining <= 0:
		return
	_player_launch_btn.disabled = true
	_player_throws_remaining -= 1
	_update_throws_counter()
	player_wheel.launch()

func _update_throws_counter() -> void:
	var remaining: int = _player_throws_remaining if _current_turn == Turn.PLAYER else _enemy_throws_remaining
	_throws_label.text = str(remaining)

func _on_player_result(slot_number: int) -> void:
	if _combat_over:
		return

	var color_str := "black" if slot_number % 2 == 1 else "red"
	_player_throws_data.append({"value": slot_number, "slot_color": color_str})
	_player_accumulated_damage += slot_number
	_update_damage_counter(_player_damage_counter, _player_damage_num, _player_accumulated_damage)

	damage_display.show_damage(slot_number)

	var throw_num: int = THROWS_PER_TURN - _player_throws_remaining
	_add_player_log("Throw %d: %d %s (total: %d)" % [
		throw_num, slot_number, color_str, _player_accumulated_damage
	])

	if _player_throws_remaining <= 0:
		await damage_display.damage_applied
		await _apply_player_damage(_player_accumulated_damage)
	else:
		_player_launch_btn.disabled = false

func _on_enemy_result(slot_number: int) -> void:
	if _combat_over:
		return

	_enemy_accumulated_damage += slot_number
	_enemy_throws_remaining -= 1
	_update_throws_counter()
	_update_damage_counter(_enemy_damage_counter, _enemy_damage_num, _enemy_accumulated_damage)

	damage_display.show_damage(slot_number)

	var color_str := "black" if slot_number % 2 == 1 else "red"
	var throw_num: int = THROWS_PER_TURN - _enemy_throws_remaining
	_add_enemy_log("Throw %d: %d %s (total: %d)" % [
		throw_num, slot_number, color_str, _enemy_accumulated_damage
	])

	if _enemy_throws_remaining > 0:
		await damage_display.damage_applied
		_do_enemy_throw()
	else:
		await damage_display.damage_applied
		await _apply_enemy_damage(_enemy_accumulated_damage)

func _apply_player_damage(amount: int) -> void:
	var mult := Modifier.compute_multiplier(_player_throws_data)
	var final_damage := roundi(amount * mult)

	GameState.enemy_hp = maxi(0, GameState.enemy_hp - final_damage)
	await _enemy_hp_bar.animate_hp(GameState.enemy_hp, GameState.enemy_max_hp)
	_hide_damage_counters()

	var log_line: String = "Total: %d damage" % final_damage
	if mult > 1.0:
		log_line += " (x%.1f mod)" % mult
	log_line += " (enemy: %d HP)" % GameState.enemy_hp
	_add_player_log(log_line)

	if GameState.enemy_hp <= 0:
		_combat_over = true
		GameState.add_gold(GameState.enemy_gold)
		GameState.complete_current_combat()
		_add_player_log("Victory! +%d gold" % GameState.enemy_gold)
		_show_reward_screen()
	else:
		_start_enemy_turn()

func _apply_enemy_damage(amount: int) -> void:
	GameState.player_hp = maxi(0, GameState.player_hp - amount)
	await _player_hp_bar.animate_hp(GameState.player_hp, GameState.player_max_hp)
	_hide_damage_counters()
	_add_enemy_log("Total: %d damage (you: %d HP)" % [amount, GameState.player_hp])
	_turn_number += 1
	if GameState.player_hp <= 0:
		_combat_over = true
		_add_enemy_log("Defeat...")
		_show_end_screen()
	else:
		_start_player_turn()

func _show_reward_screen() -> void:
	var reward = load("res://scripts/combat/reward_popup.gd").new()
	add_child(reward)
	reward.closed.connect(_show_end_screen)

func _show_end_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 15
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.502)
	overlay.position = Vector2.ZERO
	overlay.size = VIEWPORT_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)

	var btn := Button.new()
	btn.text = "Back to map"
	btn.size = Vector2(300, 48)
	btn.position = Vector2(VIEWPORT_SIZE.x * 0.5 - 150, VIEWPORT_SIZE.y * 0.5 - 24)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/map/map.tscn"))
	canvas.add_child(btn)
