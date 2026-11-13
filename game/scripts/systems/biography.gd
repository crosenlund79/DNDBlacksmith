## Biography — an adventurer's authored pre-game history (canonical v1.5 §8.1): upbringing, personality, past
## experiences and early ambitions, about 100–150 words.
## EN: Written once, when the adventurer is created (Living.make_adventurer) or first met in an older save
##     (Living.ensure / the character sheet), and stored on the adventurer (`bio`, `bio_v`); it is never regenerated or
##     rewritten. It tells only the time before the campaign: it names no person who is not in the game's own data and
##     claims no current relationship, achievement or event, so it cannot contradict the simulation or Lore. Each of the
##     24 adventurers has an anchor (upbringing, training, why they took to the road) written to agree with their
##     established facts — the personality line, family links (Aldric, Martha, Tobin), age and race in characters.json,
##     and their look. The connecting sentences come from small pools by temper and class, chosen with the world seed
##     (Living.rng_for), so a campaign's biographies are reproducible and different campaigns read differently. The
##     generator uses its own random generator: it never disturbs the adventurer's own generation.
## DA: Eventyrerens forhistorie (opvækst, personlighed, oplevelser, tidlige ønsker) skrives én gang og ændres aldrig;
##     den fortæller kun om tiden før spillet og modsiger ikke simulationen.
class_name Biography
extends RefCounted

const KEY := "bio"
const VERSION := 1

