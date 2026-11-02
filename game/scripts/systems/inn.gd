## InnLife — the Tipsy Wyvern as a place to live, not just to shop: table talk drawn from what has
## really happened, a game of knucklebones, and the personal side of romance and marriage.
## EN: Romance progresses through shared evenings AND personal moments: drinks by the fire lead to
##     dating; a walk by the stream (her story) opens courting; she gives you a keepsake; then a ring
##     from your own anvil. Married, she keeps adventuring, takes your gear for free, shares her
##     spoils, comes home to your quarters — and her fate stays bound to what you forge for her.
## DA: Kroen som et sted at leve: bordsnak om virkelige hændelser, knoglespil og romantikkens
##     personlige øjeblikke — gåtur, erindringsgave, ring, bryllup og ægteskab.
class_name InnLife
extends RefCounted

const ROMANCE := {
	"mira": {
		"walk": "You walk Mira home along the stream. She points out every bird by its call. \"Dad thinks the road will kill me,\" she says. \"Maybe. But I'd rather die out there than behind a counter.\" She laughs, then doesn't. \"Don't tell him I said that.\"",
		"keepsake": ["Mira's Carved Arrowhead", "A flint arrowhead she knapped as a girl. \"So you've something sharp that isn't yours.\""],
		"wedding": "The chapel is small and full. Aldric weeps openly. Mira wears her ranger's cloak over the dress and refuses to apologise for it.",
		"married": ["\"I saw a heron at the ford this morning. Thought of you — grumpy and standing very still.\"", "\"Dad sent bread. Again. He likes you now, you know.\"", "\"The bow you made me sings when I draw it. Don't let it go to your head.\""],
	},
	"sigrun": {
		"walk": "Sigrun walks like a soldier even by the stream. \"I had a husband once,\" she says. \"Shield-brother, really. The Ashfields took him.\" She is quiet a long while. \"You'd have liked him. He'd have hated your prices.\"",
		"keepsake": ["Sigrun's Shield-Band", "A battered brass band from an old shield-rim. \"It held a shield together for twenty years. Hold onto it.\""],
		"wedding": "Sigrun marries in mail. Half the Wyvern comes, and Varn cries louder than anyone.",
		"married": ["\"Sparred with Varn this morning. I won. Mostly because of the shield you made.\"", "\"Your shoulders are bad again. Sit. I'll do the bellows.\"", "\"Don't wait up if I'm late from the road. But do wait up.\""],
	},
	"elowen": {
		"walk": "Elowen talks about fire the way other people talk about lovers. \"Everyone at the college thought I'd burn the tower down.\" A pause. \"I did, a little. That's why I'm here.\" Sparks drift from her fingers into the stream and hiss out.",
		"keepsake": ["Elowen's Ember Charm", "A glass bead with a tiny flame inside that never goes out. \"It's mostly safe.\""],
		"wedding": "Elowen lights every candle in the chapel with a snap of her fingers. The priest pretends not to notice.",
		"married": ["\"I may have warmed the anvil for you this morning. It's... still warm.\"", "\"I read about a forge-rune that might help your shoulders. Don't worry, I've only half-tested it.\"", "\"The college wrote. I told them I'm married to a smith now. They didn't know what to say.\""],
	},
	"kestra": {
		"walk": "Kestra walks on the wall of the bridge instead of the path. \"Tobin's the good one,\" she says. \"I'm the one who takes things.\" She drops down beside you. \"I don't take from you. Notice that?\"",
		"keepsake": ["Kestra's Lucky Pick", "A thin, beautifully made lockpick. \"Never failed me. Don't use it. Or do — just don't get caught.\""],
		"wedding": "Kestra arrives late to her own wedding, climbs in through the vestry window, and Tobin pretends to be furious.",
		"married": ["\"Tobin says hello. Tobin also says you overcharged him for a hinge.\"", "\"I counted the coins in the strongbox. Don't look at me like that. They're all still there.\"", "\"Back by the next new moon. Keep the door unbarred.\""],
	},
}

const TABLE_FALLBACK := ["\"Quiet week. Too quiet.\"", "\"Barrow-dust in my boots again.\"", "\"To the smith — may his hammer stay heavy.\""]


