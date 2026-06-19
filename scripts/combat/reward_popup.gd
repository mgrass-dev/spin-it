extends CanvasLayer

const CARD_SIZE := Vector2(160, 240)
const CARD_SPACING := 24

const CARD_BG_COMMON = preload("res://sprites/shop/card_common_background.png")
const CARD_BG_RARE = preload("res://sprites/shop/card_rare_background.png")
const CARD_BG_EPIC = preload("res://sprites/shop/card_epic_background.png")
const CARD_BG_LEGENDARY = preload("res://sprites/shop/card_legendary_background.png")

const ROULETTE_WHEEL_SCENE = preload("res://scenes/roulette/roulette_wheel.tscn")

var is_merchant_mode := false
var _items: Array[Dictionary] = []
var _reward_controls: Array[CanvasItem] = []
var _gold_label: Label
var _selected_purchase: Dictionary = {}
var _mini_wheel_active := false
var _selection_wheel: RouletteWheel
var _mini_wheel_container: Node2D
var _mini_wheel_close_btn: Button
var _replaced_card: ColorRect

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
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var gold := GameState.get_gold()
	var title := Label.new()
	title.text = "VICTORY!" if not is_merchant_mode else "Merchant"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(640 - 150, 20)
	title.size = Vector2(300, 50)
	add_child(title)
	_reward_controls.append(title)

	_gold_label = Label.new()
	_gold_label.text = "Gold: %d" % gold
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.position = Vector2(640 - 100, 70)
	_gold_label.size = Vector2(200, 30)
	add_child(_gold_label)
	_reward_controls.append(_gold_label)

	var start_x := (1280 - (_items.size() * CARD_SIZE.x + (_items.size() - 1) * CARD_SPACING)) / 2
	var card_y := get_viewport().get_visible_rect().size.y / 3

	for idx in _items.size():
		var item_data := _items[idx]
		var card := _make_card(item_data, idx)
		card.position = Vector2(start_x + idx * (CARD_SIZE.x + CARD_SPACING), card_y)
		add_child(card)
		_reward_controls.append(card)

	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll (1 gold)"
	reroll_btn.size = Vector2(180, 40)
	reroll_btn.position = Vector2(640 - 90 - 100, 530)
	reroll_btn.pressed.connect(_on_reroll)
	reroll_btn.disabled = gold < 1
	add_child(reroll_btn)
	_reward_controls.append(reroll_btn)

	var pass_btn := Button.new()
	pass_btn.text = "Skip"
	pass_btn.size = Vector2(180, 40)
	pass_btn.position = Vector2(640 - 90 + 100, 530)
	pass_btn.pressed.connect(_on_pass)
	add_child(pass_btn)
	_reward_controls.append(pass_btn)

func _make_card(item_data: Dictionary, idx: int) -> Control:
	var rarity: String = item_data.get("rarity", "common")
	var card_bg_textures := {
		"common": CARD_BG_COMMON,
		"rare": CARD_BG_RARE,
		"epic": CARD_BG_EPIC,
		"legendary": CARD_BG_LEGENDARY,
	}

	var card := TextureRect.new()
	card.texture = card_bg_textures.get(rarity, CARD_BG_COMMON)
	card.size = CARD_SIZE
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.pivot_offset = CARD_SIZE / 2
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(_on_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_card_hover.bind(card, false))

	var name_lbl := Label.new()
	name_lbl.text = item_data.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 15)
	name_lbl.size = Vector2(CARD_SIZE.x, 20)
	card.add_child(name_lbl)

	var icon := Sprite2D.new()
	icon.texture = load(item_data.get("icon_path", ""))
	icon.position = Vector2(CARD_SIZE.x / 2, 100)
	icon.scale = Vector2(0.5, 0.5)
	card.add_child(icon)

	var item_type: String = item_data.get("type", "")
	if item_type == "wheel_item":
		var effects: Dictionary = item_data.get("effects", {})
		var value: int = effects.get("value", 0)
		var dmg_lbl := Label.new()
		dmg_lbl.text = str(value)
		dmg_lbl.add_theme_font_size_override("font_size", 11)
		dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dmg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var iw := 64.0 * icon.scale.x
		dmg_lbl.position = Vector2(CARD_SIZE.x / 2 - iw / 2, 98 - 64.0 * icon.scale.y)
		dmg_lbl.size = Vector2(iw, 18)
		card.add_child(dmg_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item_data.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.position = Vector2(4, 145)
	desc_lbl.size = Vector2(CARD_SIZE.x - 8, 45)
	card.add_child(desc_lbl)

	var cost: int = item_data.get("cost", 0)
	var buy_btn := Button.new()
	buy_btn.text = "Buy (%d gold)" % cost
	buy_btn.size = Vector2(CARD_SIZE.x - 20, 27)
	buy_btn.position = Vector2(10, CARD_SIZE.y - 37)
	buy_btn.pressed.connect(_on_buy.bind(idx))
	buy_btn.disabled = GameState.get_gold() < cost
	card.add_child(buy_btn)

	return card

func _on_card_hover(card: TextureRect, entered: bool) -> void:
	if not is_instance_valid(card):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.08, 1.08) if entered else Vector2.ONE, 0.12)

