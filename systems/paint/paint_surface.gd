@tool
class_name PaintSurface
extends StaticBody3D
## One paintable wall, plus the buffer holding every mark ever made on it (GDD §5.2).
##
## The buffer is a SubViewport set to CLEAR_MODE_NEVER: Godot draws into it and then
## never wipes it, so a brush quad drawn on frame 12 is still there on frame 90,000.
## That is the whole trick. Nothing about the paint is simulated per frame — it is a
## picture we keep adding to, which is why ten thousand strokes cost the same as one.
##
## Slice 1 builds only the PaintColor buffer (RGB = colour, A = coverage). §5.2's second
## buffer, PaintData (wetness / thickness / age / pass id), is a second SubViewport that
## arrives with drips and wet sheen. The shape of this file is meant to take it without
## rework: one more viewport, one more shader, the same pool of quads.
##
## This is a @tool script, which means it also runs inside the editor — that is what
## lets you drag `size` in the Inspector and watch the wall resize. The cost is that a
## crash here can spam the editor, so anything editor-side is kept to setting sizes.

const BRUSH_SHADER: Shader = preload("res://systems/paint/brush.gdshader")
const WETNESS_SHADER: Shader = preload("res://systems/paint/wetness.gdshader")
const DRY_SHADER: Shader = preload("res://systems/paint/dry.gdshader")
const WALL_SHADER: Shader = preload("res://systems/paint/wall_surface.gdshader")

@export_group("Wall")
## Size of the paintable face, in metres. This drives the mesh, the collision box and
## the resolution of the paint buffer, so it is the only place to change it.
@export var size := Vector2(6.0, 3.0):
	set(value):
		size = value
		_rebuild()

## Depth of the collision box behind the face. Purely so the wall is solid; the
## paintable surface itself is the flat quad at local z = 0.
@export var thickness := 0.06:
	set(value):
		thickness = value
		_rebuild()

## Buffer resolution, in texels per metre of wall.
##
## Painting happens with your face close to the wall, and that is the worst case: at
## 40 cm you can see about 60 cm of wall across the whole screen, so one texel covers
## roughly ten screen pixels at 256/m and every outline reads as mush. 400/m puts a
## texel at 2.5 mm, which holds up at the range the work actually happens.
##
## The cost is memory, not speed — a stamp only draws a handful of small quads, so the
## buffer's size barely touches fill rate. A 6×3 m wall at 400/m is 2400×1200 in RGBA16F,
## about 23 MB. §5.8 keeps exactly one of these live at a time, which is what makes that
## affordable. It is still the first number to drop if the 3050 complains.
##
## Texels are square by construction (both axes use this one number) and the brush maths
## relies on that. Changing it at runtime reallocates the target and WIPES the wall.
@export var texels_per_meter := 400.0:
	set(value):
		texels_per_meter = value
		_rebuild()

## Store the buffer as 16-bit float per channel instead of §5.2's RGBA8.
##
## Hazing a wall at range lays down ~2/255 of alpha per frame, and at 8 bits the
## rounding error accumulates into visible concentric rings — a soft cloud comes out
## looking like a contour map. Float blending has no rounding to accumulate.
##
## Costs double the memory (a 6×3 wall at 256 tx/m: 4.7 MB → 9.4 MB), which §5.8 makes
## affordable by keeping exactly one live buffer at a time. Turn it off and spray a
## haze at 3 m if you want to see what it is buying.
@export var high_precision_buffer := true:
	set(value):
		high_precision_buffer = value
		if is_node_ready():
			_configure_buffer()

@export_group("Look")
## Colour of the bare wall under the paint.
@export var base_color := Color(0.42, 0.41, 0.39):
	set(value):
		base_color = value
		_push_material_params()

## Roughness of the bare wall. Concrete is nearly matte. Slice 3 makes this vary with
## wetness so fresh paint reads as glossy.
@export_range(0.0, 1.0, 0.01) var base_roughness := 0.92:
	set(value):
		base_roughness = value
		_push_material_params()

@export_group("Surface")
## How hard the wall resists paint (§5.3 step 6). 0 is a smooth canvas; at 0.35 a first
## pass comes out mottled and it takes two or three to bury the texture.
@export_range(0.0, 1.0, 0.01) var wall_grain := 0.35
## Size of the aggregate. Higher is finer grit, lower is coarse blockwork.
@export var grain_scale := 260.0

