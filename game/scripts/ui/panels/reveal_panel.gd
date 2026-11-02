## RevealPanel — presents a newly crafted or gifted item with rarity-appropriate ceremony.
## DA: Viser en nyskabt eller modtaget genstand med en fejring, der passer til sjældenheden.
class_name RevealPanel
extends UIWindow

var item: Dictionary


func _init(it: Dictionary) -> void:
	item = it
	super._init("", 760, 620, true)


func _ready() -> void:
	super._ready()
	var rar: String = item.get("rarity", "common")
	title_label.text = {"legendary": "★ A Legendary Work ★", "rare": "A Rare Piece", "magic": "Something Special", "unique": "A Unique Treasure", "set": "Part of a Set"}.get(rar, "Finished")
	title_label.add_theme_color_override("font_color", Items.color(item))
	var h := UIKit.hbox(20)
	var slot := ItemSlot.new(item, 168.0)
	h.add_child(slot)
	var tt := UIKit.rich(Items.tooltip(item), 22, true)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tt)
	content.add_child(h)
	var btns := UIKit.hbox()
	if Items.is_equipment(item):
		btns.add_child(UIKit.button("Put it on display for sale", func():
			var it := Game.find_uid(int(item["uid"]))
			if not it.is_empty():
				it["for_sale"] = true
				Events.inventory_changed.emit()
			close(), 320))
	btns.add_child(UIKit.button("Keep it", close, 160))
	content.add_child(btns)
	match rar:
		"legendary", "unique", "set":
			_burst(slot)
		"rare":
			Audio.play("sfx/reveal_rare")
		"magic":
			Audio.play("sfx/reveal_magic")
		_:
			Audio.play("sfx/reveal_common")


func _burst(slot: Control) -> void:
	var p := FX.embers(60)
	p.one_shot = true
	p.explosiveness = 0.85
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 60)
	p.lifetime = 1.6
	p.position = Vector2(84, 84)
	slot.add_child(p)
	p.emitting = true
	var star := TextureRect.new()
	star.texture = Assets.get_tex("icons/star", Vector2i(32, 32))
	star.custom_minimum_size = Vector2(64, 64)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.position = Vector2(52, 52)
	star.pivot_offset = Vector2(32, 32)
	slot.add_child(star)
	var tw := create_tween()
	tw.tween_property(star, "scale", Vector2(3.2, 3.2), 0.5).from(Vector2(0.2, 0.2))
	tw.parallel().tween_property(star, "rotation", TAU, 0.9)
	tw.tween_property(star, "modulate:a", 0.0, 0.6)
