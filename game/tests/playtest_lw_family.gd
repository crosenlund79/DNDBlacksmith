## Rendered play-test phase "lw_family" (The Living Workshop — the FAMILY worker: #50–52, #40).
## What the player sees: Róisín (married) asked in conversation to help at the shop counter; Róisín behind the counter
## in her hours with a customer waiting outside; the counter's family row with the discount cap; a sale she makes within
## the cap (toast and the ledger line); the smith's own Hale Farm creature at his heel outdoors, waiting outside the inn
## while he is inside, and with him in his forge; the steward panel's night pace; the steward's smith asleep with the
## whole village at 5× and back at 1.5× when he wakes (rates measured against unscaled engine time).
## LWFAM_TAG=before runs the same scenes on the unchanged base (no Family: the new API is reached dynamically), for the
## BEFORE screenshots. Screenshots: lwfam_<tag>_*. Called from tests/playtest.gd (phase_lw_family).
extends RefCounted

const FAMILY_PATH := "res://scripts/systems/family.gd"

var pt: Node
var tag := "after"
var fam: Script = null


func _w() -> VillageWorld:
	return pt.W()


func _fam(method: String, args := []) -> Variant:
	return fam.callv(method, args) if fam != null else null


func _shot(name: String) -> void:
	await pt.shot("lwfam_%s_%s" % [tag, name])


func _wait_unscaled(s: float) -> void:
	await pt.get_tree().create_timer(s, true, false, true).timeout


func _asleep() -> bool:
	var m: Dictionary = StewardSmith.sm()
	return Steward.is_active() and str(m.get("act", "")) == "sleep" and not bool(m.get("walking", false))


func run(p: Node) -> void:
	pt = p
	tag = OS.get_environment("LWFAM_TAG") if OS.get_environment("LWFAM_TAG") != "" else "after"
	fam = load(FAMILY_PATH) if ResourceLoader.exists(FAMILY_PATH) else null
	pt.note("lw_family: tag %s, Family %s" % [tag, "present" if fam != null else "absent (base)"])
	await pt.click("New Game")
	await pt.wait(2.5)
	(Game.state["hirelings"] as Array).clear()
	Shop.customers().clear()
	Game.state["gold"] = 3000
	for it in Game.inventory():
		it.erase("for_sale")
	# married to Róisín (set up directly: this phase is about the workshop, not the romance)
	Social.set_romance("roisin", "married")
	Social.ensure("roisin")["aff"] = 60.0
	Roisin.st()["free"] = true
	await pt.advance_to(9, 5)
	_w()._update_schedules(true)
	await pt.wait(0.6)
	await _ask()
	await _counter()
	await _pet()
	await _night_pace()
	pt.note("lw_family: done")


# ---------------------------------------------------------------- 1. asking her
func _ask() -> void:
	var ok: bool = await pt.talk_to("roisin")
	pt.expect(ok, "lw_family: talking to Róisín (%s)" % str(_w().spot_for("roisin")))
	if not ok:
		return
	var has_ask: bool = pt.find_button(pt.panel(), "help at the shop counter") != null
	pt.expect(has_ask == (fam != null), "lw_family: the conversation %s 'Ask her to help at the shop counter'" % ("offers" if fam != null else "does not offer (base)"))
	await _shot("01_talk_roisin")
	if fam != null:
		await pt.click("help at the shop counter", pt.panel())
		await pt.wait(0.6)
		pt.expect(bool(_fam("helps")), "lw_family: she agrees")
		await _shot("02_she_agrees")
	await pt.close_panel()


# ---------------------------------------------------------------- 2. the counter, the cap and a sale
func _display_piece_for(a: Dictionary) -> Dictionary:
	var keep := int(a["gold"])
	a["gold"] = 1000000
	var found := {}
	for def in DB.items:
		if str(DB.item(str(def)).get("type", "")) == "companion":
			continue
		var it := Items.make(str(def), {"quality": 97.0})
		if it.is_empty() or Items.slot(it) == "":
			continue
		if Adv.purchase_check(a, it, Shop.list_price(it)) == "":
			found = it
			break
	a["gold"] = keep
	if not found.is_empty():
		Game.add_item(found, false)
		Shop.set_for_sale(int(found["uid"]), true)
	return found


