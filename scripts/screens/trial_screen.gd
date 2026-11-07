extends Control
## The Splash Trial: a pseudo-3D courtroom stage (scripts/ui/trial_stage.gd) behind a ScriptPlayer
## in stage mode (the player draws only the textbox/overlays; the stage draws chamber + speakers),
## with the Convince Meter HUD. Plays story script "trial" (or params.script_text for debugging).
## Main decides execution vs game over from Game.get_flag("vote_correct").

signal finished(result: Dictionary)

const ScriptPlayer := preload("res://scripts/core/script_player.gd")
const ConvinceMeter := preload("res://scripts/ui/convince_meter.gd")
const TrialStage := preload("res://scripts/ui/trial_stage.gd")

var _params := {}
var player: Control
var stage: TrialStage


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	stage = TrialStage.new()
	add_child(stage)
	player = ScriptPlayer.new()
	player.auto_portrait = true
	player.stage_mode = true
	add_child(player)
	stage.bind(player)
	stage.set_bg("trial")
	player.hud.add_child(ConvinceMeter.new())
	player.finished.connect(func() -> void:
		finished.emit({"vote_correct": Game.get_flag("vote_correct", false)}))
	if _params.has("script_text"):
		player.play_text(_params["script_text"])
	else:
		player.play_id("trial")
