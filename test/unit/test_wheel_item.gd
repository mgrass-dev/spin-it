extends GutTest

func test_modifier_defaults_to_zero() -> void:
	var item := WheelItem.new()
	assert_eq(item.modifier, 0)

func test_slot_color_defaults_to_black() -> void:
	var item := WheelItem.new()
	assert_eq(item.slot_color, WheelItem.SlotColor.BLACK)

func test_modifier_setter() -> void:
	var item := WheelItem.new()
	item.modifier = 42
	assert_eq(item.modifier, 42)

func test_slot_color_setter() -> void:
	var item := WheelItem.new()
	item.slot_color = WheelItem.SlotColor.RED
	assert_eq(item.slot_color, WheelItem.SlotColor.RED)