## Per adventurer: where and how they grew up, what trained them, why they took to the road; "local" = grew up in the
## village (no arrival line). Placeholders: {n} full name, {f} first name, {s}/{o}/{p} she/her/her (he/him/his),
## {S}/{P} capitalised.
const ANCHORS := {
	"mira": {"local": true,
		"up": "{n} grew up above her father Aldric's grocery, counting turnips and customers before she could read.",
		"train": "She learned the bow from the herders who traded at the shop door, and the woods from her own wandering.",
		"why": "She took up the ranger's road to prove she is more than the grocer's girl."},
	"sigrun": {"up": "{n} was raised in a fishing hold on the northern coast, where every household kept a shield by the door.",
		"train": "She stood in her first shield-wall at fifteen, guarding the boats from raiders through a long winter.",
		"why": "She left the coast to find work worthy of good steel and people worthy of plain words."},
	"elowen": {"up": "{n} grew up among the copyists of a lakeside library, where silence was a virtue and curiosity a vice.",
		"train": "She read every treatise on enchanted metal on its shelves until her tutors ran out of answers.",
		"why": "She came south to see arcane metal worked by hand instead of described in margins."},
	"kestra": {"up": "{n} grew up with her brother Tobin in the crowded lanes of a river town, where wit was cheaper than bread.",
		"train": "She learned locks and quick exits from the very people she later came to owe money.",
		"why": "She took to adventuring because honest wages would never clear what she owes."},
	"garrick": {"up": "{n} was raised by his mother Martha after his father died, and grew up carrying her firewood and her worries.",
		"train": "He swore his oath at a wayside shrine and spent two winters guarding pilgrims on the mountain roads.",
		"why": "He became a paladin to stand between ordinary people and the things that hunt them."},
	"tomas": {"up": "{n} grew up in a busy market town, raised by a dice-maker who taught him the odds before his prayers.",
		"train": "He found his calling in a temple infirmary, where his jokes worked nearly as well as his poultices.",
		"why": "He took to the road as a travelling healer, and the road's card tables took to him."},
	"varn": {"up": "{n} grew up among the hill clans, where a loud voice and an open hand were counted as wealth.",
		"train": "He learned the great axe splitting firewood for a whole winter camp, and broke a good many handles doing it.",
		"why": "He came down from the hills when the old songs stopped being enough for him."},
	"pip": {"up": "{n} grew up behind the bar of a crossroads inn, listening to more travellers' tales than any child should.",
		"train": "He learned the lute from a wandering player who paid for his room in songs.",
		"why": "He set out to collect stories first-hand instead of second-hand over a tankard."},
	"rv_aldous": {"up": "{n} was raised in a garrison town where pay day was the only holiday anyone kept.",
		"train": "He sold his sword to merchant houses for twenty years and learned to read a contract faster than a map.",
		"why": "He now prefers small, well-paid work to grand causes, and keeps his own accounts."},
	"rv_brenna": {"up": "{n} was the only daughter among a pack of brothers on a horse farm in the south.",
		"train": "She learned to fight in the yard against all of them at once, and to win at least sometimes.",
		"why": "She came north to make a name for herself before her brothers do."},
	"rv_corwin": {"up": "{n} grew up in a magistrate's household, listening to petitions through the kitchen wall.",
		"train": "He squired for an old knight of the roads who judged people by what they did when no one was watching.",
		"why": "He keeps a list of the wrongs he means to right, and the list only ever grows."},
	"rv_dagny": {"up": "{n} was raised in a dwarven hall beneath the mountains, where oaths were carved into the doorposts.",
		"train": "She kept the old oaths as a hall-warden for longer than most of her companions have been alive.",
		"why": "She left the halls to learn whether the surface world still honours a promise."},
	"rv_ewan": {"up": "{n} grew up in the deep forests, among elves who measured a life in seasons rather than years.",
		"train": "He has walked with three companies since then and outlived every one of them.",
		"why": "He keeps travelling because he trusts no map but the one in his own memory."},
	"rv_fen": {"up": "{n} grew up a poacher's daughter at the edge of a lord's forest, where silence kept food on the table.",
		"train": "She could read a trail before she could read a letter, and learned to move without a sound.",
		"why": "She turned tracker because it pays better than poaching and hangs fewer people."},
	"rv_galen": {"up": "{n} was a promising student at a city academy until a single failed examination ended his place there.",
		"train": "He went on studying alone, in rented rooms and borrowed libraries, and kept a ledger of every slight.",
		"why": "He took to the road to prove his old masters wrong."},
	"rv_hesper": {"up": "{n} grew up in a cathedral town, copying the names from old gravestones for a few pennies a page.",
		"train": "She taught herself to read broken runes from rubbings, and often forgot to eat while doing it.",
		"why": "She travels to find the names that everyone else has forgotten."},
	"rv_ivo": {"up": "{n} grew up in a halfling river village, the cheerful nuisance of every market stall.",
		"train": "He learned sleight of hand from a travelling conjuror and kept practising long after the show moved on.",
		"why": "He took to the road to clear a heavy debt, preferably with somebody else's money."},
	"rv_juno": {"up": "{n} says she grew up in three different cities, and may be telling the truth about one of them.",
		"train": "She learned to vanish in crowds and never to give the same name twice.",
		"why": "Whatever else is said of her, she has always paid her debts, and the road pays them faster."},
	"rv_korvak": {"up": "{n} grew up in a half-orc wagon camp on the edge of the steppe, where every fire had its singer.",
		"train": "He learned to fight in the camp's wrestling rings and to roar louder than the drums.",
		"why": "He wants to be remembered in a song, preferably a loud one."},
	"rv_liesl": {"up": "{n} grew up in the high pastures, among sheep, snow and very few words.",
		"train": "She lost her husband to a hard winter there and learned to fight the way the winter does.",
		"why": "She came down from the pastures because there was nothing left up there to keep her."},
	"rv_mattias": {"up": "{n} was given to a southern abbey as a boy and grew up among its infirmary beds.",
		"train": "He spent thirty years there, learning which wounds close and which need prayers as well as stitches.",
		"why": "He walked north from the abbeys to tend the wounded of the barrows."},
	"rv_nell": {"up": "{n} grew up in a village without a priest, learning herb-lore and blessings from the old women who stood in for one.",
		"train": "She became a hedge-priestess with steady hands, and her tongue only grew sharper with practice.",
		"why": "She took to the road because the wounded are wherever the adventurers are."},
	"rv_oskar": {"up": "{n} grew up in a town of festivals, where a good song could pay for a winter's bread.",
		"train": "He learned his trade singing other people's victories in other people's taverns.",
		"why": "He took to the road because he wants a victory of his own to sing about."},
	"rv_perrin": {"up": "{n} grew up in a halfling burrow full of letters, ledgers and carefully kept family trees.",
		"train": "She became a travelling chronicler, writing down what towns would rather forget.",
		"why": "She keeps moving because there is always a little more of everyone's business to learn."},
}

