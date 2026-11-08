extends RefCounted
## The lift's little performance, shared by the 3D screens: doors slide, the car hums and shakes, a ding on arrival.
## The car doesn't really travel: the world behind the closed doors is swapped.

const OPEN_X := 1.42
const SHUT_X := 0.5


static func _dur(sec: float) -> float:
	return 0.01 if Game.autotest else sec


static func set_doors(lift: Dictionary, open: bool) -> void:
	var x := OPEN_X if open else SHUT_X
	(lift["door_l"] as Node3D).position.x = -x
	(lift["door_r"] as Node3D).position.x = x


static func move_doors(host: Node, lift: Dictionary, open: bool) -> void:
	var x := OPEN_X if open else SHUT_X
	Audio.sfx("door", 1.5, -8.0)
	var tw := host.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(lift["door_l"], "position:x", -x, _dur(0.45))
	tw.tween_property(lift["door_r"], "position:x", x, _dur(0.45))
	await tw.finished


## Hum + shake while the floor number changes. Call with the doors shut.
static func rumble(host: Node, cam: Camera3D, lift: Dictionary) -> void:
	Audio.sfx("whoosh", 0.55, -6.0)
	var steps := 1 if Game.autotest else 22
	var inside: Label3D = lift.get("inside")
	if inside:
		inside.text = "..."
	for i in steps:
		if not is_instance_valid(cam):
			return
		cam.v_offset = randf_range(-0.012, 0.012)
		cam.h_offset = randf_range(-0.006, 0.006)
		await host.get_tree().create_timer(_dur(0.06), false).timeout
	if is_instance_valid(cam):
		cam.v_offset = 0.0
		cam.h_offset = 0.0
	Audio.sfx("chime", 1.5, -9.0)