func _counter() -> void:
	var w := _w()
	await pt.advance_to(10, 1)
	w._update_schedules(true)
	await pt.wait(0.5)
	# a buyer in town, a little short of the display price
	var a := Adv.get_a("sigrun")
	Expeditions.ensure(a)
	a["status"] = "in_town"
	var it := _display_piece_for(a)
	pt.expect(not it.is_empty(), "lw_family: a piece Sigrun wants is on display")
	var listed := Shop.price_of(it)
	a["gold"] = listed - maxi(1, int(listed * 0.06))
	var now := Game.day() * 24 + Game.hour()
	Shop.customers().append({"npc": "sigrun", "want": "browse", "arrived": now, "seated": now, "seat": 0, "present": true,
		"budget": int(a["gold"]), "looking_for": "", "slot": Items.slot(it)})
	w._update_schedules(true)
	# she walks over from her morning place (real time; at most ~40 s)
	var rn: NPCActor = w.npcs.get("roisin")
	var cb: Vector2 = w.spots.get("smithy_counter_back", Vector2.ZERO)
	var waited := 0.0
	while fam != null and rn != null and waited < 45.0 and (rn.path.size() > 0 or rn.position.distance_to(cb) > 40.0):
		await pt.wait(0.5)
		waited += 0.5
	pt.note("   Róisín walked to the counter in %.1f s (path left %d)" % [waited, rn.path.size() if rn != null else -1])
	var at_counter := rn != null and rn.visible and rn.position.distance_to(cb) < 40.0
	pt.expect(at_counter == (fam != null), "lw_family: Róisín %s behind the shop counter at 10:00 (she is at %s)" % ["stands" if fam != null else "is not (base)", str(w.spot_for("roisin"))])
	await pt.tp(w.spots["smithy_counter_back"] + Vector2(-260, 30))
	w.camera.zoom = Vector2(1.0, 1.0)
	w.camera.reset_smoothing()
	await pt.wait(0.6)
	await _shot("03_counter_at_ten")
	# the counter panel: her row and the cap
	Events.open_panel.emit("shop", {})
	await pt.wait(0.8)
	pt.expect((pt.find_label_containing(pt.panel(), "minds the counter") != null) == (fam != null), "lw_family: the counter shows her row")
	if fam != null:
		await pt.click("10 %", pt.panel())
		await pt.wait(0.5)
		pt.expect(int(_fam("discount_cap")) == 10, "lw_family: the cap is set to 10 % in the counter panel")
	await _shot("04_counter_panel_family_row")
	await pt.close_panel()
	await pt.wait(0.3)
	# her next 15-minute round: the sale within the cap
	var gold0 := Game.gold()
	var purse0 := int(a["gold"])
	Game.advance_minutes(15 - int(Game.state["minute"]) % 15)
	await pt.wait(0.8)
	var sold := Game.find_uid(int(it["uid"])).is_empty()
	pt.expect(sold == (fam != null), "lw_family: %s" % ("she sold it within the cap" if fam != null else "nobody sells while the smith is away from the counter (base)"))
	if sold:
		pt.expect(Game.gold() - gold0 == purse0 - int(a["gold"]) and Game.gold() - gold0 >= int(ceil(listed * 0.9)),
			"lw_family: the forge gained exactly what Sigrun paid (%d g of %d g listed)" % [Game.gold() - gold0, listed])
		var lg: Array = Game.state["ledger"]
		pt.note("   ledger: %s" % str(lg[-1]))
	await _shot("05_sale_toast")
	Events.open_panel.emit("shop", {"tab": "ledger"})
	await pt.wait(0.8)
	await pt.click("Accounts", pt.panel())
	await pt.wait(0.6)
	await _shot("06_ledger_accounts")
	await pt.close_panel()
	w.camera.zoom = Vector2(1, 1)


# ---------------------------------------------------------------- 3. the pet
func _pet_node() -> Node2D:
	for n in _w().ysort.get_children():
		if n.name == "PetFollower":
			return n.get_node_or_null("Pet") as Node2D
	return null


func _walk(to: Vector2, limit := 14.0) -> void:
	var nav := PlayerNav.of(_w())
	if nav == null:
		await pt.tp(to)
		return
	nav.walk_to_point(to)
	var t := 0.0
	while nav.active() and t < limit:
		await pt.wait(0.1)
		t += 0.1
	await pt.wait(0.8)


