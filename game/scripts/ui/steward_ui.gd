## StewardUI — shared presentation helpers for Steward Mode (Milestone S1, canonical v1.1 §4.5).
## EN: Words for the steward's records, the standing-instructions summary, what the player may still open while the
##     smith is away (looking is fine, acting in the world is not), the hand-over and the return (the While You Were
##     Away report, then any sealed letters), and the way to the real pending matter behind a deferral. Pure UI: every
##     number and sentence comes from the Steward engine (scripts/systems/steward.gd); nothing here changes the world
##     except through Steward.activate / deactivate / open_letter / resolve.
## DA: Fælles hjælpere til Forvalter-tilstanden: ord, opsummering af de stående instrukser, hvad man må åbne mens smeden
##     er væk, overdragelse og hjemkomst (rapporten og derefter forseglede breve) og vejen til den egentlige sag.
class_name StewardUI
extends RefCounted

## Panels that only LOOK at the world (or are menus): they stay available while the smith is away and — being
## opened while the steward runs — do not stop the clock (UIWindow). Everything else acts in the world (crafting,
## trading, talking, hiring, sleeping, travelling…) and is refused with a reason until the smith takes the forge back.
const ALLOWED_AWAY := ["prompt", "steward", "welcome_back", "sealed_letter", "help", "settings", "pause", "saves", "map",
	"world_map", "history", "item", "familiar", "dossier", "observe", "adventurers", "wanted", "skills", "hall_of_fame",
	"workshop", "dev_panel", "dev_catalogue"]
## Menus that still stop the clock while the steward runs (the player expects a pause menu to pause).
const STOP_TIME_AWAY := ["pause", "saves", "settings"]

const KIND_NAME := {"contract": "Contract letter", "notice": "Independence notice", "staff": "Staff", "visitor": "Visitor",
	"dispute": "Dispute", "personal": "Personal", "fame_commission": "Fame commission", "repair": "Repair of a protected piece",
	"remarkable": "Remarkable piece", "deed": "Deed", "loss": "Loss", "death": "Death", "inheritance": "Inheritance",
	"sponsorship": "Sponsored expedition"}
## The line on the outside of an envelope when the letter names no sender (a Lore event, not a visitor).
const KIND_SENDER := {"deed": "News of your work", "loss": "News of your work", "death": "Word from the village",
	"inheritance": "News of your work", "sponsorship": "Word from the road", "notice": "From your workshop"}
const LOG_ICON := {"buy": "⚖", "sell": "⚖", "list": "▣", "accept": "✎", "commit": "⚒", "deliver": "✓", "decline": "✗",
	"repair": "⚒", "restock": "⚒", "prep": "⚒", "contract_hours": "⚒", "assign": "☞", "cancel": "✗", "provisions": "▤",
	"stall": "‼", "defer": "✉", "activate": "➜", "deactivate": "⌂", "stood_down": "⌂", "order_left": "·", "repair_left": "·",
	"reserve_ok": "·", "smith_begin": "⚒", "smith_made": "✓", "smith_repair": "⚒"}
## S2: what the smith's own work was for (the report and the panel).
const PURPOSE_NAME := {"restock": "for the display", "commission": "for a commission", "prep": "prepared material"}
const COMPLETED_NAME := {"repair": ["customer repair", "customer repairs"], "commission": ["commission", "commissions"],
	"craft": ["piece for the display", "pieces for the display"], "prep": ["material preparation", "material preparations"],
	"maintain": ["station upkeep", "station upkeeps"], "contract": ["block of contract work", "blocks of contract work"],
	"restock": ["piece for the display", "pieces for the display"]}


# ======================================================================= words
static func money(g: int) -> String:
	return "%d g" % g


static func signed(g: int) -> String:
	return ("+%d g" % g) if g > 0 else ("−%d g" % absi(g) if g < 0 else "±0 g")


## A piece as the smith knows it: its earned name first ("Oathkeeper" — Iron Sword).
static func piece_name(it: Dictionary) -> String:
	if it.is_empty():
		return "?"
	var en := ItemStory.earned_name(it)
	return ("“%s” — %s" % [en, Items.display_name(it)]) if en != "" else Items.display_name(it)


## The standing instructions without creating steward state (an old save only gains it when the steward is used).
static func orders() -> Dictionary:
	return Steward.orders() if not Game.state.is_empty() and Game.state.has("steward") else Steward.default_orders()


## "1 commission", "3 commissions" (a finished-task kind from the report).
static func completed_text(kind: String, n: int) -> String:
	var w: Array = COMPLETED_NAME.get(kind, [kind, kind])
	return "%d %s" % [n, str(w[0] if n == 1 else w[1])]


static func kind_name(k: String) -> String:
	return str(KIND_NAME.get(k, k.capitalize()))


static func sender(e: Dictionary) -> String:
	var f := str(e.get("from", ""))
	if f != "":
		return f
	return str(KIND_SENDER.get(str(e.get("kind", "")), "A letter left at the smithy"))


