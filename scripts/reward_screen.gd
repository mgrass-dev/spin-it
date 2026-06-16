extends CanvasLayer

const CARD_SIZE := Vector2(200, 280)
const CARD_SPACING := 30

const SLOT_BLACK = preload("res://sprites/roue/slot_black.png")
const SLOT_RED = preload("res://sprites/roue/slot_red.png")
const WHEEL_BG = preload("res://sprites/roue/wheel_bg.png")
const WHEEL_CENTER = preload("res://sprites/roue/wheel_center.png")

const MINI_WHEEL_RADIUS := 145.0
const MINI_WHEEL_SCALE := 0.55

var is_merchant_mode := false
var _items: Array[Dictionary] = []
var _selected_purchase: Dictionary = {}
var _mini_wheel_active := false
var _mini_wheel_container: Node2D
var _mini_wheel_close_btn: Button
var _replaced_card: ColorRect
var _slot_selected := false

signal closed()

func _ready() -> void:
	layer = 20
	_randomize_items()
	_build_ui()

func _randomize_items() -> void:
	var all := GameState.get_all_items()
	all.shuffle()
	_items = all.slice(0, 3)

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var gold := GameState.get_gold()
	var title := Label.new()
	title.text = "VICTORY!" if not is_merchant_mode else "Merchant"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(640 - 150, 20)
	title.size = Vector2(300, 50)
	add_child(title)

	var gold_label := Label.new()
	gold_label.text = "Gold: %d" % gold
	gold_label.add_theme_font_size_override("font_size", 22)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.position = Vector2(640 - 100, 70)
	gold_label.size = Vector2(200, 30)
	add_child(gold_label)

	var start_x := (1280 - (_items.size() * CARD_SIZE.x + (_items.size() - 1) * CARD_SPACING)) / 2
	var card_y := 130

	for idx in _items.size():
		var item_data := _items[idx]
		var card := _make_card(item_data, idx)
		card.position = Vector2(start_x + idx * (CARD_SIZE.x + CARD_SPACING), card_y)
		add_child(card)

	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll (1 gold)"
	reroll_btn.size = Vector2(180, 40)
	reroll_btn.position = Vector2(640 - 90 - 100, 530)
	reroll_btn.pressed.connect(_on_reroll)
	reroll_btn.disabled = gold < 1
	add_child(reroll_btn)

	var pass_btn := Button.new()
	pass_btn.text = "Skip"
	pass_btn.size = Vector2(180, 40)
	pass_btn.position = Vector2(640 - 90 + 100, 530)
	pass_btn.pressed.connect(_on_pass)
	add_child(pass_btn)