@export_group("Wetness")
## Seconds for fresh paint to dry back to matte (§5.1 says ~30).
@export var wet_seconds := 30.0
## Roughness of paint that has just landed. Concrete is near matte at 0.92; fresh enamel
## is a mirror by comparison, and that gap is the whole effect.
@export_range(0.0, 1.0, 0.01) var wet_roughness := 0.12
## How much darker wet paint reads than the same paint dry.
@export_range(0.0, 1.0, 0.01) var wet_darkening := 0.14
## How readily a stamp soaks the wall, relative to how much paint it laid. Above ~4 a
## single pass leaves the wall fully wet; low values make sheen something you have to
## build. Overspray scales down by the same rule, so haze stays dry — it is microns
## thick and dry almost on contact.
@export var wetness_gain := 4.0
## How much wetness one drying pass removes. Drying has to be DRAWN — a never-cleared
## buffer has no other way to fade — so passes are batched instead of run every frame.
##
## Batching by SIZE rather than by a clock is what makes it work at all. PaintData is
## 8-bit, so one step of 1/255 is the smallest change that can land; a pass asking to
## subtract less than that rounds to nothing and drying stalls outright — at 30 s dry
## time and a 10 Hz clock each pass asks for 0.85/255, and the wall stays wet forever.
## At ~3/255 the step always lands, and 1/0.012 ≈ 83 passes still make the fade smooth.
@export_range(0.004, 0.2, 0.001) var dry_step := 0.012

@export_group("Drips")
## GDD §5.4. Turn off to compare — it is a bigger part of "does this look like paint"
## than its cost suggests.
@export var drips_enabled := true
## Resolution of the grid that decides where paint runs.
##
## §5.4 says 64×64 per wall; a fixed cell SIZE instead means a 12 m wall gets the same
## drip resolution as a 3 m one, which matters once walls stop being one test rectangle.
##
## 25/m gives 4 cm cells, fine enough to resolve a skinny cap's cone. Cells coarser than
## the cone are what made close-range work drip no matter how fast you moved: the whole
## cell gets credited with the density at the cone's centre. The solver only touches
## cells you actually spray, so this costs far less than the cell count suggests.
@export var drip_cells_per_meter := 25.0
## How long a NORMAL cap may sit on one spot before the paint runs. THE dial.
##
## Fatter caps run sooner than this and skinny ones later, because the ceiling below
## belongs to the cap, not to the wall. Lower this for a wetter, drippier game — at 0.2
## a held skinny cap runs in about a quarter second and a slow line beads up on its own.
@export_range(0.02, 5.0, 0.01) var drip_after_seconds := 0.15
## Coverage per second a "normal" cap lays down. Only here to turn the seconds above
## into the coverage units the grid actually counts; leave it unless caps are retuned.
@export var drip_reference_flow := 100.0
## Seconds before paint in a cell has dried enough to stop being able to run.
@export var drip_wet_seconds := 22.0
## Hard cap on live drips (§5.4 says ~30). Each costs 1–2 brush quads per frame.
@export var max_drips := 30
## Speed a drip starts at, metres/second.
@export var drip_speed := 0.04
## How hard it picks up, metres/second². Together with lifetime this sets run length —
## the defaults give a 4–15 cm run, which is what a real one looks like. Much past that
## and they stop reading as paint and start reading as scratches.
@export var drip_accel := 0.07
@export var drip_lifetime := Vector2(0.9, 2.4)
## Seconds a run spends pooling before it breaks and starts moving. This is what gives a
## drip its heavy head — without it runs start mid-air at full speed and look like rain.
@export var drip_hang := Vector2(0.06, 0.22)
## Small swelling near the end of a run, where paint stalls and gathers, as a fraction
## of the radius. 0 for a clean taper.
@export_range(0.0, 1.5, 0.05) var drip_bead := 0.45
## Radius at birth, metres. Slightly fatter than life on purpose: at 256 texels/m a
## true 5 mm drip is barely one texel wide and reads as an artifact rather than paint.
@export var drip_radius := 0.011
## Fraction of that radius left when it dies.
@export_range(0.05, 1.0, 0.01) var drip_taper := 0.4
@export_range(0.0, 1.0, 0.01) var drip_alpha := 0.9
## How far off straight-down a run may lean, as a fraction of its speed. Real paint
## follows whatever the wall gives it; a bundle of perfectly parallel lines reads as
## rain, not as paint.
@export_range(0.0, 0.6, 0.01) var drip_wander := 0.14

