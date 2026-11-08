## PropertyPanel — placeholder until implemented.
class_name PropertyPanel
extends UIWindow


func _init() -> void:
	super._init("Property & Workshop", 900, 500)


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.label("Coming soon.", 22, "body_italic"))
