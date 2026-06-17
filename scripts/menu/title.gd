extends Node2D

@onready var _settings_menu = $SettingsMenu
@onready var _continue_button: Button = $CanvasLayer/ButtonVBox/ContinueButton
@onready var _new_game_button: Button = $CanvasLayer/ButtonVBox/NewGameButton
@onready var _settings_button: Button = $CanvasLayer/ButtonVBox/SettingsButton

func _ready() -> void:
	$CanvasLayer/TitleLabel.add_theme_color_override("font_color", Color(0.92, 0.78, 0.25, 1))
	_continue_button.visible = GameState.has_save()
	_continue_button.pressed.connect(_on_continue)
	_new_game_button.pressed.connect(_on_new_game)
	_settings_button.pressed.connect(_on_settings)

func _on_continue() -> void:
	GameState.load_game()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _on_new_game() -> void:
	GameState.reset_game()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _on_settings() -> void:
	_settings_menu.open()
