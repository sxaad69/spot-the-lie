extends SceneTree
## Probe: does the menu actually show, and does clicking DAILY emit start_game?
## Run: godot --headless --path . --script tests/probe_flow.gd

var frames := 0
var clicked := false
var cs: Node = null


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	cs = packed.instantiate()
	root.add_child(cs)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30:
		print("[PROBE] menu visible=", cs.get_node("Menu").visible)
		var btn: Button = cs.get_node("Menu/Center/Panel/VBox/DailyBtn")
		print("[PROBE] DailyBtn rect=", btn.get_global_rect())
	if frames == 40 and not clicked:
		clicked = true
		var btn: Button = cs.get_node("Menu/Center/Panel/VBox/DailyBtn")
		btn.pressed.emit()
		print("[PROBE] pressed daily (armed=", cs.get_node("Menu")._armed, ")")
	if frames == 70:
		print("[PROBE] menu now visible=", cs.get_node("Menu").visible,
			" seed_label=", cs.get_node("Hud/SeedChip/SeedVal").text,
			" muts=", cs.get_node("Board").muts.size())
		quit(0)
	return false
