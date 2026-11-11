## Family — the smith's household in the living workshop (The Living Workshop #50–52).
## EN: The smith's spouse (Social.spouse() — one identity: her own NPC id, no apprentice record, no employee slot) may
##     agree, when asked in conversation, to help in the shop. She decides by her own character and how things stand
##     between you (WILLING), and stops on her own if that cools far enough (QUIT_MARGIN). In her hours — the shop's
##     opening hours, 9:00–18:00, with the midday hour off — and only while she is home (not on the road, not hurt, not
##     waiting at the counter herself) she stands behind the shop counter (world spot "smithy_counter_back") and, once
##     her figure is there (at_counter; headless: by the schedule), serves one waiting customer every 15 game minutes: an adventurer browsing the display, a villager wanting goods. She sells
##     through the shop's own sale path (Shop.sell_to / Shop.sell_goods) at the display price — less at most the
##     discount the player allows her (discount_cap, 0–25 %, default 0 %): she gives only as much off as the buyer needs
##     to agree, never more than the cap, and the cap is enforced in the sale path itself (Shop.counter_price_reason).
##     Every sale is the shop's normal ledger line (category "sales", party = the buyer; the money goes into the forge's
##     purse; an adventurer pays from their own purse). She never touches protected, Epic, named, legendary or
##     historically significant pieces (Steward.protection_reason), never decides commissions, parts, advice or
##     disputes, and takes repairs only with real competence (Workers kind "spouse": her own skills — every spouse in the
##     game has none, so repairs stay with the smith). While the steward runs the forge her counter work goes on and is
##     counted in its report (Steward.note_counter_sale).
##     The pet (#52): a creature from Hale Farm kept in the smith's own stores (not on display, not promised to an
##     order) walks at his heel in the world (PetFollower; the earliest one unless the player chose another).
##     State: Game.state["family"] — created on the first write (asking her, a setting, a sale, choosing a pet); reads
##     never create it, so old saves load unchanged.
## DA: Smedens ægtefælle kan, hvis hun selv vil, hjælpe ved butiksdisken i åbningstiden: hun sælger udstillede varer
##     til kunderne til udstillingsprisen, højst med den rabat spilleren tillader, gennem butikkens normale regnskab.
##     Smedens eget dyr fra Hale-gården følger ham rundt.
##
## Public API (static):
##   spouse() -> String   helper() -> String   helps() -> bool   on_duty() -> bool   duty_reason() -> String   at_counter() -> bool
##   discount_cap() -> int   set_discount_cap(pct) -> String   floor_price(listed) -> int   allows(price, listed, seller) -> bool
##   spot(npc) -> String (world.spot_for)   tick() (every 15 game minutes)   status() -> Dictionary   log_lines(n) -> Array
##   ask(npc) -> Dictionary {ok, text}   release(why := "") -> void   willing_at(npc) -> float   repair_reason() -> String
##   talk_options(npc) -> Array   talk_choose(npc, opt) -> Dictionary
##   pets() -> Array   pet() -> Dictionary   set_pet(uid) -> String
class_name Family
extends RefCounted

## Her hours behind the counter: the shop's opening hours (customers come 9:00–18:00, Shop.customer_hour) …
const COUNTER_START := 9
const COUNTER_END := 18
## … with the midday hour for her own meal (back to her ordinary routine).
const BREAK_START := 12
const BREAK_END := 13
## The discount choices the player may allow (percent off the display price). 0 % = she sells at your prices.
const DISCOUNT_STEPS := [0, 5, 10, 15, 20, 25]
const MAX_DISCOUNT := 25
## Default 0 %: your display prices stand until you choose otherwise (no hidden change of income, like the steward's
## default of never selling below a piece's value).
const DEFAULT_DISCOUNT := 0
const LOG_CAP := 40
## The world spot behind the shop counter (Venues "shop": smithy_counter_back).
const COUNTER_SPOT := "smithy_counter_back"
## How warm she must be towards the smith to agree (Social affection), by her own character: Róisín keeps a shop's
## hours gladly; Kestra likes coin and company; Sigrun between the roads; Elowen only if she is fond enough; Mira would
## "rather die out there than behind a counter" — unless she is devoted.
const WILLING := {"roisin": 20.0, "kestra": 35.0, "sigrun": 50.0, "elowen": 65.0, "mira": 85.0}
const DEFAULT_WILLING := 50.0
## She leaves the counter of her own accord when affection falls this far below what it took to agree.
const QUIT_MARGIN := 25.0

