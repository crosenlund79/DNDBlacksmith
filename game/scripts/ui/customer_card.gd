## CustomerCard — a customer's request (or a commission) as a clear card with icons.
## EN: Built from Shop.request(customer) / Shop.order_request(order): what they want (slot or
##     item), the attributes it must have ("protection ≥ 10, frost"), preferred materials, budget,
##     reward, and for commissions the deadline and priority. Used at the counter, in dialogue and
##     in the commissions panel so the same request always looks the same.
## DA: En kundes ønske som et tydeligt kort med ikoner (disk, samtale og bestillinger).
class_name CustomerCard
extends RefCounted

const SLOT_ICON := {"weapon": "icons/sword_iron", "armor": "icons/cuirass_iron", "shield": "icons/shield_round",
	"helmet": "icons/helm_iron", "boots": "icons/boots_leather", "gloves": "icons/gloves_leather", "belt": "icons/belt_leather",
	"ring": "icons/ring_silver", "amulet": "icons/amulet_silver", "cloak": "icons/cloak_travel"}
const STAT_ICON := {"attack": "ui/need_attack", "protection": "ui/need_protection", "magic": "ui/need_magic",
	"fire": "icons/coating_flame", "frost": "icons/coating_frost", "ward": "icons/runestone_ward"}
const MATERIAL_ICON := {"iron": "icons/ingot_iron", "steel": "icons/ingot_steel", "mithril": "icons/ingot_mithril",
	"starsteel": "icons/sword_starsteel", "adamantine": "icons/ingot_adamantine", "leather": "icons/leather_cured",
	"silver": "icons/ore_silver", "gems": "icons/gem_garnet", "cloth": "icons/cloth_linen"}
const KIND_WORD := {"equipment": "Customer", "repair": "Repair job", "goods": "Shopping", "dispute": "Complaint", "commission": "Commission",
	"multi": "Several requests", "advice": "Seeks advice"}


static func build(r: Dictionary, width := 0.0) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#eadcb6")
	sb.border_color = UIKit.INK if r.get("kind", "") != "dispute" else UIKit.RUBRIC
	sb.set_border_width_all(2)
	sb.border_width_left = 6
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	pc.add_theme_stylebox_override("panel", sb)
	if width > 0.0:
		pc.custom_minimum_size = Vector2(width, 0)
	var v := UIKit.vbox(4)
	pc.add_child(v)
	# header: what it is about
	var head := UIKit.hbox(12)
	var main_icon := _main_icon(r)
	if main_icon != "":
		head.add_child(_framed(main_icon, 44))   # #47: was 58
	var hv := UIKit.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label(str(KIND_WORD.get(r.get("kind", ""), "Customer")).to_upper(), 15, "heading", UIKit.RUBRIC))
	hv.add_child(UIKit.label(str(r.get("headline", "")), 22, "heading"))   # #47: was 26
	head.add_child(hv)
	v.add_child(head)
	# the requirement chips
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 6)
	if r.has("stat"):
		var t := "%s ≥ %d" % [r["stat"], int(r.get("min", 0))]
		flow.add_child(_chip(str(STAT_ICON.get(r["stat"], "ui/need_protection")), t, true))
	if str(r.get("prop", "")) != "" and r.get("prop") != r.get("stat"):
		flow.add_child(_chip(str(STAT_ICON.get(r["prop"], "icons/coating_frost")), "%s damage" % r["prop"], true))
	if r.has("condition"):
		flow.add_child(_chip("icons/oil_whetstone", str(r["condition"]), false))
	var mats: Array = r.get("materials", [])
	if not mats.is_empty():
		var mh := UIKit.hbox(4)
		for m in mats:
			mh.add_child(UIKit.icon(str(MATERIAL_ICON.get(m, "icons/ingot_iron")), 30))
		mh.add_child(UIKit.label(("needs " if r.get("material_required", false) else "prefers ") + " or ".join(PackedStringArray(mats)), 19))
		flow.add_child(mh)
	if r.has("budget"):
		flow.add_child(_chip("icons/gold", "budget %d g" % int(r["budget"]), false))
	if str(r.get("reward_text", "")) != "":
		flow.add_child(_chip("icons/purse_gift", str(r["reward_text"]), false))
	if r.has("deadline"):
		var left := int(r["deadline"]) - Game.day()
		flow.add_child(_chip("ui/need_deadline", "due day %d (%s)" % [int(r["deadline"]), "today" if left <= 0 else ("%d day%s left" % [left, "" if left == 1 else "s"])], left <= 1))
	if str(r.get("priority", "")) != "":
		var p: Dictionary = Shop.PRIORITY.get(r["priority"], {})
		if not p.is_empty():
			flow.add_child(_chip("icons/star", str(p["name"]), false))
	v.add_child(flow)
	if str(r.get("note", "")) != "":
		v.add_child(UIKit.label("“%s”" % r["note"], 18, "body_italic", Color("#5e421c")))
	# one part of a multi-order: can the smith do it now, and has it been decided?
	if r.has("availability"):
		var st := str(r.get("status", "pending"))
		var col := Color("#2f6a1e")
		var txt := "✓ Craftable now — %s" % r.get("why", "")
		match str(r["availability"]):
			"materials":
				col = Color("#6a5a12")
				txt = "Craftable — %s" % r.get("why", "")
			"locked":
				col = UIKit.RUBRIC
				txt = "✗ Not yet — %s" % r.get("why", "")
		if st != "pending":
			col = Color("#5e421c")
			txt = {"accepted": "Accepted — now a commission", "declined": "Declined", "done": "Done"}.get(st, st)
		var al := UIKit.label(txt, 19, "body_bold", col)
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(al)
	return pc


static func _main_icon(r: Dictionary) -> String:
	var d := str(r.get("item_def", ""))
	if d != "" and Assets.has_tex("icons/" + d):
		return "icons/" + d
	if SLOT_ICON.has(str(r.get("slot", ""))):
		return SLOT_ICON[str(r["slot"])]
	if r.get("kind", "") == "dispute":
		return "ui/need_dispute"
	if r.get("kind", "") == "advice":
		return "ui/ic_talk"
	return "icons/gold"


static func _framed(id: String, size: float) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#d8c495")
	sb.border_color = UIKit.GILT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(30)
	sb.set_content_margin_all(4)
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(UIKit.icon(id, size))
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pc


static func _chip(icon_id: String, text: String, strong: bool) -> Control:
	var h := UIKit.hbox(6)
	h.add_child(UIKit.icon(icon_id, 30))
	var l := UIKit.label(text, 20 if strong else 19, "body_bold" if strong else "body", UIKit.RUBRIC if strong else UIKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	return h
