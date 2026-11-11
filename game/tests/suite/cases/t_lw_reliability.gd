## The Living Workshop — RELIABILITY worker (wave 1): playtest defects #57, #59–61, #53, #58, #39, #45, #56 and the
## verifications #41, #48, #49. Each test reproduces the reported behaviour with the real systems and then checks the fix
## (or records the numbers for the later balance pass).
extends SuiteCase

const SMOKE := ["test_shield_stays_with_the_smith"]


# ------------------------------------------------------------------ fixtures
func _host() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	return root.get_child(root.get_child_count() - 1)


func _mount(c: Control) -> Control:
	_host().add_child(c)
	return c


func _unmount(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent():
			n.get_parent().remove_child(n)
		n.free()


## The first node called `n` under `root` that is not being freed (UIKit.clear queues the old children for deletion).
func _live(root: Node, n: String, cls := "") -> Node:
	for c in root.find_children(n, cls, true, false):
		var x: Node = c
		var dead := false
		while x != null and x != root:
			if x.is_queued_for_deletion():
				dead = true
				break
			x = x.get_parent()
		if not dead:
			return c
	return null


func _live_button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			var x: Node = b
			var dead := false
			while x != null and x != root:
				dead = dead or x.is_queued_for_deletion()
				x = x.get_parent()
			if not dead:
				return b
	return null


func _scan_clean(what: String) -> void:
	var r := ItemRegistry.scan()
	check((r["dup"] as Array).is_empty() and (r["shared"] as Array).is_empty() and (r["stray"] as Array).is_empty(),
		"%s: ItemRegistry.scan is clean (%s)" % [what, ItemRegistry.scan_text(r)])


## A shield the smith forges himself (real recipe, real materials).
func _forge_shield() -> Dictionary:
	give("ingot_iron", 1)
	give("leather_cured", 1)
	return craft("round_shield")


# ------------------------------------------------------------------ #57 the smith's own shield
func test_shield_stays_with_the_smith() -> void:
	fresh_game()
	var sh := _forge_shield()
	if not check(not sh.is_empty(), "the smith forges a round shield (%s)" % craft_blocker("round_shield")):
		return
	var uid := int(sh["uid"])
	var maker := str(sh.get("crafted_by", ""))
	var owners: Array = (sh.get("prov", {}).get("owners", []) as Array).duplicate(true)
	# the stores window before: the shield is in the grid
	var p := _mount(InventoryPanel.new()) as InventoryPanel
	p._select(sh)
	var take := func(n: String) -> Node: return _live(p, n)
	check(take.call("Worn_shield") != null, "the stores window has a worn-shield slot")
	# equip through the same button the player uses
	var eb := _live_button(p, "Equip on Brannoc")
	if check(eb != null, "the stores window offers 'Equip on Brannoc' for the shield"):
		eb.pressed.emit()
	eq(Game.player_worn_slot(uid), "shield", "the smith wears it in the shield slot")
	check(Game.find_uid(uid).is_empty(), "it left the stores grid (it is worn, not duplicated)")
	check(is_same(Game.state["player"]["equipment"]["shield"], sh), "the very same piece is worn (one object per uid)")
	eq(str(ItemRegistry.where(uid).get("holder", "")), "smith", "the registry knows where it is")
	var slot_node := take.call("Worn_shield") as ItemSlot
	check(slot_node != null and int(slot_node.item.get("uid", -1)) == uid, "the worn-shield slot shows it (it no longer vanishes)")
	check(take.call("TakeOff") != null, "the worn piece is selected and can be taken off")
	_scan_clean("worn")
	# identity: uid, maker and owners untouched by wearing it
	eq(str(sh.get("crafted_by", "")), maker, "maker unchanged")
	eq((sh.get("prov", {}).get("owners", []) as Array), owners, "owner chain unchanged")
	# every slot a piece can be worn in is shown (cloak, belt, amulet were missing too)
	for s in ["weapon", "shield", "armor", "helmet", "gloves", "boots", "cloak", "belt", "ring", "amulet"]:
		check(take.call("Worn_" + s) != null, "the stores window shows the %s slot" % s)
	# save/load keeps it worn, same uid, once
	check(save_load("lwrel_shield"), "save/load")
	var worn: Dictionary = Game.state["player"]["equipment"].get("shield", {})
	eq(int(worn.get("uid", -1)), uid, "after loading he still wears the same shield")
	eq(str(worn.get("crafted_by", "")), maker, "maker survives save/load")
	_scan_clean("after load")
	_unmount(p)
	# a second shield replaces it; the first goes back to the stores (nothing lost)
	var sh2 := _forge_shield()
	if check(not sh2.is_empty(), "a second shield"):
		eq(Game.equip_player(int(sh2["uid"])), "shield", "the second shield is put on")
		check(not Game.find_uid(uid).is_empty(), "the first shield is back in the stores, not lost")
		_scan_clean("swapped")
	# taking it off through the window's button
	p = _mount(InventoryPanel.new()) as InventoryPanel
	p._select(Game.state["player"]["equipment"]["shield"])
	var off := _live(p, "TakeOff") as Button
	if check(off != null, "the take-off button is offered for the worn shield"):
		off.pressed.emit()
	check(Game.player_worn_slot(int(sh2["uid"])) == "" and not Game.find_uid(int(sh2["uid"])).is_empty(), "taken off: back in the stores")
	check(not Game.unequip_player("shield"), "nothing left to take off")
	_scan_clean("taken off")
	_unmount(p)
