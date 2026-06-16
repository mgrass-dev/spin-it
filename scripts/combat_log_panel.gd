class_name CombatLogPanel
extends Control

var _vbox: VBoxContainer
var _scroll: ScrollContainer

func _init() -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_vbox)

func add_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(label)
	_scroll.scroll_vertical = 999999
