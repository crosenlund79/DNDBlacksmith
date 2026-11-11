## CraftResultPanel — the illustrated account of a finished piece: every operation and its score,
## the craftsmanship (which may exceed 100%), the dice that were rolled, the resulting statistics,
## the rarity verdict and the experience earned. Opens after crafting, and again from the stores
## for any crafted item (the record is saved on the item).
## DA: Den illustrerede beretning om et færdigt stykke: hver arbejdsgang, håndværket (kan overstige
##     100 %), terningerne, statistikken, sjældenheden og erfaringen. Kan åbnes igen fra lageret.
class_name CraftResultPanel
extends UIWindow

const STAT_NAMES := {"attack": "Attack", "protection": "Protection", "magic": "Magic", "fire": "Fire", "frost": "Frost",
	"ward": "Ward", "heal": "Healing", "edge": "Edge", "durability": "Durability"}

var item: Dictionary
var fresh := true


func _init(it: Dictionary, is_fresh := true) -> void:
	item = it
	fresh = is_fresh
	super._init("", 1560, 780, true)


func _ready() -> void:
	super._ready()
	var rar: String = item.get("rarity", "common")
	var cr: Dictionary = item.get("craft", {})
	title_label.text = {"legendary": "★ A Legendary Work ★", "rare": "A Rare Piece", "magic": "Something Special"}.get(rar, "The Finished Piece") \
		if fresh else "Record of the Work — " + str(cr.get("recipe_name", ""))
	title_label.add_theme_color_override("font_color", Items.color(item))
	var cols := UIKit.hbox(26)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(_item_column(rar, cr))
	cols.add_child(_work_column(cr))
	cols.add_child(_dice_column(cr))
	content.add_child(cols)
	var btns := UIKit.hbox()
	if fresh and Items.is_equipment(item):
		btns.add_child(UIKit.button("Put it on display for sale", func():
			var it := Game.find_uid(int(item["uid"]))
			if not it.is_empty():
				it["for_sale"] = true
				Events.inventory_changed.emit()
			close(), 320))
	btns.add_child(UIKit.button("Keep it" if fresh else "Close", close, 160))
	# The Living Realm: the same recipe again, when the materials allow — it walks you to its first station
	var rid := str(cr.get("recipe", ""))
	if fresh and rid != "" and not DB.recipe(rid).is_empty():
		var why := Smithy.craft_again_reason(rid)
		var again := UIKit.button("Craft again", func():
			close()
			var err := Smithy.craft_again(rid)
			if err != "":
				Events.toast.emit(err, "bad"), 220)
		again.name = "CraftAgain"
		again.disabled = why != ""
		again.tooltip_text = ("Start another %s and walk to its first station." % DB.recipe(rid).get("name", rid)) if why == "" else why
		btns.add_child(again)
	content.add_child(btns)
	if fresh:
		ItemSpirit.speak(item, "maker")   # a piece that woke at the forge greets its maker
		match rar:
			"legendary":
				pass  # the legendary drop sound and screen flash come from Events.legendary_found
			"rare":
				Audio.play("sfx/reveal_rare")
			"magic":
				Audio.play("sfx/reveal_magic")
			_:
				Audio.play("sfx/reveal_common")


func _heading(t: String) -> Label:
	return UIKit.label(t, 28, "heading", UIKit.GILT)


# ------------------------------------------------------------------ left: the item
func _item_column(rar: String, cr: Dictionary) -> Control:
	var v := UIKit.vbox(8)
	v.custom_minimum_size = Vector2(420, 0)
	var slot_box := CenterContainer.new()
	var slot := ItemSlot.new(item, 200.0)
	slot_box.add_child(slot)
	v.add_child(slot_box)
	var c := Items.color(item).to_html(false)
	var head := "[center][font_size=30][color=#%s]%s[/color][/font_size]" % [c, Items.display_name(item)]
	if item.has("epithet"):
		head += "\n[i][color=#%s]%s[/color][/i]" % [c, item["epithet"]]
	head += "\n[color=#%s]%s %s[/color][/center]" % [c, Items.RARITY_LABEL.get(rar, ""), Items.type_label(item)]
	v.add_child(UIKit.rich(head, 22, true))
	var st: Dictionary = item.get("stats", {})
	var lines := []
	for k in STAT_NAMES:
		var val := Items.stat(item, k)
		if k == "durability" and st.has("durability"):
			lines.append("%s  [b]%d[/b]" % [STAT_NAMES[k], int(st["durability"])])
		elif val != 0 and k != "durability":
			lines.append("%s  [b]%d[/b]" % [STAT_NAMES[k], val])
	for a in item.get("affixes", []):
		if not STAT_NAMES.has(a["stat"]):
			lines.append("[color=#8aa6f2]+%d %s[/color]" % [int(a["value"]), str(a["stat"]).capitalize()])
	if item.get("arcane_glow", false):
		lines.append("[color=#b89cff]Arcane markings glow along the metal.[/color]")
	if item.has("epic"):
		lines.append(Recognition.epic_line(item))
	lines.append("[color=#dab470]Value %d g[/color]" % Items.value(item))
	v.add_child(UIKit.rich("\n".join(lines), 24, true))
	if fresh and rar in ["legendary", "rare"]:
		_burst.call_deferred(slot, rar == "legendary")
	return v


