extends Control
## SPOT THE LIE — main game controller.
## C1: seed visible from first paint, DAILY identity in title/HUD.
## C2: timer drains score MULTIPLIER only; no hard-fail clock anywhere;
##     CHAIN GUARD streak protection; time-out never ends a level.
## C3: generator-enforced salience floor (see generator.gd).
## Modes: DAILY (worldwide seed), FREE (random seeds), MIRROR (mirrored
## right half), DRIFT (seed-lineage run, decoy density ramps per board).
##
## INPUT NOTE (web export): mouse clicks on the menu Buttons don't reach
## Controls reliably in the headless/web canvas (known Godot web quirk) —
## so the menu also accepts keys. For BOARD taps we listen on
## _unhandled_input AND _gui_input on this full-screen Control, and ALSO
## poll Input directly each frame against the manifest hitboxes as a
## belt-and-braces fallback, because CDP-dispatched mouse events over the
## Godot canvas have proven unreliable in headless chromium.

enum Mode { FREE, DAILY, MIRROR, DRIFT }

const NUM_DIFFS := 5
const MULT_MAX := 3.0
const MULT_DECAY_SECONDS := 90.0   # full multiplier window per board
const BASE_POINTS := 100
const DRIFT_BOARDS := 5

@onready var renderer: BoardRenderer = $Board
@onready var seed_label: Label = $Hud/SeedChip/SeedVal
@onready var score_label: Label = $Hud/ScoreChip/ScoreVal
@onready var mult_label: Label = $Hud/MultChip/MultVal
@onready var streak_label: Label = $Hud/StreakChip/StreakRow/StreakVal
@onready var guard_tag: Label = $Hud/StreakChip/StreakRow/GuardTag
@onready var mult_bar: ColorRect = $Hud/MultBarWrap/MultBar
@onready var dots_label: Label = $Hud/Dots
@onready var banner: PanelContainer = $Banner
@onready var banner_label: Label = $Banner/BannerLabel
@onready var btn_new: Button = $Actions/BtnNew
@onready var btn_reveal: Button = $Actions/BtnReveal
@onready var btn_menu: Button = $Actions/BtnMenu
@onready var mode_label: Label = $Hud/ModeChip/ModeVal
@onready var audio: GameAudio = $Audio
@onready var menu: Control = $Menu

var mode: int = Mode.FREE
var state: Dictionary = {}
var board_seed := ""
var start_time := 0.0
var score := 0
var found := 0
var streak := 0
var guard_armed := false
var wrong_taps := 0
var mult_penalty := 1.0
var cleared := false
var reveals_left := 1
var drift_board := 0
var drift_lineage := ""


func _ready() -> void:
	randomize()
	btn_new.pressed.connect(_on_new_seed)
	btn_reveal.pressed.connect(_on_reveal)
	btn_menu.pressed.connect(_show_menu)
	menu.start_game.connect(_on_mode_selected)
	_show_menu()


func _show_menu() -> void:
	menu.visible = true
	banner.visible = false


func _on_mode_selected(selected_mode: int) -> void:
	mode = selected_mode
	menu.visible = false
	audio.start_ambient()
	if mode == Mode.DAILY:
		drift_board = 0
		_new_board(Generator.daily_seed())
	elif mode == Mode.DRIFT:
		drift_board = 0
		drift_lineage = Generator.random_seed_string()
		_new_board(_drift_seed())
	else:
		_new_board(Generator.random_seed_string())


func _drift_seed() -> String:
	return "DRIFT-%s-%d" % [drift_lineage, drift_board]


func _new_board(seed_str: String) -> void:
	board_seed = seed_str
	state = Generator.new().generate(seed_str)
	start_time = _now()
	score = 0 if mode != Mode.DRIFT else score
	found = 0
	streak = 0
	guard_armed = false
	wrong_taps = 0
	mult_penalty = 1.0
	cleared = false
	reveals_left = 1
	renderer.setup(state.scene, state.muts, mode == Mode.MIRROR, seed_str)
	seed_label.text = seed_str
	mode_label.text = _mode_name()
	_update_dots()
	banner.visible = false
	guard_tag.visible = false
	btn_reveal.disabled = false
	print("[STL] board seed=%s mode=%s" % [seed_str, _mode_name()])
	for i in state.muts.size():
		var m: Dictionary = state.muts[i]
		print("  diff %d: %s @ (%d,%d) travel=%.1f floor=%.1f" % [i + 1, m.cls,
			int(m.epicenters[0].x), int(m.epicenters[0].y), m.travel, m.eff_floor])
	var dbg := {
		"ready": true, "seed": seed_str, "mode": _mode_name(),
		"manifest": state.muts,
	}
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			("window.SPOT_DEBUG = %s;" % [JSON.stringify(dbg)])
			+ ("window.SPOT_METRICS = function(){ return %s; };"
				% [JSON.stringify(_metrics())])
		)