@export_group("Budget")
## Most brush quads one frame may draw. One frame of spray is a short row of overlapping
## quads (see _draw_stamp), and a fast mouse sweep needs more of them to stay a line
## rather than a dotted trail. Past this we stop drawing rather than allocate forever.
##
## Read at startup only — the pool is built once in _ready(). Thirty live drips can ask
## for ~60 of these on their own, on top of whatever the can is doing.
@export var max_quads_per_frame := 192

## One frame of spray from one nozzle. The can fills these in and hands them over; the
## wall turns them into quads. Splitting it this way keeps all the can physics in
## spray_can.gd and all the buffer mechanics here.
class Stamp extends RefCounted:
	var uv_from := Vector2.ZERO  ## Where the cone landed last tick.
	var uv_to := Vector2.ZERO  ## Where it lands this tick.
	var radius_meters := 0.05  ## Cone radius where it meets the wall.
	var stretch := 1.0  ## Ellipse elongation caused by a steep angle.
	var stretch_angle := 0.0  ## Direction of that elongation, radians, in buffer space.
	var peak_alpha := 0.1  ## Alpha at the centre of the cone.
	var falloff := 2.4  ## Edge hardness. Higher is crisper.
	var color := Color.WHITE
	var spacing := 0.3  ## Gap between quads along the stroke, as a fraction of radius.
	## Whether this feeds the drip solver's thickness grid. False for overspray (haze
	## never runs) and false for drips themselves (or they would spawn each other).
	var contributes_thickness := true
	## Coverage per second this cap can pile up before the wall stops taking it, i.e. the
	## rate this cap delivers at its own working distance.
	##
	## It lives on the cap rather than the wall because that is what makes a fat cap run
	## sooner than a skinny one. A single wall-wide ceiling clips both caps to the same
	## number and erases the difference — which is what the wall absorbing "as fast as a
	## typical can delivers" really means: push harder than that and it pools.
	var absorb_rate := 100.0
	## Seconds of spraying this stamp represents.
	##
	## Carried on the stamp rather than taken from the frame that draws it, because the
	## can queues at the PHYSICS rate and the draw happens on the RENDER frame. Those are
	## different clocks, and using the wrong one silently rescales the drip solver's
	## absorb rate by whatever framerate the machine happens to be running at.
	var delta := 1.0 / 60.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $Collision
@onready var _buffer: SubViewport = $Buffer
@onready var _data: SubViewport = $Data

var _wall_material: ShaderMaterial
var _drips: DripSolver
var _quad_mesh: QuadMesh
var _quads: Array[MeshInstance2D] = []
## Mirrors _quads one for one, in the PaintData buffer. A node lives in exactly one
## viewport, so writing both buffers means two pools moving in lockstep.
var _wet_quads: Array[MeshInstance2D] = []
var _dry_rect: ColorRect
var _queue: Array[Stamp] = []
var _overflowed := false
var _clock := 0.0
var _dry_accum := 0.0
var _last_paint_time := -1000.0


func _ready() -> void:
	# Resources are shared by default in Godot: if two PaintWalls both used the same
	# QuadMesh, resizing one would resize the other AND write it back to disk. Making
	# them here, in code, means each wall owns its own. (Same reason fp_controller.gd
	# duplicates its capsule.)
	_quad_mesh = QuadMesh.new()
	_mesh.mesh = _quad_mesh
	_collision.shape = BoxShape3D.new()

	_wall_material = ShaderMaterial.new()
	_wall_material.shader = WALL_SHADER
	_mesh.material_override = _wall_material

	_configure_buffer()
	if not Engine.is_editor_hint():
		_drips = DripSolver.new(self)
	_rebuild()

	if not Engine.is_editor_hint():
		# Drying is added first so it draws UNDER the stamps: a frame that both dries and
		# paints must take the slice off before the new paint lands, not after.
		_build_dry_pass()
		_quads = _build_quad_pool(_buffer, BRUSH_SHADER)
		_wet_quads = _build_quad_pool(_data, WETNESS_SHADER)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_clock += delta
	# Drips run first so the stamps they queue land in the same render as the spray's.
	_drips.update(delta)

	var render_data := _update_drying(delta)
	if not _queue.is_empty():
		_flush()
		_last_paint_time = _clock
		render_data = true

	if render_data:
		_data.render_target_update_mode = SubViewport.UPDATE_ONCE


