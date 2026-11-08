## MultiHitGame — Enchanting: "Multi-Hit Sequence".
## EN: A faster cousin of the ring check. The needle waits a moment, then makes one quick sweep;
##     several target sections (five by default) lie around the ring. Press as the needle passes
##     each one. Every valid hit counts the same — precision inside a section does not matter —
##     and the result is decided by how many sections were struck. Presses outside a section are
##     misses and cost a little. All five is an exceptional (above 100%) weave.
## DA: Én hurtig omgang med flere målfelter. Hvert træf tæller ens; antallet af træf afgør resultatet.
class_name MultiHitGame
extends MinigameBase

const R := 170.0

var targets: Array = []     # [centre_deg, half_deg, state]  state: 0 open, 1 hit
var misses: Array = []      # angles of wrong presses
var angle := -90.0
var swept := 0.0
var wait_t := 0.0
var running := false
var n_targets := 5


func instructions() -> String:
	return "Wait for the needle, then press E, Space or click as it crosses each glowing section — every section counts"


func _start_round() -> void:
	n_targets = int(cfg.get("targets", 5))
	targets.clear()
	misses.clear()
	angle = -90.0
	swept = 0.0
	running = false
	wait_t = 0.75
	var half := maxf(9.0, float(args.get("zone", 40.0)) * 0.4)
	# spread the sections around the sweep with some jitter, never overlapping
	var span := 300.0 / n_targets
	half = minf(half, span * 0.38)
	for i in n_targets:
		var cdeg := -90.0 + 40.0 + span * i + randf_range(half + 2.0, span - half - 2.0)
		targets.append([cdeg, half, 0])
	Audio.play("sfx/check_start", -4.0)


func hits() -> int:
	var n := 0
	for tg in targets:
		if int(tg[2]) == 1:
			n += 1
	return n


func _tick(delta: float) -> void:
	if not running:
		wait_t -= delta
		if wait_t <= 0.0:
			running = true
			Audio.play("sfx/rune_hum", -8.0, 1.3)
		return
	var d := float(args.get("speed", 0.55)) * 1.45 * 360.0 * delta
	angle += d
	swept += d
	if swept >= 340.0 or hits() == targets.size():
		_resolve()


func _input(event: InputEvent) -> void:
	if finished or suspended or not started:
		return
	if confirm_pressed(event):
		get_viewport().set_input_as_handled()
		if not running:
			return
		for tg in targets:
			if int(tg[2]) == 0 and absf(angle - float(tg[0])) <= float(tg[1]):
				tg[2] = 1
				Audio.play("sfx/check_great", -6.0, 1.0 + 0.08 * hits())
				cue(true)
				if not practice:
					Events.station_worked.emit(str(args.get("station", "")), 100.0)
				return
		misses.append(angle)
		Audio.play("sfx/check_poor", -6.0)
		cue(false)


func _resolve() -> void:
	running = false
	var frac := float(hits()) / float(maxi(1, targets.size()))
	var q := 10.0 + 105.0 * pow(frac, 1.15) - 6.0 * misses.size()
	finish_round(q, "%d of %d struck" % [hits(), targets.size()])


func _draw() -> void:
	var c := draw_frame() + Vector2(0, 10)
	draw_arc(c, R, 0, TAU, 96, Color("#20140c"), 28.0)
	draw_arc(c, R, 0, TAU, 96, Color(0.55, 0.45, 0.75, 0.35), 18.0)
	for tg in targets:
		var a0 := deg_to_rad(float(tg[0]) - float(tg[1]))
		var a1 := deg_to_rad(float(tg[0]) + float(tg[1]))
		var hit := int(tg[2]) == 1
		var col := Color("#ffd27a") if hit else Color(0.75, 0.6, 1.0, 0.75 + 0.2 * sin(t * 6.0))
		draw_arc(c, R, a0, a1, 12, col, 24.0)
		if hit:
			var mid := deg_to_rad(float(tg[0]))
			draw_circle(c + Vector2(cos(mid), sin(mid)) * (R + 36), 9.0, GOLD)
	for m in misses:
		var ma := deg_to_rad(float(m))
		var mp := c + Vector2(cos(ma), sin(ma)) * (R + 36)
		draw_line(mp + Vector2(-8, -8), mp + Vector2(8, 8), Color("#ff6a50"), 3.0)
		draw_line(mp + Vector2(-8, 8), mp + Vector2(8, -8), Color("#ff6a50"), 3.0)
	var na := deg_to_rad(angle)
	var tip := c + Vector2(cos(na), sin(na)) * (R + 14)
	draw_line(c, tip, INK, 9.0)
	draw_line(c, tip, Color("#d8c8ff") if running else Color(PAPER, 0.5), 4.0)
	draw_circle(tip, 9.0, Color("#d8c8ff"))
	draw_circle(c, 16.0, INK)
	draw_circle(c, 9.0, Color("#8a6ac8"))
	var status := "Ready…" if not running and not finished else "%d / %d" % [hits(), targets.size()]
	draw_string(Assets.font("title"), Vector2(c.x - 200, c.y + 70), status, HORIZONTAL_ALIGNMENT_CENTER, 400, 36, PAPER)
	if flash > 0.0:
		draw_arc(c, R, 0, TAU, 96, Color(0.8, 0.6, 1.0, flash * 0.5), 40.0)
	draw_feedback(c + Vector2(0, -20))
