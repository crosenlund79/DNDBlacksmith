## Property — which parts of the smithy building the smith owns, its rooms, doors and installed
## stations (stub: everything owned until implemented).
## DA: Ejendom — hvilke dele af smedjebygningen smeden ejer.
class_name Property


static func init_new() -> void:
	pass


## "" when the station is installed in an owned room, otherwise the reason.
static func station_reason(_station_id: String) -> String:
	return ""