## Take a slice off the wetness buffer, on a slow tick. Returns whether it drew anything.
func _update_drying(delta: float) -> bool:
	_dry_accum += delta
	# Stop once everything laid before the last brush stroke must already be bone dry.
	# A wall nobody is painting has to cost nothing, and a full-buffer pass is the one
	# thing here that touches every texel.
	var still_drying := (_clock - _last_paint_time) < wet_seconds * 1.5
	# Wait until enough time has banked to subtract a step the 8-bit buffer can actually
	# represent. See `dry_step`.
	var amount := _dry_accum / maxf(wet_seconds, 0.01)
	if not still_drying or amount < dry_step:
		_dry_rect.visible = false
		return false

	var mat: ShaderMaterial = _dry_rect.material
	# Amount comes from elapsed time, not from the frame, so drying takes wet_seconds
	# whatever the framerate.
	mat.set_shader_parameter("amount", amount)
	_dry_rect.visible = true
	_dry_accum = 0.0
	return true


## World point on the face → position in the paint buffer, as UV in 0..1.
##
## We derive this from the wall's own local coordinates rather than reading the mesh's
## UV channel. §5.2 assumes each wall carries a unique non-overlapping UV1, which will
## be true once walls come out of Blender — but a primitive's UV layout is the engine's
## business, and guessing it wrong gives you paint that lands mirrored or upside down.
## That reads as a maths bug and isn't one.
##
## Deriving UV from position means wall_surface.gdshader can run the identical formula
## on VERTEX.xy, so the two physically cannot disagree. When real UV-mapped walls arrive,
## this becomes a raycast against a mesh with UV1 and the shader's vertex() becomes one
## line: paint_uv = UV.
##
## Note: this assumes the wall node is unscaled. Set `size`, never `scale`.
func world_to_uv(world_point: Vector3) -> Vector2:
	var local := to_local(world_point)
	return Vector2(
		local.x / size.x + 0.5,
		0.5 - local.y / size.y,
	)


## A world direction lying in the wall's plane → the same direction in buffer space.
##
## Only the direction survives, not the length: buffer space is metres times a single
## uniform scale (texels_per_meter), so angles are preserved and this is just an axis
## relabel with Y flipped, because textures count downward.
func world_dir_to_uv(world_dir: Vector3) -> Vector2:
	var local := global_transform.basis.orthonormalized().inverse() * world_dir
	return Vector2(local.x, -local.y)


## Buffer texels → UV.
func buffer_to_uv(texels: Vector2) -> Vector2:
	return texels / Vector2(_buffer.size)


func buffer_size() -> Vector2i:
	return _buffer.size


## Wet paint a cell must hold before it runs, in coverage units. Derived so the exposed
## knob can be a time — "how long may I hold the can here" — instead of an abstract
## quantity nobody can picture.
func drip_threshold() -> float:
	return drip_after_seconds * drip_reference_flow


## Which way is down, on this wall's own surface, as a unit vector in buffer space.
##
## §5.4 is specific that a drip follows world gravity projected into the wall, not the
## texture's +Y. Dropping the component along the wall normal IS that projection, which
## is why this is three lines and not a plane-projection routine.
func down_in_buffer() -> Vector2:
	var d := world_dir_to_uv(Vector3.DOWN)
	if d.length_squared() < 0.000001:
		return Vector2(0.0, 1.0)  # Wall is horizontal. Nothing runs; pick something sane.
	return d.normalized()


## Hand one tick of spray to the wall. Stamps queue up and are drawn together at the
## end of the frame — see _flush() for why that matters.
func queue_stamp(stamp: Stamp) -> void:
	_queue.append(stamp)


## Wipe the wall back to bare concrete. Debug convenience for tuning; §5.8's real
## answer to old paint is baking the buffer to a PNG at mission end and reloading it
## as a static texture.
func clear() -> void:
	_queue.clear()
	if _drips != null:
		_drips.clear()
	for quad in _quads:
		quad.visible = false
	for quad in _wet_quads:
		quad.visible = false
	if _dry_rect != null:
		_dry_rect.visible = false
	_buffer.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_buffer.render_target_update_mode = SubViewport.UPDATE_ONCE
	_data.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_data.render_target_update_mode = SubViewport.UPDATE_ONCE


