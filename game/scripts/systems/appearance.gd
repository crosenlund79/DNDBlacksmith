## Appearance — the blacksmith's chosen look (hair, beard, colours, small extras).
## EN: The default Brannoc uses his own sheet and portrait untouched. Any other look is composited from
##     layers made by tools/art/make_player_looks.py (base + hair + beard + extras, each with a colour-region
##     mask) and recoloured with a gradient map from the default tones to the chosen swatch's tones.
##     Assets.get_tex("chars/player" | "portraits/player") asks custom_tex() first, so every place that
##     shows the player picks the look up without knowing about it.
##     State: Game.state["player"]["look"] = {hair, hair_col, beard, beard_col, skin, shirt, apron, extras[]}.
## DA: Smedens udseende. Standardudseendet bruger det oprindelige ark; andre udseender sammensættes af lag
##     og omfarves. Assets spørger custom_tex() først, så alle steder der viser smeden følger med.
class_name Appearance
extends RefCounted

const KEYS := ["hair", "hair_col", "beard", "beard_col", "skin", "shirt", "apron"]
const RESIDUAL := 0.2
const COLOUR_REGION := {"hair_col": "hair", "beard_col": "beard", "skin": "skin", "shirt": "shirt", "apron": "apron"}

static var _layers := {}     # sprite id -> {img, mask, idx}
static var _tex := {}        # "<kind>|<look key>" -> Texture2D
static var _tex_order: Array = []


static func data() -> Dictionary:
	var d: Variant = DB.extra("appearance")
	return d if d is Dictionary else {}


static func default_look() -> Dictionary:
	var d: Dictionary = data().get("default", {})
	return d.duplicate(true)


## The current look (normalised; created lazily for old saves).
static func look() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("player"):
		return default_look()
	var p: Dictionary = Game.state["player"]
	if not p.has("look") or not (p["look"] is Dictionary):
		p["look"] = default_look()
	return normalise(p["look"])


static func set_look(l: Dictionary) -> void:
	if Game.state.is_empty():
		return
	Game.state["player"]["look"] = normalise(l)
	Events.appearance_changed.emit()


static func reset() -> void:
	set_look(default_look())


## Valid ids only; missing keys fall back to the default.
static func normalise(l: Dictionary) -> Dictionary:
	var d := default_look()
	var out := {}
	for k: String in KEYS:
		var v := str(l.get(k, d.get(k, "")))
		out[k] = v if v in option_ids(k) else str(d.get(k, ""))
	var ex: Array = []
	var valid := option_ids("extras")
	for e in l.get("extras", d.get("extras", [])):
		if str(e) in valid and not ex.has(str(e)):
			ex.append(str(e))
	var ordered: Array = []
	for e: String in valid:
		if ex.has(e):
			ordered.append(e)
	out["extras"] = ordered
	return out


static func is_default(l: Dictionary) -> bool:
	return key(normalise(l)) == key(default_look())


static func key(l: Dictionary) -> String:
	var parts := []
	for k: String in KEYS:
		parts.append(str(l.get(k, "")))
	var ex: Array = (l.get("extras", []) as Array).duplicate()
	ex.sort()
	parts.append("+".join(ex))
	return "/".join(parts)


## Option rows for the panel: ids for an axis ("hair", "beard", "extras", or a colour key).
static func options(axis: String) -> Array:
	var d := data()
	if COLOUR_REGION.has(axis):
		return d.get("colours", {}).get(COLOUR_REGION[axis], [])
	return d.get(axis, [])


static func option_ids(axis: String) -> Array:
	var out := []
	for o in options(axis):
		out.append(str(o["id"]))
	return out


static func option_name(axis: String, id: String) -> String:
	for o in options(axis):
		if str(o["id"]) == id:
			return str(o.get("name", id))
	return id


## Step an option axis by +-1 (wraps), returning a new look.
static func cycle(l: Dictionary, axis: String, dir: int) -> Dictionary:
	var out := normalise(l)
	var ids := option_ids(axis)
	if ids.is_empty():
		return out
	var i: int = ids.find(str(out.get(axis, ids[0])))
	out[axis] = ids[(i + dir + ids.size()) % ids.size()]
	return out


static func toggle_extra(l: Dictionary, extra: String) -> Dictionary:
	var out := normalise(l)
	var ex: Array = out["extras"]
	if ex.has(extra):
		ex.erase(extra)
	else:
		ex.append(extra)
	return normalise(out)


# ------------------------------------------------------------------ textures
## Called by Assets.get_tex for "chars/player" and "portraits/player": null = use the normal art.
static func custom_tex(id: String, l: Variant = null) -> Texture2D:
	var lk: Dictionary = look() if l == null else normalise(l)
	if is_default(lk) or data().is_empty():
		return null
	var kind := "mini" if id.begins_with("chars/") else "portrait"
	var ck := kind + "|" + key(lk)
	if _tex.has(ck):
		return _tex[ck]
	var img := compose(kind, lk)
	if img == null:
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[ck] = t
	_tex_order.append(ck)
	while _tex_order.size() > 12:
		_tex.erase(_tex_order.pop_front())
	return t


## Texture for a look (default look → the shipped art). Used by the customise preview.
static func tex_for(kind: String, l: Dictionary) -> Texture2D:
	var id := ("chars/player" if kind == "mini" else "portraits/player")
	var t := custom_tex(id, l)
	return t if t != null else Assets.get_tex(id, Vector2i(768, 512) if kind == "mini" else Vector2i(256, 256))


static func layers_for(kind: String, l: Dictionary) -> Array:
	var avail: Array = data().get("layers", {}).get(kind, [])
	var want := ["base", "hair_" + str(l["hair"]), "beard_" + str(l["beard"])]
	for e: String in option_ids("extras"):
		if (l["extras"] as Array).has(e):
			want.append("x_" + e)
	return want.filter(func(x): return avail.has(x))


