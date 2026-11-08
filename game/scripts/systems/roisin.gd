## Roisin — Róisín, the red-haired companion at the Velvet Lantern, and the smith's romance with her.
## EN: A sharp-witted sailor's daughter who mends broken clockwork and hates being underestimated. She owes
##     Madam Rosalind 200 gold for passage, debts and dresses, and wants a tea house of her own.
##     Stages: acquaintance → friend (warmth from talk, tea, gifts, asking her opinion of your work)
##       → dating (her father's sea-clock mended + two pots of tea + enough warmth)
##       → courting (a walk down to the harbour, then you ask) → her contract bought out together
##       → married (a ring). Uses Social (aff, fam, romance stage, memories) like the other romances;
##     intimacy is a discreet fade-to-black via the dialogue's "fade" result, never explicit.
##     State: Game.state["roisin"] (created lazily) + Social["roisin"].
## DA: Róisín på Velvet Lantern: venskab, te, sø-uret, gåtur til havnen, frikøb af kontrakten og bryllup.
##     Intime øjeblikke er diskret fade-to-black.
class_name Roisin
extends RefCounted

const ID := "roisin"
const CONTRACT := 200
const INSTALMENT := 50
const TEA_PRICE := 3
const STAGES := ["acquaintance", "friend", "dating", "courting", "married"]

const STORIES := [
	[0.0, "She is turning a tiny brass gear between finger and thumb. \"Róisín. Don't try to spell it.\" The gear clicks home in something that looks like the inside of a pocket-watch. \"Broken things are honest, smith. They show you exactly where they failed. People hide it better.\""],
	[10.0, "\"My father ran the [i]Kestrel[/i] out of Saltmere. Taught me knots before letters and the sextant before needlework.\" She ties a bowline in a ribbon without looking. \"He went down off the Teeth when I was sixteen. The sea doesn't give things back. I learned to fix what it leaves.\""],
	[20.0, "\"Men come up those stairs expecting a pretty face that nods.\" Her green eyes narrow. \"I can splice rope, read a chart and gut a cod faster than Hilde pours. Nobody asks. You asked about the clock. I noticed.\""],
	[30.0, "\"Rosalind holds my contract. Passage money, my mother's debts, the very dress I'm wearing — two hundred gold, all told.\" She says it the way a captain reads soundings. \"When it's paid, I'm opening a tea house. Proper leaf from the southern boats. No ale. No stairs.\""],
	[45.0, "\"You know what I like about your hands?\" She turns one over in hers. \"Burn scars in all the places a working man's should be. No lies in them. I could get used to hands like that.\""],
]

const GIFTS := {
	"herb_moonwort": "She sniffs it and laughs. \"Moonwort. With a little honey it's the best night-tea there is. You've been listening.\"",
	"herb_emberleaf": "\"Emberleaf! It'll make a tea that bites back.\" She tucks it away as if it were silver. \"Like me, you're thinking. Don't say it.\"",
	"gem_moonstone": "She holds it up to the lamp. \"It looks like sea-glass from the Saltmere shingle. Father used to bring me pockets of it.\" She is quiet a moment. \"Thank you.\"",
	"relic_coin": "She reads the worn face with a thumb. \"Old Hesperan mint — sailors' luck. My father had one sewn into his collar.\" A wry smile. \"It didn't work for him. Maybe it will for me.\"",
	"amulet_silver": "\"Your own work?\" She turns it to catch the light, checking the jump-rings like a jeweller. \"Clean joins. All right — I'll wear it. Where people can see.\"",
}

const MARRIED := [
	"\"The kettle's on and the shop's swept. Sit — your shoulders are up around your ears again.\"",
	"\"A ship's master came in for tea and stayed for three pots. Says my leaf is better than Port Varra's.\" She is unbearably pleased.",
	"\"I took apart your bellows hinge. It squeaked. Don't look at me like that, it's better now.\"",
]


# ------------------------------------------------------------------ state
static func st() -> Dictionary:
	if not Game.state.has(ID):
		Game.state[ID] = {"contract_paid": 0, "free": false, "clock": false, "walked": false, "tea_day": -1, "teas": 0,
			"opinion_day": -1, "gift_day": -1, "evenings": 0}
	return Game.state[ID]


static func stage() -> String:
	match Social.romance(ID):
		"married":
			return "married"
		"courting":
			return "courting"
		"dating":
			return "dating"
	return "friend" if Social.aff(ID) >= 15.0 and Social.fam(ID) >= 10.0 else "acquaintance"