func _configure_buffer() -> void:
	_buffer.transparent_bg = true  # Unpainted wall = alpha 0, so the concrete shows.
	_buffer.disable_3d = true  # Nothing in here but flat quads.
	_buffer.use_hdr_2d = high_precision_buffer

	# CLEAR_MODE_ONCE clears on the next frame and then switches ITSELF to
	# CLEAR_MODE_NEVER. That is exactly what §5.2 asks for, and it also solves the
	# problem that a never-cleared target starts life full of undefined garbage.
	_buffer.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_buffer.render_target_update_mode = SubViewport.UPDATE_ONCE

	# PaintData stays 8-bit per §5.2. Wetness is a smooth 0..1 that only ever drives a
	# roughness lerp, so quantisation is invisible — and the subtractive drying pass was
	# chosen precisely so that 8 bits still reaches zero.
	_data.transparent_bg = true
	_data.disable_3d = true
	_data.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_data.render_target_update_mode = SubViewport.UPDATE_ONCE


func _rebuild() -> void:
	# Exported setters fire while the scene is still loading, before @onready resolves.
	if not is_node_ready():
		return

	_quad_mesh.size = size

	var box: BoxShape3D = _collision.shape
	box.size = Vector3(size.x, size.y, thickness)
	# Push the solid part backwards so the paintable face stays at local z = 0.
	_collision.position.z = -thickness * 0.5

	var texels := Vector2i(
		maxi(8, roundi(size.x * texels_per_meter)),
		maxi(8, roundi(size.y * texels_per_meter)),
	)
	if _buffer.size != texels:
		_buffer.size = texels
		_data.size = texels
		_configure_buffer()  # Resizing drops the old target; clear the new one.

	if _dry_rect != null:
		_dry_rect.size = Vector2(texels)

	if _drips != null:
		_drips.resize(_buffer.size)

	_push_material_params()


func _push_material_params() -> void:
	if _wall_material == null:
		return
	_wall_material.set_shader_parameter("paint_tex", _buffer.get_texture())
	_wall_material.set_shader_parameter("wet_tex", _data.get_texture())
	_wall_material.set_shader_parameter("base_color", base_color)
	_wall_material.set_shader_parameter("base_roughness", base_roughness)
	_wall_material.set_shader_parameter("wet_roughness", wet_roughness)
	_wall_material.set_shader_parameter("wet_darkening", wet_darkening)
	_wall_material.set_shader_parameter("wall_size", size)


func _build_quad_pool(viewport: SubViewport, shader: Shader) -> Array[MeshInstance2D]:
	var root := Node2D.new()
	root.name = "Quads"
	viewport.add_child(root)

	var pool_mesh := QuadMesh.new()
	pool_mesh.size = Vector2.ONE  # Unit square; each quad scales itself to its cone.

	var pool: Array[MeshInstance2D] = []
	for i in max_quads_per_frame:
		var quad := MeshInstance2D.new()
		quad.mesh = pool_mesh
		# Each quad gets its own material because peak alpha and falloff differ between
		# the core cone and its overspray halo within a single frame.
		var mat := ShaderMaterial.new()
		mat.shader = shader
		quad.material = mat
		quad.visible = false
		root.add_child(quad)
		pool.append(quad)
	return pool


func _build_dry_pass() -> void:
	_dry_rect = ColorRect.new()
	_dry_rect.name = "Dry"
	var mat := ShaderMaterial.new()
	mat.shader = DRY_SHADER
	_dry_rect.material = mat
	_dry_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dry_rect.visible = false
	_dry_rect.position = Vector2.ZERO
	_dry_rect.size = Vector2(_data.size)
	_data.add_child(_dry_rect)


## Draw every stamp queued this frame, then ask the buffer for exactly one render.
##
## Flushing in _process rather than _physics_process is deliberate: Godot runs all
## physics ticks first, then _process, then draws. So by the time we get here every
## nozzle has had its say, and if physics ran twice this frame both ticks land in the
## same render instead of one silently overwriting the other.
func _flush() -> void:
	var texels := Vector2(_buffer.size)
	var used := 0
	for stamp in _queue:
		used = _draw_stamp(stamp, used, texels)

	for i in range(used, _quads.size()):
		_quads[i].visible = false
		_wet_quads[i].visible = false

	_queue.clear()
	# UPDATE_ONCE renders a single frame and then disables itself again, so the buffer
	# costs nothing on frames where nobody is spraying.
	_buffer.render_target_update_mode = SubViewport.UPDATE_ONCE


