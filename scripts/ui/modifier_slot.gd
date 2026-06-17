class_name ModifierSlot
extends Control

const PADDING := 4
const ICON_HEIGHT := 20
const SEPARATION := 6

var _item_data: Dictionary = {}
var _icon_texture: Texture2D
var _placeholder: Control
var _placeholder_label: Label
var _label: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, 84)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_placeholder = Control.new()
	_placeholder.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PADDING
	)
	_placeholder.draw.connect(_draw_placeholder)
	add_child(_placeholder)

	_placeholder_label = Label.new()
	_placeholder_label.text = "No current modifier"
	_placeholder_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	_placeholder_label.add_theme_font_size_override("font_size", 12)
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, PADDING + 2
	)
	add_child(_placeholder_label)

	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.visible = false
	add_child(_label)


func setup(item_data: Dictionary) -> void:
	_item_data = item_data
	var has_item := not item_data.is_empty()
	_placeholder.visible = not has_item
	_placeholder_label.visible = not has_item
	_label.visible = has_item
	if has_item:
		var tex_path = item_data.get("icon_path", "")
		_icon_texture = load(tex_path) if not tex_path.is_empty() else null
		_label.text = item_data.get("name", "")
		var rarity = item_data.get("rarity", "common")
		_label.add_theme_color_override("font_color", _rarity_color(rarity))
	_position_children()
	_placeholder.queue_redraw()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_children()


func _icon_draw_size() -> Vector2:
	if _icon_texture:
		var tex := _icon_texture.get_size()
		var scale := ICON_HEIGHT / tex.y
		return Vector2(tex.x * scale, tex.y * scale)
	return Vector2(ICON_HEIGHT, ICON_HEIGHT)

func _position_children() -> void:
	var content_x := PADDING
	var content_y := PADDING
	var content_w := maxf(0, size.x - PADDING * 2)
	var content_h := maxf(0, size.y - PADDING * 2)

	var icon_size := _icon_draw_size()
	var label_x := content_x + icon_size.x + SEPARATION
	var label_w := maxf(0, content_x + content_w - label_x)

	_label.position = Vector2(label_x, content_y)
	_label.size = Vector2(label_w, content_h)


func _draw() -> void:
	if _item_data.is_empty():
		return
	var r := Rect2(
		Vector2(PADDING, PADDING),
		size - Vector2(PADDING * 2, PADDING * 2)
	)
	if r.size.x <= 0 or r.size.y <= 0:
		return
	draw_rect(r, Color(0.15, 0.12, 0.08, 0.7), true)

	if _icon_texture:
		var icon_size := _icon_draw_size()
		var icon_y := r.position.y + (r.size.y - icon_size.y) / 2.0
		draw_texture_rect(_icon_texture, Rect2(r.position.x, icon_y, icon_size.x, icon_size.y), false)


func is_empty() -> bool:
	return _item_data.is_empty()


static func _rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Color(0.3, 0.6, 1.0)
		"epic":
			return Color(0.7, 0.3, 0.9)
		"legendary":
			return Color(1.0, 0.7, 0.1)
		_:
			return Color.WHITE


func _draw_placeholder() -> void:
	var r := Rect2(Vector2.ZERO, _placeholder.size)
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var color := Color(0.78, 0.55, 0.18, 0.5)
	var w := 1.5
	var dash := 5.0
	var gap := 3.0
	var radius := 4.0

	_placeholder.draw_dashed_line(
		r.position + Vector2(radius, 0),
		r.position + Vector2(r.size.x - radius, 0),
		color, w, dash, gap, true
	)
	_placeholder.draw_dashed_line(
		r.position + Vector2(radius, r.size.y),
		r.position + Vector2(r.size.x - radius, r.size.y),
		color, w, dash, gap, true
	)
	_placeholder.draw_dashed_line(
		r.position + Vector2(0, radius),
		r.position + Vector2(0, r.size.y - radius),
		color, w, dash, gap, true
	)
	_placeholder.draw_dashed_line(
		r.position + Vector2(r.size.x, radius),
		r.position + Vector2(r.size.x, r.size.y - radius),
		color, w, dash, gap, true
	)
