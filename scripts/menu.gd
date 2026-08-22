extends Control
## Title / mode-select screen. C1: DAILY + procedural identity readable
## immediately; the seed is a visible UI element in the HUD behind this.

signal start_game(mode: int)

enum Mode { FREE, DAILY, MIRROR, DRIFT }

@onready var daily_btn: Button = $Center/Panel/VBox/DailyBtn
@onready var free_btn: Button = $Center/Panel/VBox/FreeBtn
@onready var mirror_btn: Button = $Center/Panel/VBox/MirrorBtn
@onready var drift_btn: Button = $Center/Panel/VBox/DriftBtn


func _ready() -> void:
	daily_btn.pressed.connect(func(): start_game.emit(Mode.DAILY))
	free_btn.pressed.connect(func(): start_game.emit(Mode.FREE))
	mirror_btn.pressed.connect(func(): start_game.emit(Mode.MIRROR))
	drift_btn.pressed.connect(func(): start_game.emit(Mode.DRIFT))
