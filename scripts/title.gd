extends Node2D

@onready var _settings_menu = $SettingsMenu

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.08)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	canvas.add_child(bg)

	var title := Label.new()
	title.text = "Spin it"
	title.add_theme_font_size_override("font_size", 90)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 130)
	title.size = Vector2(1280, 110)
	canvas.add_child(title)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.position = Vector2(490, 310)
	vbox.size = Vector2(300, 300)
	canvas.add_child(vbox)

	if GameState.has_save():
		var btn := _make_button("Continue")
		vbox.add_child(btn)
		btn.pressed.connect(_on_continue)

	var new_btn := _make_button("New Game")
	vbox.add_child(new_btn)
	new_btn.pressed.connect(_on_new_game)

	var settings_btn := _make_button("Settings  ⚙")
	vbox.add_child(settings_btn)
	settings_btn.pressed.connect(_on_settings)

func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(300, 56)
	btn.add_theme_font_size_override("font_size", 22)
	return btn

func _on_continue() -> void:
	GameState.load_game()
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _on_new_game() -> void:
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _on_settings() -> void:
	_settings_menu.open()
