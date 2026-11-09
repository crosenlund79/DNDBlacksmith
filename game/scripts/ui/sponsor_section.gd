## SponsorSection — "Sponsor adventurers" in the dispatch ledger (Hirelings, H), beside sending hirelings.
## EN: Progressive disclosure: the sponsorships under way (objective, party, terms, ETA, status; Watch / Call off)
##     first; then the commission form (site → objective → party → terms) with a plain hint about whether the party
##     looks capable; then the negotiation (their answer, a counter-offer to agree to, revise or walk away from).
##     Everything is decided by Sponsor; this only shows it and passes the smith's choices on.
## DA: Sponsorér eventyrere: igangværende sponsorater, bestillingsformular og forhandling.
class_name SponsorSection
extends VBoxContainer

static var expanded := true
static var sel_site := ""
static var sel_obj := 0
static var sel_party := ""
static var terms := {"fee": 40, "bonus": 40, "share": 0}
static var last_answer := {}

var _queued := false


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	name = "SponsorSection"
	Events.expeditions_changed.connect(_queue)
	_build()


func _queue() -> void:
	if _queued:
		return
	_queued = true
	_build.call_deferred()


func _build() -> void:
	_queued = false
	if not is_inside_tree():
		return
	UIKit.clear(self)
	var head := UIKit.hbox(12)
	var hl := UIKit.label("Sponsor adventurers", 28, "heading", UIKit.RUBRIC)
	head.add_child(hl)
	var sub := UIKit.label("Pay a company or a lone adventurer to fetch something from a known site. They weigh the danger, the pay and you.", 18, "body_italic")
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sub)
	head.add_child(UIKit.button("Hide the form" if expanded else "Commission an expedition", func(): expanded = not expanded; _queue(), 0))
	add_child(head)
	# ---- what is under way (and the last results)
	var shown := Sponsor.open()
	for sp in Sponsor.all():
		if shown.size() >= 4:
			break
		if not shown.has(sp) and str(sp["status"]) in ["done", "cancelled"] and Game.day() - int(sp.get("day", 0)) <= 6:
			shown.append(sp)
	for sp in shown:
		add_child(_row(sp))
	if shown.is_empty():
		add_child(UIKit.label("No sponsored expeditions yet.", 18, "body_italic"))
	if not expanded:
		return
	_form()
	_negotiation()


func _row(sp: Dictionary) -> Control:
	var row := UIKit.hbox(10)
	var col: String = {"success": "#26622f", "partial": "#735800", "failure": "#9e3a0c", "lost": "#7e2418"}.get(str(sp.get("outcome", "")), "#20140c")
	var r := UIKit.rich("[color=%s]%s[/color]" % [col, Sponsor.line(sp)], 18)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(r)
	var sid := str(sp["id"])
	match str(sp["status"]):
		"contracted":
			row.add_child(UIKit.button("Call off", func():
				var err := Sponsor.cancel(sid)
				Events.toast.emit(err if err != "" else "Called off; the fee is back in your purse.", "bad" if err != "" else "info"), 120))
		"under_way":
			var eid := str(sp["exp"])
			var wb := UIKit.button("Watch", func(): Events.open_panel.emit("observe", {"id": eid}), 110)
			wb.disabled = not Expeditions.can_observe()
			wb.tooltip_text = "Follow the expedition on its map." if Expeditions.can_observe() else "On Master you hear of it when they return."
			row.add_child(wb)
		"done":
			if str(sp.get("lore", "")) != "":
				var place := str(sp["objective"]["site"])
				row.add_child(UIKit.button("Site", func(): Events.open_panel.emit("world_map", {"site": place}), 90))
	return row


