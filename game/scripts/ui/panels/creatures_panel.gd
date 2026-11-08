## CreaturesPanel — placeholder until implemented.
class_name CreaturesPanel
extends UIWindow


func _init(args: Dictionary = {}) -> void:
	super._init("Creatures & Companions", 900, 500)


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.label("Coming soon.", 22, "body_italic"))
