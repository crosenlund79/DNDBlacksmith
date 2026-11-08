## HistoryPanel — placeholder until implemented.
class_name HistoryPanel
extends UIWindow


func _init(kind: String = "", id: String = "") -> void:
	super._init("History", 900, 500)


func _ready() -> void:
	super._ready()
	content.add_child(UIKit.label("Coming soon.", 22, "body_italic"))
