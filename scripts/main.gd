extends Node2D

enum Turn { PLAYER, ENEMY }

@onready var player_wheel: Node2D = $PlayerWheel
@onready var enemy_wheel: Node2D = $EnemyWheel
@onready var ball: Node2D = $Ball
@onready var damage_display: CanvasLayer = $DamageDisplay
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _enemy_hp_bar: ProgressBar = $UILayer/EnemyHPBar
@onready var _player_hp_bar: ProgressBar = $UILayer/PlayerHPBar

const WHEEL_VISUAL_RADIUS := 250.0
const BALL_APPROACH_DURATION := 0.5
const ENEMY_SPIN_DELAY := 2.0

var _ball_over_wheel := false
var _ball_rolling := false
var _ball_offset_angle := 0.0
var _ball_approach_start := Vector2.ZERO
var _ball_approach_time := 0.0
var _combat_over := false
var _current_turn: Turn = Turn.PLAYER
var _turn_number: int = 1

var _enemy_section_overlay: ColorRect
var _player_section_overlay: ColorRect
var _player_log_vbox: VBoxContainer
var _enemy_log_vbox: VBoxContainer
var _player_log_scroll: ScrollContainer
var _enemy_log_scroll: ScrollContainer
var _enemy_ball: Sprite2D
var _enemy_hp_label: Label
var _player_hp_label: Label

func _ready() -> void:
	if not OS.has_feature("editor"):
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_size(screen_size)
		DisplayServer.window_set_position(Vector2i.ZERO)

	ball.picked_up.connect(_on_ball_picked_up)
	ball.released.connect(_on_ball_released)
	player_wheel.spin_completed.connect(_on_spin_completed)
	enemy_wheel.spin_completed.connect(_on_enemy_spin_completed)
	damage_display.damage_applied.connect(_on_damage_applied)

	_setup_hp_bars()
	_setup_section_overlays()
	_setup_logs()
	_setup_enemy_ball()
	_start_player_turn()

# ─── Setup ───────────────────────────────────────────────────────────────────

func _setup_hp_bars() -> void:
	if GameState.enemy_max_hp == 0:
		GameState.enemy_max_hp = 50
		GameState.enemy_hp = 50
	if GameState.player_max_hp == 0:
		GameState.player_max_hp = 50
		GameState.player_hp = 50

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.1, 0.1)
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.04, 0.04, 0.85)
	bg.set_corner_radius_all(3)

	for bar: ProgressBar in [_enemy_hp_bar, _player_hp_bar]:
		bar.add_theme_stylebox_override("fill", fill.duplicate())
		bar.add_theme_stylebox_override("background", bg.duplicate())

	_enemy_hp_bar.max_value = GameState.enemy_max_hp
	_enemy_hp_bar.value = GameState.enemy_hp
	_player_hp_bar.max_value = GameState.player_max_hp
	_player_hp_bar.value = GameState.player_hp

	for bar: ProgressBar in [_enemy_hp_bar, _player_hp_bar]:
		var lbl := Label.new()
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(lbl)
		if bar == _enemy_hp_bar:
			_enemy_hp_label = lbl
		else:
			_player_hp_label = lbl
	_update_hp_labels()

func _setup_section_overlays() -> void:
	# Layer 2 sits above the Node2D world but below the HP-bar UILayer (5)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	_enemy_section_overlay = ColorRect.new()
	_enemy_section_overlay.color = Color(0, 0, 0, 0xA0 / 255.0)
	_enemy_section_overlay.position = Vector2.ZERO
	_enemy_section_overlay.size = Vector2(1280, 315)
	_enemy_section_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_enemy_section_overlay)

	_player_section_overlay = ColorRect.new()
	_player_section_overlay.color = Color(0, 0, 0, 0xA0 / 255.0)
	_player_section_overlay.position = Vector2(0, 315)
	_player_section_overlay.size = Vector2(1280, 405)
	_player_section_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_player_section_overlay)

func _setup_enemy_ball() -> void:
	_enemy_ball = Sprite2D.new()
	_enemy_ball.texture = load("res://sprites/billes/bille_blanche.png")
	_enemy_ball.scale = Vector2(0.5, 0.5)
	_enemy_ball.z_index = 2
	_enemy_ball.visible = false
	add_child(_enemy_ball)

func _update_hp_labels() -> void:
	if _enemy_hp_label:
		_enemy_hp_label.text = "%d / %d" % [GameState.enemy_hp, GameState.enemy_max_hp]
	if _player_hp_label:
		_player_hp_label.text = "%d / %d" % [GameState.player_hp, GameState.player_max_hp]

