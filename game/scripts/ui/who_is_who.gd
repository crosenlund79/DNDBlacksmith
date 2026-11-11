## WhoIsWho — telling apart the people the smith deals with (Living Workshop #54–55).
## EN: Four kinds, each with one word, one colour and one place, used the same way on the counter, the Commissions
##     book, the adventurers' roster and in conversation:
##       waiting      — sitting at your counter now (they give up after a few hours): serve them at the counter;
##       commission   — an order you accepted, open in the Commissions book;
##       opportunity  — an adventurer in town who needs something forged and has not ordered it yet: they will place
##                      a commission if you ask ("Ask what they need forged" in conversation — usually at the Tipsy
##                      Wyvern). Exactly the condition under which Talk offers that option;
##       visiting     — any other adventurer in town (not a customer right now).
##     Read-only: derived from Shop and the adventurers' state, nothing stored.
## DA: Skelner mellem ventende kunder, bestillinger, bestillingsmuligheder og besøgende eventyrere.
class_name WhoIsWho
extends RefCounted

const KINDS := {
	"waiting": {"word": "Waiting at your counter", "short": "At counter", "col": Color("#a4441e")},
	"commission": {"word": "Open commission", "short": "Commission", "col": Color("#24409a")},
	"opportunity": {"word": "Commission opportunity — ask them", "short": "Ask them", "col": Color("#4c7a34")},
	"visiting": {"word": "Visiting adventurer", "short": "In town", "col": Color("#6a5a44")},
}


## Does this adventurer need something forged that they have not ordered yet — the "Ask what they need forged" option?
static func is_opportunity(a: Dictionary) -> bool:
	if a.is_empty() or not (str(a.get("status", "")) in ["in_town", "injured"]) or str(a.get("needs", "")) == "":
		return false
	var id := str(a.get("id", ""))
	if Shop.refuses(id) or not Shop.customer(id).is_empty():
		return false
	if Shop.open_orders().any(func(o): return str(o["npc"]) == id):
		return false
	return not Adv.commission_ask(a).has("why")   # LW #56: they would really commission it if asked


## Adventurers in town with a commission opportunity, by name.
static func opportunities() -> Array:
	var out := []
	for a in Adv.all().values():
		if is_opportunity(a):
			out.append(a)
	out.sort_custom(func(x, y): return str(x["name"]) < str(y["name"]))
	return out


## "waiting" | "commission" | "opportunity" | "visiting" | "" (not in town and no business with the forge).
static func kind_of(npc: String) -> String:
	var cu := Shop.customer(npc)
	if not cu.is_empty() and cu.get("present", true):
		return "waiting"
	if Shop.open_orders().any(func(o): return str(o["npc"]) == npc):
		return "commission"
	var a := Adv.get_a(npc)
	if is_opportunity(a):
		return "opportunity"
	if not a.is_empty() and str(a.get("status", "")) in ["in_town", "injured"]:
		return "visiting"
	return ""


## A chip for a kind ("" → an empty control).
static func chip(kind: String, short := false) -> Control:
	if not KINDS.has(kind):
		return Control.new()
	var k: Dictionary = KINDS[kind]
	var c := UIKit.chip(str(k["short" if short else "word"]), k["col"])
	c.name = "Kind_" + kind
	return c


## What the adventurer needs, in words ("a helmet").
static func need_text(a: Dictionary) -> String:
	return Shop.slot_phrase(str(a.get("needs", "")))


## Where they are, in words, for "go and ask them".
static func where_text(a: Dictionary) -> String:
	if str(a.get("status", "")) == "injured":
		return "recovering in town"
	if str(a.get("activity", "")) == "at_inn":
		return "at the Tipsy Wyvern"
	return "in town"
