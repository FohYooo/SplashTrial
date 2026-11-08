extends Node
## Keeps the mouse captured while the player walks around a 3D room, and frees it for menus,
## dialogue choices and the pause menu. Runs while the tree is paused (the pause menu pauses it).
## The host sets `want` to a Callable returning true when walking is allowed.

var want: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cap := not get_tree().paused and want.is_valid() and bool(want.call())
	var m := Input.MOUSE_MODE_CAPTURED if cap else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != m:
		Input.mouse_mode = m


func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## True for the "use / interact" inputs of the 3D rooms: E, Space, Enter, or a left click while captured.
static func is_interact(e: InputEvent) -> bool:
	var k := e as InputEventKey
	if k:
		return k.pressed and not k.echo and (k.physical_keycode == KEY_E or k.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	var mb := e as InputEventMouseButton
	if mb:
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	return false


## Debug: value of a `--key=value` user argument ("" if absent).
static func arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return ""


## Debug: parse "--cam=x,y,z,tx,ty,tz" into [pos, target] (empty if absent).
static func cam_arg() -> Array:
	var s := arg("cam")
	if s == "":
		return []
	var v := s.split(",")
	if v.size() < 6:
		return []
	return [Vector3(float(v[0]), float(v[1]), float(v[2])), Vector3(float(v[3]), float(v[4]), float(v[5]))]