func _pet() -> void:
	var w := _w()
	var stock := Commerce.creature_stock()
	var bought := ""
	for i in stock.size():
		if not bool(stock[i].get("sold", false)) and not Companions.flying({"def": str(stock[i]["def"])}) and Commerce.buy_creature(i) == "":
			bought = str(stock[i]["def"])
			break
	pt.expect(bought != "", "lw_family: a creature from Hale Farm in the smith's stores (%s)" % bought)
	# out of the forge into the village
	await pt.tp(w.spots["smithy_door_out"] + Vector2(0, -40))
	await pt.wait(1.5)
	await _walk(w.spots["smithy_door_out"] + Vector2(-260, -260))
	var pet := _pet_node()
	var close := pet != null and pet.visible and pet.position.distance_to(w.player.position) < 120.0
	pt.expect(close == (fam != null), "lw_family: %s" % ("the creature trots at his heel (%.0f px)" % pet.position.distance_to(w.player.position) if pet != null else "no creature follows him (base)"))
	await _shot("07_pet_at_his_heel")
	# into the inn: it waits outside
	await _walk(w.spots["inn_door_out"] + Vector2(0, 30))
	await _walk(w.spots["inn_door_out"] + Vector2(0, -260), 10.0)
	await pt.wait(1.5)
	pet = _pet_node()
	if fam != null:
		var inside := str(w.area) == "inn"
		var outside: bool = pet != null and not (w.buildings["inn"]["rect"] as Rect2).has_point(pet.position)
		pt.expect(inside and outside, "lw_family: he is in the inn (%s), the creature waits outside (%s)" % [str(w.area), str(pet.position) if pet != null else "-"])
	await _shot("08_pet_waits_outside_inn")
	await pt.tp(w.spots["inn_door_out"] + Vector2(0, 120))
	await pt.wait(0.3)
	# back home: with him in the forge
	await pt.tp(w.spots["smithy_door_out"] + Vector2(0, -60))
	await pt.wait(1.0)
	await _walk(w.spots["smithy_counter_back"] + Vector2(220, 140))
	await pt.wait(1.2)
	pet = _pet_node()
	if fam != null:
		pt.expect(pet != null and pet.visible and str(w.area) == "smithy" and pet.position.distance_to(w.player.position) < 140.0, "lw_family: in his own forge the creature is with him")
		var pf: Node = pet.get_parent()
		pt.expect(not bool(pf.call("keep_clear", pet.position)), "lw_family: it rests clear of doorways and stations")
	await _shot("09_pet_in_the_forge")


# ---------------------------------------------------------------- 4. the steward's night pace
class DeltaProbe:
	extends Node
	var scaled := 0.0
	var unscaled := 0.0
	var hours := 0
	var walker: NPCActor = null
	var walked := 0.0          # px the walker moved in frames it was walking
	var walk_minutes := 0.0    # game minutes those frames covered (scaled delta × the clock's rate)
	var _last := Vector2.INF

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		Events.hour_passed.connect(func(_d, _h): hours += 1)

	func _process(delta: float) -> void:
		scaled += delta
		unscaled += delta / maxf(0.001, Engine.time_scale)
		if walker != null and is_instance_valid(walker):
			if walker.path.size() > 0 and _last != Vector2.INF and Game.ui_blockers == 0:
				walked += walker.position.distance_to(_last)
				walk_minutes += delta * Game.MINUTES_PER_SECOND
			_last = walker.position


## Over `secs` of unscaled engine time: game minutes per unscaled second, a walking villager's px per unscaled second
## and per game minute, hourly ticks seen and game hours passed.
func _rates(secs: float) -> Dictionary:
	var w := _w()
	var walker: NPCActor = null
	for id in w.npcs:
		var n: NPCActor = w.npcs[id]
		if n.visible and n.path.size() > 1 and not n.get_meta("apprentice", false):
			walker = n
			break
	var probe := DeltaProbe.new()
	probe.walker = walker
	pt.add_child(probe)
	await pt.get_tree().process_frame
	var n0 := walker.position if walker != null else Vector2.ZERO
	var m0 := Game.now()
	var u0 := probe.unscaled
	var h0 := int(m0 / 60)
	while probe.unscaled - u0 < secs:
		await pt.get_tree().process_frame
	var u := maxf(0.001, probe.unscaled - u0)
	var mins := Game.now() - m0
	var out := {"clock": float(mins) / u, "npc": 0.0, "npc_per_min": 0.0, "minutes": mins, "hours_seen": probe.hours,
		"hours_passed": int(Game.now() / 60) - h0, "scale": Engine.time_scale}
	if walker != null and is_instance_valid(walker) and probe.walk_minutes > 0.0:
		out["npc"] = walker.position.distance_to(n0) / u
		out["npc_per_min"] = probe.walked / probe.walk_minutes   # while walking: speed ÷ 1.6 at any pace
		out["npc_speed"] = walker.speed
		out["walker"] = walker.npc_id
	probe.queue_free()
	return out