const LINES := {
	"roisin": ["\"Behind a counter? Brannoc, I've stood behind worse.\" She is already tying on an apron. \"Nine till six, the midday hour for my tea. I'll sell what you put on display at the price on the tag — and haggle only as far as you let me.\"",
		"\"I've only just bought my own hours back.\" She softens it with a hand on your arm. \"Ask me again when I'm sure I'm giving them, not selling them.\""],
	"kestra": ["\"Me? Minding your coin?\" Kestra grins like a cat. \"Everything I take goes in your strongbox. I'll even count it twice — out loud, so you can sleep.\"",
		"\"Stand still behind a counter all day?\" She laughs. \"Ask me when I owe you a favour, smith.\""],
	"sigrun": ["\"Between the roads, aye.\" Sigrun cracks her knuckles. \"I can tell a buyer what a blade's worth better than you can, and they'll believe me.\"",
		"\"I swing swords. I don't sell them.\" A pause. \"Not yet, anyway.\""],
	"elowen": ["\"Selling?\" Elowen sighs as if you had asked her to scrub the slag pit. \"Fine. I'll tell them which of your pieces hums. They'll pay.\"",
		"\"I did not leave the college to keep a shop, dearest.\" She kisses your sooty cheek anyway."],
	"mira": ["\"Behind a counter…\" She laughs, then sees your face. \"For you. When I'm home from the road. Don't tell Dad — he'll say he always knew.\"",
		"\"I'd rather die out there than behind a counter. You know that.\" She softens. \"Ask me something else, love.\""],
}
const LINE_DEFAULT := ["\"I'll mind the counter when I'm home.\"", "\"Not now. Ask me another day.\""]


# ======================================================================= state (created on the first write)
static func _fam() -> Dictionary:
	if Game.state.is_empty():
		return {}
	var f: Variant = Game.state.get("family", {})
	if f is Dictionary:
		return f
	return {}


static func st() -> Dictionary:
	if Game.state.is_empty():
		return {}
	if not Game.state.has("family") or not Game.state["family"] is Dictionary:
		Game.state["family"] = {}
	var f: Dictionary = Game.state["family"]
	var d := {"helper": "", "since": -1, "asked": {}, "discount_cap": DEFAULT_DISCOUNT, "log": [], "sales_n": 0, "sales_gold": 0,
		"discount_gold": 0, "today": {"day": -1, "n": 0, "gold": 0, "off": 0}, "pet_uid": -1}
	for k in d:
		if not f.has(k):
			f[k] = d[k]
	return f


# ======================================================================= who
static func spouse() -> String:
	if Game.state.is_empty() or not Game.state.has("social"):
		return ""
	return Social.spouse()


## The spouse, when she has agreed to help in the shop ("" otherwise — also when she is no longer the spouse).
static func helper() -> String:
	var h := str(_fam().get("helper", ""))
	return h if h != "" and h == spouse() else ""


static func helps() -> bool:
	return helper() != ""


static func willing_at(npc: String) -> float:
	return float(WILLING.get(npc, DEFAULT_WILLING))


static func _first_name(npc: String) -> String:
	return Talk.npc_name(npc).split(" ")[0]


# ======================================================================= the discount cap
static func discount_cap() -> int:
	return clampi(int(_fam().get("discount_cap", DEFAULT_DISCOUNT)), 0, MAX_DISCOUNT)


## Sets the most she may take off a display price (whole percent, 0–25). "" or why not.
static func set_discount_cap(pct: Variant) -> String:
	if not (pct is int or pct is float) or int(pct) != float(pct) or int(pct) < 0 or int(pct) > MAX_DISCOUNT:
		return "The discount is a whole percentage from 0 to %d." % MAX_DISCOUNT
	st()["discount_cap"] = int(pct)
	Events.customers_changed.emit()
	return ""


## The lowest price she may agree for a piece (or one unit) listed at `listed`: at most discount_cap() % off, never
## below 1 g. At 0 % it is the display price itself.
static func floor_price(listed: int) -> int:
	if listed <= 1:
		return maxi(0, listed)
	return maxi(1, int(ceil(float(listed) * float(100 - discount_cap()) / 100.0)))


## May `seller` agree `price` for something listed at `listed`? The smith ("") sells at his display price; the spouse at
## most discount_cap() % below it, and only while she is on duty; nobody sells above the display price at the counter.
static func allows(price: int, listed: int, seller: String) -> bool:
	if price == listed:
		return true
	if price > listed or price < 0:
		return false
	return seller != "" and seller == helper() and on_duty() and price >= floor_price(listed)


# ======================================================================= her hours
static func in_hours(h := -1) -> bool:
	var hr := Game.hour() if h < 0 else h
	return hr >= COUNTER_START and hr < COUNTER_END and not (hr >= BREAK_START and hr < BREAK_END)