## A childhood lesson, by temper (Adv.TRAITS).
const LESSON := {
	"brave": ["Even as a child {f} was the first across the frozen millpond and the last to admit a bruise.",
		"{S} learned early that fear is a poor reason to stay at home."],
	"cautious": ["{S} learned early to count the exits of any room and the coins in any bargain.",
		"Childhood taught {o} that the careful ones are the ones who come home."],
	"greedy": ["Lean years taught {o} to value a full purse above a good reputation.",
		"{S} learned early that nothing is truly lost until someone else has found it."],
	"steady": ["{S} learned early that patience finishes more work than talent ever starts.",
		"Long, plain days taught {o} to keep going when others stop."],
	"reckless": ["{S} learned early that the quickest way through trouble is straight through the middle of it.",
		"As a child {f} broke more bones than rules, though {s} broke a fair number of rules too."],
	"devout": ["{S} learned prayers before letters and has never quite stopped saying them.",
		"Faith came early to {o}, and has outlasted every hard winter since."],
}

## How they are on the road, by temper (what the expedition simulation's temper means).
const TEMPER := {
	"brave": ["On the road {s} presses on where others turn back, and companions follow {o} more readily than they admit.",
		"In a tight corner {s} steps forward first, which has earned {o} both friends and scars."],
	"cautious": ["On the road {s} turns back early rather than late, which is exactly why {s} is still on it.",
		"In a tight corner {s} looks for the way out before the way through."],
	"greedy": ["On the road {s} goes one chamber deeper than is wise whenever the spoils look rich enough.",
		"In a tight corner {s} still finds a moment to check what the enemy was carrying."],
	"steady": ["On the road {s} is the one others want beside them when a fight runs long.",
		"In a tight corner {s} keeps a level head and a level blade."],
	"reckless": ["On the road {s} strikes first and bandages later, and {p} scars keep count.",
		"In a tight corner {s} charges, and the corner is usually sorry."],
	"devout": ["On the road {s} keeps the old wards and rites, and swears they have saved more lives than steel.",
		"In a tight corner {s} prays aloud, and fights no worse for it."],
}

## The hope they first set out with (past tense: their present goals are the simulation's), by class.
const HOPE := {
	"Fighter": "When {s} first set out, {s} hoped to earn a captain's trust and a captain's pay.",
	"Ranger": "When {s} first set out, {s} hoped to walk paths that no map remembers.",
	"Wizard": "When {s} first set out, {s} hoped to read the one book no library would lend.",
	"Rogue": "When {s} first set out, {s} hoped for one great score and a quiet life after it.",
	"Paladin": "When {s} first set out, {s} hoped to stand wherever the danger was worst.",
	"Cleric": "When {s} first set out, {s} hoped to bring every companion home alive.",
	"Barbarian": "When {s} first set out, {s} hoped for a fight worth retelling by the fire.",
	"Bard": "When {s} first set out, {s} hoped to witness a deed worthy of a ballad.",
}

## A habit, by class.
const HABIT := {
	"Fighter": ["{S} sleeps with a whetstone within reach.", "{S} oils every blade at dusk, borrowed or not."],
	"Ranger": ["{S} still checks the wind before breakfast.", "{S} notices tracks even on a tavern floor."],
	"Wizard": ["{S} fills the margins of every book {s} touches, including other people's.", "{S} carries more ink than food."],
	"Rogue": ["{S} never sits with {p} back to a door.", "{S} counts the coins in a room before the people."],
	"Paladin": ["{S} mends {p} own gear and anyone else's who asks.", "{S} rises before dawn to keep {p} vows."],
	"Cleric": ["{S} carries more bandages than coin.", "{S} learns the name of everyone {s} treats."],
	"Barbarian": ["{S} laughs loudest when the odds are worst.", "{S} eats like two and shares like three."],
	"Bard": ["{S} keeps a notebook of names, tunes and debts owed.", "{S} tunes {p} instrument whenever a room goes quiet."],
}

const CLOSE := ["Whatever {s} has done since arriving belongs to the village's own memory.",
	"What came after {s} reached the village is the village's story to tell, not this one."]
const CLOSE_LOCAL := ["Everything since then belongs to the village's own memory.",
	"The rest of {p} story is being written in the village that raised {o}."]

