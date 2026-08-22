class_name GameAudio
extends Node
## Procedural-lite audio: OGG SFX from tools/gen_sfx.js (jsfxr params,
## generated-original) + ambient loop. Web export note: AudioStreamPlayer
## works on secure contexts; GitHub Pages is HTTPS so this is safe.

var sfx := {}
var ambient: AudioStreamPlayer


func _ready() -> void:
	for key in ["spot", "error", "streak", "clear", "reveal"]:
		var path := "res://assets/audio/%s.ogg" % key
		if ResourceLoader.exists(path):
			sfx[key] = load(path)
	if ResourceLoader.exists("res://assets/audio/ambient.ogg"):
		ambient = AudioStreamPlayer.new()
		ambient.stream = load("res://assets/audio/ambient.ogg")
		ambient.volume_db = -14.0
		ambient.bus = "Master"
		add_child(ambient)


func play(key: String, volume_db: float = -6.0) -> void:
	if sfx.has(key):
		var p := AudioStreamPlayer.new()
		p.stream = sfx[key]
		p.volume_db = volume_db
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()


func start_ambient() -> void:
	if ambient and not ambient.playing:
		ambient.play()


func stop_ambient() -> void:
	if ambient:
		ambient.stop()
