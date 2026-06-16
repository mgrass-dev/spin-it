extends CanvasLayer

@onready var menu_panel: Control = $MenuPanel
@onready var settings_button: Button = $SettingsButton
@onready var settings_button_close: Button = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/SettingsButtonClose
@onready var screen_option_button: OptionButton = $MenuPanel/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ScreenOptionButton

func _ready() -> void:
	settings_button.pressed.connect(_on_settings_pressed)
	settings_button_close.pressed.connect(_on_settings_pressed)
	screen_option_button.item_selected.connect(_on_display_mode_selected)
	
	var current_mode := DisplayServer.window_get_mode()
	match current_mode:
		DisplayServer.WINDOW_MODE_WINDOWED: screen_option_button.selected = 0
		DisplayServer.WINDOW_MODE_FULLSCREEN: screen_option_button.selected = 1
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: screen_option_button.selected = 2

func _on_settings_pressed() -> void:
	menu_panel.visible = not menu_panel.visible

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and menu_panel.visible:
		_on_settings_pressed()

func open() -> void:
	menu_panel.visible = true

func _on_display_mode_selected(index: int) -> void:
	match index:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