## Lay one stamp down as a row of overlapping quads, and return the new pool cursor.
func _draw_stamp(stamp: Stamp, first: int, texels: Vector2) -> int:
	if first >= _quads.size():
		_warn_overflow()
		return first

	var radius_texels: float = stamp.radius_meters * texels_per_meter
	var from: Vector2 = stamp.uv_from * texels
	var to: Vector2 = stamp.uv_to * texels

	# The crosshair covers ground between physics ticks. Drawing one quad per tick makes
	# a fast stroke come out as a dotted line, so fill the gap with a row of them.
	var step := maxf(radius_texels * stamp.spacing, 1.0)
	var span := from.distance_to(to)
	var wanted := maxi(int(ceilf(span / step)), 1)
	var count := clampi(wanted, 1, _quads.size() - first)
	if count < wanted:
		_warn_overflow()

	# The can emitted a fixed amount of paint this tick. Smeared over a longer path it
	# has to be thinner everywhere. This is the same conservation idea as the radius²
	# divide in the can, and it is why a quick sweep is a pale streak and a held hand
	# saturates — neither behaviour is tuned in, both fall out of dividing by count.
	var alpha := stamp.peak_alpha / float(count)

	for i in count:
		# Quads run over (0, 1], deliberately skipping uv_from. That point is where the
		# LAST frame's stroke ended and was already painted; putting a quad there too
		# double-doses every frame boundary, which shows up as a regular dashing along
		# an otherwise steady line.
		#
		# It also makes the stroke exactly uniform: spacing is span/count, so each of
		# the `count` quads carries peak/count and the paint per unit length comes out
		# independent of how many quads the frame happened to need.
		var t := float(i + 1) / float(count)
		var quad := _quads[first + i]
		quad.visible = true
		quad.position = from.lerp(to, t)
		quad.rotation = stamp.stretch_angle
		# The mesh is a unit square, so scaling by the diameter gives the right size.
		# Scaling X more than Y is what turns the circular cone into §5.3's ellipse;
		# rotation aims the long axis. brush.gdshader stays a plain radial falloff.
		quad.scale = Vector2(radius_texels * 2.0 * stamp.stretch, radius_texels * 2.0)

		var mat: ShaderMaterial = quad.material
		mat.set_shader_parameter("paint_color", stamp.color)
		mat.set_shader_parameter("peak_alpha", alpha)
		mat.set_shader_parameter("falloff", stamp.falloff)
		mat.set_shader_parameter("buffer_size", texels)
		mat.set_shader_parameter("wall_grain", wall_grain)
		mat.set_shader_parameter("grain_scale", grain_scale)

		# The same quad again, in the PaintData buffer. Position, rotation and scale are
		# copied rather than recomputed so the two buffers cannot drift apart.
		var wet_quad := _wet_quads[first + i]
		wet_quad.visible = true
		wet_quad.transform = quad.transform
		var wet_mat: ShaderMaterial = wet_quad.material
		# Scaled by what the stamp actually laid, so a solid pass soaks the wall while an
		# overspray haze barely dampens it.
		wet_mat.set_shader_parameter(
			"wetness", clampf(alpha * wetness_gain, 0.0, 1.0)
		)
		wet_mat.set_shader_parameter("falloff", stamp.falloff)

		# Mirror what we just drew into the grid that decides where paint runs. Feeding
		# it here rather than from the can means it sees every quad exactly as the GPU
		# does, including the sub-frame ones — the grid cannot drift out of step with
		# the picture.
		#
		# The solver gets the stamp's uncut peak and this quad's share of it separately,
		# because it has to apply its absorb-rate cap to the whole frame's flow before
		# the split, not to each quad after it.
		if stamp.contributes_thickness:
			_drips.deposit(quad.position, radius_texels, 1.0 / float(count), stamp)

	return first + count


func _warn_overflow() -> void:
	if _overflowed:
		return
	_overflowed = true
	push_warning(
		"PaintSurface '%s': ran out of brush quads in one frame. Raise "
		% name + "max_quads_per_frame, or raise the can's stamp_spacing."
	)