static func elapsed(mins: int) -> String:
	var d := int(mins / 1440)
	var h := int((mins % 1440) / 60)
	var m := mins % 60
	if d > 0:
		return "%d day%s %d h" % [d, "" if d == 1 else "s", h]
	return "%d h %02d min" % [h, m]


static func key() -> String:
	return Settings.key_label("panel_steward")


## The standing instructions in one line (the top of the instructions panel, the hand-over confirmation).
static func summary_line(o: Dictionary) -> String:
	var duties: Dictionary = o.get("duties", {})
	var on := 0
	for d in Steward.DUTIES:
		if bool(duties.get(d, false)):
			on += 1
	var cats: Array = o.get("buy_categories", [])
	var prot := (o.get("protected", []) as Array).size()
	var res := (o.get("reserved", {}) as Dictionary).size()
	return "Up to %d g a day and %d g in all, never below %d g · buys %s · %d of %d duties · %d piece%s protected by hand · %d suppl%s reserved" % [
		int(o.get("daily_limit", 0)), int(o.get("session_limit", 0)), int(o.get("reserve", 0)),
		("%d categor%s" % [cats.size(), "y" if cats.size() == 1 else "ies"]) if not cats.is_empty() else "nothing",
		on, Steward.DUTIES.size(), prot, "" if prot == 1 else "s", res, "y" if res == 1 else "ies"]