static func compose(kind: String, l: Dictionary) -> Image:
	var dir := "chars/" if kind == "mini" else "portraits/"
	var out: Image = null
	for lay: String in layers_for(kind, l):
		var L := _layer(dir + "player_l_" + lay)
		if L.is_empty():
			continue
		var own := ""
		if lay == "base":
			own = "apron"
		elif lay.begins_with("hair_"):
			own = "hair"
		elif lay.begins_with("beard_"):
			own = "beard"
		var ramps := [_ramp("skin", str(l["skin"])), _ramp("shirt", str(l["shirt"])),
			_ramp(own, str(l.get(own if own != "hair" and own != "beard" else own + "_col", ""))) if own != "" else null]
		var img: Image = L["img"]
		if ramps.any(func(r): return r != null):
			img = _recolour(L, ramps)
		if out == null:
			out = img.duplicate()
		else:
			out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return out


static func _layer(id: String) -> Dictionary:
	if _layers.has(id):
		return _layers[id]
	var img := _load_image(id)
	var mask := _load_image(id + "_mask")
	if img == null or mask == null:
		_layers[id] = {}
		return {}
	img.convert(Image.FORMAT_RGBA8)
	mask.convert(Image.FORMAT_RGB8)
	var md := mask.get_data()
	var idx := PackedInt32Array()
	var n := img.get_width() * img.get_height()
	for i in n:
		var m := i * 3
		if md[m] > 0 or md[m + 1] > 0 or md[m + 2] > 0:
			idx.append(i)
	_layers[id] = {"img": img, "mask": md, "idx": idx}
	return _layers[id]


static func _load_image(id: String) -> Image:
	var tex := Assets.get_tex(id) if Assets.has_tex(id) else null
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		var p := ProjectSettings.globalize_path("res://assets/sprites/" + Assets.template_id(id) + ".png")
		if FileAccess.file_exists(p):
			img = Image.load_from_file(p)
	if img == null or img.is_empty():
		return null
	return img


## Gradient-map anchors {in: [Color], out: [Color], lin: [float]} or null when the swatch is the default.
static func _ramp(region: String, swatch: String) -> Variant:
	var sw: Array = data().get("colours", {}).get(region, [])
	if sw.is_empty():
		return null
	var def_id := str(default_look().get(region if region in ["skin", "shirt", "apron"] else region + "_col", ""))
	if swatch == def_id or swatch == "":
		return null
	var src: Array = []
	var dst: Array = []
	for o in sw:
		if str(o["id"]) == def_id:
			src = o["tones"]
		if str(o["id"]) == swatch:
			dst = o["tones"]
	if src.is_empty() or dst.is_empty():
		return null
	var ink := Color(str(data().get("ink", "#20140c")))
	var white := Color("#fffaf0")
	# anchors from dark to light: ink, shadow, base, light, white
	var cin := [ink, Color(str(src[2])), Color(str(src[1])), Color(str(src[0])), white]
	var cout := [ink, Color(str(dst[2])), Color(str(dst[1])), Color(str(dst[0])), white]
	var lin := []
	for c: Color in cin:
		lin.append(_lum(c.r, c.g, c.b))
	return {"in": cin, "out": cout, "lin": lin}


static func _lum(r: float, g: float, b: float) -> float:
	return 0.3 * r + 0.59 * g + 0.11 * b


static func _recolour(L: Dictionary, ramps: Array) -> Image:
	var src: Image = L["img"]
	var data_b := src.get_data()
	var md: PackedByteArray = L["mask"]
	var idx: PackedInt32Array = L["idx"]
	for i in idx:
		var p := i * 4
		if data_b[p + 3] == 0:
			continue
		var r: float = data_b[p] / 255.0
		var g: float = data_b[p + 1] / 255.0
		var b: float = data_b[p + 2] / 255.0
		for ch in 3:
			var ramp: Variant = ramps[ch]
			if ramp == null:
				continue
			var w: float = md[i * 3 + ch] / 255.0
			if w <= 0.0:
				continue
			var lin: Array = ramp["lin"]
			var cin: Array = ramp["in"]
			var cout: Array = ramp["out"]
			var l := _lum(r, g, b)
			var ei: Color
			var eo: Color
			var lb := float(lin[2])
			if l <= lb:
				# shading below the base tone (hatching, soot, crescent shadows) darkens multiplicatively
				var f := l / maxf(lb, 0.001)
				ei = (cin[2] as Color) * f
				eo = (cout[2] as Color) * f
			else:
				# lights: base → light tone → paper white
				var k := 2
				while k < 3 and l > float(lin[k + 1]):
					k += 1
				var span := float(lin[k + 1]) - float(lin[k])
				var t := clampf((l - float(lin[k])) / span, 0.0, 1.0) if absf(span) > 0.0001 else 0.0
				ei = (cin[k] as Color).lerp(cin[k + 1], t)
				eo = (cout[k] as Color).lerp(cout[k + 1], t)
			# a gradient map plus a little of the pixel's own colour drift (soot, blush, grain)
			var nr := clampf(eo.r + RESIDUAL * (r - ei.r), 0.0, 1.0)
			var ng := clampf(eo.g + RESIDUAL * (g - ei.g), 0.0, 1.0)
			var nb := clampf(eo.b + RESIDUAL * (b - ei.b), 0.0, 1.0)
			r = lerpf(r, nr, w)
			g = lerpf(g, ng, w)
			b = lerpf(b, nb, w)
		data_b[p] = int(r * 255.0 + 0.5)
		data_b[p + 1] = int(g * 255.0 + 0.5)
		data_b[p + 2] = int(b * 255.0 + 0.5)
	return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8, data_b)
