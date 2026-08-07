extends CharacterBody3D
## First-person controller, hand-written per GDD §12.3.
##
## The body model here is load-bearing, not decoration: §5.6 makes vertical reach
## the primary level-design puzzle, so the camera has a real height, crouching
## really lowers it, and `reach_height()` is the number level design is built against.

@export_group("Look")
@export var mouse_sensitivity := 0.0022
@export var pitch_limit_deg := 89.0

@export_group("Move")
@export var walk_speed := 3.2
@export var sprint_speed := 5.4
@export var crouch_speed := 1.5
@export var ground_accel := 14.0
@export var air_accel := 2.5
@export var jump_velocity := 5.0

@export_group("Painting stance")
## Walking speed while painting. Full walk speed is ~4x this, which is fine for crossing
## a rooftop and useless for the 10 cm adjustments a letter needs — one tap of W at
## normal speed moves you half a letter, and there is no way to nudge.
@export var paint_walk_speed := 0.8
## Mouse sensitivity multiplier while painting. Your hand does finer work at a wall than
## it does scanning a street, and the same number cannot serve both.
@export_range(0.1, 1.0, 0.05) var paint_look_scale := 0.7

@export_group("Body")
@export var stand_height := 1.80
@export var crouch_height := 1.10
@export var crouch_speed_lerp := 8.0
## Eye sits this far below the crown of the head.
@export var eye_drop := 0.14
## How far above the eye the hand can comfortably paint. Standing, this puts the
## top of your reach at ~2.2m off the floor, which is the figure §5.6 designs to.
@export var reach_above_eye := 0.55

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _collision: CollisionShape3D = $Collision
@onready var _ceiling_check: RayCast3D = $CeilingCheck
@onready var _interactor: RayCast3D = $Head/Camera/Interactor

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _capsule: CapsuleShape3D
var _pitch := 0.0
var _height := 0.0
var _wants_crouch := false
var _stance := false

## Emitted when the player settles into or out of painting stance. The can listens to
## reposition itself; the HUD listens to show the palette.
signal stance_changed(active: bool)


func _ready() -> void:
	# The shape resource is shared by default; mutating it would edit the .tscn on disk.
	_capsule = _collision.shape.duplicate()
	_collision.shape = _capsule
	_height = stand_height
	_apply_height()
	_ceiling_check.target_position = Vector3(0, stand_height + 0.05, 0)
	_capture_mouse(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured():
		var sensitivity := mouse_sensitivity
		if _stance:
			sensitivity *= paint_look_scale
		rotate_y(-event.relative.x * sensitivity)
		_pitch = clampf(
			_pitch - event.relative.y * sensitivity,
			-deg_to_rad(pitch_limit_deg),
			deg_to_rad(pitch_limit_deg),
		)
		_head.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed and not _mouse_captured():
		_capture_mouse(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("paint_stance"):
		set_painting_stance(not _stance)


func _try_interact() -> void:
	var hit := _interactor.get_collider()
	if hit != null and hit.has_method("interact"):
		hit.interact()

func _physics_process(delta: float) -> void:
	_wants_crouch = Input.is_action_pressed("crouch")
	_update_height(delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump") and not _is_crouched():
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	# Reaching for sprint is the clearest possible statement that you are done painting.
	if _stance and Input.is_action_just_pressed("sprint"):
		set_painting_stance(false)

	var speed := walk_speed
	if _stance:
		speed = paint_walk_speed
	elif _is_crouched():
		speed = crouch_speed
	elif Input.is_action_pressed("sprint"):
		speed = sprint_speed
	var accel := ground_accel if is_on_floor() else air_accel
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	planar = planar.lerp(wish * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.x = planar.x
	velocity.z = planar.z

	move_and_slide()


## Settle into (or out of) painting stance: slow, fine movement and a finer look.
##
## Painting and walking are different activities that happen to share a keyboard. One
## speed cannot serve both — quick enough to cross a rooftop is far too coarse to place
## a letter, and slow enough to place a letter makes the rest of the game a slog.
func set_painting_stance(active: bool) -> void:
	if _stance == active:
		return
	_stance = active
	stance_changed.emit(_stance)


func is_painting_stance() -> bool:
	return _stance


## Highest point the player can comfortably paint, in world space. M1 uses this to
## decide when the arm is over-extended (more sway, less control).
func reach_height() -> float:
	return _camera.global_position.y + reach_above_eye


func eye_height() -> float:
	return _camera.global_position.y - global_position.y


func _update_height(delta: float) -> void:
	var target := stand_height
	if _wants_crouch or _blocked_above():
		target = crouch_height
	_height = move_toward(_height, target, crouch_speed_lerp * delta)
	_apply_height()


func _apply_height() -> void:
	_capsule.height = _height
	_collision.position.y = _height * 0.5
	_head.position.y = _height - eye_drop


func _is_crouched() -> bool:
	return _height < (stand_height + crouch_height) * 0.5


func _blocked_above() -> bool:
	_ceiling_check.force_raycast_update()
	return _ceiling_check.is_colliding()


func _capture_mouse(capture: bool) -> void:
	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	)


func _mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
