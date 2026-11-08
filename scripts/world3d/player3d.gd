extends CharacterBody3D
## First-person explorer for the 3D rooms: WASD / arrows to walk (physical keys, so ZQSD on AZERTY),
## mouse to look (while the screen has captured the mouse), Shift to hurry.
## The host screen sets `enabled` and asks `focus_body()` for the interactable under the crosshair.

const SPEED := 3.1
const RUN := 5.2
const ACCEL := 11.0
const GRAVITY := 18.0
const EYE := 1.5
const SENS := 0.0022
const REACH := 3.4

var enabled := false
var cam: Camera3D
var ray: RayCast3D
var pitch := 0.0
var _bob_t := 0.0
var _bob_amt := 0.0
var _turn_tw: Tween = null


func _ready() -> void:
	_setup_input()
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.3
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.8
	add_child(col)
	cam = Camera3D.new()
	cam.position.y = EYE
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 120.0
	add_child(cam)
	cam.make_current()
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collision_mask = 1 | 2
	ray.collide_with_areas = false
	ray.add_exception(self)
	cam.add_child(ray)


static func _setup_input() -> void:
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])


static func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


## Teleport and face a point (used on spawn / room changes).
func place(pos: Vector3, look_point: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	look_at_point(look_point)


func look_at_point(p: Vector3) -> void:
	var eye := global_position + Vector3(0, EYE, 0)
	var d := p - eye
	rotation.y = atan2(-d.x, -d.z)
	pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-80), deg_to_rad(80))
	if cam:
		cam.rotation.x = pitch


## Smoothly turn to face a point (talking to someone).
func turn_to(p: Vector3, dur: float = 0.3) -> void:
	var eye := global_position + Vector3(0, EYE, 0)
	var d := p - eye
	var yaw := atan2(-d.x, -d.z)
	var cur := rotation.y
	yaw = cur + wrapf(yaw - cur, -PI, PI)
	var pt := clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-60), deg_to_rad(60))
	if _turn_tw:
		_turn_tw.kill()
	_turn_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_turn_tw.tween_property(self, "rotation:y", yaw, dur)
	_turn_tw.tween_property(self, "pitch", pt, dur)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var mm := event as InputEventMouseMotion
	if mm:
		rotate_y(-mm.relative.x * SENS)
		pitch = clampf(pitch - mm.relative.y * SENS, deg_to_rad(-80), deg_to_rad(80))


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	dir.y = 0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var spd := RUN if Input.is_key_pressed(KEY_SHIFT) else SPEED
	var k := clampf(ACCEL * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * spd, k)
	velocity.z = lerpf(velocity.z, dir.z * spd, k)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_bob_amt = lerpf(_bob_amt, clampf(hspeed / SPEED, 0.0, 1.0), clampf(8.0 * delta, 0.0, 1.0))
	_bob_t += delta * hspeed * 1.9


func _process(_delta: float) -> void:
	if cam:
		cam.rotation.x = pitch
		cam.position.y = EYE + sin(_bob_t * 2.0) * 0.028 * _bob_amt
		cam.position.x = cos(_bob_t) * 0.018 * _bob_amt


## The interactable body under the crosshair (or null).
func focus_body() -> Node3D:
	if ray == null:
		return null
	ray.force_raycast_update()
	if not ray.is_colliding():
		return null
	var c := ray.get_collider()
	if c is Node3D and (c as Node3D).has_meta("target"):
		return c as Node3D
	return null