static func stage_name() -> String:
	return {"acquaintance": "Acquaintance", "friend": "Friend", "dating": "Seeing each other", "courting": "Courting",
		"married": "Married"}.get(stage(), "Acquaintance")


static func is_free() -> bool:
	return bool(st().get("free", false))


static func evening_hours() -> bool:
	var h := Game.hour()
	return h >= 19 or h < 2


# ------------------------------------------------------------------ schedule
## Where she is right now (world.spot_for). `own_spot`: the world has a "lantern_roisin" spot.
static func spot(own_spot: bool) -> String:
	var h := Game.hour()
	if stage() == "married":
		if h >= 9 and h < 18:
			return "inn_garden"        # her tea table until the lead gives her a tea house
		return "quarters_table" if h >= 20 and h < 23 else ""
	if is_free():
		if h >= 9 and h < 18:
			return "inn_garden"
		return "inn_t3b" if h >= 18 and h < 22 else ""
	if h >= 4 and h < 10:
		return ""                      # asleep after the late shift
	return "lantern_roisin" if own_spot else "upstairs_hall"


# ------------------------------------------------------------------ dialogue
static func greeting() -> String:
	match stage():
		"married":
			return "\"There's my smith.\" " + MARRIED[(Game.day() + 1) % MARRIED.size()]
		"courting":
			return "Róisín's face does something complicated and lovely when she sees you. \"You're late. I'd decided to be cross. It isn't working.\""
		"dating":
			return "\"Ironhand.\" She finishes a knot in a length of watch-chain and pockets it. \"Come to be bossed about?\""
		"friend":
			return "\"The smith! Sit, sit — mind the springs, they bite.\""
	if Social.band(ID) in ["cool", "hostile"]:
		return "She doesn't look up from her clockwork. \"We're closed to you, smith.\""
	return "A red-haired woman with sea-green eyes looks up from a tray of tiny gears. \"You're the one who makes the loud noises down the lane.\""


static func options(area: String) -> Array:
	var s := st()
	var stg := stage()
	var out := []
	out.append({"id": "talk", "label": "Talk"})
	if int(s["tea_day"]) != Game.day():
		out.append({"id": "r_tea", "label": "Share a pot of tea (%d g)" % TEA_PRICE})
	if int(s["opinion_day"]) != Game.day():
		out.append({"id": "r_work", "label": "Ask what she thinks of your work"})
	if not bool(s["clock"]) and Social.aff(ID) >= 10.0:
		out.append({"id": "r_clock", "label": "Offer to mend her father's sea-clock (1 steel ingot)"})
	if stg == "dating" and not bool(s["walked"]) and (Game.hour() >= 17 or Game.hour() < 1):
		out.append({"id": "r_walk", "label": "Walk her down to the harbour"})
	if stg == "dating" and bool(s["walked"]):
		out.append({"id": "r_court", "label": "Ask to court her"})
	if stg == "courting" and not is_free():
		out.append({"id": "r_contract", "label": "Put %d g toward her contract (%d of %d paid)" % [INSTALMENT, int(s["contract_paid"]), CONTRACT]})
	if stg == "courting" and is_free() and Social.spouse() == "":
		out.append({"id": "r_propose", "label": "Propose (offer a ring)"})
	if stg in ["dating", "courting", "married"] and evening_hours():
		out.append({"id": "r_evening", "label": "Spend the evening together"})
	if stg in ["courting", "married"] and (Game.hour() >= 21 or Game.hour() < 2):
		out.append({"id": "r_stay", "label": "Stay the night"})
	if int(s["gift_day"]) != Game.day():
		var n := 0
		for def: String in DB.character(ID).get("likes", []):
			if Game.count(def) > 0 and n < 3:
				out.append({"id": "r_gift_" + def, "label": "Give her %s" % DB.item(def).get("name", def).to_lower()})
				n += 1
	# before you are seeing each other she is a Lantern companion like the others
	if stg in ["acquaintance", "friend"] and not is_free():
		out.append({"id": "evening", "label": "Spend the evening (25 g)"})
	if not is_free():
		out.append({"id": "rumour", "label": "Ask what the adventurers are saying (5 g)"})
	out.append({"id": "bye", "label": "Farewell"})
	return out


