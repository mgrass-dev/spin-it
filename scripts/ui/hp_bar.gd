class_name HPBar
extends HBoxContainer

@export var icon_size: Vector2 = Vector2(40, 40)
@export var font_size_name: int = 14
@export var font_size_value: int = 11

var _hp_tween: Tween

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $Content/NameLabel
@onready var _bar_row: HBoxContainer = $Content/BarRow
@onready var _bar: ProgressBar = $Content/BarRow/Bar
@onready var _value_label: Label = $Content/BarRow/ValueLabel

func _ready() -> void:
	_icon.custom_minimum_size = icon_size
	_name_label.add_theme_font_size_override("font_size", font_size_name)
	_value_label.add_theme_font_size_override("font_size", font_size_value)
	_style_bar()

func _style_bar() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.1, 0.1)
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.04, 0.04, 0.85)
	bg.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.show_percentage = false
	_value_label.add_theme_color_override("font_color", Color.WHITE)

func set_bar_fill_color(color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)

func setup(icon_texture: Texture2D, entity_name: String, hp: int, max_hp: int) -> void:
	_icon.texture = icon_texture
	_icon.visible = icon_texture != null
	_name_label.text = entity_name
	_name_label.visible = entity_name != ""
	_bar_row.visible = max_hp > 0
	update_hp(hp, max_hp)

func update_hp(hp: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	_bar.value = hp
	if max_hp > 0:
		_value_label.text = "%d / %d" % [hp, max_hp]

func animate_hp(hp: int, max_hp: int, duration: float = 0.3) -> void:
	_bar.max_value = max_hp
	_value_label.text = "%d / %d" % [hp, max_hp]
	if _bar.value == hp:
		return
	if _hp_tween and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(_bar, "value", hp, duration)
	await _hp_tween.finished
