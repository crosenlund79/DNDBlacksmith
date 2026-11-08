## Events — global signal bus.
## EN: Decouples systems: gameplay code emits, UI and world listen.
## DA: Afkobler systemerne: spillogik udsender signaler, UI og verden lytter.
extends Node

signal toast(text: String, kind: String)            # kind: info|good|bad|legendary
signal gold_changed(total: int)
signal inventory_changed
signal time_changed(day: int, minute: int)
signal hour_passed(day: int, hour: int)
signal day_started(day: int)
signal skill_level_up(who: String, skill: String, level: int)
signal crafting_changed
signal station_worked(station_id: String, quality: float)   # one resolved skill check at a station
signal customers_changed
signal chronicle_added(entry: Dictionary)
signal expeditions_changed
signal expedition_event(exp_id: String, entry: Dictionary)   # a customer set out, sat down, was served or left
signal item_crafted(item: Dictionary)
signal legendary_found(item: Dictionary)
signal hirelings_changed
signal adventurers_changed
signal adventurer_departed(id: String, exit_id: String)
signal adventurer_returned(id: String, exit_id: String)
signal hireling_departed(id: String, exit_id: String)
signal hireling_returned(id: String, exit_id: String)
signal orders_changed
signal relationship_event(npc: String, text: String)
signal world_flag_changed(flag: String)
signal open_panel(panel_id: String, args: Dictionary)
signal close_panels
signal request_dialogue(npc_id: String)
signal request_fade(text: String, minutes: int)
signal game_loaded
signal objective_changed(text: String)
signal fatigue_changed(value: float)              # Vitality: 0 fresh .. 100 spent
signal appearance_changed                         # the player changed hair/beard/colours (Appearance)

signal apprentices_changed                       # workshop apprentices: staff, tasks, stations or notices changed
signal lore_recorded(event: Dictionary)          # a world event was recorded (Lore) — places, items, adventurers
