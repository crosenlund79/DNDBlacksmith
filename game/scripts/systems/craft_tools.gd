## CraftTools — molds and patterns (R4; canonical §5, D11; PROD-020; decision 9, the audit's default).
## EN: Craftable, reusable physical aids for the work they suit, never universally required and without wear (§5: "do
##     not create a tool-replacement chore"). The minimal set of decision 9 — casting molds for the cast Designs and a
##     pattern for one forged series:
##       mold_ring        the Silver Band and the Garnet Ring (melted silver poured true);
##       mold_amulet      the Sapphire Amulet;
##       pattern_muster   the muster's iron helm and round shield, forged to one pattern.
##     A tool counts while it is in the workshop's stores. With it, those Designs are steadier (+QUALITY craftsmanship
##     for whoever makes them) and a bulk line of them at the Project Bench takes HOURS_FACTOR of the hours per piece.
##     Nothing is ever locked behind a tool, and tools are made from the Designs in data/recipes.json at the usual
##     stations. They never wear out.
## DA: Støbeforme og mønstre: genbrugelige hjælpemidler uden slid, aldrig et krav.
class_name CraftTools
extends RefCounted

const TOOLS := {
	"mold_ring": ["silver_band", "garnet_ring"],
	"mold_amulet": ["sapphire_amulet"],
	"pattern_muster": ["iron_helm", "round_shield"],
}
const QUALITY := 3.0
const HOURS_FACTOR := 0.75


## The tool that serves a Design ("" when none does).
static func tool_for(rid: String) -> String:
	for t in TOOLS:
		if (TOOLS[t] as Array).has(rid):
			return str(t)
	return ""


## Is the tool for this Design in the workshop's stores?
static func has_for(rid: String) -> bool:
	var t := tool_for(rid)
	if t == "" or Game.state.is_empty():
		return false
	for it in Game.inventory():
		if str(it.get("def", "")) == t:
			return true
	return false


static func quality_bonus(rid: String) -> float:
	return QUALITY if has_for(rid) else 0.0


static func hours_factor(rid: String) -> float:
	return HOURS_FACTOR if has_for(rid) else 1.0


## "Cast in the ring mold" — for the views ("" when no tool helps or it is not in the stores).
static func note(rid: String) -> String:
	var t := tool_for(rid)
	if t == "":
		return ""
	var nm := str(DB.item(t).get("name", t))
	return ("Worked with the %s (steadier, and quicker at the bench)." % nm) if has_for(rid) else ("A %s would help (make it once; it never wears out)." % nm)
