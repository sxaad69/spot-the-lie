class_name BoardRenderer
extends Node2D
## Single-scene renderer: draws one generated scene twice (left = ORIGINAL,
## right = THE LIE) with mutations applied to the right half. Also draws
## hit rings, found-diff markers, and the reveal-one-diff hint pulse.

signal rendered

const HALF_W := 550.0
const H := 620.0
const GAP := 60.0
const MARGIN := 22.0
const OX_R := HALF_W + GAP  # right half origin x

## Base paintings: AI-generated flat-noir scenes (assets/base/*.webp).
## Board -> painting is seeded & deterministic (same seed = same painting).
static var paintings: Array[Texture2D] = []


static func load_paintings() -> void:
	if not paintings.is_empty():
		return
	var names := [
		"room-study", "room-kitchen", "room-attic", "room-bedroom",
		"market-street", "market-fish", "market-spice",
		"street-corner", "street-alley", "street-station",
		"space-station", "space-lab",
	]
	for n in names:
		var path := "res://assets/base/%s.webp" % n
		if ResourceLoader.exists(path):
			paintings.append(load(path))
	print("[STL] loaded %d base paintings" % paintings.size())


var scene: Array = []
var muts: Array = []
var rings: Array = []          # {x, y, t0} in canonical coords
var hints: Array = []          # {x, y, t0} reveal-one-diff pulses
var mirror := false            # mirror-pairs mode: right half is mirrored
var bg_texture: Texture2D = null
var elapsed_provider: Callable  # returns seconds since board start (for ring anim)


func setup(p_scene: Array, p_muts: Array, p_mirror: bool, seed_str: String = "") -> void:
	scene = p_scene
	muts = p_muts
	mirror = p_mirror
	rings = []
	hints = []
	load_paintings()
	if not paintings.is_empty():
		var idx := 0
		if seed_str != "":
			idx = abs(int(Generator.xmur3(seed_str))) % paintings.size()
		bg_texture = paintings[idx]
	else:
		bg_texture = null
	queue_redraw()


func add_ring(canon: Vector2) -> void:
	rings.append({"x": canon.x, "y": canon.y, "t0": _now()})
	queue_redraw()


