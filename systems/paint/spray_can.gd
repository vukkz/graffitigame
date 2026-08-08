class_name SprayCan
extends Node3D
## The can (GDD §5.3). Owns the physics of one spray tick and hands the result to
## whatever PaintSurface it happens to be pointed at.
##
## What is here: cone geometry, deposition, angle stretch, overspray, valve dynamics,
## arm reach, cap swapping.
## What is not, yet: pressure drain and sputter, paint volume, the shake minigame
## (§5.3 step 9, §5.5). `_pressure` is pinned at 1.0 so the deposition formula already
## has its slot — those should change what `_pressure` is and nothing else.

signal cap_changed(cap: SprayCap)
signal color_changed(color: Color, index: int)
## Re-emitted from the player so the HUD only needs to know about the can.
signal stance_changed(active: bool)
## Audio hooks (§10.2). The can announces what it is doing; sound decides what that means.
signal trigger_started()
signal trigger_released()
## `rhythm` is 0..1 for how close to the beat this press landed.
signal shaken(rhythm: float, mix: float, volume: float)
signal sputter_changed(active: bool)
signal emptied()

@export_group("Can")
## The paint currently loaded. Set by picking from `palette`; also the starting colour.
@export var can_color := Color("c8102e")
## Cans you are carrying, selected with the number keys. §7.1 makes paint a scarce,
## bought resource, so eventually this is inventory rather than a palette — the shape is
## the same, a list of cans with a colour each.
@export var palette: PackedColorArray = PackedColorArray([
	Color(0.72, 0.74, 0.76),  # chrome
	Color(0.06, 0.06, 0.07),  # black
	Color(0.95, 0.95, 0.93),  # white
	Color(0.78, 0.09, 0.14),  # red
	Color(0.8, 0.28, 0.75),  # magenta
	Color(0.11, 0.31, 0.72),  # blue
	Color(0.97, 0.78, 0.09),  # yellow
	Color(0.16, 0.6, 0.29),  # green
])
## Caps you can cycle with the cap_next action. Order is the cycle order.
@export var caps: Array[SprayCap] = []
## Furthest the paint reaches at all. Past this the ray misses and nothing happens.
@export var max_range := 5.0
## Distance the caps' `seconds_to_solid` is quoted at — roughly where a player stands.
@export var reference_distance := 0.8

@export_group("Pressure")
## Seconds of continuous spraying to drain full pressure. §5.3 step 9.
##
## Long on purpose. Shaking is loud and it draws attention (§5.5, and the reason a writer
## does it in the shadows before starting) — so a can that needs re-shaking every few
## seconds turns the whole mechanic into a chore and drowns out the moment it is meant to
## create. You shake before a piece, and once or twice inside it. Sputter starts at 25%,
## so this figure is really "seconds of trigger before it starts to go".
@export var pressure_seconds := 45.0
## Below this the can sputters: noisy, weaker, and the cone shrinks and jitters.
@export_range(0.0, 1.0, 0.01) var sputter_below := 0.25
## Pressure a well-timed shake puts back. Shaking MIXES, it does not refill — pressure
## comes back, paint does not.
@export_range(0.0, 1.0, 0.01) var shake_recovery := 0.32
## How ragged a sputtering can gets: peak random swing in flow and cone size.
@export_range(0.0, 1.0, 0.01) var sputter_jitter := 0.7

@export_group("Paint")
## Seconds of continuous spraying in a full can, WITH A SKINNY CAP. A separate, slower
## resource than pressure (§5.3 step 9) — at zero the can is dead and you throw it away.
##
## Divided by the cap's `drain_rate`, so this is the top of the range and the fat cap
## sits at the bottom of it. A real 400 ml can gives 200–300 s of continuous trigger;
## this is deliberately past that, because §7.1 makes paint scarce through what it COSTS
## rather than through running dry mid-letter, and being cut off halfway through a fill
## is the least interesting way a piece can go wrong.
@export var volume_seconds := 380.0

