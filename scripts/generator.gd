class_name Generator
extends RefCounted
## SPOT THE LIE — seeded scene-graph generator with salience floor (C3).
## Faithful port of the W1 feeler generator (master index.html), which was
## harness-verified over 2000 seeds. Mutation classes: add / remove / flip /
## swap-position / resize — recolor is NOT a class at all (accessibility pin
## by construction). RESIZE capped ~1 per board (pulse caveat t_9c8d114f:
## resizes read as identical to the eye; sweep-spice at low frequency only).

const FLOOR_PX := 26.0          # salience floor (edge-travel px)
const DENSE_RADIUS := 88.0      # "local decoy density" neighbourhood
const DENSE_BOOST := 1.35       # floor multiplier in dense neighbourhoods
const MIN_CLEAR := 66.0         # min px between diff epicenters (anti-cluster)
const SHAPES_N := 14
const NUM_DIFFS := 5
const MAX_RESIZES := 1          # pulse caveat: resize is rare sweep-spice

const HALF_W := 550.0
const H := 620.0
const MARGIN := 22.0

# flat-noir scene palette (muted, colorblind-safe greys/blues — structural
# classes carry every diff so recolor would be redundant anyway)
const PALETTE: Array[Color] = [
	Color("9aa3b5"), Color("778093"), Color("b8bfc9"),
	Color("6d7689"), Color("8a93a6"), Color("a08f7d"),
]

var rng := RandomNumberGenerator.new()


static func xmur3(str: String) -> int:
	var h: int = 1779033703 ^ str.length()
	for i in str.length():
		h = _imul(h ^ str.unicode_at(i), 3432918353)
		h = ((h << 13) | ((h >> 19) & 0x1FFF)) & 0xFFFFFFFF
	h = _imul(h ^ ((h >> 16) & 0xFFFF), 2246822507)
	h = _imul(h ^ ((h >> 13) & 0x1FFF), 3266489909)
	return (h ^ ((h >> 16) & 0xFFFF)) & 0xFFFFFFFF


static func _imul(a: int, b: int) -> int:
	# JS Math.imul equivalent: 32-bit integer multiply (wraps like JS)
	var prod: int = a * b
	var masked: int = prod & 0xFFFFFFFF
	return masked if masked < 0x80000000 else masked - 0x100000000


func make_rng(seed_str: String) -> RandomNumberGenerator:
	rng = RandomNumberGenerator.new()
	rng.seed = xmur3(seed_str)
	return rng


static func dist(ax: float, ay: float, bx: float, by: float) -> float:
	return Vector2(ax - bx, ay - by).length()


static func bbox(s: Dictionary) -> Array:
	match s.kind:
		"circle":
			return [s.x - s.r, s.y - s.r, s.x + s.r, s.y + s.r]
		_:
			return [s.x - s.w / 2.0, s.y - s.h / 2.0, s.x + s.w / 2.0, s.y + s.h / 2.0]


static func b_gap(a: Dictionary, b: Dictionary) -> float:
	var A: Array = bbox(a)
	var B: Array = bbox(b)
	return max(max(A[0] - B[2], B[0] - A[2]), max(A[1] - B[3], B[1] - A[3]))


static func max_dim(s: Dictionary) -> float:
	return s.r * 2.0 if s.kind == "circle" else max(s.w, s.h)


func gen_scene(r: RandomNumberGenerator) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	var guard := 0
	while shapes.size() < SHAPES_N and guard < 900:
		guard += 1
		var kind_roll := r.randf()
		var cx := MARGIN + r.randf() * (HALF_W - 2 * MARGIN)
		var cy := MARGIN + r.randf() * (H - 2 * MARGIN)
		var s := {}
		if kind_roll < 0.4:
			s = {"kind": "rect", "x": cx, "y": cy, "w": 36 + r.randf() * 48, "h": 30 + r.randf() * 40}
		elif kind_roll < 0.75:
			s = {"kind": "circle", "x": cx, "y": cy, "r": 16 + r.randf() * 18}
		else:
			s = {"kind": "tri", "x": cx, "y": cy, "w": 46 + r.randf() * 40, "h": 38 + r.randf() * 34,
				"dir": 1 if r.randf() < 0.5 else -1}
		s["fill"] = PALETTE[shapes.size() % PALETTE.size()]
		s["id"] = shapes.size()
		var ok := true
		for o in shapes:
			if b_gap(s, o) <= 10.0:
				ok = false
				break
		if ok:
			shapes.append(s)
	return shapes