## Resolves one of her options. Returns {} for options handled by Talk (evening, rumour, bye).
static func choose(opt: String, _area: String) -> Dictionary:
	var s := st()
	var e := Social.ensure(ID)
	if opt == "talk":
		var first_today := int(e.get("last_talk", -1)) != Game.day()
		e["last_talk"] = Game.day()
		if first_today:
			Social.change(ID, 1.5, 4.0)
		return {"text": _story()}
	if opt == "r_tea":
		if not Game.can_afford(TEA_PRICE):
			return {"text": "Your purse is too light even for tea."}
		Game.add_gold(-TEA_PRICE, "inn", "Tea with Róisín")
		s["tea_day"] = Game.day()
		s["teas"] = int(s["teas"]) + 1
		Social.change(ID, 5.0, 5.0, "tea_" + str(Game.day()), "Shared a pot of tea with the smith.")
		Vitality.refresh(6.0)
		var t := "She brews it properly — warmed pot, leaf measured by eye, steeped while she counts under her breath in a sailor's cadence. It is the best thing you've drunk in years."
		return {"text": t + _maybe_date()}
	if opt == "r_work":
		s["opinion_day"] = Game.day()
		Social.change(ID, 2.0, 3.0)
		return {"text": opinion()}
	if opt == "r_clock":
		if Game.count("ingot_steel") < 1:
			return {"text": "\"Springs want good steel, smith. Come back with an ingot and I'll hold the lamp.\""}
		Game.remove_def("ingot_steel", 1)
		s["clock"] = true
		Vitality.add_fatigue(6.0)
		Social.change(ID, 10.0, 8.0, "sea_clock", "The smith mended my father's sea-clock. It ticks again.")
		Game.journal("You mended the sea-clock of Róisín's drowned father. It ticks again.")
		return {"text": "You draw a new mainspring from the steel and she fits it, tongue between her teeth. When the old chronometer ticks, she laughs out loud and then, abruptly, has to look out of the window for a while.\n\n\"Twelve years it's been stopped,\" she says at last. \"Thank you, Brannoc.\"" + _maybe_date(),
			"fade": "An evening at the bench, among tiny screws…", "minutes": 90}
	if opt == "r_walk":
		s["walked"] = true
		Social.change(ID, 10.0, 8.0, "walk_harbour", "Walked to the harbour with Brannoc and told him about the Kestrel.")
		return {"text": "You walk her down to the harbour. She names every boat by its rigging. At the end of the quay she points out past the light. \"The Teeth are that way. I came ashore here with nothing but the clock and my mother's debts, and Rosalind was the only one who'd pay my passage.\" The wind takes her hair like a flag. \"I don't regret much. I regret signing that.\"",
			"fade": "The long way round, by the water…", "minutes": 60}
	if opt == "r_court":
		if Social.aff(ID) >= 55.0:
			Social.set_romance(ID, "courting")
			Social.change(ID, 6.0, 4.0, "courting", "Brannoc asked to court me. Properly.")
			Game.journal("You are courting Róisín.")
			return {"text": "\"Court me?\" She looks at you as if you were a clock that had started chiming the right hour. \"Nobody's ever asked. They pay.\" She takes your arm. \"Yes. Now buy me a terrible pie and walk me home like a gentleman.\""}
		return {"text": "\"Ask me again when you've learned how I take my tea.\" It is not quite a no."}
	if opt == "r_contract":
		if not Game.can_afford(INSTALMENT):
			return {"text": "Your purse is too light."}
		Game.add_gold(-INSTALMENT, "inn", "Toward Róisín's contract")
		s["contract_paid"] = int(s["contract_paid"]) + INSTALMENT
		Social.change(ID, 4.0, 2.0)
		if int(s["contract_paid"]) >= CONTRACT:
			s["free"] = true
			Social.change(ID, 12.0, 6.0, "contract_free", "The smith helped me buy my contract back from Rosalind.")
			Game.journal("Róisín's contract is paid. She is her own woman — and plans a tea house.")
			Audio.play("sfx/coins")
			return {"text": "Madam Rosalind counts the last coins twice, then tears the contract in half with a dancer's flourish. \"Go on, then, girl. Make your tea.\"\n\nOn the stairs Róisín stops, shaking, and laughs, and kisses you hard enough to knock your breath out. \"I owe nobody,\" she says. \"Not even you. Remember that.\" She doesn't let go of your hand."}
		return {"text": "You set %d gold on Rosalind's ledger in Róisín's name. %d of %d paid. Róisín adds a little purse of her own savings beside it and says nothing at all, which from her is a great deal." % [INSTALMENT, int(s["contract_paid"]), CONTRACT]}
	if opt == "r_propose":
		var ring := ""
		for it in Game.inventory():
			if Items.slot(it) == "ring":
				ring = str(it["uid"])
				break
		if ring == "":
			return {"text": "You'll need a ring. One from your own anvil would mean something to a woman who mends things."}
		if Social.aff(ID) < 75.0:
			return {"text": "\"Not yet, Brannoc.\" She closes your fingers over the ring. \"Ask me when I'm sure. I'll tell you when.\""}
		Game.take_uid(int(ring))
		Social.set_romance(ID, "married")
		Social.change(ID, 15.0, 10.0, "married", "Married Brannoc Ironhand.")
		Game.set_flag("married")
		Shop.rep_change(4.0, "the smith married Róisín of the harbour.")
		Game.journal("You married Róisín. She keeps her own name, her own tea house and your heart, roughly in that order.")
		Audio.play("sfx/level_up")
		return {"text": "She turns the band in the lamplight, checking the join like a jeweller. \"Clean,\" she says, and then her voice goes. \"Yes. Yes, you great soot-faced fool.\"\n\nThe chapel is small. Hilde cries; Rosalind pretends she doesn't. Róisín wears green, and the sea-clock in her pocket keeps perfect time.",
			"fade": "A small ceremony at the Chapel of the Dawn…", "minutes": 120}
	if opt == "r_evening":
		s["evenings"] = int(s["evenings"]) + 1
		Social.change(ID, 3.0, 4.0, "evening_" + str(Game.day()), "A quiet evening with Brannoc.")
		Vitality.refresh(8.0)
		return {"text": "She shows you how to hear when a balance wheel is true. You tell her about the barrow at Greyfen. Somewhere in the middle the lamp is turned down, and the rest of the evening is nobody's business but yours.",
			"fade": "The lamp is turned down. The night is yours and hers alone.", "minutes": 180}
	if opt == "r_stay":
		var mins: int = ((6 - Game.hour() + 24) % 24) * 60 - Game.state["minute"] % 60
		Vitality.sleep(mins)
		Social.change(ID, 3.0, 3.0)
		return {"text": "You wake to gulls and the smell of a teapot warming. She is already up, hair like a banked fire, repairing your belt buckle without asking.",
			"fade": "The lamp gutters out…", "minutes": mins}
	if opt.begins_with("r_gift_"):
		var def := opt.substr(7)
		if Game.count(def) < 1:
			return {"text": "You pat your pockets. Nothing."}
		Game.remove_def(def, 1)
		s["gift_day"] = Game.day()
		Social.change(ID, 6.0, 3.0, "gift_" + def, "Brannoc gave me %s." % DB.item(def).get("name", def))
		return {"text": str(GIFTS.get(def, "\"For me? That's... thoughtful.\"")) + _maybe_date()}
	return {}