@export_group("Shake")
## How well mixed the can starts. Low on purpose: §5.5 makes under-shaking a legal move
## that produces a visibly worse can, and that is the entire teaching mechanism. A shake
## minigame you cannot fail is a chore.
@export_range(0.0, 1.0, 0.01) var starting_mix := 0.35
## Seconds between shakes the can wants — §5.5 asks for roughly 2 Hz.
@export var shake_period := 0.5
## How far off that beat still counts for something.
@export var shake_tolerance := 0.28
## Mix gained by one shake on the beat. §5.5 wants 8–12 presses for a full mix.
@export_range(0.01, 1.0, 0.01) var mix_per_shake := 0.11
## Seconds for a mixed can left alone to settle back out.
@export var settle_seconds := 240.0
## What a completely unmixed can puts out, as a fraction of a mixed one. Patchy, thin,
## and the colour never quite arrives.
@export_range(0.0, 1.0, 0.01) var unmixed_output := 0.45

@export_group("Angle")
## Cap on how far a steep angle may stretch the cone into an ellipse. §5.3 calls out
## incidence 0.4 as where it starts to matter, which is a stretch of 2.5; 3.0 lets you
## get a little past that before it stops smearing further.
@export_range(1.0, 8.0, 0.1) var max_stretch := 3.0

@export_group("Trigger")
## Seconds for the valve to reach full flow after you press. A cap does not snap open,
## and the thin lead-in is most of why a stroke reads as sprayed rather than stamped.
@export_range(0.0, 0.4, 0.005) var trigger_attack := 0.03
## Seconds for flow to die after you let go. THIS IS THE CUT.
##
## The can keeps painting for a moment while your hand is already moving away, so the
## line thins to a point instead of ending in a blunt stub. How sharp the cut comes out
## is decided by how fast you were moving when you released — which makes it a skill,
## not a setting.
##
## Nothing narrows the cone here. As flow drops the soft outer edge stops registering
## at all, so the visible line closes in on its own.
@export_range(0.0, 0.4, 0.005) var trigger_release := 0.09

@export_group("Reach")
## How far off the wall the nozzle is held while in painting stance. Mouse wheel.
##
## The arm holds this distance for you rather than you steering it. Where you stand then
## decides what you can REACH — §5.6's whole job, crates and boosts and getting higher —
## but stops deciding whether the line comes out sharp or washed out. Those were tangled
## together, and the result was that the only place you could lay a tight line was so
## close to the wall you could not see the letter you were drawing.
##
## §5.1: simulate the feedback, abstract the labour. Distance still drives width and
## density exactly as before; what is abstracted is having to re-aim your body for it on
## every stroke. The wheel is still there when you want a fatter or tighter line.
@export_range(0.08, 1.2, 0.01) var working_distance := 0.32
## Limits the wheel can drive `working_distance` between.
@export var working_distance_range := Vector2(0.12, 0.95)
## How far the arm can extend to hold that distance. Past this you have to walk.
@export_range(0.0, 2.0, 0.01) var max_reach := 1.2
## Metres of working distance per wheel click.
@export_range(0.01, 0.3, 0.01) var reach_step := 0.04
## How quickly the arm slides to the reach you asked for.
@export var reach_lerp := 14.0
## Closest the nozzle may ever get. Stops the cone collapsing to a pinpoint when you
## push the can at a wall you are already standing against.
@export var min_nozzle_distance := 0.05

@export_group("Can proxy")
## Draw a gray-box can in the corner of the screen.
##
## This is feedback, not art. Reach is meaningless as a hidden number — you cannot tell
## how far you have leaned in — but you read your own arm's position instantly when you
## can see it. The real hand and can arrive with the art pass; the job this does is
## making an invisible axis legible, and that job exists now.
@export var show_can_proxy := true
## Where the can sits at zero reach: right, down, and metres in front of the eye.
@export var proxy_offset := Vector3(0.19, -0.20, 0.42)

@export_group("Stroke")
## Gap between the quads making up one frame's stroke, as a fraction of the cone radius.
## Lower is smoother and costs more quads; above ~0.5 a fast sweep goes visibly dotty.
@export_range(0.05, 1.0, 0.01) var stamp_spacing := 0.3

@export_group("HUD")
## Optional Label showing the current cap. Gray-box scaffolding; §9's real HUD replaces it.
@export var cap_label_path: NodePath

## Multiplies the wall's grain_scale for the overspray stamp. Airborne paint breaks up
## much finer than concrete aggregate, and matching the two makes the powder read as part
## of the wall instead of as something the can did.
const OVERSPRAY_GRAIN_SCALE := 1.8

@onready var _ray: RayCast3D = $Ray

