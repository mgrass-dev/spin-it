extends Node2D

enum Turn { PLAYER, ENEMY }

const VIEWPORT_SIZE := Vector2(1280, 720)
const OVERLAY_ALPHA := 0xA0 / 255.0
const OVERLAY_SPLIT_Y := 315

const WHEEL_VISUAL_RADIUS := 250.0
const BALL_APPROACH_DURATION := 0.5
const ENEMY_SPIN_DELAY := 2.0
const THROWS_PER_TURN := 3

const PLAYER_LOG_POS := Vector2(8, 510)
const PLAYER_LOG_SIZE := Vector2(250, 200)
const ENEMY_LOG_POS := Vector2(1022, 8)
const ENEMY_LOG_SIZE := Vector2(250, 300)

@onready var player_wheel: Node2D = $PlayerWheel
@onready var enemy_wheel: Node2D = $EnemyWheel
@onready var ball: Node2D = $Ball
@onready var damage_display: CanvasLayer = $DamageDisplay
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _enemy_hp_bar: HPBar = $UILayer/EnemyHPBar
@onready var _player_hp_bar: HPBar = $UILayer/PlayerHPBar

const BALL_Y_OFFSET := 15.0

var _ball_over_wheel := false
var _ball_rolling := false
var _ball_offset_angle := 0.0
var _ball_approach_start := Vector2.ZERO
var _ball_approach_time := 0.0
var _combat_over := false
var _current_turn: Turn = Turn.PLAYER
var _turn_number: int = 1

var _player_throws_remaining: int = THROWS_PER_TURN
var _enemy_throws_remaining: int = THROWS_PER_TURN
var _player_accumulated_damage: int = 0
var _enemy_accumulated_damage: int = 0

var _enemy_section_overlay: ColorRect
var _player_section_overlay: ColorRect
var _player_log: CombatLogPanel
var _enemy_log: CombatLogPanel
var _enemy_ball: Sprite2D
var _throws_label: Label

func _ready() -> void:
	if not OS.has_feature("editor"):
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_size(screen_size)
		DisplayServer.window_set_position(Vector2i.ZERO)

	ball.released.connect(_on_ball_released)
	player_wheel.spin_completed.connect(_on_spin_completed)
	enemy_wheel.spin_completed.connect(_on_enemy_spin_completed)

	_setup_hp_bars()
	_setup_section_overlays()
	_setup_logs()
	_setup_enemy_ball()
	_setup_throws_label()
	_start_player_turn()

# ─── Setup ───────────────────────────────────────────────────────────────────

func _setup_hp_bars() -> void:
	if GameState.enemy_max_hp == 0:
		GameState.enemy_max_hp = 50
		GameState.enemy_hp = 50
	if GameState.player_max_hp == 0:
		GameState.player_max_hp = 50
		GameState.player_hp = 50

	_enemy_hp_bar.setup(
		load("res://sprites/map/icon_combat.png"),
		"",
		GameState.enemy_hp,
		GameState.enemy_max_hp
	)
	_player_hp_bar.setup(null, "", GameState.player_hp, GameState.player_max_hp)

func _setup_section_overlays() -> void:
	# Layer 2 sits above the Node2D world but below the HP-bar UILayer (5)
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

func _setup_enemy_ball() -> void:
	_enemy_ball = Sprite2D.new()
	_enemy_ball.texture = load("res://sprites/balls/ball_white.png")
	_enemy_ball.scale = Vector2(0.5, 0.5)
	_enemy_ball.z_index = 2
	_enemy_ball.visible = false
	add_child(_enemy_ball)

func _setup_throws_label() -> void:
	_throws_label = Label.new()
	_throws_label.position = Vector2(920, 670)
	_throws_label.size = Vector2(72, 28)
	_throws_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_throws_label.add_theme_font_size_override("font_size", 24)
	_throws_label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(_throws_label)

func _setup_logs() -> void:
	_player_log = CombatLogPanel.new()
	_player_log.position = PLAYER_LOG_POS
	_player_log.size = PLAYER_LOG_SIZE
	_ui_layer.add_child(_player_log)

	_enemy_log = CombatLogPanel.new()
	_enemy_log.position = ENEMY_LOG_POS
	_enemy_log.size = ENEMY_LOG_SIZE
	_ui_layer.add_child(_enemy_log)

# ─── Logging ─────────────────────────────────────────────────────────────────

func _add_player_log(text: String) -> void:
	_player_log.add_line(text, Color(1.0, 0.85, 0.7))

func _add_enemy_log(text: String) -> void:
	_enemy_log.add_line(text, Color(0.7, 0.85, 1.0))

# ─── Turn management ─────────────────────────────────────────────────────────

func _start_player_turn() -> void:
	_current_turn = Turn.PLAYER
	_player_throws_remaining = THROWS_PER_TURN
	_player_accumulated_damage = 0
	_enemy_section_overlay.visible = true
	_player_section_overlay.visible = false
	ball.process_mode = Node.PROCESS_MODE_INHERIT
	ball.return_to_slot()
	ball.visible = true
	_update_throws_counter()
	_add_player_log("— Turn %d: your turn —" % _turn_number)

func _start_enemy_turn() -> void:
	_current_turn = Turn.ENEMY
	_enemy_throws_remaining = THROWS_PER_TURN
	_enemy_accumulated_damage = 0
	_enemy_section_overlay.visible = false
	_player_section_overlay.visible = true
	_update_throws_counter()
	_add_enemy_log("— Turn %d: enemy's turn —" % _turn_number)
	_do_enemy_throw()

func _do_enemy_throw() -> void:
	if _combat_over:
		return
	_enemy_ball.visible = true
	enemy_wheel.start_spinning()
	await get_tree().create_timer(ENEMY_SPIN_DELAY).timeout
	if not _combat_over:
		enemy_wheel.stop_on_random_item()