func _night_pace() -> void:
	var w := _w()
	await pt.advance_to(20, 30)
	Events.open_panel.emit("steward", {})
	await pt.wait(0.8)
	if fam != null:
		var b: Button = pt.find_button(pt.panel(), "while you sleep")
		pt.expect(b != null, "lw_family: the steward panel offers the night pace")
		if b != null:
			b.pressed.emit()
			await pt.wait(0.5)
		pt.expect(bool(Steward.orders().get("sleep_pace", false)), "lw_family: the night pace is chosen")
	await _shot("10_steward_panel_night_pace")
	var why := StewardUI.hand_over()
	pt.expect(why == "", "lw_family: the steward takes over (%s)" % why)
	await pt.close_panel()
	await pt.wait(1.0)
	pt.expect(is_equal_approx(Engine.time_scale, 1.5), "lw_family: awake at the steward's pace (×%s)" % str(Engine.time_scale))
	var day_r := await _rates(4.0)
	pt.note("   awake (×%s): %.2f game min per unscaled s; %s walks %.1f px per game minute (own speed %.0f px/s ÷ 1.6 = %.1f)" % [str(day_r["scale"]), float(day_r["clock"]),
		str(day_r.get("walker", "-")), float(day_r["npc_per_min"]), float(day_r.get("npc_speed", 0.0)), float(day_r.get("npc_speed", 0.0)) / 1.6])
	# let the evening run until he is asleep in his bed (5-minute steps while he does not walk; real time while he does)
	var g := 0
	while not _asleep() and g < 4000:
		g += 1
		if bool(StewardSmith.sm().get("walking", false)):
			await _wait_unscaled(0.2)
		else:
			Game.advance_minutes(5)
			await pt.get_tree().process_frame
	pt.expect(_asleep(), "lw_family: the smith is asleep in his bed (%s)" % Game.time_string())
	await _wait_unscaled(0.5)
	var night := is_equal_approx(Engine.time_scale, 5.0)
	pt.expect(night == (fam != null), "lw_family: asleep, the whole village runs at ×%s" % str(Engine.time_scale))
	await _shot("11_asleep_plate_pace")
	var night_r := await _rates(12.0)
	pt.note("   asleep (×%s): %.2f game min per unscaled s; %s walks %.1f px per game minute (own speed %.0f px/s ÷ 1.6 = %.1f); %d hourly ticks for %d hours passed (%d game min)" % [
		str(night_r["scale"]), float(night_r["clock"]), str(night_r.get("walker", "-")), float(night_r["npc_per_min"]), float(night_r.get("npc_speed", 0.0)),
		float(night_r.get("npc_speed", 0.0)) / 1.6, int(night_r["hours_seen"]), int(night_r["hours_passed"]), int(night_r["minutes"])])
	if float(night_r.get("npc_speed", 0.0)) > 0.0:
		var exp_pm := float(night_r["npc_speed"]) / 1.6
		pt.expect(absf(float(night_r["npc_per_min"]) - exp_pm) < exp_pm * 0.1, "lw_family: at 5× a walk takes the same game minutes as at any pace (%.1f vs %.1f px per game minute)" % [float(night_r["npc_per_min"]), exp_pm])
	pt.expect(int(night_r["hours_seen"]) == int(night_r["hours_passed"]), "lw_family: every game hour ticked exactly once at the night pace")
	if fam != null:
		var ratio := float(night_r["clock"]) / maxf(0.01, float(day_r["clock"]))
		pt.expect(ratio > 2.8 and ratio < 3.8, "lw_family: the clock runs 5/1.5 ≈ 3.3× faster than by day (%.2f)" % ratio)
	if fam == null:
		StewardUI.take_back()   # the base: no night pace to follow to the morning
		await _wait_unscaled(1.0)
		await pt.close_panel()
		return
	# real time to the morning (the night pace while he sleeps): he wakes at 6:00 and the day pace returns
	var probe := DeltaProbe.new()
	pt.add_child(probe)
	var m0 := Game.now()
	var wall0 := Time.get_ticks_msec()
	var night_scales := {}
	while _asleep() and probe.unscaled < 240.0:
		await pt.get_tree().process_frame
		night_scales[snappedf(Engine.time_scale, 0.1)] = true
	var night_u := probe.unscaled
	var night_m := Game.now() - m0
	var night_h := probe.hours
	probe.queue_free()
	await _wait_unscaled(1.0)
	pt.note("   to the morning: %d game min in %.1f s of engine time (%.2f min/s; %.0f s wall clock under load); hourly ticks %d; time scales seen while asleep %s" % [
		night_m, night_u, float(night_m) / maxf(0.01, night_u), (Time.get_ticks_msec() - wall0) / 1000.0, night_h, str(night_scales.keys())])
	pt.expect(night_scales.keys() == [5.0], "lw_family: 5× all night long while he slept")
	pt.expect(not _asleep() and Game.hour() == 6, "lw_family: he wakes at 6:00 (%s)" % Game.time_string())
	pt.expect(is_equal_approx(Engine.time_scale, 1.5), "lw_family: awake, back to the steward's pace (×%s)" % str(Engine.time_scale))
	await _shot("12_morning_back_to_steward_pace")
	StewardUI.take_back()
	await _wait_unscaled(1.0)
	pt.expect(not Steward.is_active() and is_equal_approx(Engine.time_scale, 1.0), "lw_family: the workshop taken back: normal speed (×%s)" % str(Engine.time_scale))
	await pt.close_panel()