# ------------------------------------------------------------------ table talk
## What the room is talking about tonight, drawn from the world's real recent events.
static func table_talk() -> String:
	var lines := []
	for a in Adv.all().values():
		Adv.ensure(a)
		if a["status"] == "dead" and Game.day() - int(a.get("died_day", Game.day())) <= 7:
			lines.append("\"To %s,\" someone says, and the room goes quiet. \"The barrows took a good one.\"" % a["name"])
		elif not a["history"].is_empty() and Game.day() - int(a["history"][-1]["day"]) <= 3 and a["status"] in ["in_town", "injured"]:
			var h: Dictionary = a["history"][-1]
			var dn: String = DB.destinations.get(h["dest"], {}).get("name", "the road")
			if str(h["outcome"]).begins_with("success"):
				var credit := ""
				for uid in h.get("credits", {}):
					credit = h["credits"][uid]
				lines.append("%s is telling the table about %s%s." % [a["name"], dn, (" — the smith's work won the day (%s)" % credit) if credit != "" else ""])
			else:
				lines.append("%s nurses a drink and won't talk about %s." % [a["name"], dn])
	if Social.spouse() != "":
		lines.append("Someone raises a cup to the smith and %s. Hilde rolls her eyes and pours anyway." % Adv.get_a(Social.spouse()).get("name", "his wife"))
	if int(Game.state["stats"].get("legendaries", 0)) > 0:
		lines.append("Pip has made up a song about a legendary blade from the Ironhand forge. It is not a good song.")
	var rw := Shop.reputation_word()
	if rw in ["renowned", "well respected"]:
		lines.append("At the bar, a stranger asks where to find a decent smith. Three people point at you.")
	elif rw in ["notorious", "poorly thought of"]:
		lines.append("Conversation dips when you come in. Someone mutters about refunds.")
	if lines.is_empty():
		lines = TABLE_FALLBACK.duplicate()
	lines.shuffle()
	return "\n".join(lines.slice(0, 3))


## Knucklebones: 2d6 each, highest wins. Small stakes, real familiarity.
static func knucklebones(npc: String) -> String:
	if not Game.can_afford(5):
		return "Your purse is too light even for knucklebones."
	var you := Dice.roll("2d6")
	var them := Dice.roll("2d6")
	Social.change(npc, 1.5, 5.0)
	Audio.play("sfx/dice_roll")
	var t := "You throw %s (%d); %s throws %s (%d). " % [str(you["faces"]), int(you["total"]), Talk.npc_name(npc), str(them["faces"]), int(them["total"])]
	if int(you["total"]) > int(them["total"]):
		Game.add_gold(5, "inn", "Won at knucklebones")
		return t + "\"Bah. Again tomorrow.\""
	if int(you["total"]) < int(them["total"]):
		Game.add_gold(-5, "inn", "Lost at knucklebones")
		return t + "They sweep up your coins with a grin."
	return t + "A draw. You both drink to it."


# ------------------------------------------------------------------ romance beats
static func can_walk(npc: String) -> bool:
	return ROMANCE.has(npc) and Social.romance(npc) == "dating" and not Game.has_flag("walked_" + npc) and Social.aff(npc) >= 35.0 and (Game.hour() >= 17 or Game.hour() < 1)


static func walk(npc: String) -> String:
	Game.set_flag("walked_" + npc)
	Social.change(npc, 10.0, 8.0, "walk", "Walked by the stream with Brannoc and told him things I don't tell people.")
	return ROMANCE[npc]["walk"]


## While courting, after a good evening, she gives you something of hers.
static func maybe_keepsake(npc: String) -> String:
	if not ROMANCE.has(npc) or Social.romance(npc) != "courting" or Game.has_flag("keepsake_" + npc):
		return ""
	Game.set_flag("keepsake_" + npc)
	var k: Array = ROMANCE[npc]["keepsake"]
	var it := Items.make("relic_coin")
	it["name"] = k[0]
	it["keepsake"] = npc
	it["desc"] = k[1]
	Game.add_item(it, false)
	Social.remember(npc, "keepsake", "Gave Brannoc %s" % k[0], 5.0)
	Game.journal("%s gave you %s." % [Talk.npc_name(npc), k[0]])
	return "\n\nBefore she goes she presses something into your hand: [b]%s[/b]. %s" % [k[0], k[1]]


static func wedding(npc: String) -> String:
	# marrying into a family: her kin become yours
	for r in Social.relatives(npc):
		Social.change(r, 25.0, 15.0, "family_" + npc, "The smith married into our family.", false)
	Shop.rep_change(5.0, "the smith married %s." % Talk.npc_name(npc))
	Game.set_flag("married")
	return str(ROMANCE.get(npc, {}).get("wedding", "A small ceremony at the Chapel of the Dawn."))


static func married_line(npc: String) -> String:
	var ls: Array = ROMANCE.get(npc, {}).get("married", ["\"Husband.\""])
	return ls[(Game.day() + npc.length()) % ls.size()]
