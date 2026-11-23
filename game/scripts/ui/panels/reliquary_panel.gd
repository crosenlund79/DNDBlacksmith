## ReliquaryPanel — the Reliquary (route `reliquary` {uid}; R6): the case and what rests in it, why each piece earned
## its place, its heirs as the records show them (with the evidence), the letters, the agreed terms, and the way to
## restoration. Opened from the Reliquary station in the smithy and from a sealed heir letter.
## EN: Left: the case's places and the out-of-service pieces in the stores that could rest there (or why not).
##     Right: the chosen piece — significance, state, its ancestral nature (a bloodline Unique), the heirs with the
##     record behind each, letters, the terms, and the actions: lay it in, write to an heir, take it out for restoration.
## DA: Relikvieskabet: stykkerne, deres betydning, arvingerne med beviser, breve, aftaler og restaurering.
class_name ReliquaryPanel
extends UIWindow

const GOOD := Color("#2f6a1e")
const BAD := Color("#9a2a14")

var uid := -1
var list_box: VBoxContainer
var right: VBoxContainer
var offer := 0   # compensation offered, as a share of the piece's value (0, 10, 25, 50 %)
var buy := false


func _init(args: Dictionary = {}) -> void:
	uid = int(args.get("uid", -1))
	super._init("The Reliquary", 1400, 820)
	name = "ReliquaryPanel"


func _ready() -> void:
	super._ready()
	if uid < 0:
		var c := Reliquary.cases()
		if not c.is_empty():
			uid = int(c[0]["uid"])
	_build()


func _it() -> Dictionary:
	var it := Reliquary.held(uid)
	return it if not it.is_empty() else Game.find_uid(uid)


func _build() -> void:
	UIKit.clear(content)
	content.add_child(UIKit.rich("[i]\"A sword was forged to be wielded, not admired behind glass.\"[/i]  The Reliquary honours pieces that can no longer serve and whose service is remembered. It adds no fame — history earned that.", 19))
	var row := UIKit.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lv := UIKit.vbox(6)
	lv.custom_minimum_size = Vector2(440, 0)
	list_box = UIKit.vbox(4)
	lv.add_child(UIKit.scroll(list_box, 680))
	row.add_child(lv)
	right = UIKit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := UIKit.scroll(right, 700)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sc)
	content.add_child(row)
	_fill_list()
	_detail()


func _fill_list() -> void:
	UIKit.clear(list_box)
	list_box.add_child(UIKit.heading("In the case (%d of %d)" % [Reliquary.cases().size(), Reliquary.CASES]))
	if Reliquary.cases().is_empty():
		list_box.add_child(UIKit.note("Empty."))
	for it in Reliquary.cases():
		list_box.add_child(_row(it, true))
	list_box.add_child(UIKit.divider())
	list_box.add_child(UIKit.heading("Out of service, in your stores"))
	var any := false
	for it in Game.inventory():
		if Items.is_equipment(it) and Reliquary.out_of_service(it):
			list_box.add_child(_row(it, false))
			any = true
	if not any:
		list_box.add_child(UIKit.note("Nothing broken or unusable in the stores."))


func _row(it: Dictionary, in_case: bool) -> Control:
	var u := int(it.get("uid", -1))
	var b := UIKit.button(("✦ " if in_case else "") + Items.display_name(it), func():
		uid = u
		_build())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if u == uid:
		b.add_theme_color_override("font_color", GOOD)
	return b


