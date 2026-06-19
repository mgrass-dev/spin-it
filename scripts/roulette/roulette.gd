extends Node2D

@onready var _wheel_top:    RouletteWheel = $WheelTop
@onready var _wheel_bottom: RouletteWheel = $WheelBottom
@onready var _btn_top:      Button        = $UILayer/LaunchTopButton
@onready var _btn_bottom:   Button        = $UILayer/LaunchBottomButton
@onready var _label_top:    Label         = $UILayer/ResultLabelTop
@onready var _label_bottom: Label         = $UILayer/ResultLabelBottom
@onready var _back_button:  Button        = $UILayer/BackButton

func _ready() -> void:
	_btn_top.pressed.connect(_on_top_launch)
	_btn_bottom.pressed.connect(_on_bottom_launch)
	_wheel_top.result_ready.connect(_on_top_result)
	_wheel_bottom.result_ready.connect(_on_bottom_result)
	_back_button.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/menu/title.tscn"))

func _on_top_launch() -> void:
	if _wheel_top.is_running:
		return
	_btn_top.disabled  = true
	_label_top.text    = "Ball in play..."
	_wheel_top.launch()

func _on_bottom_launch() -> void:
	if _wheel_bottom.is_running:
		return
	_btn_bottom.disabled = true
	_label_bottom.text   = "Ball in play..."
	_wheel_bottom.launch()

func _on_top_result(slot_number: int) -> void:
	_label_top.text   = "Result: Slot %d" % slot_number
	_btn_top.disabled = false

func _on_bottom_result(slot_number: int) -> void:
	_label_bottom.text   = "Result: Slot %d" % slot_number
	_btn_bottom.disabled = false