func _setup_logs() -> void:
	# Player log — bottom-left of player section, left of the wheel
	var pl := _make_log(Vector2(8, 510), Vector2(250, 200))
	_player_log_scroll = pl[0]
	_player_log_vbox = pl[1]

	# Enemy log — top-right of enemy section, right of the wheel
	var el := _make_log(Vector2(1022, 8), Vector2(250, 300))
	_enemy_log_scroll = el[0]
	_enemy_log_vbox = el[1]

func _make_log(pos: Vector2, sz: Vector2) -> Array:
	var panel := Panel.new()
	panel.position = pos
	panel.size = sz
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	_ui_layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	return [scroll, vbox]

# ─── Logging ─────────────────────────────────────────────────────────────────

func _add_log(vbox: VBoxContainer, scroll: ScrollContainer, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(label)
	await get_tree().process_frame
	scroll.scroll_vertical = 999999

func _add_player_log(text: String) -> void:
	_add_log(_player_log_vbox, _player_log_scroll, text, Color(1.0, 0.85, 0.7))

func _add_enemy_log(text: String) -> void:
	_add_log(_enemy_log_vbox, _enemy_log_scroll, text, Color(0.7, 0.85, 1.0))

# ─── Turn management ─────────────────────────────────────────────────────────

func _start_player_turn() -> void:
	_current_turn = Turn.PLAYER
	_enemy_section_overlay.visible = true
	_player_section_overlay.visible = false
	_add_player_log("— Tour %d : votre tour —" % _turn_number)

func _start_enemy_turn() -> void:
	_current_turn = Turn.ENEMY
	_enemy_section_overlay.visible = false
	_player_section_overlay.visible = true
	_add_enemy_log("— Tour %d : tour ennemi —" % _turn_number)

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
		if _enemy_ball != null and _enemy_ball.visible:
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
			Vector2(cos(spin_r + _ball_offset_angle), sin(spin_r + _ball_offset_angle)) * radius

		if _ball_approach_time > 0.0:
			_ball_approach_time -= delta
			var t: float = clamp(1.0 - _ball_approach_time / BALL_APPROACH_DURATION, 0.0, 1.0)
			ball.global_position = _ball_approach_start.lerp(target_pos, t)
		else:
			ball.global_position = target_pos

func _on_ball_picked_up() -> void:
	pass

func _on_ball_released(_world_pos: Vector2) -> void:
	if _combat_over or _current_turn == Turn.ENEMY:
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
	# Offset so ball ends at world angle -PI/2 (the pointer/top) when spinning_part
	# reaches target_r — which is exactly where the winning wheel_item will be.
	_ball_offset_angle = -PI / 2.0 - target_r
	_ball_approach_start = ball.global_position
	_ball_approach_time = BALL_APPROACH_DURATION

	ball.start_rolling()
	_ball_rolling = true

# ─── Spin callbacks ──────────────────────────────────────────────────────────

func _on_spin_completed(item: WheelItem) -> void:
	_ball_rolling = false
	ball.visible = false
	damage_display.show_damage(item.modifier)

func _on_enemy_spin_completed(item: WheelItem) -> void:
	if _combat_over:
		return
	_enemy_ball.visible = false
	damage_display.show_damage(item.modifier)

# ─── Damage resolution ───────────────────────────────────────────────────────

func _on_damage_applied(amount: int) -> void:
	match _current_turn:
		Turn.PLAYER: _apply_player_damage(amount)
		Turn.ENEMY:  _apply_enemy_damage(amount)

func _apply_player_damage(amount: int) -> void:
	GameState.enemy_hp = maxi(0, GameState.enemy_hp - amount)
	_enemy_hp_bar.value = GameState.enemy_hp
	_update_hp_labels()
	ball.return_to_slot()
	ball.visible = true
	_add_player_log("Vous infligez %d dégâts  (ennemi : %d PV)" % [amount, GameState.enemy_hp])
	if GameState.enemy_hp <= 0:
		_combat_over = true
		GameState.complete_current_combat()
		_add_player_log("Victoire !")
		_show_end_screen()
	else:
		_start_enemy_turn()

func _apply_enemy_damage(amount: int) -> void:
	GameState.player_hp = maxi(0, GameState.player_hp - amount)
	_player_hp_bar.value = GameState.player_hp
	_update_hp_labels()
	_add_enemy_log("L'ennemi inflige %d dégâts  (vous : %d PV)" % [amount, GameState.player_hp])
	_turn_number += 1
	if GameState.player_hp <= 0:
		_combat_over = true
		_add_enemy_log("Défaite...")
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
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)

	var btn := Button.new()
	btn.text = "Retour à la carte"
	btn.size = Vector2(300, 48)
	btn.position = Vector2(640 - 150, 360 - 24)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/map.tscn"))
	canvas.add_child(btn)