var _pressure := 1.0
## Paint left. Never recovers — shaking mixes, it does not refill.
var _volume := 1.0
## How well mixed. Drives how good the output is at all, separately from pressure.
var _mix := 1.0
var _last_shake := -100.0
var _shake_run := 0
var _sputtering := false
## Per-colour state. Each entry in `palette` is a separate physical can: its own paint,
## its own pressure, its own mix. Switching colour puts one can down and picks another up,
## so a fresh colour is full — and unshaken, which is the cost of reaching for it.
## The three above are the ACTIVE can, swapped in and out of these on a colour change.
var _volumes := PackedFloat32Array()
var _pressures := PackedFloat32Array()
var _mixes := PackedFloat32Array()
## How far open the valve is, 0..1. Not the same as the trigger being held — it lags
## behind it, and that lag is the cut.
var _valve := 0.0
var _reach := 0.0
var _reach_target := 0.0
var _cap_index := 0
var _color_index := -1
var _fallback_cap: SprayCap
var _last_surface: PaintSurface = null
var _last_uv := Vector2.ZERO
var _player: Node = null

var _proxy: Node3D
var _proxy_nozzle: MeshInstance3D
var _proxy_nozzle_mesh: CylinderMesh
var _proxy_nozzle_material: StandardMaterial3D


func _ready() -> void:
	# −Z is forward. The ray length is the can's range, so there is one number to change.
	_ray.target_position = Vector3(0.0, 0.0, -max_range)
	# A can with no caps assigned should still spray rather than crash on a null.
	_fallback_cap = SprayCap.new()
	_init_cans()
	_player = _find_player()
	if _player != null and _player.has_signal("stance_changed"):
		_player.stance_changed.connect(func(active: bool) -> void:
			stance_changed.emit(active))
	if show_can_proxy:
		_build_can_proxy()
	_apply_cap()


func _unhandled_input(event: InputEvent) -> void:
	# Wheel clicks are momentary — press and release land in the same frame — so read
	# them as events rather than polling, which can miss one between physics ticks.
	if event.is_action_pressed("reach_in"):
		working_distance = clampf(
			working_distance - reach_step,
			working_distance_range.x,
			working_distance_range.y,
		)
	elif event.is_action_pressed("reach_out"):
		working_distance = clampf(
			working_distance + reach_step,
			working_distance_range.x,
			working_distance_range.y,
		)
	elif event.is_action_pressed("cap_next") and caps.size() > 1:
		_cap_index = (_cap_index + 1) % caps.size()
		_apply_cap()
	elif event.is_action_pressed("shake"):
		_register_shake()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Read straight off the keycode rather than through eight input actions. This is
		# gray-box scaffolding for trying colours out; §9's real UI replaces the whole
		# selector, and eight rebindable actions would be noise in project.godot until
		# then. Physical keycode, so it works on a Serbian keyboard layout too.
		var key: int = event.physical_keycode
		if key >= KEY_1 and key <= KEY_9:
			select_color(key - KEY_1)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("paint_clear"):
		_clear_target()

	_update_reach(delta)
	_update_can_proxy()
	_refresh_hud()

	# Paint settles whether you are using it or not.
	_mix = maxf(_mix - delta / maxf(settle_seconds, 0.01), 0.0)

	var held := Input.is_action_pressed("spray") and _volume > 0.0
	# Reaching for the trigger IS getting into position. Making stance something you have
	# to remember to switch on would mean most players never find it, and the ones who
	# did would blame the game for the strokes they ruined before they did.
	if held and _player != null and not _player.is_painting_stance() and _aim() != null:
		_player.set_painting_stance(true)

	if Input.is_action_just_pressed("spray"):
		if _volume > 0.0:
			trigger_started.emit()
		else:
			emptied.emit()
	elif Input.is_action_just_released("spray"):
		trigger_released.emit()

	if held:
		# §5.3 step 9. Two resources at two speeds: pressure sags in seconds and a shake
		# brings it back; paint takes minutes and never comes back at all.
		#
		# Both are scaled by the cap, because the cap is the hole the paint leaves
		# through. See SprayCap.drain_rate for why pressure takes the square root.
		var drain: float = maxf(cap().drain_rate, 0.01)
		_pressure = maxf(
			_pressure - delta * sqrt(drain) / maxf(pressure_seconds, 0.01), 0.0
		)
		var was_empty := _volume <= 0.0
		_volume = maxf(_volume - delta * drain / maxf(volume_seconds, 0.01), 0.0)
		if _volume <= 0.0 and not was_empty:
			emptied.emit()

	var sputter_now: bool = held and _quality() < 0.999
	if sputter_now != _sputtering:
		_sputtering = sputter_now
		sputter_changed.emit(_sputtering)

	var ramp := trigger_attack if held else trigger_release
	_valve = move_toward(_valve, 1.0 if held else 0.0, delta / maxf(ramp, 0.001))

	if _valve <= 0.0:
		# Valve shut and finished bleeding down. Break stroke continuity so the next
		# press starts a fresh mark instead of drawing a line from wherever the
		# crosshair used to be.
		_last_surface = null
		return

	_spray_tick(delta)