# ------------------------------------------------------------------ middle: the operations
func _work_column(cr: Dictionary) -> Control:
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_heading("The Work"))
	# Living Workshop B1: the level is the maker's own — say whose when a workshop specialist made it
	var by := ""
	if str(cr.get("maker_name", "")) != "":
		var who := Workers.resolve(str(cr.get("maker", "")))
		by = " · made by %s%s" % [str(cr["maker_name"]), (" (%s)" % Workers.title(who).to_lower()) if str(who["kind"]) == "apprentice" else ""]
	v.add_child(UIKit.rich("[i]%s · %s · difficulty %d · %s %d%s[/i]" % [cr.get("recipe_name", ""), cr.get("material", ""),
		int(cr.get("difficulty", 1)), SkillSys.skill_name(str(cr.get("skill", "smithing"))), int(cr.get("level", 0)), by], 20, true))
	for o in cr.get("ops", []):
		var row := UIKit.hbox(10)
		var nm := UIKit.label(str(o.get("op", "")), 21, "body", UIKit.PAPER)
		nm.custom_minimum_size = Vector2(300, 0)
		nm.clip_text = true
		row.add_child(nm)
		var bar := QualityBar.new(float(o.get("q", 0)), o.get("checks", []))
		bar.custom_minimum_size = Vector2(220, 30)
		row.add_child(bar)
		var q := float(o.get("q", 0))
		row.add_child(UIKit.label("%d%%  %s" % [int(round(q)), Crafting.grade(q)], 21, "body_bold", _qcol(q)))
		v.add_child(row)
	v.add_child(UIKit.divider())
	var q := float(cr.get("quality", item.get("quality", 0)))
	var big := UIKit.label("Craftsmanship  %d%%" % int(round(q)), 44, "title", _qcol(q))
	v.add_child(big)
	var note := "precision %.1f%% + skill %.1f%%" % [float(cr.get("base_quality", q)), float(cr.get("skill_bonus", 0))]
	if float(cr.get("tree_bonus", 0)) > 0.05 or float(cr.get("assist_bonus", 0)) > 0.05:
		note += " (incl. skill tree %+.1f, helping hand %+.1f)" % [float(cr.get("tree_bonus", 0)), float(cr.get("assist_bonus", 0))]
	if q > 100.0:
		note += " — [color=#ffa050]beyond perfection[/color]"
	v.add_child(UIKit.rich("[i]%s[/i]" % note, 20, true))
	# S2 (OBS-11): a material batch says what decided its size, and that its grade is not kept
	var yl := yield_lines(item)
	if not yl.is_empty():
		var yr := UIKit.rich("\n".join(yl), 20, true)
		yr.name = "YieldNote"
		v.add_child(yr)
	var xp: Dictionary = cr.get("xp", {})
	var xl := []
	for s in xp:
		xl.append("+%d %s" % [int(xp[s]), SkillSys.skill_name(s)])
	if not xl.is_empty():
		v.add_child(UIKit.rich("[color=#c8b898]Experience: %s%s[/color]" % [", ".join(xl), "  [i](routine work for an expert)[/i]" if cr.get("expert", false) else ""], 20, true))
	# how craftsmanship, the dice, the material and the smith's skill made each statistic
	var bd: Array = cr.get("breakdown", [])
	if not bd.is_empty():
		v.add_child(UIKit.divider())
		v.add_child(_heading("How the numbers came about"))
		var adv: Dictionary = cr.get("advantage", {})
		if not adv.is_empty():
			v.add_child(UIKit.rich("[i][color=#c8b898]%d%% craftsmanship → [b]%s[/b] on the stat dice%s[/color][/i]" % [int(round(q)), str(adv.get("word", "")),
				" (physical rolls get a modifier instead)" if cr.get("dice_mode", "") == "physical" else ""], 19, true))
		var lines_bd := PackedStringArray(bd.map(func(x): return str(x)))
		var aff := PackedStringArray()
		for a in item.get("affixes", []):
			aff.append("%+d %s" % [int(a.get("value", 0)), str(a.get("stat", "")).capitalize()])
		if not aff.is_empty():
			lines_bd.append("then the %s rarity adds %s" % [Items.RARITY_LABEL.get(str(item.get("rarity", "common")), ""), ", ".join(aff)])
		v.add_child(UIKit.rich("[color=#efe4cc]%s[/color]" % "\n".join(lines_bd), 19, true))
	return v