## Her verdict on the best piece you're carrying — she has opinions.
static func opinion() -> String:
	var best := {}
	for it in Game.inventory():
		if it.has("quality") and Items.slot(it) != "":
			if best.is_empty() or float(it["quality"]) > float(best["quality"]):
				best = it
	if best.is_empty():
		return "\"Show me something you've made first. I don't judge a clock by its case.\""
	var q := float(best["quality"])
	var nm := Items.display_name(best)
	if q >= 90.0:
		return "She weighs the %s for a long, silent moment. \"I'd hang that on a wall and charge for a look. Don't let it go to your head — it's already gone to mine.\"" % nm
	if q >= 70.0:
		return "\"Good, honest work.\" She sights along the %s. \"Balance sits a hair forward. Deliberate? Then I approve.\"" % nm
	if q >= 45.0:
		return "\"It'll do its job.\" She runs a fingernail along the %s. \"Your grind wanders near the end, though. Tired hands?\"" % nm
	return "She turns the %s over twice. \"Smith. Did you make this before breakfast, or during?\"" % nm


static func _story() -> String:
	var e := Social.ensure(ID)
	var told: int = int(e.get("stories_told", 0))
	var avail := STORIES.filter(func(x): return float(x[0]) <= Social.fam(ID))
	var text := greeting()
	if told < avail.size():
		text += "\n\n" + str(avail[told][1])
		e["stories_told"] = told + 1
	return text


## Friend → dating once the sea-clock ticks again, you've shared two pots of tea and she's warm enough.
static func _maybe_date() -> String:
	if Social.romance(ID) != "none" or not bool(st()["clock"]) or int(st()["teas"]) < 2 or Social.aff(ID) < 25.0:
		return ""
	Social.set_romance(ID, "dating")
	Game.journal("You and Róisín have been seeing each other.")
	return "\n\n[i]Before you go, she straightens your collar — and leaves her hand there a moment longer than she needs to. \"Same time tomorrow, Ironhand?\"[/i]"
