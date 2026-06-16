class_name Modifier
extends RefCounted

enum Type {
	NONE,
	SUM_X2,
	ALL_BLACK_X2,
	ALL_RED_X2,
	ALL_EVEN_X2,
	ALL_ODD_X2,
}

const TYPE_MAP := {
	"sum_x2": Type.SUM_X2,
	"all_black_x2": Type.ALL_BLACK_X2,
	"all_red_x2": Type.ALL_RED_X2,
	"all_even_x2": Type.ALL_EVEN_X2,
	"all_odd_x2": Type.ALL_ODD_X2,
}

static func compute_multiplier(throws: Array[Dictionary]) -> float:
	var mult: float = 1.0
	for item in GameState.get_modifier_items():
		var e: Dictionary = item.get("effects", {})
		var t: Type = TYPE_MAP.get(e.get("modifier_type", ""), Type.NONE)
		match t:
			Type.SUM_X2:
				mult *= 2.0
			Type.ALL_BLACK_X2:
				if throws.all(func(t): return t.get("slot_color", "") == "black"):
					mult *= 2.0
			Type.ALL_RED_X2:
				if throws.all(func(t): return t.get("slot_color", "") == "red"):
					mult *= 2.0
			Type.ALL_EVEN_X2:
				if throws.all(func(t): return t.get("value", 0) % 2 == 0):
					mult *= 2.0
			Type.ALL_ODD_X2:
				if throws.all(func(t): return t.get("value", 0) % 2 == 1):
					mult *= 2.0
	return mult