## Generic upbringing and training for an adventurer without an anchor (none today; kept for safety).
const UP_RACE := {
	"Dwarf": "{n} was raised in a dwarven hall beneath the mountains, where every child learns a trade before a song.",
	"Elf": "{n} grew up in the old forests, where the elves teach patience before archery.",
	"Halfling": "{n} grew up in a busy halfling village, where every door was open and every table full.",
	"Half-orc": "{n} grew up in a wandering camp on the edge of the steppe, where strength and loyalty were the same word.",
}
const UP_GENERIC := ["{n} grew up in a small market town, the kind every road passes through and few stop in.",
	"{n} was raised on a farm at the edge of the wilds, where wolves were a fact of life."]
const TRAIN_CLASS := {
	"Fighter": "{S} learned the sword in a town militia.", "Ranger": "{S} learned bow and tracking from foresters.",
	"Wizard": "{S} studied with a hedge-wizard who kept more cats than books.", "Rogue": "{S} learned locks and quick exits in the alleys.",
	"Paladin": "{S} swore {p} oath at a wayside shrine.", "Cleric": "{S} trained in a temple infirmary.",
	"Barbarian": "{S} learned to fight in a clan's wrestling rings.", "Bard": "{S} learned {p} songs in taverns and at weddings.",
}


## The adventurer's biography, written once (now, if it has none yet) and never changed afterwards.
static func text(a: Dictionary) -> String:
	ensure(a)
	return str(a.get(KEY, ""))


## Writes the biography if the adventurer has none (a new adventurer, or one from an older save). Never rewrites.
static func ensure(a: Dictionary) -> void:
	if a.is_empty() or not a.has("id") or str(a.get(KEY, "")) != "":
		return
	a[KEY] = compose(a)
	a["bio_v"] = VERSION


## The biography for this adventurer as it would be written now (pure: reads only stable facts and the world seed).
static func compose(a: Dictionary) -> String:
	var id := str(a.get("id", ""))
	var r := Living.rng_for("biography_" + id)
	var cls := str(a.get("cls", ""))
	var temper := str(a.get("trait", Adv.CLASS_TRAIT.get(cls, "steady")))
	var anchor: Dictionary = ANCHORS.get(id, {})
	var parts: Array[String] = []
	parts.append(str(anchor.get("up", _generic_up(a, r))))
	parts.append(_pick(r, LESSON.get(temper, LESSON["steady"])))
	parts.append(str(anchor.get("train", TRAIN_CLASS.get(cls, "{S} learned to fight wherever {s} could."))))
	parts.append(_pick(r, TEMPER.get(temper, TEMPER["steady"])))
	parts.append(str(anchor.get("why", "{S} took to the road for reasons {s} keeps to {o}self.")))
	parts.append(str(HOPE.get(cls, "When {s} first set out, {s} hoped to make something of {o}self.")))
	parts.append(_pick(r, HABIT.get(cls, ["{S} travels light."])))
	parts.append(_pick(r, CLOSE_LOCAL if bool(anchor.get("local", false)) else CLOSE))
	return _fill(" ".join(parts), a)


static func word_count(t: String) -> int:
	return t.split(" ", false).size()


static func _generic_up(a: Dictionary, r: RandomNumberGenerator) -> String:
	var race := str(DB.character(str(a.get("id", ""))).get("race", ""))
	return str(UP_RACE[race]) if UP_RACE.has(race) else str(_pick(r, UP_GENERIC))


static func _pick(r: RandomNumberGenerator, arr: Array) -> String:
	return str(arr[r.randi_range(0, arr.size() - 1)])


## Pronouns follow the adventurer's established look (characters.json `look.female`); unknown → they/them.
static func _fill(t: String, a: Dictionary) -> String:
	var look: Variant = DB.character(str(a.get("id", ""))).get("look", {})
	var fem: Variant = (look as Dictionary).get("female", null) if look is Dictionary else null
	var pr := ["they", "them", "their"] if fem == null else (["she", "her", "her"] if bool(fem) else ["he", "him", "his"])
	var name := str(a.get("name", "They"))
	var out := t.replace("{n}", name).replace("{f}", name.split(" ")[0])
	out = out.replace("{S}", pr[0].capitalize()).replace("{P}", pr[2].capitalize())
	out = out.replace("{s}", pr[0]).replace("{o}", pr[1]).replace("{p}", pr[2])
	return out