## One press of the shake button (§5.5).
##
## Rhythm is what is being scored, not effort. Presses near the can's beat mix it; mashing
## as fast as you can, or dawdling, banks almost nothing. That is what makes it a mechanic
## instead of a chore — you can fail it, and failing shows up on the wall.
func _register_shake() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var gap := now - _last_shake
	_last_shake = now

	# A press after a long pause starts a new run; there is no beat to be on yet, so it
	# scores full rather than punishing you for beginning.
	var rhythm := 1.0
	if gap > shake_period + shake_tolerance * 2.0:
		_shake_run = 0
	elif _shake_run > 0:
		rhythm = clampf(1.0 - absf(gap - shake_period) / maxf(shake_tolerance, 0.01), 0.0, 1.0)
	_shake_run += 1

	_mix = clampf(_mix + mix_per_shake * rhythm, 0.0, 1.0)
	_pressure = clampf(_pressure + shake_recovery * rhythm, 0.0, 1.0)
	shaken.emit(rhythm, _mix, _volume)


## How good the output is right now, 0..1. Pressure and mix are separate failures that
## happen to look similar on the wall: one is a thin sputtering line, the other is a
## patchy one that never reaches full colour.
func _quality() -> float:
	var from_pressure := clampf(_pressure / maxf(sputter_below, 0.001), 0.0, 1.0)
	var from_mix := lerpf(unmixed_output, 1.0, _mix)
	return clampf(from_pressure * from_mix, 0.0, 1.0)


func pressure() -> float:
	return _pressure


func volume() -> float:
	return _volume


func mix() -> float:
	return _mix


## Load the paint at `index` in the palette. Out-of-range indices are ignored, so the
## number keys past the end of the palette simply do nothing.
func select_color(index: int) -> void:
	if index < 0 or index >= palette.size() or index == _color_index:
		return
	# Put the can you were holding back in the bag exactly as you left it.
	_stow_active()
	_color_index = index
	_pressure = _pressures[index]
	_volume = _volumes[index]
	_mix = _mixes[index]
	can_color = palette[index]
	_refresh_nozzle_color()
	color_changed.emit(can_color, index)


## Fill the bag: one full, unshaken can per colour in the palette.
func _init_cans() -> void:
	var count := palette.size()
	_volumes.resize(count)
	_volumes.fill(1.0)
	_pressures.resize(count)
	_pressures.fill(1.0)
	_mixes.resize(count)
	_mixes.fill(starting_mix)

	if count == 0:
		_mix = starting_mix
		return
	# Adopt whichever palette can matches the colour the scene starts with, so the
	# authored colour is a real can in the bag rather than a nameless extra one.
	_color_index = _match_palette(can_color)
	can_color = palette[_color_index]
	_pressure = _pressures[_color_index]
	_volume = _volumes[_color_index]
	_mix = _mixes[_color_index]


func _stow_active() -> void:
	if _color_index >= 0 and _color_index < _volumes.size():
		_pressures[_color_index] = _pressure
		_volumes[_color_index] = _volume
		_mixes[_color_index] = _mix


## Nearest palette entry to `color`. Tolerant, because a colour round-tripped through the
## Inspector comes back a hair off what was typed.
func _match_palette(color: Color) -> int:
	var best := 0
	var best_distance := INF
	for i in palette.size():
		var c := palette[i]
		var distance := (
			absf(c.r - color.r) + absf(c.g - color.g) + absf(c.b - color.b)
		)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


