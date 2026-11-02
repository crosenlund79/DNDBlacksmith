## LootPanel — opens a container and reveals its contents one item at a time.
## EN: Unrevealed slots show "?"; a short search timer runs for each (rarer finds take a breath
##     longer). Rarity was fixed when the container was created — the reveal only presents it.
## DA: Uafslørede pladser viser "?"; en kort søgetid løber for hver. Sjældenheden blev afgjort,
##     da beholderen blev skabt — afsløringen viser den blot.
class_name LootPanel
extends UIWindow

var container: Dictionary
var slots: Array = []
var bar: ProgressBar
var status: RichTextLabel
var index := 0
var timer := 0.0
var duration := 1.0
var done := false


func _init(uid: int) -> void:
	for c in Game.state["returns"]:
		if int(c["uid"]) == uid:
			container = c
	super._init(str(container.get("name", "Container")), 980, 600, true)


func _ready() -> void:
	super._ready()
	if container.is_empty():
		close()
		return
	Audio.play("sfx/bag_open")
	content.add_child(UIKit.rich("[i]%s[/i]" % container.get("note", ""), 22, true))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for it in container.get("contents", []):
		var s := ItemSlot.new(it, 92.0)
		s.hidden_item = true
		grid.add_child(s)
		slots.append(s)
	content.add_child(grid)
	bar = UIKit.bar(0.0, 1.0, 600)
	content.add_child(bar)
	status = UIKit.rich("", 22, true)
	content.add_child(status)
	var take := UIKit.button("Take everything", _take, 260)
	content.add_child(take)
	_start_next()


func _start_next() -> void:
	if index >= slots.size():
		done = true
		bar.value = 1.0
		status.text = "[color=#c8b898]Searched. %d item%s found.[/color]" % [slots.size(), "" if slots.size() == 1 else "s"]
		return
	var rar: String = slots[index].item.get("rarity", "common")
	duration = {"common": 0.75, "magic": 1.0, "rare": 1.35, "legendary": 1.9, "unique": 1.9, "set": 1.6}.get(rar, 0.8)
	timer = 0.0
	status.text = "[color=#c8b898]Searching…[/color]"


func _process(delta: float) -> void:
	if done or slots.is_empty():
		return
	timer += delta
	bar.value = timer / duration
	if int(timer * 6) != int((timer - delta) * 6):
		Audio.play("sfx/search_tick", -12.0)
	if timer >= duration:
		var s: ItemSlot = slots[index]
		s.hidden_item = false
		s.refresh()
		var it: Dictionary = s.item
		var rar: String = it.get("rarity", "common")
		status.text = "[color=#%s]%s[/color]" % [Items.color(it).to_html(false), Items.display_name(it)]
		match rar:
			"legendary", "unique", "set":
				UIRoot.instance.legendary_flash()
				Events.toast.emit("★ LEGENDARY: " + Items.display_name(it), "legendary")
				var p := FX.embers(50)
				p.one_shot = true
				p.explosiveness = 0.9
				p.spread = 180.0
				p.initial_velocity_min = 100.0
				p.initial_velocity_max = 220.0
				p.position = Vector2(46, 46)
				s.add_child(p)
				p.emitting = true
				if rar == "legendary":
					Game.state["stats"]["legendaries"] += 1
			"rare":
				Audio.play("sfx/reveal_rare")
			"magic":
				Audio.play("sfx/reveal_magic")
			_:
				Audio.play("sfx/reveal_common", -4.0)
		index += 1
		_start_next()


func _take() -> void:
	for it in container.get("contents", []):
		Game.add_item(it, false)
	Game.state["returns"].erase(container)
	Events.inventory_changed.emit()
	Events.toast.emit("Added %d item%s to your stores." % [container.get("contents", []).size(), "" if container.get("contents", []).size() == 1 else "s"], "good")
	if str(container.get("from", "")).begins_with("Borin"):
		Objectives.complete("open_bag")
	close()
