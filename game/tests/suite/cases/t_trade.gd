## Harbour trading and import orders: ships arrive, sell, and special imports are delivered through trade.
extends SuiteCase

const SMOKE := ["test_import_lifecycle"]


func test_import_lifecycle() -> void:
	if not has_system("trade"):
		skip("Trade not in this build")
		return
	Game.state["gold"] = 8000
	Trade.mark_seen("ore_orichalcum")
	var info := Trade.import_info("ore_orichalcum")
	check(not info.is_empty(), "a known exotic ore can be imported")
	var g0 := Game.gold()
	eq(Trade.place_import("ore_orichalcum", 2), "", "an import is ordered with a deposit")
	check(Game.gold() < g0, "the deposit is paid")
	var c0 := Game.count("ore_orichalcum")
	var guard := 0
	while Trade.deliveries().is_empty() and guard < 20:
		days(1)
		guard += 1
	check(not Trade.deliveries().is_empty(), "the delivery arrives after %d days" % guard)
	if not Trade.deliveries().is_empty():
		eq(Trade.collect_delivery(str(Trade.deliveries()[0]["id"])), "", "balance paid and goods collected")
	eq(Game.count("ore_orichalcum"), c0 + 2, "the goods are in the stores")


func test_ships_visit() -> void:
	if not has_system("trade"):
		skip("Trade not in this build")
		return
	var guard := 0
	while Trade.current_ship().is_empty() and guard < 10:
		days(1)
		guard += 1
	check(not Trade.current_ship().is_empty(), "a merchant ship docks within %d days" % guard)
	check(save_load("suite_trade") and (not Trade.current_ship().is_empty() or not Trade.next_arrival().is_empty()), "ship schedule persists")
