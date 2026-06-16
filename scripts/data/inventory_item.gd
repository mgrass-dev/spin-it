extends RefCounted

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum ItemType { BALL, MODIFIER, WHEEL_ITEM, OTHER }

const RARITY_NAMES := ["common", "rare", "epic", "legendary"]
const TYPE_NAMES := ["ball", "modifier", "wheel_item", "other"]

static func create(data: Dictionary) -> Dictionary:
	return {
		"id": data.get("id", ""),
		"name": data.get("name", ""),
		"description": data.get("description", ""),
		"type": data.get("type", TYPE_NAMES[ItemType.OTHER]),
		"icon_path": data.get("icon_path", ""),
		"rarity": data.get("rarity", RARITY_NAMES[Rarity.COMMON]),
		"effects": data.get("effects", {}),
	}

static func rarity_enum(rarity_name: String) -> Rarity:
	var idx := RARITY_NAMES.find(rarity_name)
	return Rarity.values()[idx if idx >= 0 else 0]

static func type_enum(type_name: String) -> ItemType:
	var idx := TYPE_NAMES.find(type_name)
	return ItemType.values()[idx if idx >= 0 else 3]
