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
	# arm after two frames so the boot frame can't double-fire a mode
	await get_tree().process_frame
	_armed = true


func _go(mode: int) -> void:
	if not _armed:
		return
	start_game.emit(mode)


## Keyboard fallback: Enter = DAILY, 1-4 pick modes directly. This also gives
## QA a deterministic non-pointer path into the game.
func _unhandled_key_input(event: InputEvent) -> void:
	if not _armed or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_1:
				_go(Mode.DAILY)
			KEY_2:
				_go(Mode.FREE)
			KEY_3:
				_go(Mode.MIRROR)
			KEY_4:
				_go(Mode.DRIFT)
