extends Control
## Plays one story script full-screen. params: {"script": id} or {"script_text": "..."}

signal finished(result: Dictionary)

const ScriptPlayer := preload("res://scripts/core/script_player.gd")

var _params := {}


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	var sp := ScriptPlayer.new()
	add_child(sp)
	sp.finished.connect(func() -> void: finished.emit({}))
	if _params.has("script_text"):
		sp.play_text(_params["script_text"])
	else:
		sp.play_id(str(_params.get("script", "")))