# ------------------------------------------------------------------ right: dice and rarity
func _dice_column(cr: Dictionary) -> Control:
	var v := UIKit.vbox(6)
	v.custom_minimum_size = Vector2(440, 0)
	var dice: Dictionary = cr.get("dice", {})
	v.add_child(_heading("The Dice — %s" % ("physical, rolled by hand" if cr.get("dice_mode", "") == "physical" else "digital")))
	var attrs: Dictionary = DB.crafting.get("dice", {})
	var order: Array = DB.recipe(str(cr.get("recipe", ""))).get("dice", {}).keys()
	for k in dice:
		if not order.has(k):
			order.append(k)
	for k in order:
		if not dice.has(k):
			continue
		var e: Dictionary = dice[k]
		var row := UIKit.hbox(10)
		var sides := Dice.sides(str(e.get("expr", "1d6")))
		row.add_child(UIKit.icon("ui/dice_d20" if sides >= 20 else ("ui/dice_d12" if sides >= 10 else "ui/dice_d6"), 52))
		var how := str(e.get("text", ""))
		if how == "":
			how = str(attrs.get(k, {}).get("desc", ""))
		var lab := UIKit.rich("[b]%s[/b] %s → [font_size=28][color=#ffc070]%d[/color][/font_size]\n[i][color=#c8b898]%s[/color][/i]" % [
			attrs.get(k, {}).get("label", k.capitalize()), e.get("expr", ""), int(e.get("total", 0)), how], 19, true)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		v.add_child(row)
	if dice.is_empty():
		v.add_child(UIKit.label("No dice were rolled.", 20, "body_italic", UIKit.PAPER))
	var parts: Dictionary = cr.get("rarity_parts", {})
	if not parts.is_empty():
		v.add_child(UIKit.divider())
		v.add_child(_heading("Rarity"))
		var th: Dictionary = DB.crafting.get("rarity", {}).get("thresholds", {})
		var rb := RarityBar.new(float(cr.get("rarity_score", 0)), th)
		rb.custom_minimum_size = Vector2(420, 56)
		v.add_child(rb)
		var bits := ["craftsmanship %.0f" % float(parts.get("quality", 0)), "fortune %.0f" % float(parts.get("fortune", 0))]
		if float(parts.get("bonus", 0)) > 0:
			bits.append("material & runes %.0f" % float(parts["bonus"]))
		if float(parts.get("masterwork", 0)) > 0:
			bits.append("[color=#ffa050]masterwork %.0f[/color]" % float(parts["masterwork"]))
		v.add_child(UIKit.rich("[color=#c8b898]Score %.0f = %s[/color]" % [float(cr.get("rarity_score", 0)), " + ".join(bits)], 19, true))
	return v


## S2 (OBS-11): for a stackable batch (materials, draughts…), what decided its size — the recipe's units, and the bonus
## unit with its cause (craftsmanship ≥ 105 % or a purity 6) or why there was none — and, for plain materials, that the
## batch's craftsmanship is not kept: its units join the stock and work like any other in later recipes (inputs are
## taken by kind; Crafting.build). Reads the craft record's "yield" (S2); older records are reconstructed. [] = n/a.
static func yield_lines(it: Dictionary) -> Array:
	var cr: Dictionary = it.get("craft", {})
	var d := DB.item(str(it.get("def", "")))
	if cr.is_empty() or Items.is_equipment(it) or not bool(d.get("stack", false)):
		return []
	var q := float(cr.get("quality", it.get("quality", 0)))
	var y: Dictionary = cr.get("yield", {})
	if y.is_empty():
		var dice: Dictionary = cr.get("dice", {})
		var pur := int((dice["purity"] as Dictionary).get("total", -1)) if dice.get("purity") is Dictionary else -1
		var base0 := int(DB.recipe(str(cr.get("recipe", ""))).get("qty", 1))
		var bonus0 := q >= Crafting.YIELD_BONUS_Q or pur >= 6
		y = {"base": base0, "bonus": 1 if bonus0 else 0, "why": ("craftsmanship" if q >= Crafting.YIELD_BONUS_Q else "purity") if bonus0 else "", "purity": pur}
	var nm := str(d.get("name", it.get("name", "")))
	var base := int(y.get("base", 1))
	var total := base + int(y.get("bonus", 0))
	var pur_v := int(y.get("purity", -1))
	var lines := []
	var head := "[b]Batch: %d %s[/b] — the recipe makes %d" % [total, nm, base]
	if int(y.get("bonus", 0)) > 0:
		var cause := "your craftsmanship reached %d%% (105%% or more adds a unit)" % int(round(q)) if str(y.get("why", "")) == "craftsmanship" \
			else "the purity die rolled a 6 (a pure batch adds a unit)"
		head += ", [color=#ffc070]+1 bonus unit[/color] because %s." % cause
	else:
		head += ". No bonus unit: that needs 105%% craftsmanship or a purity 6 — this batch had %d%%%s." % [int(round(q)),
			(", purity %d" % pur_v) if pur_v >= 0 else ""]
	lines.append(head)
	if str(d.get("type", "")) == "material":
		lines.append("[i][color=#c8b898]Craftsmanship sets how many units a batch yields, not their grade: these join your %s stock and work exactly like the rest in later recipes.[/color][/i]" % nm)
	return lines


