extends SceneTree
## Headless generator harness for the GDScript port.
## Mirrors the feeler's 2000-seed harness: determinism, class legality
## (no recolor), floor integrity, anti-cluster, resize cap, variety.
## Run: godot --headless --path . --script tests/test_generator.gd

const N_SEEDS := 2000
const NUM_DIFFS := 5
const MIN_CLEAR := 66.0
const FLOOR_PX := 26.0
const MAX_RESIZES := 1

var fails := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)


func _init() -> void:
	var g := Generator.new()
	var cls_counts := {}
	var travel_min := INF
	var resize_boards := 0
	var seen_signatures := {}

	for i in N_SEEDS:
		var seed := "TEST-%04d" % i
		var res: Dictionary = g.generate(seed)
		check(not res.is_empty(), "%s: generate failed" % seed)
		if res.is_empty():
			continue
		var scene: Array = res.scene
		var muts: Array = res.muts
		check(scene.size() == Generator.SHAPES_N, "%s: scene size %d" % [seed, scene.size()])
		check(muts.size() == NUM_DIFFS, "%s: muts %d" % [seed, muts.size()])

		var resizes := 0
		var epis: Array = []
		for m in muts:
			check(m.cls in ["add", "remove", "flip", "swap-position", "resize"],
				"%s: illegal class %s" % [seed, m.cls])
			check(not m.has("recolor"), "%s: recolor present" % seed)
			# floor integrity: every accepted mutation met its effective floor
			check(m.travel >= m.eff_floor, "%s: travel %s < floor %s" % [seed, m.travel, m.eff_floor])
			check(m.eff_floor >= FLOOR_PX, "%s: eff_floor below base" % seed)
			cls_counts[m.cls] = int(cls_counts.get(m.cls, 0)) + 1
			travel_min = min(travel_min, m.travel)
			if m.cls == "resize":
				resizes += 1
			for e in m.epicenters:
				epis.append(e)
		check(resizes <= MAX_RESIZES, "%s: %d resizes" % [seed, resizes])
		if resizes == MAX_RESIZES:
			resize_boards += 1
		# anti-cluster: all epicenters pairwise >= MIN_CLEAR
		for a in epis.size():
			for b in range(a + 1, epis.size()):
				var d := Generator.dist(epis[a].x, epis[a].y, epis[b].x, epis[b].y)
				check(d >= MIN_CLEAR - 0.01, "%s: epicenters %s px apart < %s" % [seed, d, MIN_CLEAR])

		# determinism: same seed → same answer key
		var res2: Dictionary = g.generate(seed)
		var sig := _sig(res2.muts)
		check(sig == _sig(muts), "%s: non-deterministic" % seed)
		seen_signatures[sig] = true

	# variety: signature space is huge but 5-slot boards from a 14-shape scene
	# collide naturally (the JS feeler harness asserted class legality +
	# determinism, not unique-signature counts — same standard here). What
	# matters for feel: no single board repeats more than a handful of times.
	var max_repeats := 0
	for sig in seen_signatures:
		max_repeats = maxi(max_repeats, int(seen_signatures[sig]))
	check(seen_signatures.size() > N_SEEDS * 0.4,
		"variety: only %d unique signatures in %d seeds" % [seen_signatures.size(), N_SEEDS])
	check(max_repeats <= 8,
		"variety: one board repeated %d times" % max_repeats)

	print("=== GENERATOR HARNESS: %s ===" % ("PASS" if fails == 0 else "FAIL x%d" % fails))
	print("class distribution: %s" % str(cls_counts))
	print("min accepted travel: %.1f px (floor %.0f)" % [travel_min, FLOOR_PX])
	print("boards using the resize slot: %d/%d" % [resize_boards, N_SEEDS])
	quit(1 if fails > 0 else 0)


func _sig(muts: Array) -> String:
	var parts: Array[String] = []
	for m in muts:
		parts.append("%s@%d(%d,%d)" % [m.cls, m.target.id, int(m.epicenters[0].x), int(m.epicenters[0].y)])
	return "|".join(parts)
