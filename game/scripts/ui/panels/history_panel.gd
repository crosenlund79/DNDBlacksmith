## HistoryPanel — the event history of a person, a piece of work or a workstation (see History).
## EN: kind "npc" (id = character/hireling id), "item" (id = uid) or "station" (id = station id).
##     Tabs group the entries; every row shows its day and a coloured kind tag.
## DA: Historikken for en person, en genstand eller en arbejdsstation.
class_name HistoryPanel
extends UIWindow

const KIND := {
	"deed": ["Deed", "#7e2418"], "memory": ["Memory", "#5e421c"], "trade": ["Trade", "#735800"], "gift": ["Gift", "#26622f"],
	"expedition": ["Expedition", "#2d5a78"], "commission": ["Commission", "#8a4a10"], "work": ["Work", "#3c5226"],
	"craft": ["Crafted", "#9e3a0c"], "owner": ["Owner", "#24409a"], "note": ["Note", "#5e421c"],
}
const TABS := {
	"npc": [["all", "Everything", []], ["deeds", "Deeds & Expeditions", ["deed", "expedition"]], ["memories", "Memories & Gifts", ["memory", "gift"]],
		["trade", "Trade & Commissions", ["trade", "commission"]], ["work", "Work", ["work"]]],
	"item": [["all", "Everything", []], ["craft", "Craft Record", ["craft"]], ["owners", "Owners & Deeds", ["owner", "deed", "note"]]],
	"station": [["all", "Work Done Here", []]],
}

var kind := ""
var id := ""
var tab := "all"
var list: VBoxContainer
var tabs_row: HBoxContainer
var entries: Array = []


func _init(k: String = "", i: String = "") -> void:
	kind = k
	id = i
	super._init("History", 1180, 760)


func _ready() -> void:
	super._ready()
	_header()
	tabs_row = UIKit.hbox(8)
	content.add_child(tabs_row)
	list = UIKit.vbox(6)
	content.add_child(UIKit.scroll(list, 470))
	_collect()
	_tabs()
	_fill()


func _collect() -> void:
	match kind:
		"npc": entries = History.npc_entries(id)
		"item": entries = History.item_entries(History.find_item(int(id)))
		"station": entries = History.station_entries(id)
		_: entries = []


func _header() -> void:
	var h := UIKit.hbox(18)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match kind:
		"npc":
			var hl := Hire.get_h(id)
			h.add_child(UIKit.portrait("portraits/" + (str(hl["look"]) if not hl.is_empty() else id), 120))
			title_label.text = "History — " + Talk.npc_name(id)
			var c := DB.character(id)
			var sub := str(c.get("title", c.get("cls", "")))
			var a := Adv.get_a(id)
			if not a.is_empty():
				sub = "%s %s, level %d" % [Adv.rating_text(a), str(a.get("cls", "")), int(a.get("level", 1))]
			elif not hl.is_empty():
				sub = "Your hireling since day %d" % int(hl.get("hired_day", 1))
			v.add_child(UIKit.label(sub, 22, "heading_italic", UIKit.RUBRIC))
			var bandw := {"hostile": "openly hostile", "cool": "cool towards you", "neutral": "neither friend nor foe",
				"warm": "warm towards you", "friendly": "a friend", "devoted": "devoted to you"}
			v.add_child(UIKit.label("They are %s." % bandw.get(Social.band(id), "unknown to you"), 20, "body_italic"))
			var why := TalkMarkers.wants_to_talk(id)
			if why != "":
				v.add_child(UIKit.rich("[color=#7e2418]❧[/color] [i]%s[/i]" % why, 20))
		"item":
			var it := History.find_item(int(id))
			if it.is_empty():
				title_label.text = "History — a lost piece"
				v.add_child(UIKit.label("This piece is no longer anywhere you can see.", 20, "body_italic"))
			else:
				h.add_child(ItemSlot.new(it, 110.0))
				title_label.text = "History — " + Items.display_name(it)
				v.add_child(UIKit.label("%s · %s" % [Items.RARITY_LABEL.get(str(it.get("rarity", "common")), ""), Items.type_label(it)], 22, "heading_italic", UIKit.RUBRIC))
				var chain := History.owner_chain(it)
				if not chain.is_empty():
					v.add_child(UIKit.rich("[b]Hands it passed through:[/b] " + " → ".join(chain), 20))
		"station":
			var st := DB.station(id)
			h.add_child(UIKit.icon("stations/" + id, 120))
			title_label.text = "History — " + str(st.get("name", id))
			var lg: Array = History.station_log().get(id, [])
			var n := lg.size()
			var best := {}
			var tot := 0.0
			for e in lg:
				tot += float(e.get("q", 0.0))
				if best.is_empty() or float(e.get("final_q", 0.0)) > float(best.get("final_q", 0.0)):
					best = e
			v.add_child(UIKit.label(Crafting.DISCIPLINE_NAME.get(str(st.get("discipline", "")), ""), 22, "heading_italic", UIKit.RUBRIC))
			if n > 0:
				v.add_child(UIKit.rich("[b]%d[/b] piece%s worked here · average step %d%% · finest: [i]%s[/i]" % [n, "" if n == 1 else "s", int(round(tot / n)), str(best.get("text", "")).get_slice(" — ", 0)], 20))
			else:
				v.add_child(UIKit.label("Nothing has been made here yet.", 20, "body_italic"))
	h.add_child(v)
	content.add_child(h)
	content.add_child(UIKit.divider())


func _tabs() -> void:
	UIKit.clear(tabs_row)
	for t in TABS.get(kind, [["all", "Everything", []]]):
		var key: String = t[0]
		var n := _filtered(t[2]).size()
		var b := UIKit.button("%s (%d)" % [t[1], n], func(): tab = key; _tabs(); _fill(), 0)
		if key == tab:
			b.add_theme_color_override("font_color", UIKit.RUBRIC)
			b.add_theme_color_override("font_hover_color", UIKit.RUBRIC)
		tabs_row.add_child(b)


func _filtered(kinds: Array) -> Array:
	if kinds.is_empty():
		return entries
	return entries.filter(func(e): return kinds.has(e["kind"]))


func _fill() -> void:
	UIKit.clear(list)
	var kinds: Array = []
	for t in TABS.get(kind, []):
		if t[0] == tab:
			kinds = t[2]
	var es := _filtered(kinds)
	if es.is_empty():
		list.add_child(UIKit.label("Nothing recorded yet." if entries.is_empty() else "Nothing of this sort recorded.", 22, "body_italic"))
		return
	var last_day := -1
	for e in es:
		var d := int(e["day"])
		if d != last_day:
			last_day = d
			list.add_child(UIKit.label("Day %d" % d if d > 0 else "Long ago", 22, "heading", UIKit.RUBRIC))
		var row := UIKit.hbox(12)
		var k: Array = KIND.get(str(e["kind"]), ["Note", "#5e421c"])
		var tag := UIKit.label(k[0], 16, "body_bold", Color(k[1]))
		tag.custom_minimum_size = Vector2(110, 0)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(tag)
		var txt := UIKit.rich(("[color=#5e421c]%s[/color]  " % e["time"] if str(e.get("time", "")) != "" else "") + str(e["text"]), 19)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		if kind == "station" and int(e.get("item", 0)) > 0 and not History.find_item(int(e["item"])).is_empty():
			var uid := str(e["item"])
			row.add_child(UIKit.button("Piece", func(): Events.open_panel.emit("history", {"kind": "item", "id": uid}), 90))
		list.add_child(row)
