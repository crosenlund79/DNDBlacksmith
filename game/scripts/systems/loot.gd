## Loot — loot tables, random equipment and containers that are revealed item by item.
## EN: Rarity is decided here (by the loot system), never by the reveal animation.
## DA: Sjældenhed afgøres her af loot-systemet — aldrig af afsløringsanimationen.
class_name Loot
extends RefCounted


## skill: the finder's relevant skill level; "skill_entries" in a table add finds that only
## experienced hands recognise (a sapphire vein, a reliquary under the mound).
static func roll_table(table_id: String, bias := 0.0, skill := 0) -> Array:
	var t: Dictionary = DB.loot.get(table_id, {})
	if t.is_empty():
		return []
	bias += float(t.get("rarity_bias", 0))
	var entries: Array = t["entries"].duplicate()
	var se: Dictionary = t.get("skill_entries", {})
	for k in se:
		if skill >= int(k):
			entries.append_array(se[k])
	var total := 0.0
	for e in entries:
		total += float(e[1])
	var out := []
	var n := Rng.ri("expeditions", int(t["rolls"][0]), int(t["rolls"][1]))
	for i in n:
		var pick := Rng.f("expeditions") * total
		for e in entries:
			pick -= float(e[1])
			if pick <= 0.0:
				var qty := Rng.ri("expeditions", int(e[2][0]), int(e[2][1]))
				var id: String = e[0]
				if id.begins_with("equip:"):
					out.append(random_equipment(id.substr(6), bias))
				else:
					out.append(Items.make(id, {"qty": qty, "quality": Rng.rf("expeditions", 55, 95)}))
				break
	return out


static func _equip_defs(category: String) -> Array:
	var defs := []
	for d in DB.items.values():
		var s: Variant = d.get("slot")
		if not (s is String) or s == "":
			continue
		var tags: Array = d.get("tags", [])
		if tags.has("unique") or tags.has("set"):
			continue
		if category == "weapon" and s != "weapon":
			continue
		if category == "jewel" and not (s in ["ring", "amulet"]):
			continue
		defs.append(d["id"])
	return defs


static func random_equipment(category := "any", bias := 0.0) -> Dictionary:
	if category == "ancient":
		# grave-goods of an older age: well made, often magical, never common junk
		var adefs := _equip_defs("any")
		var aid: String = Rng.pick("expeditions", adefs)
		var aq := Rng.rf("expeditions", 85.0, 118.0)
		var ait := Items.make(aid, {"quality": aq, "dice": {"edge": Rng.ri("expeditions", 8, 20), "guard": Rng.ri("expeditions", 8, 20), "temper": Rng.ri("expeditions", 4, 12)}})
		var ar := Items.rarity_from(aq, Rng.ri("expeditions", 30, 100), 10.0 + bias * 0.2)
		Items.apply_rarity(ait, "rare" if ar in ["common", "magic"] else ar)
		ait["crafted_by"] = "a smith of the barrow-kings' age"
		ait["ancient"] = true
		return ait
	if category == "garrison":
		# v1.6 §8.1, the Weeping Fortress: the garrison's old arms and armour — well made, historic, never common junk
		var gdefs := _equip_defs("any")
		var gid: String = Rng.pick("expeditions", gdefs)
		var gq := Rng.rf("expeditions", 82.0, 112.0)
		var git := Items.make(gid, {"quality": gq, "dice": {"edge": Rng.ri("expeditions", 8, 20), "guard": Rng.ri("expeditions", 8, 20), "temper": Rng.ri("expeditions", 4, 12)}})
		var gr := Items.rarity_from(gq, Rng.ri("expeditions", 30, 100), 8.0 + bias * 0.2)
		Items.apply_rarity(git, "rare" if gr in ["common", "magic"] else gr)
		git["crafted_by"] = "an armourer of the Weeping Garrison"
		git["ancient"] = true
		return git
	if category == "legendary_demo":
		var it := Items.make("sword_steel", {"quality": 112.0, "dice": {"edge": 18, "temper": 10}})
		Items.apply_rarity(it, "legendary")
		it["crafted_by"] = "a dwarf-smith of Ironroot, long dead"
		return it
	var defs := _equip_defs(category)
	var def_id: String = Rng.pick("expeditions", defs) if not defs.is_empty() else "dagger"
	var q := clampf(Rng.rf("expeditions", 45.0, 100.0) + bias * 0.3, 20.0, 125.0)
	var dice := {"edge": Rng.ri("expeditions", 1, 20), "guard": Rng.ri("expeditions", 1, 20), "temper": Rng.ri("expeditions", 1, 12)}
	var it := Items.make(def_id, {"quality": q, "dice": dice})
	var fortune := Rng.ri("expeditions", 1, 100) + int(bias)
	var score := q * 0.65 + fortune * 0.45
	# very rare named drops. A Unique exists once per campaign (D13, Uniques): once it has been minted — whatever has
	# happened to it since — the find is an ordinary piece instead. Set pieces may recur.
	if score >= 112.0 and Rng.f("expeditions") < 0.25:
		var named := "grimhold" if Rng.f("expeditions") < 0.5 else "wyvernscale_pauldron"
		if not Uniques.is_unique_def(named) or Uniques.can_mint(named):
			var nit := Items.make(named, {"quality": q})
			Uniques.register(nit, "loot")
			return nit
	var rar := Items.rarity_from(q, fortune)
	if rar != "common":
		Items.apply_rarity(it, rar)
	return it


## Creates a container item whose contents are fixed at creation.
static func make_container(def_id: String, contents: Array, from := "", note := "") -> Dictionary:
	var c := Items.make(def_id)
	c["contents"] = contents
	c["from"] = from
	c["note"] = note
	return c


static func best_rarity(items: Array) -> String:
	var order := ["common", "magic", "rare", "set", "unique", "legendary"]
	var best := 0
	for it in items:
		best = max(best, order.find(it.get("rarity", "common")))
	return order[best]