func _on_buy(idx: int) -> void:
	print("[reward] === BUY CLICKED === idx=", idx)
	var item: Dictionary = _items[idx]
	var cost: int = item.get("cost", 0)
	var gold: int = GameState.get_gold()
	print("[reward] item=", item.get("name", "?"), " cost=", cost, " gold=", gold)
	if gold < cost:
		print("[reward] *** GOLD CHECK FAILED: gold < cost ***")
		return
	print("[reward] gold check PASSED")

	var item_type: String = item.get("type", "")
	print("[reward] type=", item_type)
	match item_type:
		"modifier":
			print("[reward] --- modifier branch ---")
			GameState.spend_gold(cost)
			GameState.add_item(item)
			GameState.save_game()
			_on_pass()
		"wheel_item":
			print("[reward] === WHEEL ITEM BRANCH ===")
			_selected_purchase = item
			print("[reward] _selected_purchase stored: ", _selected_purchase.get("name", "?"))
			print("[reward] calling _show_mini_wheel()")
			_show_mini_wheel()
			print("[reward] returned from _show_mini_wheel()")
		_:
			print("[reward] --- default branch ---")
			GameState.spend_gold(cost)
			GameState.add_item(item)
			GameState.save_game()
			_on_pass()

func _show_mini_wheel() -> void:
	print("[reward] === _show_mini_wheel ENTERED ===")
	_mini_wheel_active = true
	print("[reward] hiding reward controls (count=", _reward_controls.size(), ")")
	for c in _reward_controls:
		if is_instance_valid(c):
			c.hide()
		else:
			print("[reward]   invalid control in _reward_controls")

	print("[reward] creating _mini_wheel_container")
	_mini_wheel_container = Node2D.new()
	_mini_wheel_container.name = "MiniWheelContainer"
	add_child(_mini_wheel_container)
	print("[reward] container child of popup: ", _mini_wheel_container.get_parent() == self)
	print("[reward] container in scene tree: ", _mini_wheel_container.is_inside_tree())

	print("[reward] adding title label to container")
	var title := Label.new()
	title.text = "Choose a slot to replace"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(640 - 200, 20)
	title.size = Vector2(400, 40)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_wheel_container.add_child(title)

	print("[reward] instantiating RouletteWheel from scene")
	_selection_wheel = ROULETTE_WHEEL_SCENE.instantiate()
	print("[reward] wheel instantiated: ", _selection_wheel)
	print("[reward] setting selection_mode to true")
	_selection_wheel.selection_mode = true
	print("[reward] setting wheel_scale=", 0.55)
	_selection_wheel.wheel_scale = 0.55
	print("[reward] setting position=", Vector2(640, 370))
	_selection_wheel.position = Vector2(640, 370)
	print("[reward] adding wheel to container")
	_mini_wheel_container.add_child(_selection_wheel)
	print("[reward] wheel is_inside_tree: ", _selection_wheel.is_inside_tree())
	print("[reward] wheel visible: ", _selection_wheel.visible)
	print("[reward] wheel position: ", _selection_wheel.position)
	print("[reward] wheel scale: ", _selection_wheel.scale)
	print("[reward] wheel selection_mode: ", _selection_wheel.selection_mode)
	print("[reward] connecting slot_selected signal")
	_selection_wheel.slot_selected.connect(_on_selection_slot_selected)
	
	# Lift number labels above the popup layer
	var numbers_cl := _selection_wheel.get_node_or_null("CanvasLayer") as CanvasLayer
	if numbers_cl:
		numbers_cl.layer = 21
		print("[reward] numbers container layer set to 21")
	else:
		print("[reward] WARNING: numbers CanvasLayer not found")

	var side_card_size := Vector2(180, 210)
	var side_card_y := 240

	print("[reward] creating left card (Purchase)")
	var left_card := ColorRect.new()
	left_card.size = side_card_size
	left_card.color = Color(0.12, 0.12, 0.18, 0.95)
	left_card.position = Vector2(60, side_card_y)
	left_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_wheel_container.add_child(left_card)
	_make_mini_card(left_card, _selected_purchase, "Purchase")

	print("[reward] creating right card (Replaced)")
	_replaced_card = ColorRect.new()
	_replaced_card.size = side_card_size
	_replaced_card.color = Color(0.12, 0.12, 0.18, 0.95)
	_replaced_card.position = Vector2(1280 - 60 - side_card_size.x, side_card_y)
	_replaced_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replaced_card.hide()
	_mini_wheel_container.add_child(_replaced_card)

	print("[reward] creating Close button")
	_mini_wheel_close_btn = Button.new()
	_mini_wheel_close_btn.text = "Close"
	_mini_wheel_close_btn.size = Vector2(160, 40)
	_mini_wheel_close_btn.position = Vector2(640 - 80, 640)
	_mini_wheel_close_btn.pressed.connect(_on_mini_wheel_close)
	_mini_wheel_close_btn.hide()
	_mini_wheel_container.add_child(_mini_wheel_close_btn)

	print("[reward] === _show_mini_wheel COMPLETE ===")

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

	var rarity: String = item_data.get("rarity", "common")
	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.position = Vector2(0, 102)
	rarity_lbl.size = Vector2(card.size.x, 18)
	var rarity_colors := {"common": Color(0.8, 0.8, 0.8), "rare": Color(0.3, 0.6, 1.0), "epic": Color(0.7, 0.3, 0.9), "legendary": Color(1.0, 0.7, 0.0)}
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