## Index of the loaded paint in the palette, or −1 if it is not one of them.
func color_index() -> int:
	return _color_index


## The cap currently screwed on.
func cap() -> SprayCap:
	if _cap_index >= 0 and _cap_index < caps.size() and caps[_cap_index] != null:
		return caps[_cap_index]
	return _fallback_cap


func _spray_tick(delta: float) -> void:
	var surface := _aim()
	if surface == null:
		_last_surface = null
		return

	var c := cap()
	var hit := _ray.get_collision_point()
	var normal := _ray.get_collision_normal()
	var origin := _ray.global_position
	var ray_dir := (hit - origin).normalized()

	# The nozzle sits `_reach` metres down the aiming ray, in front of the eye. Because
	# it is ON the ray, nozzle-to-wall is exactly eye-to-wall minus the reach — no
	# approximation, and the ray never starts inside the wall the way a moved raycast
	# would.
	var dist := maxf(origin.distance_to(hit) - _reach, min_nozzle_distance)

	# §5.3 step 2. 1.0 is square on to the wall, 0.0 is edge on.
	var incidence := clampf(-ray_dir.dot(normal), 0.0, 1.0)

	# §5.3 step 3: a cone widens linearly with distance. One tan() and "far away is
	# wide" is already correct — no curve, no table.
	var radius := _cone_radius(dist)

	# §5.3 step 9: below ~25% pressure the cone shrinks and jitters and the flow goes
	# ragged. Rolling the dice per tick is what makes it read as sputter rather than as
	# a quiet can — an even, weak line just looks like you moved further away.
	var quality := _quality()
	var jitter := (1.0 - quality) * sputter_jitter
	if jitter > 0.0:
		radius *= lerpf(1.0 - jitter * 0.45, 1.0, randf())


	# §5.3 step 5: a circular cone meeting the wall at an angle prints an ellipse,
	# elongated by 1/incidence along the direction the ray is leaning.
	var stretch := clampf(1.0 / maxf(incidence, 0.001), 1.0, max_stretch)

	# Squared, because a linear ramp still ends bluntly: alpha saturates, so the whole
	# top half of the ramp paints identically and only the last instant reads as a
	# taper. Squaring moves the interesting part of the decay to where the eye is.
	var valve := _valve * _valve

	# §5.3 step 4, the line the whole system hangs off. Fixed flow spread over a disc of
	# area ∝ radius² has to thin out as the disc grows, and the ellipse spreads it
	# thinner again. Close = dense and fast, far = thin and hazy, steep = a wide smear.
	# All three behaviours, one division.
	# `quality` carries what used to be a hard-coded pressure of 1.0. Everything else in
	# this line is untouched — §5.3 step 4 still owns the distance and angle behaviour.
	var flow := quality * lerpf(1.0 - jitter, 1.0, randf())
	var deposit := flow * valve * _cap_flow() * delta / (radius * radius * stretch)

	var uv := surface.world_to_uv(hit)
	if surface != _last_surface:
		_last_surface = surface
		_last_uv = uv

	var angle := _stretch_angle(surface, ray_dir, normal)

	var core := PaintSurface.Stamp.new()
	core.uv_from = _last_uv
	core.uv_to = uv
	core.radius_meters = radius
	core.stretch = stretch
	core.stretch_angle = angle
	core.falloff = c.falloff
	core.core_frac = c.core_frac
	core.peak_alpha = (
		deposit
		* (1.0 - c.overspray_share)
		* _cone_normalisation(c.falloff, c.core_frac)
	)
	core.color = can_color
	core.spacing = stamp_spacing
	core.delta = delta
	# What this cap delivers at its working distance. The drip grid treats it as the
	# rate the wall can absorb, so a cap that pushes more paint runs sooner — which is
	# the whole difference between a skinny and a fat cap on a held trigger.
	core.absorb_rate = 3.0 / maxf(c.seconds_to_solid, 0.001)
	surface.queue_stamp(core)

	# §5.3 step 7, but ONLY the far-field dust now. The soft edge of the line itself is
	# the cone's own shoulder (SprayCap.core_frac), because that is bounded by the cone
	# and is allowed to saturate; this stamp reaches metres and must never saturate at
	# all. See SprayCap.overspray_share for why the two had to be separated.
	#
	# Same flow accounting as the core: the haze's share of the paint, spread over a disc
	# that is `mult` times wider and therefore mult² times larger in area.
	var haze := PaintSurface.Stamp.new()
	haze.uv_from = _last_uv
	haze.uv_to = uv
	haze.radius_meters = radius * c.overspray_radius_mult
	haze.stretch = stretch
	haze.stretch_angle = angle
	haze.falloff = c.overspray_falloff
	# Flat falloff, no plateau: dust has no core. Passing 0.0 here is also what keeps this
	# term identical to what it was before the plateau existed.
	haze.peak_alpha = (
		deposit
		* c.overspray_share
		/ (c.overspray_radius_mult * c.overspray_radius_mult)
		* _cone_normalisation(c.overspray_falloff, 0.0)
	)
	haze.color = can_color
	haze.spacing = stamp_spacing
	# Powder is speckled where the core is smooth. Same noise field, different cause: the
	# core is being resisted by the concrete, the powder is paint that broke up in the air
	# before it landed. Finer scale so it reads as grit rather than as blotches.
	haze.grain = c.overspray_grain
	haze.grain_scale_mult = OVERSPRAY_GRAIN_SCALE
	# Haze is a few microns of dust over a wide area. It never runs, so it must not feed
	# the drip grid — counting it would make a slow wide pass drip as readily as a held
	# trigger, which is exactly backwards.
	haze.contributes_thickness = false
	surface.queue_stamp(haze)

	_last_uv = uv


