## HelpPanel — the searchable reference guide (content from Reference) and the tutorial switch.
## EN: args {"topic": tab id or a search phrase} opens a section. Typing in the search box filters
##     every tab at once; nothing the smith has not discovered is listed.
## DA: Den søgbare opslagsbog; args {"topic": ...} åbner et afsnit.
class_name HelpPanel
extends UIWindow

var tab := "basics"
var query := ""
var search: LineEdit
var tab_col: VBoxContainer
var list: VBoxContainer
var count_label: Label
var tut_button: Button


func _init(args: Dictionary = {}) -> void:
	super._init("Help & Reference", 1500, 860)
	var t := str(args.get("topic", ""))
	if t != "":
		var is_tab := false
		for x in Reference.TABS:
			if x[0] == t:
				is_tab = true
		if is_tab:
			tab = t
		else:
			query = t


func _ready() -> void:
	super._ready()
	var top := UIKit.hbox(12)
	top.add_child(UIKit.label("Search", 24, "heading"))
	search = LineEdit.new()
	search.placeholder_text = "Type to search every section — e.g. anvil, rarity, wages"
	search.custom_minimum_size = Vector2(620, 46)
	search.add_theme_font_override("font", Assets.font("body"))
	search.add_theme_font_size_override("font_size", 22)
	search.text = query
	search.clear_button_enabled = true
	search.text_changed.connect(func(t: String):
		query = t
		_fill())
	top.add_child(search)
	count_label = UIKit.label("", 18, "body_italic")
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(count_label)
	tut_button = UIKit.button("", _toggle_tutorial, 0)
	top.add_child(tut_button)
	content.add_child(top)
	var h := UIKit.hbox(16)
	tab_col = UIKit.vbox(4)
	tab_col.custom_minimum_size = Vector2(330, 0)
	h.add_child(tab_col)
	list = UIKit.vbox(10)
	var sc := UIKit.scroll(list, 660)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sc)
	content.add_child(h)
	_tabs()
	_fill()
	_tut_label()
	if query == "":
		search.call_deferred("grab_focus")


func _tut_label() -> void:
	tut_button.text = "Hide the tutorial" if Tutorial.enabled() else "Restart the tutorial"


func _toggle_tutorial() -> void:
	if Tutorial.enabled():
		Tutorial.set_enabled(false)
		Events.toast.emit("Tutorial hidden.", "info")
	else:
		Tutorial.restart()
		Events.toast.emit("Tutorial restarted — see the card on the left.", "good")
	_tut_label()


func _tabs() -> void:
	UIKit.clear(tab_col)
	for t in Reference.TABS:
		var key: String = t[0]
		var b := UIKit.button(t[1], func():
			tab = key
			query = ""
			search.text = ""
			_tabs()
			_fill(), 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if key == tab and query == "":
			b.add_theme_color_override("font_color", UIKit.RUBRIC)
			b.add_theme_color_override("font_hover_color", UIKit.RUBRIC)
			b.text = "❧ " + str(t[1])
		tab_col.add_child(b)


func _fill() -> void:
	UIKit.clear(list)
	var es: Array
	if query.strip_edges() != "":
		es = Reference.search(query)
		count_label.text = "%d result%s for “%s”" % [es.size(), "" if es.size() == 1 else "s", query.strip_edges()]
	else:
		es = Reference.tab_entries(tab)
		count_label.text = Reference.tab_name(tab)
		list.add_child(UIKit.label(Reference.tab_name(tab), 32, "title"))
	if es.is_empty():
		list.add_child(UIKit.label("Nothing found. Try another word — undiscovered recipes and secrets are not listed.", 22, "body_italic"))
		return
	var last_tab := ""
	for e in es:
		if query.strip_edges() != "" and e["tab"] != last_tab:
			last_tab = e["tab"]
			list.add_child(UIKit.label(Reference.tab_name(last_tab), 24, "heading", UIKit.RUBRIC))
		var row := UIKit.hbox(14)
		if str(e.get("icon", "")) != "" and Assets.has_tex(str(e["icon"])):
			row.add_child(UIKit.icon(str(e["icon"]), 56))
		else:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(56, 10)
			row.add_child(sp)
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(str(e["title"]), 24, "heading"))
		v.add_child(UIKit.rich(str(e["body"]), 19))
		row.add_child(v)
		list.add_child(row)
		list.add_child(UIKit.divider())
	_tabs()
