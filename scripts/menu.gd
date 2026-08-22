extends Control
## Title / mode-select screen (C1: DAILY + procedural identity readable;
## seed visible in HUD behind this overlay).

signal start_game(mode: int)

enum Mode { FREE, DAILY, MIRROR, DRIFT }

@onready var daily_btn: Button = $Center/Panel/VBox/DailyBtn
@onready var free_btn: Button = $Center/Panel/VBox/FreeBtn
@onready var mirror_btn: Button = $Center/Panel/VBox/MirrorBtn
@onready var drift_btn: Button = $Center/Panel/VBox/DriftBtn

var _armed := false


func _ready() -> void:
	daily_btn.pressed.connect(func(): _go(Mode.DAILY))
	free_btn.pressed.connect(func(): _go(Mode.FREE))
	mirror_btn.pressed.connect(func(): _go(Mode.MIRROR))
	drift_btn.pressed.connect(func(): _go(Mode.DRIFT))
	# arm on the next frame so a click that opened the menu doesn't
	# immediately re-trigger a mode (classic double-fire bug)
	await get_tree().process_frame
	_armed = true


func _go(mode: int) -> void:
	if not _armed:
		return
	start_game.emit(mode)


func _gui_input(event: InputEvent) -> void:
	# forward clicks to the buttons underneath (CenterContainer handles layout;
	# this guard keeps the overlay from eating events)
	if event is InputEventMouseButton:
		pass


func _unhandled_input(event: InputEvent) -> void:
	pass
