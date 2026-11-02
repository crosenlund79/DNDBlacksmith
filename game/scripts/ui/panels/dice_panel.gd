## DicePanel — roll digital dice or enter physical dice results, then finish the piece.
## EN: Both modes feed the same Crafting.finish() stat calculation.
## DA: Begge tilstande bruger den samme Crafting.finish()-beregning.
class_name DicePanel
extends UIWindow

var spec := {}
var results := {}
var faces := {}
var faces_ui := {}
var inputs := {}
var mode := "auto"
var rolled := false
var _anim_t := 0.0


func _init() -> void:
	super._init("The Dice", 900, 640)


func _ready() -> void:
	super._ready()
	spec = Crafting.dice_spec()
	mode = Settings.get_value("gameplay/dice_mode", "auto")
	_build()


func _build() -> void:
	UIKit.clear(content)
	faces_ui.clear()
	inputs.clear()
	var j := Crafting.job()
	var q := Crafting.final_quality(j)
	content.add_child(UIKit.rich("[b]%s[/b] — craftsmanship [color=#9e3a0c][b]%d%%[/b][/color]\n[i]Your precision sets the foundation; the dice decide the rest.[/i]" % [DB.recipe(j.get("recipe", "")).get("name", ""), int(round(q))], 24))
	if spec.has("fortune"):
		var lo := Crafting.rarity_eval(q, 1, 0.0)
		var hi := Crafting.rarity_eval(q, 100, 0.0)
		content.add_child(UIKit.rich("[i]With this craftsmanship the piece will be at least [b]%s[/b] and at best [b]%s[/b] (before material and rune bonuses).[/i]" % [
			Items.RARITY_LABEL[lo["rarity"]], Items.RARITY_LABEL[hi["rarity"]]], 20))
	var modes := UIKit.hbox()
	var ba := UIKit.button("Digital dice", func(): _set_mode("auto"), 220)
	var bp := UIKit.button("Physical dice (enter rolls)", func(): _set_mode("physical"), 320)
	ba.disabled = mode == "auto"
	bp.disabled = mode == "physical"
	modes.add_child(ba)
	modes.add_child(bp)
	content.add_child(modes)
	content.add_child(UIKit.divider())
	for key in spec:
		var expr: String = spec[key]
		var row := UIKit.hbox(16)
		var die := TextureRect.new()
		var sides := Dice.sides(expr)
		die.texture = Assets.get_tex("ui/dice_d20" if sides >= 20 else ("ui/dice_d12" if sides >= 10 else "ui/dice_d6"), Vector2i(96, 96))
		die.custom_minimum_size = Vector2(72, 72)
		die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(die)
		var attr: Dictionary = DB.crafting.get("dice", {}).get(key, {})
		var lab := UIKit.rich("[b]%s[/b] — %s\n[i]%s[/i]" % [attr.get("label", key.capitalize()), expr, attr.get("desc", "")], 22)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		if mode == "auto":
			var f := UIKit.label("–", 44, "title", UIKit.RUBRIC)
			f.custom_minimum_size = Vector2(120, 0)
			f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			faces_ui[key] = f
			row.add_child(f)
		else:
			var boxes := []
			for i in int(Dice.parse(expr)["n"]):
				var sb := SpinBox.new()
				sb.min_value = 1
				sb.max_value = sides
				sb.value = 1
				sb.custom_minimum_size = Vector2(140, 46)
				boxes.append(sb)
				row.add_child(sb)
			inputs[key] = boxes
		content.add_child(row)
	content.add_child(UIKit.divider())
	if mode == "auto":
		content.add_child(UIKit.button("Roll the dice", _roll, 300) if not rolled else UIKit.button("Finish the piece", _finish, 300))
	else:
		content.add_child(UIKit.button("Use these rolls", _confirm_physical, 300))


func _set_mode(m: String) -> void:
	mode = m
	rolled = false
	results.clear()
	faces.clear()
	Settings.set_value("gameplay/dice_mode", m)
	_build()


func _roll() -> void:
	Audio.play("sfx/dice_roll")
	for key in spec:
		var r := Dice.roll(spec[key])
		results[key] = int(r["total"])
		faces[key] = r["faces"]
	_anim_t = 1.1
	set_process(true)


func _process(delta: float) -> void:
	if _anim_t <= 0.0:
		return
	_anim_t -= delta
	for key in faces_ui:
		var lab: Label = faces_ui[key]
		lab.text = str(randi_range(1, Dice.sides(spec[key]))) if _anim_t > 0.0 else str(results[key])
	if _anim_t <= 0.0:
		Audio.play("sfx/dice_land")
		rolled = true
		var keep := results.duplicate()
		var keep_f := faces.duplicate()
		_build()
		results = keep
		faces = keep_f
		for key in faces_ui:
			(faces_ui[key] as Label).text = str(results[key])


func _confirm_physical() -> void:
	for key in inputs:
		var vals := []
		for sb in inputs[key]:
			vals.append(int((sb as SpinBox).value))
		var chk := Dice.from_faces(spec[key], vals)
		if chk.is_empty():
			Events.toast.emit("%s must be between 1 and %d." % [key, Dice.sides(spec[key])], "bad")
			return
		results[key] = int(chk["total"])
		faces[key] = vals
	Audio.play("sfx/dice_land")
	_finish()


func _finish() -> void:
	var full := {}
	for key in results:
		full[key] = {"total": int(results[key]), "faces": faces.get(key, [int(results[key])])}
	var it := Crafting.finish(full, "physical" if mode == "physical" else "digital")
	if not it.is_empty():
		Events.open_panel.emit("craft_result", {"item": it, "fresh": true})