func add_hint(canon: Vector2) -> void:
	hints.append({"x": canon.x, "y": canon.y, "t0": _now()})
	queue_redraw()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _draw() -> void:
	# halves: painting background (or flat panel fallback) + divider
	for half in [false, true]:
		var ox := OX_R if half else 0.0
		var rect := Rect2(ox + 8, 10, HALF_W - 16, H - 20)
		if bg_texture:
			# crop-to-fill: paintings are 576x864 (2:3), half panel is ~542x600
			var tex_aspect: float = bg_texture.get_width() / float(bg_texture.get_height())
			var rect_aspect := rect.size.x / rect.size.y
			var src := Rect2()
			if tex_aspect > rect_aspect:
				var sh := 1.0
				var sw := rect_aspect / tex_aspect
				src = Rect2((1.0 - sw) / 2.0, (1.0 - sh) / 2.0, sw, sh)
			else:
				var sw := 1.0
				var sh := tex_aspect / rect_aspect
				src = Rect2((1.0 - sw) / 2.0, (1.0 - sh) / 2.0, sw, sh)
			draw_texture_rect_region(bg_texture, rect, src)
		else:
			draw_rect(rect, Color("20242f"))
		if half and mirror:
			# mirror-pairs: flip the right half horizontally around its center
			pass  # handled by drawing shapes mirrored below; painting stays identical
	draw_rect(Rect2(HALF_W + GAP / 2 - 2, 0, 4, H), Color("2c3342"))

	var fnt := ThemeDB.fallback_font
	draw_string(fnt, Vector2(22, 34), "ORIGINAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("39404f"))
	var right_label := "THE LIE (MIRRORED)" if mirror else "THE LIE"
	draw_string(fnt, Vector2(OX_R + 22, 34), right_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("39404f"))

	for half in [false, true]:
		var ox := OX_R if half else 0.0
		for s in scene:
			if half and mirror and s.kind != "circle":
				pass  # shapes are placed symmetrically enough; mirror flips tri direction
			var sd: Dictionary = s.duplicate()
			if half:
				for m in muts:
					if m.cls == "swap-position":
						if m.target.id == s.id:
							sd.x = m.target2.x
							sd.y = m.target2.y
						elif m.target2.id == s.id:
							sd.x = m.target.x
							sd.y = m.target.y
				if mirror and s.kind == "tri":
					sd.dir = -int(s.dir)
			_draw_shape(sd, ox, half)
		if half:
			for m in muts:
				if m.cls == "add":
					var t: Dictionary = m.target.duplicate()
					t["id"] = -1
					_draw_shape(t, ox, true)

	var now := _now()
	# found rings (both halves)
	for r in rings:
		var age: float = (now - r.t0) / 0.65
		if age > 1.0:
			continue
		for ox in [0.0, OX_R]:
			var pos := Vector2(ox + r.x, r.y)
			draw_arc(pos, 10 + age * 34, 0, TAU, 40,
				Color(0.34, 0.79, 0.54, 1.0 - age), 3.5)
	# hint pulses (reveal-one-diff)
	for h in hints:
		var age: float = (now - h.t0) / 2.5
		if age > 1.0:
			continue
		for ox in [0.0, OX_R]:
			var pos := Vector2(ox + h.x, h.y)
			var col := Color(1.0, 0.82, 0.25, 0.9 * (1.0 - age))
			draw_arc(pos, 26 + age * 30, 0, TAU, 48, col, 4.0)


func _draw_shape(s: Dictionary, ox: float, mutated: bool) -> void:
	var sh: Dictionary = s.duplicate()
	if mutated:
		for m in muts:
			if m.cls == "remove" and m.target.id == s.id:
				return  # absent on the lie side
			if m.cls == "resize" and m.target.id == s.id:
				if sh.kind == "circle":
					sh.r *= m.factor
				else:
					sh.w *= m.factor
					sh.h *= m.factor
			if m.cls == "flip" and m.target.id == s.id:
				sh.dir = -int(sh.dir)
	var fill: Color = sh.fill
	var center := Vector2(ox + sh.x, sh.y)
	match sh.kind:
		"circle":
			draw_circle(center, sh.r, fill)
			draw_arc(center, sh.r, 0, TAU, 48, Color("11141b"), 1.5)
		"tri":
			var bx: float = sh.w / 2.0 * int(sh.dir)
			var pts := PackedVector2Array([
				center + Vector2(-bx, -sh.h / 2.0),
				center + Vector2(-bx, sh.h / 2.0),
				center + Vector2(bx, 0),
			])
			draw_colored_polygon(pts, fill)
			_draw_poly_outline(pts)
		_:
			var rect := Rect2(center.x - sh.w / 2.0, center.y - sh.h / 2.0, sh.w, sh.h)
			draw_rect(rect, fill)
			draw_rect(rect, Color("11141b"), false, 1.5)


func _draw_poly_outline(pts: PackedVector2Array) -> void:
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color("11141b"), 1.5)


## Canonical coords from a click at local pos.
func to_canonical(local: Vector2) -> Vector2:
	if local.x < OX_R:
		return Vector2(local.x, local.y)
	return Vector2(local.x - OX_R, local.y)


## Hit radius for a mutation (generous minimum so taps feel fair).
static func hit_radius(m: Dictionary) -> float:
	var r: float = maxf(34.0, Generator.max_dim(m.target) * 0.55)
	if m.has("target2"):
		r = maxf(r, Generator.max_dim(m.target2) * 0.55)
	return r


func _process(_delta: float) -> void:
	# rings/hints animate on their own clocks — redraw while any is alive
	queue_redraw()