func propose(cls: String, r: RandomNumberGenerator, scene: Array, epicenters: Array) -> Dictionary:
	var live: Array = []
	for s in scene:
		if not s.get("dead", false):
			live.append(s)

	var clear_of_epis := func(s: Dictionary) -> bool:
		for e in epicenters:
			if dist(s.x, s.y, e.x, e.y) < MIN_CLEAR:
				return false
		return true

	if cls == "add":
		var px := MARGIN + 40 + r.randf() * (HALF_W - 2 * MARGIN - 80)
		var py := MARGIN + 40 + r.randf() * (H - 2 * MARGIN - 80)
		var kind_roll := r.randf()
		var s := {}
		if kind_roll < 0.4:
			s = {"kind": "rect", "x": px, "y": py, "w": 36 + r.randf() * 48, "h": 30 + r.randf() * 40}
		elif kind_roll < 0.75:
			s = {"kind": "circle", "x": px, "y": py, "r": 16 + r.randf() * 18}
		else:
			s = {"kind": "tri", "x": px, "y": py, "w": 46 + r.randf() * 40, "h": 38 + r.randf() * 34,
				"dir": 1 if r.randf() < 0.5 else -1}
		s["fill"] = PALETTE[r.randi_range(0, PALETTE.size() - 1)]
		for o in live:
			if b_gap(s, o) <= 12.0:
				return {}
		if not clear_of_epis.call(s):
			return {}
		return {"cls": cls, "target": s, "epicenters": [{"x": s.x, "y": s.y}],
			"travel": 2.0 * max_dim(s)}

	if cls == "remove":
		var cand: Array = []
		for s in live:
			if clear_of_epis.call(s):
				cand.append(s)
		if cand.is_empty():
			return {}
		var t: Dictionary = cand[r.randi_range(0, cand.size() - 1)]
		return {"cls": cls, "target": t, "epicenters": [{"x": t.x, "y": t.y}],
			"travel": 2.0 * max_dim(t)}

	if cls == "flip":  # asymmetric shapes only (tri); rect/circle flips are no-ops
		var cand: Array = []
		for s in live:
			if s.kind == "tri" and clear_of_epis.call(s):
				cand.append(s)
		if cand.is_empty():
			return {}
		var t: Dictionary = cand[r.randi_range(0, cand.size() - 1)]
		return {"cls": cls, "target": t, "epicenters": [{"x": t.x, "y": t.y}],
			"travel": t.w * 0.6}

	if cls == "swap-position":
		var pairs: Array = []
		for i in live.size():
			for j in range(i + 1, live.size()):
				var a: Dictionary = live[i]
				var b: Dictionary = live[j]
				var d := dist(a.x, a.y, b.x, b.y)
				if d >= FLOOR_PX + 18 and d <= HALF_W * 0.62:
					pairs.append([a, b, d])
		var ok_pairs: Array = []
		for p in pairs:
			var a: Dictionary = p[0]
			var b: Dictionary = p[1]
			if clear_of_epis.call(a) and clear_of_epis.call(b) and dist(a.x, a.y, b.x, b.y) >= MIN_CLEAR:
				ok_pairs.append(p)
		if ok_pairs.is_empty():
			return {}
		var pick: Array = ok_pairs[r.randi_range(0, ok_pairs.size() - 1)]
		return {"cls": cls, "target": pick[0], "target2": pick[1],
			"epicenters": [{"x": pick[0].x, "y": pick[0].y}, {"x": pick[1].x, "y": pick[1].y}],
			"travel": pick[2]}

	if cls == "resize":
		var cand: Array = []
		for s in live:
			if clear_of_epis.call(s):
				cand.append(s)
		if cand.is_empty():
			return {}
		var t: Dictionary = cand[r.randi_range(0, cand.size() - 1)]
		var grow := r.randf() < 0.55
		var f := (1.32 + r.randf() * 0.18) if grow else 1.0 / (1.32 + r.randf() * 0.18)
		var nw: float = t.r * 2 * f if t.kind == "circle" else t.w * f
		var nh: float = t.r * 2 * f if t.kind == "circle" else t.h * f
		var nb := [t.x - nw / 2.0, t.y - nh / 2.0, t.x + nw / 2.0, t.y + nh / 2.0]
		if nb[0] < MARGIN or nb[1] < MARGIN or nb[2] > HALF_W - MARGIN or nb[3] > H - MARGIN:
			return {}
		return {"cls": cls, "target": t, "factor": f, "grow": grow,
			"epicenters": [{"x": t.x, "y": t.y}],
			"travel": abs(max_dim(t) * f - max_dim(t)) * 1.6}

	return {}


