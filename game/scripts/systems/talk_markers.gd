## TalkMarkers — who wants a word with the smith right now (shown as speech marks on the minimap
## and the village map).
## EN: Derived from existing systems (waiting customers, disputes, commissions ready to deliver, the
##     weekly delivery, the current objective, romance milestones) plus explicit flags any system can
##     set: TalkMarkers.flag(npc, reason) / TalkMarkers.clear(npc), stored in Game.state["talk_markers"].
## DA: Hvem vil gerne tale med smeden lige nu (talebobler på kortet).
class_name TalkMarkers
extends RefCounted


## Explicit flags set by other systems: npc -> reason text (removed with clear()).
static func flags() -> Dictionary:
	if not Game.state.has("talk_markers"):
		Game.state["talk_markers"] = {}
	return Game.state["talk_markers"]


static func flag(npc: String, reason: String) -> void:
	flags()[npc] = reason


static func clear(npc: String) -> void:
	flags().erase(npc)


## "" when the NPC has nothing particular to say, otherwise a short reason.
static func wants_to_talk(npc: String) -> String:
	return str(all().get(npc, ""))


## npc -> reason for everybody who wants a word.
static func all() -> Dictionary:
	var out := {}
	if Game.state.is_empty():
		return out
	for k in flags():
		out[k] = str(flags()[k])
	for c in Shop.waiting():
		var npc := str(c["npc"])
		match str(c.get("want", "")):
			"dispute":
				out[npc] = "Disputes your work — wants a refund"
			"repair":
				out[npc] = "Waiting outside the shop with a repair"
			"goods":
				out[npc] = "Waiting outside the shop to buy a draught"
			"advice":
				out[npc] = "Waiting outside the shop to ask your advice on their gear"
			_:
				out[npc] = "Waiting outside the shop to browse your wares"
	# commissions you could hand over right now
	for o in Shop.open_orders():
		var npc2 := str(o["npc"])
		if out.has(npc2):
			continue
		for it in Game.inventory():
			if Items.is_equipment(it) and Shop.item_meets(o, it):
				out[npc2] = "Your commission for them is ready to deliver"
				break
	if Game.state.get("world", {}).get("delivery_pending", false):
		out["aldric"] = "Has the weekly delivery for the forge"
	if Objectives.text().begins_with("Speak with Borin") and not out.has("borin"):
		out["borin"] = "Has something to tell you"
	for id in DB.characters:
		if not DB.characters[id].get("romance", false) or out.has(id):
			continue
		var stage := Social.romance(id)
		if stage == "dating" and Game.has_flag("walked_" + id):
			out[id] = "Might welcome a courtship"
		elif stage == "courting" and Game.count("ring_silver") > 0:
			out[id] = "Waiting for you to ask the question"
	return out