func _on_selection_slot_selected(slot_index: int) -> void:
	print("[reward] _on_selection_slot_selected slot=", slot_index,
		" purchase=", _selected_purchase.get("name", "?"))
	_apply_slot(slot_index)

func _apply_slot(slot_index: int) -> void:
	var cost: int = _selected_purchase.get("cost", 0)
	if not GameState.spend_gold(cost):
		print("[reward] not enough gold to apply slot")
		return
	GameState.add_item(_selected_purchase.duplicate())
	GameState.save_game()

	var effects: Dictionary = _selected_purchase.get("effects", {})
	var value: int = effects.get("value", 1)
	var slot_color: String = effects.get("slot_color", "black")
	var item_id: String = _selected_purchase.get("id", "")
	print("[reward] _apply_slot idx=", slot_index,
		" value=", value, " color=", slot_color, " item=", item_id)

	var replaced: Dictionary = GameState.get_slot_at_position(slot_index)
	GameState.replace_slot(slot_index, value, slot_color, item_id)

	GameState.save_game()
	_selection_wheel.load_player_slots()
	_mini_wheel_close_btn.show()

	if _replaced_card:
		_replaced_card.show()
		var replaced_item: Dictionary = {}
		if not replaced.is_empty():
			for item in GameState.get_all_items():
				if item.get("id", "") == replaced.get("item_id", ""):
					replaced_item = item.duplicate()
					break
		if replaced_item.is_empty():
			var was_black := slot_index % 2 == 0
			var prev_color := "black" if was_black else "red"
			var prev_val := slot_index + 1
			if not replaced.is_empty():
				prev_color = replaced.get("slot_color", prev_color)
				prev_val = replaced.get("value", prev_val)
			replaced_item = {
				"id": "",
				"name": "Slot %d" % (slot_index + 1),
				"description": "%s - %d" % [prev_color, prev_val],
				"type": "wheel_item",
				"icon_path": "res://sprites/roue/slot_%s.png" % prev_color,
				"rarity": "common",
			}
		_make_mini_card(_replaced_card, replaced_item, "Replaced")

func _on_mini_wheel_close() -> void:
	_mini_wheel_active = false
	_return_to_shop()

func _return_to_shop() -> void:
	if is_instance_valid(_mini_wheel_container):
		_mini_wheel_container.queue_free()
		_mini_wheel_container = null
	_selection_wheel = null
	_mini_wheel_close_btn = null
	_replaced_card = null

	if _gold_label:
		_gold_label.text = "Gold: %d" % GameState.get_gold()

	for c in _reward_controls:
		if is_instance_valid(c):
			c.show()

	if is_merchant_mode:
		closed.emit()
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
	_reward_controls.clear()
	_gold_label = null
	_mini_wheel_active = false
	_selection_wheel = null
	_mini_wheel_container = null
	_mini_wheel_close_btn = null
	_replaced_card = null
	_randomize_items()
	_build_ui()