## Why she is not behind the counter right now ("" = she is on duty).
static func duty_reason() -> String:
	var npc := helper()
	if npc == "":
		return "nobody of the family helps in the shop"
	var nm := _first_name(npc)
	var h := Game.hour()
	if h >= BREAK_START and h < BREAK_END:
		return "%s takes the midday hour (back at %02d:00)" % [nm, BREAK_END]
	if not in_hours():
		return "%s minds the counter %02d:00–%02d:00" % [nm, COUNTER_START, COUNTER_END]
	var a := Adv.get_a(npc)
	if not a.is_empty():
		match str(a.get("status", "")):
			"away":
				return "%s is away on the road" % nm
			"injured":
				return "%s is resting her injuries" % nm
			"dead", "missing", "gone":
				return "%s is not here" % nm
	if not Shop.customer(npc).is_empty():
		return "%s is waiting at the counter herself" % nm
	if Memorial.funeral_spot(npc) != "":
		return "%s is at the graveside" % nm
	return ""


static func on_duty() -> bool:
	return duty_reason() == ""


## Is she standing behind the counter? With a world, her figure must have arrived there (the world walks her over at the
## hour); headless runs (no world) go by the schedule alone — one engine for play and tests, like the steward's smith.
static func at_counter(npc := "") -> bool:
	var who := npc if npc != "" else helper()
	var tree := Engine.get_main_loop() as SceneTree
	var w: Node = tree.get_first_node_in_group("world") if tree != null else null
	if w == null:
		return true
	var n: Variant = (w.get("npcs") as Dictionary).get(who, null) if w.get("npcs") is Dictionary else null
	var sp: Variant = (w.get("spots") as Dictionary).get(COUNTER_SPOT, null) if w.get("spots") is Dictionary else null
	if not n is Node2D or not sp is Vector2:
		return true   # no figure or no counter in this world: the schedule decides
	var fig: Node2D = n
	var walking: bool = fig.get("path") is PackedVector2Array and not (fig.get("path") as PackedVector2Array).is_empty()
	return fig.visible and not walking and fig.position.distance_to(sp as Vector2) < 80.0


## world.spot_for: behind the shop counter while on duty ("" = her ordinary routine).
static func spot(npc: String) -> String:
	if npc == "" or npc != helper() or not on_duty():
		return ""
	return COUNTER_SPOT


# ======================================================================= asking her
## Asks the spouse to help in the shop. She agrees by her character and affection; a refusal stands for the day.
static func ask(npc: String) -> Dictionary:
	if npc == "" or npc != spouse():
		return {"ok": false, "text": "\"Help in your shop? We're not married, smith.\""}
	if helps():
		return {"ok": true, "text": "\"I already mind the counter. Did you forget?\""}
	var s := st()
	var lines: Array = LINES.get(npc, LINE_DEFAULT)
	s["asked"][npc] = Game.day()
	if Social.aff(npc) < willing_at(npc):
		return {"ok": false, "text": str(lines[1])}
	s["helper"] = npc
	s["since"] = Game.day()
	Social.change(npc, 2.0, 2.0, "counter", "Agreed to help Brannoc in the shop.", false)
	_log("%s agreed to help at the shop counter (%02d:00–%02d:00, the midday hour off)." % [Talk.npc_name(npc), COUNTER_START, COUNTER_END])
	Game.journal("%s will mind the shop counter in her hours — she sells what you put on display, at most %d %% off." % [Talk.npc_name(npc), discount_cap()])
	Events.customers_changed.emit()
	return {"ok": true, "text": str(lines[0])}


## The counter is the smith's again (asked by him, or she stopped of her own accord).
static func release(why := "") -> void:
	if str(_fam().get("helper", "")) == "":
		return
	var npc := str(st()["helper"])
	st()["helper"] = ""
	_log(why if why != "" else "%s no longer minds the shop counter." % Talk.npc_name(npc))
	Events.customers_changed.emit()


static func asked_today(npc: String) -> bool:
	return int((_fam().get("asked", {}) as Dictionary).get(npc, -1)) == Game.day()


# ======================================================================= talk
static func talk_options(npc: String) -> Array:
	if npc == "" or npc != spouse():
		return []
	if helps():
		return [{"id": "f_counter_day", "label": "Ask how the shop went today"},
			{"id": "f_counter_release", "label": "Tell her she needn't mind the counter any more"}]
	var o := {"id": "f_counter_ask", "label": "Ask her to help at the shop counter"}
	if asked_today(npc):
		o["disabled"] = "she gave you her answer today"
	return [o]


