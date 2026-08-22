extends SceneTree
## Verify tap logic headlessly with event-position diagnostics.
## Run: godot --headless --path . --script tests/probe_tap.gd

var frames := 0
var cs: Node = null
var pressed := false


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	cs = packed.instantiate()
	root.add_child(cs)


func _process(_delta: float) -> bool:
	frames += 1
	if cs == null:
		return false
	if frames == 30 and not pressed:
		pressed = true
		var btn: Button = cs.get_node("Menu/Center/Panel/VBox/DailyBtn")
		btn.pressed.emit()
	if frames == 60:
		var e0: Dictionary = cs.get_node("Board").muts[0].epicenters[0]
		var local := Vector2(e0.x + 4, e0.y + 4)
		print("[PROBE] e0=", local)
		# call handler directly first (logic check)
		cs._try_tap(local)
		print("[PROBE] after direct: found=", cs.found, " wrong=", cs.wrong_taps)
		# now the Input pipeline path
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = local
		ev.global_position = local
		Input.parse_input_event(ev)
	if frames == 90:
		print("[PROBE] end: found=", cs.found, " wrong=", cs.wrong_taps)
		quit(0)
	return false