func _detail() -> void:
	UIKit.clear(right)
	var it := _it()
	if it.is_empty():
		right.add_child(UIKit.note("Choose a piece."))
		return
	var in_case := not Reliquary.held(uid).is_empty()
	var hh := UIKit.hbox(14)
	hh.add_child(UIKit.icon(Items.icon_id(it), 72))
	hh.add_child(UIKit.title(Items.display_name(it), 30))
	right.add_child(hh)
	var sig := Reliquary.significance(it)
	var state := GearDepth.state_word(it)
	var lines := PackedStringArray()
	lines.append("[b]State:[/b] %s" % ("unusable — only restoration brings it back" if state == "disabled" else ("broken — half strength until mended" if state == "broken" else "sound")))
	lines.append("[b]Why it is remembered:[/b] %s" % (sig if sig != "" else "[color=#9a2a14]nothing on record — it has earned no place in the case[/color]"))
	var anc := Reliquary.ancestral_state(it)
	if anc != "":
		lines.append("[b]Ancestral nature:[/b] %s" % ("awake" if anc == "awake" else "[color=#9a2a14]asleep[/color] — only a restoration with the consent of its line wakes it fully"))
	var c := Reliquary.claim(uid)
	if c.has("answer"):
		lines.append("[b]Agreed with %s:[/b] %s%s" % [str(c.get("heir_name", "")), {"decline": "declined to take part", "custody": "consent; it remains the family's, kept in your care",
			"return": "consent; restored, it goes home to them", "sold": "consent and a sale — it is yours"}.get(str(c["answer"]), str(c["answer"])),
			(" — %d g compensation" % int(c.get("compensation", 0))) if int(c.get("compensation", 0)) > 0 else ""])
	right.add_child(UIKit.rich("\n".join(lines), 20))
	var acts := UIKit.hbox(10)
	if in_case:
		acts.add_child(UIKit.button("Take it out for restoration", func():
			var why := Reliquary.take_out(uid)
			if why != "":
				Events.toast.emit(why, "bad")
				return
			close()
			Events.open_panel.emit("refine", {"station": Refinement.station_for(_it_any(), "restore"), "uid": uid, "action": "restore"})))
	else:
		var why2 := Reliquary.enshrine_reason(it)
		var b := UIKit.button("Lay it in the Reliquary", func():
			var w := Reliquary.enshrine(uid)
			Events.toast.emit(w if w != "" else "Laid in the Reliquary.", "bad" if w != "" else "good")
			_build())
		b.name = "Enshrine"
		b.disabled = why2 != ""
		acts.add_child(b)
		if why2 != "":
			right.add_child(UIKit.note(why2))
	right.add_child(acts)
	right.add_child(UIKit.divider())
	# heirs, as the records show them
	right.add_child(UIKit.heading("Heirs on record"))
	var hs := Reliquary.heirs_of(it)
	if hs.is_empty():
		right.add_child(UIKit.note("No living heir is on record: no one who held it without selling it lives, and no recorded family of a fallen bearer survives. No one is invented."))
	for h in hs:
		var box := UIKit.vbox(4)
		box.add_child(UIKit.rich("[b]%s[/b] — %s\n[i]%s[/i]" % [str(h["name"]), Reliquary._rel_text(h), str(h["evidence"])], 19))
		box.name = "Heir_" + str(h["id"])
		right.add_child(box)
	if not hs.is_empty() and (not c.has("answer") or str(c["answer"]) == "decline"):
		var v := Valuation.value(it)
		var orow := UIKit.hbox(8)
		orow.add_child(UIKit.label("Compensation:", 19))
		for pct in [0, 10, 25, 50]:
			var p2: int = pct
			var tb := UIKit.small_button("%d g" % int(round(float(v) * float(p2) / 100.0)), func():
				offer = p2
				_detail())
			if offer == pct:
				tb.add_theme_color_override("font_color", GOOD)
			orow.add_child(tb)
		var bb := UIKit.small_button(("✓ " if buy else "") + "offer to buy (%d g)" % int(round(float(v) * 1.2)), func():
			buy = not buy
			_detail())
		orow.add_child(bb)
		right.add_child(orow)
		var h0: Dictionary = hs[0]
		var wb := UIKit.button("Write to %s" % str(h0["name"]), func():
			var why3 := Reliquary.write_to(uid, str(h0["id"]), int(round(float(v) * float(offer) / 100.0)), int(round(float(v) * 1.2)) if buy else 0)
			Events.toast.emit(why3 if why3 != "" else "The letter is on its way — an answer tomorrow.", "bad" if why3 != "" else "good")
			_detail())
		wb.name = "WriteHeir"
		right.add_child(wb)
	# letters
	var ls := (Reliquary.st().get("letters", []) as Array).filter(func(l): return int(l.get("uid", -1)) == uid)
	if not ls.is_empty():
		right.add_child(UIKit.divider())
		right.add_child(UIKit.heading("Letters"))
		for l in ls:
			right.add_child(UIKit.rich("[color=#6b5a3e]Day %d[/color] — %s" % [int(l["day"]), str(l["text"])], 18))


func _it_any() -> Dictionary:
	var it := Game.find_uid(uid)
	return it if not it.is_empty() else Reliquary.held(uid)