static func talk_choose(npc: String, opt: String) -> Dictionary:
	match opt:
		"f_counter_ask":
			return {"text": str(ask(npc)["text"])}
		"f_counter_release":
			release("You told %s she needn't mind the shop counter any more." % Talk.npc_name(npc))
			return {"text": "\"Suits me.\" She hangs the apron on its nail. \"Your customers, your prices, your headache.\""}
		"f_counter_day":
			var t := _today()
			if int(t["n"]) == 0:
				return {"text": "\"Nobody bought a thing from me today. %s\"" % ("Put something on display, Brannoc — I can't sell air." if Shop.stock().is_empty() else "They looked, mind.")}
			return {"text": "\"%d sale%s today, %d gold in the strongbox%s.\" She taps the ledger. \"It's all written down.\"" % [int(t["n"]),
				"" if int(t["n"]) == 1 else "s", int(t["gold"]), (" — %d off, all told, to close them" % int(t["off"])) if int(t["off"]) > 0 else ", every one at your price"]}
	return {}


# ======================================================================= work at the counter
## Every 15 game minutes (Game.advance_minutes): while on duty she serves one waiting customer.
static func tick() -> void:
	if Game.state.is_empty() or not Game.state.has("family"):
		return
	var npc := helper()
	if npc == "":
		if str(_fam().get("helper", "")) != "" and spouse() != str(_fam().get("helper", "")):
			release("%s no longer minds the shop counter." % Talk.npc_name(str(_fam()["helper"])))   # widowed, or she left
		return
	if Social.aff(npc) < willing_at(npc) - QUIT_MARGIN:
		release("%s has stopped minding the shop counter — things between you are not what they were." % Talk.npc_name(npc))
		Game.journal("%s has stopped minding the shop counter." % Talk.npc_name(npc))
		return
	if not on_duty() or not at_counter(npc):
		return   # off duty, or still on her way to the counter
	for c in Shop.waiting().duplicate():
		if _serve(c):
			return


## Tries to serve one seated customer. True when a sale was made.
static func _serve(c: Dictionary) -> bool:
	var npc := str(c.get("npc", ""))
	if npc == "" or npc == helper():
		return false
	var hour_now := int(Game.now() / 60)
	if int(c.get("family_seen", -1)) == hour_now:
		return false   # looked at this hour already; again on the next hour (the display may have changed)
	match str(c.get("want", "")):
		"browse":
			c["family_seen"] = hour_now
			return _serve_browse(npc)
		"goods":
			c["family_seen"] = hour_now
			return _serve_goods(c, npc)
	return false   # repairs need competence (repair_reason); commissions, parts, advice and disputes are the smith's


## The highest price in [floor, listed] at which `ok` holds (ok is monotone: a buyer who takes it at p takes it below
## p too). -1 when not even the floor will do.
static func _best_price(listed: int, ok: Callable) -> int:
	if ok.call(listed):
		return listed
	var lo := floor_price(listed)
	if lo >= listed or not ok.call(lo):
		return -1
	var hi := listed
	while hi - lo > 1:
		var mid := int((lo + hi) / 2)
		if ok.call(mid):
			lo = mid
		else:
			hi = mid
	return lo


static func _sellable(it: Dictionary) -> bool:
	return bool(it.get("for_sale", false)) and str(it.get("for_order", "")) == "" and Steward.protection_reason(it) == ""


static func _serve_browse(npc: String) -> bool:
	var a := Adv.get_a(npc)
	if a.is_empty():
		return false
	var pick := {}
	var pick_price := -1
	var pick_score := -1.0
	for it in Shop.stock():
		if not Items.is_equipment(it) or not _sellable(it):
			continue
		var it2: Dictionary = it
		var p := _best_price(Shop.price_of(it), func(x: int) -> bool: return Adv.purchase_check(a, it2, x) == "")
		if p < 0:
			continue
		var sc := Items.score(it)
		if sc > pick_score or (sc == pick_score and p > pick_price):
			pick = it
			pick_price = p
			pick_score = sc
	if pick.is_empty():
		return false
	var listed := Shop.price_of(pick)
	var nm := Items.display_name(pick)
	var uid := int(pick["uid"])
	if Shop.sell_to(npc, uid, pick_price, helper()) != "":
		return false
	_sold(uid, nm, npc, pick_price, listed)
	return true