func _make_card(item_data: Dictionary, idx: int) -> Control:
	var card := ColorRect.new()
	card.size = CARD_SIZE
	card.color = Color(0.15, 0.15, 0.2, 0.95)

	var icon := Sprite2D.new()
	icon.texture = load(item_data.get("icon_path", ""))
	icon.position = Vector2(CARD_SIZE.x / 2, 50)
	icon.scale = Vector2(2, 2)
	card.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = item_data.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 90)
	name_lbl.size = Vector2(CARD_SIZE.x, 25)
	card.add_child(name_lbl)

	var rarity_lbl := Label.new()
	var rarity: String = item_data.get("rarity", "commun")
	rarity_lbl.text = rarity
	rarity_lbl.add_theme_font_size_override("font_size", 12)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.position = Vector2(0, 115)
	rarity_lbl.size = Vector2(CARD_SIZE.x, 20)
	var rarity_colors := {"commun": Color(0.8, 0.8, 0.8), "rare": Color(0.3, 0.6, 1.0), "épique": Color(0.7, 0.3, 0.9), "légendaire": Color(1.0, 0.7, 0.0)}
	rarity_lbl.add_theme_color_override("font_color", rarity_colors.get(rarity, Color.WHITE))
	card.add_child(rarity_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item_data.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.position = Vector2(5, 140)
	desc_lbl.size = Vector2(CARD_SIZE.x - 10, 70)
	card.add_child(desc_lbl)

	var cost: int = item_data.get("cost", 0)
	var buy_btn := Button.new()
	buy_btn.text = "Buy (%d gold)" % cost
	buy_btn.size = Vector2(CARD_SIZE.x - 20, 35)
	buy_btn.position = Vector2(10, CARD_SIZE.y - 45)
	buy_btn.pressed.connect(_on_buy.bind(idx))
	buy_btn.disabled = GameState.get_gold() < cost
	card.add_child(buy_btn)

	return card

func _on_buy(idx: int) -> void:
	var item: Dictionary = _items[idx]
	var cost: int = item.get("cost", 0)
	if not GameState.spend_gold(cost):
		return

	var item_type: String = item.get("type", "")
	match item_type:
		"modifier":
			GameState.add_item(item)
			GameState.save_game()
			_on_pass()
		"wheel_item":
			_selected_purchase = item
			GameState.add_item(item)
			_show_mini_wheel()
		_:
			GameState.add_item(item)
			GameState.save_game()
			_on_pass()

func _show_mini_wheel() -> void:
	_mini_wheel_active = true
	_slot_selected = false

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var title := Label.new()
	title.text = "Choose a slot to replace"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(640 - 200, 20)
	title.size = Vector2(400, 40)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var gold_lbl := Label.new()
	gold_lbl.text = "Gold: %d" % GameState.get_gold()
	gold_lbl.add_theme_font_size_override("font_size", 18)
	gold_lbl.position = Vector2(640 + 180, 20)
	gold_lbl.size = Vector2(120, 30)
	gold_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gold_lbl)

	_mini_wheel_container = Node2D.new()
	add_child(_mini_wheel_container)
	_build_mini_wheel_visual()

	var side_card_size := Vector2(180, 210)
	var side_card_y := 250

	var left_card := ColorRect.new()
	left_card.size = side_card_size
	left_card.color = Color(0.12, 0.12, 0.18, 0.95)
	left_card.position = Vector2(60, side_card_y)
	left_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_card)
	_make_mini_card(left_card, _selected_purchase, "Purchase")

	var right_card := ColorRect.new()
	right_card.size = side_card_size
	right_card.color = Color(0.12, 0.12, 0.18, 0.95)
	right_card.position = Vector2(1280 - 60 - side_card_size.x, side_card_y)
	right_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_card.hide()
	add_child(right_card)
	_replaced_card = right_card

	_mini_wheel_close_btn = Button.new()
	_mini_wheel_close_btn.text = "Close"
	_mini_wheel_close_btn.size = Vector2(160, 40)
	_mini_wheel_close_btn.position = Vector2(640 - 80, 640)
	_mini_wheel_close_btn.pressed.connect(_on_mini_wheel_close)
	_mini_wheel_close_btn.hide()
	add_child(_mini_wheel_close_btn)

func _make_mini_card(card: ColorRect, item_data: Dictionary, label_text: String) -> void:
	for child in card.get_children():
		child.queue_free()

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 4)
	lbl.size = Vector2(card.size.x, 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	if item_data.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Empty slot"
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.position = Vector2(0, 80)
		empty_lbl.size = Vector2(card.size.x, 22)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(empty_lbl)
		return

	var icon := Sprite2D.new()
	icon.texture = load(item_data.get("icon_path", ""))
	if icon.texture:
		icon.position = Vector2(card.size.x / 2, 50)
		icon.scale = Vector2(1.5, 1.5)
	card.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = item_data.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 80)
	name_lbl.size = Vector2(card.size.x, 22)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	var rarity: String = item_data.get("rarity", "commun")
	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.position = Vector2(0, 102)
	rarity_lbl.size = Vector2(card.size.x, 18)
	var rarity_colors := {"commun": Color(0.8, 0.8, 0.8), "rare": Color(0.3, 0.6, 1.0), "épique": Color(0.7, 0.3, 0.9), "légendaire": Color(1.0, 0.7, 0.0)}
	rarity_lbl.add_theme_color_override("font_color", rarity_colors.get(rarity, Color.WHITE))
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rarity_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item_data.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.position = Vector2(5, 125)
	desc_lbl.size = Vector2(card.size.x - 10, 80)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc_lbl)

