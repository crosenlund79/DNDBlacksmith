## QuickTravelMenu — placeholder until implemented.
class_name QuickTravelMenu
extends UIWindow


func _init(args: Dictionary = {}) -> void:
	super._init("Quick Travel", 900, 500)


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.label("Coming soon.", 22, "body_italic"))