static func _serve_goods(c: Dictionary, npc: String) -> bool:
	var want := str(c.get("looking_for", ""))
	var budget := int(c.get("budget", 0))
	for it in Game.inventory():
		if str(it.get("def", "")) != want or not _sellable(it):
			continue
		var unit := Shop.price_of(it) / maxi(1, int(it.get("qty", 1)))
		var p := _best_price(unit, func(x: int) -> bool: return x <= budget)
		if p < 0:
			return false
		var uid := int(it["uid"])
		if Shop.sell_goods(npc, uid, p, helper()) != "":
			return false
		_sold(uid, str(DB.item(want).get("name", want)), npc, p, unit)
		return true
	return false


static func _sold(uid: int, name: String, npc: String, price: int, listed: int) -> void:
	var s := st()
	var off := listed - price
	s["sales_n"] = int(s["sales_n"]) + 1
	s["sales_gold"] = int(s["sales_gold"]) + price
	s["discount_gold"] = int(s["discount_gold"]) + off
	var t := _today()
	t["n"] = int(t["n"]) + 1
	t["gold"] = int(t["gold"]) + price
	t["off"] = int(t["off"]) + off
	s["today"] = t
	var who := Talk.npc_name(helper())
	var how := (" (%d %% off %d g)" % [int(round(100.0 * off / float(maxi(1, listed)))), listed]) if off > 0 else ""
	var line := "%s sold %s to %s for %d g%s." % [who, name, Talk.npc_name(npc), price, how]
	_log(line)
	Events.toast.emit(line, "good")
	Steward.note_counter_sale(uid, name, npc, price, who)


static func _today() -> Dictionary:
	var t: Dictionary = _fam().get("today", {})
	if int(t.get("day", -1)) != Game.day():
		return {"day": Game.day(), "n": 0, "gold": 0, "off": 0}
	return t.duplicate()


static func _log(text: String) -> void:
	var lg: Array = st()["log"]
	lg.append({"day": Game.day(), "time": Game.time_string(), "text": text})
	while lg.size() > LOG_CAP:
		lg.pop_front()


static func log_lines(n := 6) -> Array:
	var lg: Array = _fam().get("log", [])
	return lg.slice(maxi(0, lg.size() - n))


## Why she does not take a customer's repair ("" = she could): only with her own competence at the grinding wheel
## (Workers kind "spouse"). No spouse in the game has smithing, so repairs stay with the smith (or the steward's smith).
static func repair_reason() -> String:
	var npc := helper()
	if npc == "":
		return "nobody of the family helps in the shop"
	var why := Workers.station_reason(npc, "grinding_wheel")
	if why != "":
		return why
	if Workers.level(npc, "smithing") < 1:
		return "%s has no smithing — repairs wait for the smith" % _first_name(npc)
	return ""


## For the counter's family row: {spouse, name, helps, on_duty, why, cap, steps, today {n, gold, off}, sales_n, sales_gold,
## discount_gold, hours, asked_today, willing}.
static func status() -> Dictionary:
	var sp := spouse()
	if sp == "":
		return {}
	var f := _fam()
	return {"spouse": sp, "name": Talk.npc_name(sp), "helps": helps(), "on_duty": on_duty(), "at_counter": helps() and on_duty() and at_counter(sp),
		"why": duty_reason(), "cap": discount_cap(),
		"steps": DISCOUNT_STEPS, "today": _today(), "sales_n": int(f.get("sales_n", 0)), "sales_gold": int(f.get("sales_gold", 0)),
		"discount_gold": int(f.get("discount_gold", 0)), "hours": [COUNTER_START, COUNTER_END], "asked_today": asked_today(sp),
		"willing": Social.aff(sp) >= willing_at(sp)}


# ======================================================================= the pet (#52)
## The creatures in the smith's own stores that could walk with him: not on display, not promised to an order.
static func pets() -> Array:
	if Game.state.is_empty():
		return []
	return Game.inventory().filter(func(it): return Companions.is_companion(it) and not bool(it.get("for_sale", false)) and str(it.get("for_order", "")) == "")


## The smith's pet: the one he chose (set_pet), else the one he has kept longest ({} when he keeps none).
static func pet() -> Dictionary:
	var all := pets()
	if all.is_empty():
		return {}
	var chosen := int(_fam().get("pet_uid", -1))
	var best: Dictionary = all[0]
	for it in all:
		if int(it.get("uid", -1)) == chosen:
			return it
		if int(it.get("uid", 0)) < int(best.get("uid", 0)):
			best = it
	return best


## Chooses which of his creatures walks with him. "" or why not.
static func set_pet(uid: int) -> String:
	for it in pets():
		if int(it.get("uid", -1)) == uid:
			st()["pet_uid"] = uid
			Events.inventory_changed.emit()
			return ""
	return "That creature is not in your stores (or it is on display)."