func _build_mini_wheel_visual() -> void:
	for child in _mini_wheel_container.get_children():
		child.queue_free()

	var center := Vector2(640, 400)
	var rad := MINI_WHEEL_RADIUS * MINI_WHEEL_SCALE

	var bg := Sprite2D.new()
	bg.texture = WHEEL_BG
	bg.position = center
	bg.scale = Vector2(MINI_WHEEL_SCALE, MINI_WHEEL_SCALE)
	bg.z_index = 1
	_mini_wheel_container.add_child(bg)

	var angle_step: float = TAU / 20
	var default_values: Array = Array(range(1, 21))
	default_values.shuffle()

	var equipped_by_pos: Dictionary = {}
	for eq in GameState.equipped_wheel_slots:
		var p: int = eq.get("position", -1)
		if p >= 0 and p < 20:
			equipped_by_pos[p] = eq

	for i in 20:
		var angle := i * angle_step
		var pos := center + Vector2(cos(angle), sin(angle)) * rad

		var is_black: bool
		var val: int
		if i in equipped_by_pos:
			var eq: Dictionary = equipped_by_pos[i]
			is_black = eq.get("slot_color", "black") == "black"
			val = eq.get("value", 1)
		else:
			is_black = i % 2 == 0
			val = default_values[i]

		var tex := SLOT_BLACK if is_black else SLOT_RED
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.scale = Vector2(MINI_WHEEL_SCALE, MINI_WHEEL_SCALE)
		sp.position = pos
		sp.rotation = angle + PI / 2
		sp.z_index = 5
		_mini_wheel_container.add_child(sp)

		var lbl := Label.new()
		lbl.text = str(val)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = pos - Vector2(18, 8)
		lbl.size = Vector2(36, 16)
		lbl.z_index = 6
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mini_wheel_container.add_child(lbl)

	var inner := Sprite2D.new()
	inner.texture = WHEEL_CENTER
	inner.position = center
	inner.scale = Vector2(MINI_WHEEL_SCALE, MINI_WHEEL_SCALE)
	inner.z_index = 8
	_mini_wheel_container.add_child(inner)

func _input(event: InputEvent) -> void:
	if not _mini_wheel_active or _slot_selected:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var click_pos := (event as InputEventMouseButton).position
	var center := Vector2(640, 400)
	var dist := click_pos.distance_to(center)
	var rad := MINI_WHEEL_RADIUS * MINI_WHEEL_SCALE
	var tolerance: float = rad * 0.35

	if abs(dist - rad) > tolerance:
		return

	var angle := (click_pos - center).angle()
	while angle < 0:
		angle += TAU
	var angle_step: float = TAU / 20
	var idx := int(angle / angle_step + 0.5) % 20
	_apply_slot(idx)
	get_viewport().set_input_as_handled()

func _apply_slot(slot_index: int) -> void:
	var effects: Dictionary = _selected_purchase.get("effects", {})
	var value: int = effects.get("value", 1)
	var slot_color: String = effects.get("slot_color", "black")
	var item_id: String = _selected_purchase.get("id", "")

	var replaced: Dictionary = GameState.get_slot_at_position(slot_index)
	GameState.replace_slot(slot_index, value, slot_color, item_id)

	_slot_selected = true
	GameState.save_game()
	_build_mini_wheel_visual()
	_mini_wheel_close_btn.show()

	if _replaced_card:
		_replaced_card.show()
		var replaced_item: Dictionary = {}
		if not replaced.is_empty():
			for item in GameState.get_all_items():
				if item.get("id", "") == replaced.get("item_id", ""):
					replaced_item = item.duplicate()
					break
		_make_mini_card(_replaced_card, replaced_item, "Replaced")

func _on_mini_wheel_close() -> void:
	_mini_wheel_active = false
	if is_merchant_mode:
		closed.emit()
		queue_free()
	else:
		get_tree().change_scene_to_file("res://scenes/map.tscn")
		queue_free()

func _on_reroll() -> void:
	if not GameState.spend_gold(1):
		return
	_rebuild()

func _on_pass() -> void:
	closed.emit()
	queue_free()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_items.clear()
	_mini_wheel_active = false
	_slot_selected = false
	_mini_wheel_container = null
	_mini_wheel_close_btn = null
	_replaced_card = null
	_randomize_items()
	_build_ui()