static func _qcol(q: float) -> Color:
	if q >= 114.0:
		return Color("#ffa050")
	if q >= 100.0:
		return Color("#ffc070")
	if q >= 90.0:
		return Color("#f0d060")
	if q >= 75.0:
		return Color("#efe4cc")
	return Color("#ff9a80")


func _burst(slot: Control, legendary: bool) -> void:
	if not is_instance_valid(slot) or slot.has_meta("burst"):
		return
	slot.set_meta("burst", true)
	var p := FX.embers(90 if legendary else 40)
	p.one_shot = true
	p.explosiveness = 0.85
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 300.0
	p.gravity = Vector2(0, 60)
	p.lifetime = 1.8
	p.position = Vector2(100, 100)
	slot.add_child(p)
	p.emitting = true
	if not legendary:
		return
	var star := TextureRect.new()
	star.texture = Assets.get_tex("icons/star", Vector2i(32, 32))
	star.custom_minimum_size = Vector2(64, 64)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.position = Vector2(68, 68)
	star.pivot_offset = Vector2(32, 32)
	slot.add_child(star)
	var tw := create_tween()
	tw.tween_property(star, "scale", Vector2(3.4, 3.4), 0.5).from(Vector2(0.2, 0.2))
	tw.parallel().tween_property(star, "rotation", TAU, 0.9)
	tw.tween_property(star, "modulate:a", 0.0, 0.7)


## A bar showing one operation's score on a 0–130% scale, with a tick at 100% and dots per check.
class QualityBar extends Control:
	var q := 0.0
	var checks: Array = []

	func _init(value: float, c: Array) -> void:
		q = value
		checks = c

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, h * 0.25, w, h * 0.5), Color(0.1, 0.07, 0.05))
		var f := clampf(q / 130.0, 0.0, 1.0)
		draw_rect(Rect2(0, h * 0.25, w * f, h * 0.5), CraftResultPanel._qcol(q))
		var x100 := w * 100.0 / 130.0
		draw_line(Vector2(x100, 0), Vector2(x100, h), Color("#efe4cc"), 2.0)
		for c in checks:
			draw_circle(Vector2(w * clampf(float(c) / 130.0, 0.0, 1.0), h * 0.5), 4.0, Color("#20140c"))
		draw_rect(Rect2(0, h * 0.25, w, h * 0.5), Color("#6e6250"), false, 1.5)


## A bar showing the rarity score against the configured thresholds, in the rarity colour families.
class RarityBar extends Control:
	var score := 0.0
	var th := {}

	func _init(s: float, t: Dictionary) -> void:
		score = s
		th = t

	func _draw() -> void:
		var w := size.x
		var top := 4.0
		var bh := 22.0
		var mx := maxf(150.0, score + 10.0)
		var bands := [["common", 0.0, float(th.get("magic", 68))], ["magic", float(th.get("magic", 68)), float(th.get("rare", 88))],
			["rare", float(th.get("rare", 88)), float(th.get("legendary", 112))], ["legendary", float(th.get("legendary", 112)), mx]]
		for b in bands:
			var col: Color = Items.COL_BORDER[b[0]]
			draw_rect(Rect2(w * b[1] / mx, top, w * (b[2] - b[1]) / mx, bh), Color(col, 0.35))
		var sx := w * clampf(score / mx, 0.0, 1.0)
		draw_rect(Rect2(0, top + 6, sx, bh - 12), Color("#efe4cc"))
		draw_line(Vector2(sx, 0), Vector2(sx, top + bh + 6), Color("#ffd27a"), 3.0)
		var f := Assets.font("body")
		for b in bands:
			draw_string(f, Vector2(w * b[1] / mx + 4, top + bh + 24), Items.RARITY_LABEL[b[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Items.COL_DARK[b[0]])
