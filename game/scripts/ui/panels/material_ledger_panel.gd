## MaterialLedgerPanel — the material ledger (Living Workshop #46; route "materials", from the stores' "Material
## ledger" button).
## EN: Per material: what is in the stores now, what came in since the record began and from where (bought — and from
##     whom —, made at your stations or by a named worker, starting stores, received), what was used, and — kept
##     apart, never guessed — what was on hand before the record began (origin unknown) and any change the record
##     could not itemise. The latest movements underneath. Reads MaterialLedger only; the gold ledger is untouched.
## DA: Materialeregnskab: beholdning, tilgang efter kilde, forbrug; det ukendte før registreringen holdes adskilt.
class_name MaterialLedgerPanel
extends UIWindow

const COLS := [["Material", 250], ["In stores", 92], ["Came in since the record began", 520], ["Used", 80], ["Before the record", 150], ["Not itemised", 120]]

var only_stock := false
var body: VBoxContainer


func _init(args := {}) -> void:
	only_stock = bool(args.get("stock", false))
	super._init("Material Ledger", 1340, 0)
	name = "MaterialLedger"


func _ready() -> void:
	super._ready()
	body = UIKit.vbox(6)
	content.add_child(body)
	_build()
	Events.inventory_changed.connect(_build)


func _build() -> void:
	if not is_inside_tree():
		return
	UIKit.clear(body)
	var since := MaterialLedger.since_day()
	var head := UIKit.hbox(12)
	var intro := ""
	if MaterialLedger.st().is_empty():
		intro = "Nothing has moved since this ledger began keeping count (day %d). What is in the stores now was there before it — its origin is not recorded." % since
	elif MaterialLedger.complete():
		intro = "A complete record from the first day: every material that came in or was used."
	else:
		intro = "Recorded from day %d. Stock on hand before then is shown apart — where it came from was never recorded." % since
	var il := UIKit.note(intro, UIKit.FS_SMALL)
	il.name = "LedgerIntro"
	il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(il)
	var tg := UIKit.small_button("Show everything recorded" if only_stock else "Only what is in the stores", func():
		only_stock = not only_stock
		_build.call_deferred(), 0)
	tg.name = "StockToggle"
	head.add_child(tg)
	body.add_child(head)
	# the table
	var grid := GridContainer.new()
	grid.name = "LedgerTable"
	grid.columns = COLS.size()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	for c in COLS:
		var hl := UIKit.label(str(c[0]), UIKit.FS_MIN, "body_bold", UIKit.RUBRIC)
		hl.custom_minimum_size = Vector2(float(c[1]), 0)
		grid.add_child(hl)
	var shown := 0
	for r in MaterialLedger.rows():
		if only_stock and int(r["remaining"]) <= 0:
			continue
		shown += 1
		var nm := UIKit.hbox(6)
		nm.add_child(UIKit.icon(Items.icon_id({"def": r["def"]}), 26))
		var nl := UIKit.label(str(r["name"]), UIKit.FS_SMALL, "body_bold")
		nl.name = "Mat_" + str(r["def"])
		nm.add_child(nl)
		grid.add_child(nm)
		grid.add_child(_num(int(r["remaining"]), true))
		var parts := PackedStringArray()
		for s in r["sources"]:
			parts.append("%s %s" % [UIKit.num(int(s[1])), str(s[0])])
		var src := UIKit.label(("%s in: " % UIKit.num(int(r["acquired"])) + " · ".join(parts)) if not parts.is_empty() else "—", UIKit.FS_MIN)
		src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		src.custom_minimum_size = Vector2(float(COLS[2][1]), 0)
		grid.add_child(src)
		grid.add_child(_num(int(r["used"]), false))
		var bf := int(r["before"])
		grid.add_child(UIKit.label(("%s — origin unknown" % UIKit.num(bf)) if bf > 0 else "—", UIKit.FS_MIN, "body_italic", UIKit.FADED))
		var ux := int(r["unitemised"])
		var ul := UIKit.label(("%+d" % ux) if ux != 0 else "—", UIKit.FS_MIN, "body_italic", UIKit.FADED)
		if ux != 0:
			ul.tooltip_text = "Changes made without passing the ledger (e.g. sold to the caravan or pawnshop, given away): counted, not itemised."
			ul.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(ul)
	if shown == 0:
		body.add_child(UIKit.note("No materials in the stores." if only_stock else "No materials recorded yet."))
	body.add_child(UIKit.scroll(grid, mini(560, 34 + shown * 34)))
	# the latest movements
	var rec := MaterialLedger.recent()
	if not rec.is_empty():
		body.add_child(UIKit.divider())
		body.add_child(UIKit.label("Latest movements", UIKit.FS_BODY, "heading"))
		var lines := PackedStringArray()
		for i in range(rec.size() - 1, maxi(-1, rec.size() - 9), -1):
			var e: Array = rec[i]
			var t := int(e[0])
			lines.append("Day %d, %02d:%02d · %s %s — %s" % [int(t / 1440) + 1, int((t % 1440) / 60), t % 60,
				("+%s" % UIKit.num(int(e[2]))) if int(e[2]) > 0 else UIKit.num(int(e[2])), str(DB.item(str(e[1])).get("name", e[1])), str(e[3])])
		var ml := UIKit.label("\n".join(lines), UIKit.FS_MIN)
		ml.name = "LedgerRecent"
		body.add_child(ml)


func _num(n: int, strong: bool) -> Label:
	var l := UIKit.label(UIKit.num(n), UIKit.FS_SMALL, "body_bold" if strong else "body", UIKit.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l