func _form() -> void:
	var sites := Sponsor.sites()
	if sites.is_empty():
		add_child(UIKit.label("No site is known yet.", 18, "body_italic"))
		return
	if not sites.has(sel_site):
		sel_site = str(sites[0])
	var box := UIKit.vbox(6)
	# ---- 1: where
	var r1 := UIKit.hbox(10)
	r1.add_child(_cap("Site"))
	var so := OptionButton.new()
	so.name = "SiteOption"
	so.custom_minimum_size = Vector2(300, 40)
	for i in sites.size():
		so.add_item("%s (%s)" % [WorldSites.name_of(str(sites[i])), WorldSites.danger_word(str(sites[i]))], i)
		if str(sites[i]) == sel_site:
			so.select(i)
	so.item_selected.connect(func(i): sel_site = str(sites[i]); sel_obj = 0; _queue())
	r1.add_child(so)
	var cond := WorldSites.conditions(sel_site)
	var tr: Array = Expeditions.region(sel_site).get("travel_h", [2, 3])
	var si := UIKit.label("%s · %d–%d h on the road each way%s" % [WorldSites.danger_word(sel_site).capitalize(), int(tr[0]), int(tr[1]), (" · " + str(cond[0])) if not cond.is_empty() else ""], 17, "body_italic")
	si.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(si)
	box.add_child(r1)
	# ---- 2: what
	var objs := Sponsor.objectives(sel_site)
	var r2 := UIKit.hbox(10)
	r2.add_child(_cap("Fetch"))
	var oo := OptionButton.new()
	oo.name = "ObjectiveOption"
	oo.custom_minimum_size = Vector2(620, 40)
	sel_obj = clampi(sel_obj, 0, maxi(0, objs.size() - 1))
	for i in objs.size():
		oo.add_item("%s — %s" % [Sponsor.KIND_WORD.get(str(objs[i]["kind"]), objs[i]["kind"]), objs[i]["name"]], i)
	if not objs.is_empty():
		oo.select(sel_obj)
	oo.item_selected.connect(func(i): sel_obj = i; _queue())
	r2.add_child(oo)
	box.add_child(r2)
	# ---- 3: who
	var cands := Sponsor.candidates()
	var r3 := UIKit.hbox(10)
	r3.add_child(_cap("Ask"))
	var po := OptionButton.new()
	po.name = "PartyOption"
	po.custom_minimum_size = Vector2(620, 40)
	var found := false
	for i in cands.size():
		po.add_item(str(cands[i]["label"]), i)
		if str(cands[i]["key"]) == sel_party:
			po.select(i)
			found = true
	if not found and not cands.is_empty():
		sel_party = str(cands[0]["key"])
		po.select(0)
	po.item_selected.connect(func(i): sel_party = str(cands[i]["key"]); _queue())
	r3.add_child(po)
	if not cands.is_empty() and not objs.is_empty():
		var ids: Array = Sponsor.candidate(sel_party).get("members", [])
		var dr := Sponsor.danger_ratio(sel_site, ids) if not ids.is_empty() else 9.0
		var fit := "They look more than equal to it" if dr < 0.45 else ("A fair match for them" if dr < 0.8 else ("It will test them" if WorldSites.capable(sel_site, Sponsor.strength_of(ids), Sponsor.risk_of(ids)) else "This looks beyond them"))
		var fl := UIKit.label(fit, 18, "body_bold", Color("#26622f") if dr < 0.8 else (Color("#735800") if dr < 1.2 else UIKit.RUBRIC))
		fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r3.add_child(fl)
	box.add_child(r3)
	if cands.is_empty():
		box.add_child(UIKit.label("Nobody is in town and free to ask right now — adventurers come back and rest at the Tipsy Wyvern.", 18, "body_italic"))
	# ---- 4: terms
	var r4 := UIKit.hbox(10)
	r4.add_child(_cap("Terms"))
	var fee := _spin(r4, "Fee up front", "fee", 0, 2000, 5)
	var bonus := _spin(r4, "on success", "bonus", 0, 2000, 5)
	var share := _spin(r4, "% share", "share", 0, 90, 5)
	var gl := UIKit.label("You have %d g" % Game.gold(), 17, "body_italic")
	gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r4.add_child(gl)
	var ob := UIKit.button("Make the offer", func():
		terms = {"fee": int(fee.value), "bonus": int(bonus.value), "share": int(share.value)}
		last_answer = Sponsor.propose(objs[sel_obj], sel_party, terms)
		_queue(), 200)
	ob.name = "OfferButton"
	ob.disabled = cands.is_empty() or objs.is_empty()
	r4.add_child(ob)
	box.add_child(r4)
	add_child(box)


func _negotiation() -> void:
	var t := Sponsor.talk()
	var ans: Dictionary = t.get("answer", last_answer) if not t.is_empty() else last_answer
	if ans.is_empty():
		return
	var v := str(ans.get("verdict", ""))
	var col: String = {"accept": "#26622f", "counter": "#735800", "refuse": "#9e3a0c"}.get(v, "#20140c")
	var word: String = {"accept": "Accepted", "counter": "Counter-offer", "refuse": "Refused"}.get(v, "")
	var box := UIKit.vbox(4)
	box.name = "Negotiation"
	var hdr := "[color=%s][b]%s[/b][/color]%s — %s" % [col, word, (" (round %d)" % int(ans.get("round", 1))) if int(ans.get("round", 1)) > 1 else "", str(ans.get("who", ""))]
	box.add_child(UIKit.rich("%s: [i]%s[/i]" % [hdr, str(ans.get("reason", ""))], 19))
	if v == "counter" and not t.is_empty():
		var c: Dictionary = ans["counter"]
		var where := (" at %s" % WorldSites.name_of(str(c["site"]))) if c.has("site") else ""
		var row := UIKit.hbox(8)
		var tl := UIKit.label("They ask: %s%s" % [Sponsor.terms_text(c), where], 19, "body_bold")
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		row.add_child(UIKit.button("Agree", func():
			var err := Sponsor.agree()
			last_answer = {} if err == "" else {"verdict": "refuse", "reason": err}
			if err != "":
				Events.toast.emit(err, "bad")
			_queue(), 110))
		row.add_child(UIKit.button("Revise my offer", func():
			terms = {"fee": int(c["fee"]), "bonus": int(c["bonus"]), "share": int(c["share"])}
			if c.has("site"):
				sel_site = str(c["site"])
				var os := Sponsor.objectives(sel_site)
				for i in os.size():
					if str(os[i]["node"]) == str(c.get("node", "")) and str(os[i]["kind"]) == str(t["obj"]["kind"]) and str(os[i]["def"]) == str(t["obj"]["def"]):
						sel_obj = i
				Sponsor.walk_away()
			_queue(), 0))
		row.add_child(UIKit.button("Walk away", func(): last_answer = {}; Sponsor.walk_away(), 0))
		box.add_child(row)
	elif v == "accept" and str(ans.get("sid", "")) != "":
		var sp := Sponsor.get_s(str(ans["sid"]))
		if not sp.is_empty():
			box.add_child(UIKit.label("%s held for them until they leave · back %s" % [Sponsor.terms_text(sp["terms"]), Sponsor.when_text(Sponsor.eta(sp))], 18, "body_italic"))
	add_child(box)


func _cap(t: String) -> Label:
	var l := UIKit.label(t, 20, "body_bold", UIKit.RUBRIC)
	l.custom_minimum_size = Vector2(70, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _spin(row: HBoxContainer, label: String, key: String, lo: int, hi: int, step: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = int(terms.get(key, 0))
	sb.custom_minimum_size = Vector2(110, 40)
	sb.name = "Spin_" + key
	sb.value_changed.connect(func(v): terms[key] = int(v))
	row.add_child(sb)
	var l := UIKit.label(label, 17)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return sb