## Raycast down the crosshair and return the PaintSurface we hit, or null.
##
## Godot's physics raycast gives back a point and a normal and nothing else — there is
## no get_collision_uv(). That absence is the reason PaintSurface.world_to_uv() exists.
func _aim() -> PaintSurface:
	_ray.force_raycast_update()
	return _ray.get_collider() as PaintSurface


## Hold the nozzle at `working_distance` off whatever we are pointed at, as far as the
## arm goes. Out of stance the can drops back to rest.
func _update_reach(delta: float) -> void:
	var target := 0.0
	if is_painting_stance() and _ray.is_colliding():
		var wall := _ray.global_position.distance_to(_ray.get_collision_point())
		target = clampf(wall - working_distance, 0.0, max_reach)
	_reach_target = target
	_reach = lerpf(_reach, _reach_target, clampf(reach_lerp * delta, 0.0, 1.0))


func is_painting_stance() -> bool:
	return _player != null and _player.is_painting_stance()


## Walk up the tree for whoever owns the body. Duck-typed on the method rather than on a
## class or an exported path — the same trick the door uses for `interact()`, and it
## means the can works under any rig that can answer the question.
func _find_player() -> Node:
	var node := get_parent()
	while node != null and not node.has_method("is_painting_stance"):
		node = node.get_parent()
	return node


## Cone radius where it meets a wall `dist` metres away.
func _cone_radius(dist: float) -> float:
	var c := cap()
	return c.nozzle_radius + dist * tan(deg_to_rad(c.cone_half_angle_deg))


## §5.3's cap_flow, derived from the cap's `seconds_to_solid` rather than typed in.
##
## Alpha accumulates as 1 − e^(−dose), so a dose of 3.0 is ~95% covered — "solid". Work
## backwards from that to the flow constant reaching it in the requested time at the
## reference distance. The reference radius is fixed, so this is a constant: the
## 1/radius² behaviour at the actual hit distance is untouched.
func _cap_flow() -> float:
	var c := cap()
	var peak_per_second := 3.0 / maxf(c.seconds_to_solid, 0.001)
	var r_ref := _cone_radius(reference_distance)
	var deposit_to_peak := (
		(1.0 - c.overspray_share) * _cone_normalisation(c.falloff, c.core_frac)
	)
	return peak_per_second * r_ref * r_ref / maxf(deposit_to_peak, 0.001)


## Direction of the ellipse's long axis, in the wall's buffer space. It is the ray
## direction flattened into the plane of the wall — literally "which way the spray is
## leaning across the surface".
func _stretch_angle(surface: PaintSurface, ray_dir: Vector3, normal: Vector3) -> float:
	var in_plane := ray_dir - normal * ray_dir.dot(normal)
	if in_plane.length_squared() < 0.000001:
		return 0.0  # Dead square on: the ellipse is a circle, any angle will do.
	var uv_dir := surface.world_dir_to_uv(in_plane.normalized())
	return atan2(uv_dir.y, uv_dir.x)