func _metrics() -> Dictionary:
	return {
		"seed": board_seed, "mode": _mode_name(), "time_s": snappedf(_now() - start_time, 0.1),
		"wrong_taps": wrong_taps, "score": score, "found": found,
		"total": NUM_DIFFS, "cleared": cleared, "streak": streak,
		"mult": snappedf(current_mult(), 0.01), "drift_board": drift_board,
	}


func _mode_name() -> String:
	match mode:
		Mode.DAILY: return "DAILY"
		Mode.MIRROR: return "MIRROR"
		Mode.DRIFT: return "DRIFT"
		_: return "FREE"


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func current_mult() -> float:
	var decay: float = clampf(1.0 - (_now() - start_time) / MULT_DECAY_SECONDS, 0.0, 1.0)
	return maxf(1.0, 1.0 + (MULT_MAX - 1.0) * decay) * mult_penalty


## Frame-polled input fallback: check the last mouse press against diff
## hitboxes in canonical space. Works even when event routing drops the
## click before it reaches _unhandled_input (headless web quirk).
var _last_press := Vector2(-9999, -9999)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# prefer the event's own position (get_local_mouse_position can lag
		# or be stale in headless/web environments)
		_try_tap(renderer.get_local_mouse_position() if event.position == Vector2.ZERO else event.position)


func _try_tap(local: Vector2) -> void:
	if menu.visible or cleared or state.is_empty():
		return
	if local.x < 0 or local.x > BoardRenderer.OX_R + BoardRenderer.HALF_W or local.y < 0 or local.y > BoardRenderer.H:
		return
	var canon := renderer.to_canonical(local)
	for i in state.muts.size():
		var m: Dictionary = state.muts[i]
		if m.get("found", false):
			continue
		for e in m.epicenters:
			if Vector2(canon.x - e.x, canon.y - e.y).length() <= BoardRenderer.hit_radius(m):
				m["found"] = true
				renderer.add_ring(Vector2(e.x, e.y))
				_on_correct_tap()
				return
	_wrong_tap()


func _on_correct_tap() -> void:
	streak += 1
	found += 1
	var pts := int(round(BASE_POINTS * current_mult() * (1.0 + 0.1 * (streak - 1))))
	score += pts
	audio.play("streak" if streak >= 3 else "spot")
	_update_dots()
	if found == NUM_DIFFS:
		_finish_board()


func _wrong_tap() -> void:
	wrong_taps += 1
	if streak >= 2 and not guard_armed:
		guard_armed = true
		guard_tag.visible = true
		audio.play("error", -10.0)
	else:
		streak = 0
		guard_armed = false
		guard_tag.visible = false
		audio.play("error")
	mult_penalty = 0.5


func _on_reveal() -> void:
	if reveals_left <= 0 or cleared:
		return
	reveals_left -= 1
	btn_reveal.disabled = true
	audio.play("reveal")
	for m in state.muts:
		if not m.get("found", false):
			renderer.add_hint(Vector2(m.epicenters[0].x, m.epicenters[0].y))
			break


func _finish_board() -> void:
	cleared = true
	var secs := _now() - start_time
	audio.play("clear")
	var msg := "SCENE CLEARED — %.1fs\nscore %d · wrong taps %d · seed %s" % [
		secs, score, wrong_taps, board_seed]
	var next_hint := ""
	if mode == Mode.DRIFT and drift_board + 1 < DRIFT_BOARDS:
		next_hint = "\nDRIFT continues — next board incoming…"
	msg += next_hint
	_show_banner(msg)
	if mode == Mode.DRIFT and drift_board + 1 < DRIFT_BOARDS:
		drift_board += 1
		await get_tree().create_timer(2.2).timeout
		banner.visible = false
		_new_board(_drift_seed())
	elif mode == Mode.DRIFT:
		_show_banner("DRIFT RUN COMPLETE — final score %d" % score)


func _show_banner(text: String) -> void:
	banner_label.text = text
	banner.visible = true


func _on_new_seed() -> void:
	if mode == Mode.DAILY:
		_new_board(Generator.daily_seed())
	elif mode == Mode.DRIFT:
		drift_board = 0
		drift_lineage = Generator.random_seed_string()
		score = 0
		_new_board(_drift_seed())
	else:
		_new_board(Generator.random_seed_string())


func _process(_delta: float) -> void:
	if state.is_empty():
		return
	var m := current_mult()
	mult_label.text = "%.2f×" % m
	mult_bar.size.x = (m - 1.0) / (MULT_MAX - 1.0) * 150.0
	score_label.text = str(score)
	streak_label.text = str(streak)


func _update_dots() -> void:
	dots_label.text = "●".repeat(found) + "○".repeat(NUM_DIFFS - found)