# ─── Process / Ball ──────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _combat_over:
		return

	if _current_turn == Turn.ENEMY:
		if _enemy_ball.visible:
			var spin_r: float = enemy_wheel.get_spinning_rotation()
			var radius: float = enemy_wheel.get_item_world_radius()
			_enemy_ball.global_position = enemy_wheel.global_position + \
				Vector2(cos(spin_r), sin(spin_r)) * radius
		return

	if ball.is_held():
		var ball_pos: Vector2 = ball.global_position
		var dist: float = (ball_pos - player_wheel.global_position).length()
		var is_over: bool = dist <= WHEEL_VISUAL_RADIUS * player_wheel.scale.x

		if is_over and not _ball_over_wheel:
			_ball_over_wheel = true
			player_wheel.start_spinning()
			player_wheel.set_highlight(true)
		elif not is_over and _ball_over_wheel:
			_ball_over_wheel = false
			player_wheel.stop_spinning()
			player_wheel.set_highlight(false)

	if _ball_rolling:
		var spin_r: float = player_wheel.get_spinning_rotation()
		var radius: float = player_wheel.get_item_world_radius()
		var target_pos: Vector2 = player_wheel.global_position + \
			Vector2(cos(spin_r + _ball_offset_angle), sin(spin_r + _ball_offset_angle)) * radius + \
			Vector2(0, BALL_Y_OFFSET)

		if _ball_approach_time > 0.0:
			_ball_approach_time -= delta
			var t: float = clamp(1.0 - _ball_approach_time / BALL_APPROACH_DURATION, 0.0, 1.0)
			ball.global_position = _ball_approach_start.lerp(target_pos, t)
		else:
			ball.global_position = target_pos

func _on_ball_released(_world_pos: Vector2) -> void:
	if _combat_over or _current_turn == Turn.ENEMY or _player_throws_remaining <= 0:
		ball.return_to_slot()
		return
	if _ball_over_wheel:
		_ball_over_wheel = false
		player_wheel.set_highlight(false)
		_launch_ball_on_wheel()
	else:
		player_wheel.stop_spinning()
		ball.return_to_slot()

func _launch_ball_on_wheel() -> void:
	var spin_info: Dictionary = player_wheel.stop_on_random_item()
	if spin_info.is_empty():
		ball.return_to_slot()
		return

	var target_r: float = float(spin_info["target_r"])
	# Offset so ball ends at world angle -PI/2 (pointer/top) when
	# spinning_part reaches target_r (winning wheel_item position).
	_ball_offset_angle = -PI / 2.0 - target_r
	_ball_approach_start = ball.global_position
	_ball_approach_time = BALL_APPROACH_DURATION

	ball.start_rolling()
	_ball_rolling = true

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _update_throws_counter() -> void:
	var remaining: int = _player_throws_remaining if _current_turn == Turn.PLAYER else _enemy_throws_remaining
	_throws_label.text = str(remaining)

# ─── Spin callbacks ──────────────────────────────────────────────────────────

func _on_spin_completed(item: WheelItem) -> void:
	_ball_rolling = false
	ball.return_to_slot()
	ball.visible = true

	_player_accumulated_damage += item.modifier
	_player_throws_remaining -= 1
	_update_throws_counter()

	damage_display.show_damage(item.modifier)

	var throw_num: int = THROWS_PER_TURN - _player_throws_remaining
	_add_player_log("Throw %d: %d (total: %d)" % [
		throw_num, item.modifier, _player_accumulated_damage
	])

	if _player_throws_remaining <= 0:
		ball.process_mode = Node.PROCESS_MODE_DISABLED
		await damage_display.damage_applied
		_apply_player_damage(_player_accumulated_damage)

func _on_enemy_spin_completed(item: WheelItem) -> void:
	if _combat_over:
		return
	_enemy_ball.visible = false

	_enemy_accumulated_damage += item.modifier
	_enemy_throws_remaining -= 1
	_update_throws_counter()

	damage_display.show_damage(item.modifier)

	var throw_num: int = THROWS_PER_TURN - _enemy_throws_remaining
	_add_enemy_log("Throw %d: %d (total: %d)" % [
		throw_num, item.modifier, _enemy_accumulated_damage
	])

	if _enemy_throws_remaining > 0:
		await damage_display.damage_applied
		_do_enemy_throw()
	else:
		await damage_display.damage_applied
		_apply_enemy_damage(_enemy_accumulated_damage)

# ─── Damage resolution ───────────────────────────────────────────────────────

func _apply_player_damage(amount: int) -> void:
	GameState.enemy_hp = maxi(0, GameState.enemy_hp - amount)
	_enemy_hp_bar.update_hp(GameState.enemy_hp, GameState.enemy_max_hp)
	_add_player_log("Total: %d damage (enemy: %d HP)" % [amount, GameState.enemy_hp])
	if GameState.enemy_hp <= 0:
		_combat_over = true
		GameState.complete_current_combat()
		_add_player_log("Victory!")
		_show_end_screen()
	else:
		_start_enemy_turn()

func _apply_enemy_damage(amount: int) -> void:
	GameState.player_hp = maxi(0, GameState.player_hp - amount)
	_player_hp_bar.update_hp(GameState.player_hp, GameState.player_max_hp)
	_add_enemy_log("Total: %d damage (you: %d HP)" % [amount, GameState.player_hp])
	_turn_number += 1
	if GameState.player_hp <= 0:
		_combat_over = true
		_add_enemy_log("Defeat...")
		_show_end_screen()
	else:
		_start_player_turn()

# ─── End screen ──────────────────────────────────────────────────────────────

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
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/map.tscn"))
	canvas.add_child(btn)