## A soft-edged brush puts less paint on the wall than a hard one of the same peak
## alpha, because most of its disc is nearly empty. Dividing that out keeps the total
## constant when you change the cap's shape.
##
## Without this, tuning `falloff` would quietly retune flow as well, and you would chase
## the two around in circles forever.
##
## The profile is a plateau of radius `c` at full strength, then a (1 − d)^k shoulder
## running to zero at the rim (see brush.gdshader). Its mean over the unit disc is
##
##     avg = c² + 2w/(k+1) − 2w²/(k+2),   w = 1 − c
##
## which at c = 0 collapses to the old 2/((k+1)(k+2)), so the pure-falloff case is
## unchanged and `core_frac = 0` really is the previous behaviour.
##
## Note what this does NOT do: peak alpha stays pinned to `seconds_to_solid` whatever the
## profile, because this factor cancels between here and _cap_flow(). Widening the core
## therefore costs nothing at the centre — it only widens the part of the line that
## reaches that centre value. That is why the plateau is a straight gain and not a trade.
func _cone_normalisation(k: float, c: float) -> float:
	var core := clampf(c, 0.0, 0.95)
	var w := 1.0 - core
	var avg := core * core + 2.0 * w / (k + 1.0) - 2.0 * w * w / (k + 2.0)
	return 1.0 / maxf(avg, 0.0001)


func _apply_cap() -> void:
	var c := cap()
	if _proxy_nozzle_mesh != null:
		# A fat cap looks fat on the can. Cheap, and it means a swap is legible before
		# you have sprayed anything.
		var r: float = clampf(0.006 + c.cone_half_angle_deg * 0.0018, 0.006, 0.024)
		_proxy_nozzle_mesh.top_radius = r
		_proxy_nozzle_mesh.bottom_radius = r
	_refresh_nozzle_color()
	cap_changed.emit(c)


## Gray-box readout. §9 designs the real thing; right now these three numbers are the
## only way to see why the can is behaving the way it is.
func _refresh_hud() -> void:
	var label := get_node_or_null(cap_label_path) as Label
	if label == null:
		return
	label.text = "%s\npressure %d%%\npaint %d%%\nmix %d%%" % [
		cap().display_name,
		roundi(_pressure * 100.0),
		roundi(_volume * 100.0),
		roundi(_mix * 100.0),
	]


## The nozzle wears the loaded paint, so the can in your hand tells you what colour you
## are about to lay down without you having to look away from the wall.
func _refresh_nozzle_color() -> void:
	if _proxy_nozzle_material != null:
		_proxy_nozzle_material.albedo_color = can_color


func _clear_target() -> void:
	var surface := _aim()
	if surface != null:
		surface.clear()


func _build_can_proxy() -> void:
	_proxy = Node3D.new()
	_proxy.name = "CanProxy"
	add_child(_proxy)

	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.033
	body_mesh.bottom_radius = 0.033
	body_mesh.height = 0.2
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.16, 0.16, 0.18)
	body_material.roughness = 0.45
	_proxy.add_child(_make_part(body_mesh, body_material, 0.0))

	_proxy_nozzle_mesh = CylinderMesh.new()
	_proxy_nozzle_mesh.height = 0.03
	_proxy_nozzle_material = StandardMaterial3D.new()
	_proxy_nozzle = _make_part(_proxy_nozzle_mesh, _proxy_nozzle_material, -0.115)
	_proxy.add_child(_proxy_nozzle)


## A cylinder laid along −Z (forward) instead of its native +Y, `z` metres ahead.
func _make_part(mesh: Mesh, material: Material, z: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	part.position = Vector3(0.0, 0.0, z)
	# Without this the can throws a large soft shadow onto the very wall you are
	# painting, which is unreadable and looks like a bug in the paint.
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part


func _update_can_proxy() -> void:
	if _proxy == null:
		return
	var forward := proxy_offset.z + _reach
	# Stop the can at the wall. Your arm cannot reach through concrete, and watching it
	# come to a halt is what tells you that you are as close as you can get.
	if _ray.is_colliding():
		var wall := _ray.global_position.distance_to(_ray.get_collision_point())
		forward = minf(forward, maxf(wall - 0.16, 0.14))
	_proxy.position = Vector3(proxy_offset.x, proxy_offset.y, -forward)