## Returns {scene, muts, log} — muts = answer key. {} on exhausted retries.
func generate(seed_str: String) -> Dictionary:
	var r := make_rng(seed_str)
	for attempt in 10:
		var scene := gen_scene(r)
		var muts: Array[Dictionary] = []
		var epicenters: Array = []
		var log_rows: Array = []
		var ok := true
		var resizes := 0
		for slot in NUM_DIFFS:
			if not ok:
				break
			var placed := {}
			for t in 60:
				var classes := ["add", "remove", "flip", "swap-position", "resize"]
				var cls: String = classes[r.randi_range(0, 4)]
				# pulse caveat: cap RESIZE frequency (~1 per board)
				if cls == "resize" and resizes >= MAX_RESIZES:
					continue
				var p := propose(cls, r, scene, epicenters)
				if p.is_empty():
					continue
				# salience floor relative to LOCAL DECOY DENSITY (C3)
				var e: Dictionary = p.epicenters[0]
				var neighbours := 0
				for s in scene:
					if not s.get("dead", false) and s != p.get("target") and s != p.get("target2") \
							and dist(s.x, s.y, e.x, e.y) < DENSE_RADIUS:
						neighbours += 1
				var eff_floor := FLOOR_PX * (DENSE_BOOST if neighbours > 3 else 1.0)
				if p.travel < eff_floor:
					log_rows.append({"slot": slot, "cls": cls, "rejected": "below-floor",
						"travel": snappedf(p.travel, 0.1), "eff_floor": snappedf(eff_floor, 0.1)})
					continue
				placed = p
				placed["eff_floor"] = snappedf(eff_floor, 0.1)
				placed["neighbours"] = neighbours
				placed["slot"] = slot
				log_rows.append({"slot": slot, "cls": cls, "accepted": true,
					"travel": snappedf(p.travel, 0.1), "eff_floor": snappedf(eff_floor, 0.1)})
				break
			if placed.is_empty():
				ok = false
			else:
				if placed.cls == "resize":
					resizes += 1
				muts.append(placed)
				epicenters.append_array(placed.epicenters)
		if ok and muts.size() == NUM_DIFFS:
			print("[STL] seed=%s N=%d diffs (attempt %d)" % [seed_str, muts.size(), attempt + 1])
			return {"scene": scene, "muts": muts, "log": log_rows}
	push_error("[STL] generator exhausted retries for seed " + seed_str)
	return {}


## Daily seed derivation: everyone worldwide gets the same boards per UTC day.
static func daily_seed(day_offset: int = 0) -> String:
	var d := Time.get_unix_time_from_system() + day_offset * 86400.0
	var days := int(floor(d / 86400.0))
	var ymd := Time.get_datetime_dict_from_unix_time(days * 86400 + 12 * 3600)
	var ds := "%04d-%02d-%02d" % [ymd.year, ymd.month, ymd.day]
	return "DAILY-" + ds


static func random_seed_string() -> String:
	const ABC := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
	var r := RandomNumberGenerator.new()
	r.randomize()
	var s := ""
	for i in 8:
		s += ABC[r.randi_range(0, ABC.length() - 1)]
	return s.substr(0, 4) + "-" + s.substr(4)
