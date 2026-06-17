extends GutTest

const MODIFIER_SLOT = preload("res://scripts/ui/modifier_slot.gd")

func test_instantiation() -> void:
	var slot = MODIFIER_SLOT.new()
	assert_not_null(slot)
	assert_true(slot.is_empty())
	slot.free()

func test_setup_with_item() -> void:
	var slot = MODIFIER_SLOT.new()
	var item = {
		"id": "mod_sum_x2",
		"name": "Double Sum",
		"type": "modifier",
		"icon_path": "res://sprites/roue/slot_red.png",
		"rarity": "legendary",
	}
	slot.setup(item)
	assert_false(slot.is_empty())
	slot.free()

func test_setup_empty_clears() -> void:
	var slot = MODIFIER_SLOT.new()
	slot.setup({"id": "test", "name": "Test", "type": "modifier"})
	assert_false(slot.is_empty())
	slot.setup({})
	assert_true(slot.is_empty())
	slot.free()

func test_three_slots_created_in_modifiers_container() -> void:
	var container = VBoxContainer.new()
	for i in 3:
		container.add_child(MODIFIER_SLOT.new())
	assert_eq(container.get_child_count(), 3)
	container.free()