## The standing instructions as a short bulleted list (bbcode) for the hand-over confirmation.
static func summary_bbcode(o: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("• [b]Money:[/b] up to %d g a day and %d g while you are away; never below a purse of %d g." % [int(o["daily_limit"]), int(o["session_limit"]), int(o["reserve"])])
	var cats: Array = o.get("buy_categories", [])
	lines.append("• [b]May buy:[/b] %s — at the village counters while they are open." % (", ".join(PackedStringArray(cats)) if not cats.is_empty() else "nothing"))
	var on := PackedStringArray()
	var off := PackedStringArray()
	for d in Steward.DUTIES:
		(on if bool(o["duties"].get(d, false)) else off).append(str(Steward.DUTY_NAME.get(d, d)))
	lines.append("• [b]Duties:[/b] %s%s." % [", ".join(on) if not on.is_empty() else "none", ("  [color=#7e2418](off: %s)[/color]" % ", ".join(off)) if not off.is_empty() else ""])
	var orr: Dictionary = o["order_rules"]
	lines.append("• [b]Ordinary orders:[/b] difficulty up to %d, reward at least %d g, finished %d day%s before the deadline%s." % [int(orr["max_difficulty"]),
		int(orr["min_reward"]), int(orr["deadline_margin"]), "" if int(orr["deadline_margin"]) == 1 else "s", "; unsuitable parts declined" if bool(orr["decline_unsuitable"]) else ""])
	var sr: Dictionary = o["sell_rules"]
	lines.append("• [b]Selling:[/b] never below %d %% of a piece's value; %s%s; keeps %d piece%s on display%s." % [int(sr["min_price_pct"]),
		"new workshop pieces go on display" if bool(sr["list_new_work"]) else "new pieces stay in the stores",
		", your ordinary stored pieces too" if bool(sr["list_existing"]) else "", int(sr["stock_target"]), "" if int(sr["stock_target"]) == 1 else "s",
		"; serves goods customers from your shelf" if bool(sr["sell_goods"]) else ""])
	var hrs: Array = o.get("smith_hours", [8, 18])
	lines.append("• [b]Your own work:[/b] %s, %02d:00–%02d:00 with the midday hour off; you rest and sleep as usual and gain no experience from it." % [
		"routine forging, counter repairs and preparation at an ordinary, steady standard" if bool(o["duties"].get("smith", false)) else "none (you only rest)",
		int(hrs[0]), int(hrs[1])])
	lines.append("• [b]Pace:[/b] %s%s." % ["the whole village runs half again as fast (1.5×) while you are away" if float(o.get("pace", 1.5)) > 1.0 else "normal speed (1×)",
		("; the nights pass at %d× while you sleep" % int(Steward.SLEEP_PACE)) if bool(o.get("sleep_pace", false)) else ""])
	var prot := (o.get("protected", []) as Array).size()
	var res: Dictionary = o.get("reserved", {})
	var rl := PackedStringArray()
	for d2 in res:
		rl.append("%s ≥ %d" % [str(DB.item(str(d2)).get("name", d2)), int(res[d2])])
	lines.append("• [b]Never touched:[/b] Epic, named, legendary and historically significant pieces%s%s." % [
		(", %d piece%s you protected" % [prot, "" if prot == 1 else "s"]) if prot > 0 else "", ("; kept in stock: " + ", ".join(rl)) if not rl.is_empty() else ""])
	return "\n".join(lines)


## Text cut at a word boundary with an ellipsis (the plate keeps every line short).
static func clip(t: String, n: int) -> String:
	if t.length() <= n:
		return t
	var cut := t.left(n)
	var sp := cut.rfind(" ")
	return (cut.left(sp) if sp > int(n / 2.0) else cut).rstrip(" ,;:—-") + "…"


static func shortened(e: Dictionary, n: int) -> Dictionary:
	var c := e.duplicate()
	c["text"] = clip(str(e.get("text", "")), n)
	return c


## One steward log line for the plate and the panel.
static func log_line(e: Dictionary, with_day := false) -> String:
	var ic := str(LOG_ICON.get(str(e.get("kind", "")), "·"))
	var when := ("day %d %s" % [int(e.get("day", 0)), str(e.get("time", ""))]) if with_day else str(e.get("time", ""))
	return "[color=#6e5a40]%s[/color] %s %s" % [when, ic, str(e.get("text", ""))]


# ======================================================================= away
## "" when the panel `id` may be opened now; otherwise why not (the smith is away and the panel would act in the world).
static func away_block(id: String) -> String:
	if not Steward.smith_away() or ALLOWED_AWAY.has(id):
		return ""
	return "You are away — the steward is running the forge. Take the workshop back first (%s, or the steward's plate)." % key()


static func away_note() -> String:
	return "You are away: the steward runs the forge. Look around as you like; take the workshop back to act yourself."


## S2: one line on the smith at work for the plate and the panel ("" when the steward is not running).
static func smith_line(s: Dictionary) -> String:
	if s.is_empty():
		return ""
	return "[b]You:[/b] %s [color=#6e5a40]· %s (fatigue %d)[/color]" % [str(s.get("activity", "")), str(s.get("band", "")), int(round(float(s.get("fatigue", 0.0))))]


## S2: "1.5×" / "1×" (Living Workshop #40: "5×" — the night pace while the smith sleeps).
static func pace_text(p: float) -> String:
	if p >= Steward.SLEEP_PACE - 0.01:
		return "%d×" % int(Steward.SLEEP_PACE)
	return "1.5×" if p > 1.0 else "1×"


# ======================================================================= hand-over and return
## The UI's own reason not to hand over now (the engine's first; then a fade or check in progress).
static func can_activate() -> String:
	var why := Steward.can_activate()
	if why != "":
		return why
	if UIRoot.instance and is_instance_valid(UIRoot.instance.fade_rect) and UIRoot.instance.fade_rect.color.a > 0.05:
		return "Wait until the scene has settled."
	return ""


## Hands the forge over (the confirmation was the steward panel). "" or why not.
static func hand_over() -> String:
	var why := can_activate()
	if why != "":
		return why
	why = Steward.activate()
	if why != "":
		return why
	Events.toast.emit("The steward runs the forge and sets you to routine work (pace %s) — you gain no experience from it; nothing happens while the game is closed." % pace_text(Steward.pace()), "good")
	return ""


## Takes the forge back and shows While You Were Away (followed by any sealed letters).
static func take_back() -> Dictionary:
	if not Steward.is_active():
		return {}
	var r := Steward.deactivate()
	Events.close_panels.emit()
	Events.open_panel.emit.call_deferred("welcome_back", {"report": r})
	return r


## After the world starts: the report of a session that ended when the game was closed (shown once), else any
## sealed letters still unopened.
static func after_world_start() -> void:
	if Game.state.is_empty():
		return
	var r := Steward.take_pending_report()
	if not r.is_empty():
		Events.open_panel.emit("welcome_back", {"report": r})


# ======================================================================= the way to the real matter
## Opens the panel of the real pending matter behind a deferral's action {route, args}. Adventurers have a dossier;
## anyone else's record is their history.
static func go(action: Dictionary) -> bool:
	var route := str(action.get("route", ""))
	if route == "":
		return false
	var args: Dictionary = (action.get("args", {}) as Dictionary).duplicate(true)
	if route == "dossier" and Adv.get_a(str(args.get("id", ""))).is_empty():
		route = "history"
		args = {"kind": "npc", "id": str(args.get("id", ""))}
	if route == "apprentice" and (not Game.state.has("apprentices") or Apprentices.get_a(str(args.get("id", ""))).is_empty()):
		route = "workshop"
		args = {}
	Events.open_panel.emit.call_deferred(route, args)
	return true


## Follows a deferred matter to its place: reads it (open_letter marks it opened), marks it seen to, opens the route.
static func follow(id: String) -> bool:
	var l := Steward.open_letter(id)
	if l.is_empty():
		return false
	Steward.resolve(id)
	return go(l.get("action", {}))


## The place a Lore event of the report belongs to: the piece's history, the adventurer's dossier, or the legends.
static func world_link(ev_id: String) -> Dictionary:
	var e := Lore.event(ev_id)
	for u in e.get("items", []):
		if not ItemRegistry.find(int(u)).is_empty():
			return {"route": "history", "args": {"kind": "item", "id": str(int(u))}}
	for a in e.get("actors", []):
		if not Adv.get_a(str(a)).is_empty():
			return {"route": "dossier", "args": {"id": str(a)}}
	return {"route": "wanted", "args": {"tab": "legends"}}
