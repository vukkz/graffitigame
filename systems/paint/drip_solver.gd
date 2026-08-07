class_name DripSolver
extends RefCounted
## Drips — GDD §5.4, "the money feature".
##
## Deliberately not a fluid simulation. A coarse CPU grid mirrors how much wet paint is
## sitting where; when a cell goes over threshold it launches an agent that walks
## downhill stamping a thinning trail into the same buffer the spray uses.
##
## That works because a drip is a *shape*, not a physics problem. What people recognise
## is the tapering run — wide where you over-sprayed, narrowing as the paint runs out.
## Nobody has ever looked at a wall and checked the surface tension.
##
## Two things here are not obvious and both were bugs before they were features:
##
## 1. THE ABSORB RATE. Deposition goes as 1/distance², so up close a single frame asks
##    for several times full coverage. The picture clamps that (a wall cannot be more
##    than covered) but the drip grid used to count all of it, so painting close by
##    dripped no matter how fast you moved. Paint arriving faster than the wall can take
##    it does not pile up, it blows back off — so the rate is capped here too.
##
## 2. NO PERIODIC SCAN. Cells decay lazily from a timestamp and are only tested when
##    something lands on them, because a cell can only cross the threshold on deposit.
##    That is what makes a fine grid affordable: cost tracks what you are painting, not
##    how big the wall is.
##
## Owned by one PaintSurface and reads its tuning, so every drip knob lives on the wall's
## Inspector page next to everything else.

## One running drip. Lives a second or two and is then forgotten; the paint it laid stays
## in the buffer forever, like everything else.
class Drip extends RefCounted:
	var pos := Vector2.ZERO  ## Head position, in buffer texels.
	var prev := Vector2.ZERO
	var speed := 0.0  ## Texels per second.
	var radius := 0.0  ## Texels, at birth.
	var life := 1.0
	var hang := 0.0  ## Seconds spent pooling before it breaks and runs.
	var age := 0.0
	var drift := 0.0  ## Sideways lean, so runs are not all parallel.
	var color := Color.WHITE

var _surface: PaintSurface
## Wet paint per cell, in coverage units: 1.0 is one solid pass worth sitting on top.
var _cells := PackedFloat32Array()
## When each cell was last written, on `_clock`. Lets cells dry lazily instead of the
## whole grid being walked every frame.
var _time := PackedFloat32Array()
## Colour last landed in each cell, so a run is made of the paint that caused it.
var _colors := PackedColorArray()
var _w := 0
var _h := 0
var _texels_per_cell := 1.0
var _clock := 0.0
var _down_cell := Vector2i(0, 1)
var _live: Array[Drip] = []


func _init(surface: PaintSurface) -> void:
	_surface = surface


func live_count() -> int:
	return _live.size()


## Called when the buffer is resized, and once at startup.
func resize(buffer_texels: Vector2i) -> void:
	_texels_per_cell = maxf(
		_surface.texels_per_meter / maxf(_surface.drip_cells_per_meter, 0.1), 1.0
	)
	_w = maxi(int(ceilf(float(buffer_texels.x) / _texels_per_cell)), 1)
	_h = maxi(int(ceilf(float(buffer_texels.y) / _texels_per_cell)), 1)
	var down := _surface.down_in_buffer()
	_down_cell = Vector2i(int(roundf(down.x)), int(roundf(down.y)))
	clear()


func clear() -> void:
	var n := _w * _h
	_cells.resize(n)
	_cells.fill(0.0)
	_time.resize(n)
	_time.fill(0.0)
	_colors.resize(n)
	_colors.fill(Color.WHITE)
	_live.clear()


func update(delta: float) -> void:
	_clock += delta
	if not _surface.drips_enabled or _w == 0:
		return
	_advance(delta)


## Record paint landing. `center` and `radius` are in buffer texels; `share` is this
## quad's fraction of the stamp's peak, since one frame's spray is drawn as several.
func deposit(center: Vector2, radius: float, share: float, stamp: PaintSurface.Stamp) -> void:
	if _w == 0 or stamp.peak_alpha <= 0.0 or not _surface.drips_enabled:
		return

	# See note 1 at the top. Cap what the wall can take per second, THEN split across the
	# frame's quads — capping each quad instead would let a fast stroke sneak `count`
	# times the limit through. The ceiling comes from the stamp because it belongs to
	# the cap: a fat cap pushes past it sooner, which is why fat caps run.
	var usable: float = (
		minf(stamp.peak_alpha, stamp.absorb_rate * stamp.delta) * share
	)
	if usable <= 0.0:
		return
	var color := stamp.color

	var cx := center.x / _texels_per_cell
	var cy := center.y / _texels_per_cell
	# The real cone radius drives the mask, so a cell only accumulates while the cone
	# genuinely covers it. Clamping this upward is what made close range drip 8x too
	# readily; see the header.
	var cr := radius / _texels_per_cell
	var threshold := _surface.drip_threshold()
	var tau: float = maxf(_surface.drip_wet_seconds, 0.01)

	# A cone narrower than a cell cannot be resolved by the grid: whether any cell centre
	# happens to fall inside it comes down to sub-cell luck, so a skinny cap up close was
	# scoring anywhere from nothing to full depending on where the crosshair sat. Credit
	# the one cell it is inside, at full weight. Paint really is landing there.
	if cr < 0.75:
		_add(
			clampi(int(cx), 0, _w - 1),
			clampi(int(cy), 0, _h - 1),
			usable,
			threshold,
			tau,
			cr,
			color,
		)
		return

	var x0 := maxi(int(floorf(cx - cr)), 0)
	var x1 := mini(int(ceilf(cx + cr)), _w - 1)
	var y0 := maxi(int(floorf(cy - cr)), 0)
	var y1 := mini(int(ceilf(cy + cr)), _h - 1)

	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			# Half a cell is subtracted before the falloff is applied because a cell is a
			# square, not a point, and what decides whether paint runs is the THICKEST
			# film inside it. Without this the cell under the cone's centre is docked by
			# however far its centre happens to sit from the crosshair, which cost a fat
			# cap most of its advantage over a skinny one on a held trigger.
			var away := Vector2(float(gx) + 0.5 - cx, float(gy) + 0.5 - cy).length()
			var d := maxf(away - 0.5, 0.0) / cr
			if d >= 1.0:
				continue
			_add(gx, gy, usable * (1.0 - d), threshold, tau, cr, color)


## Put paint in one cell, dry it first, and launch a run if it is now over the line.
func _add(
	gx: int,
	gy: int,
	amount: float,
	threshold: float,
	tau: float,
	radius_cells: float,
	color: Color,
) -> void:
	var i := gy * _w + gx
	var v: float = _cells[i] * exp(-(_clock - _time[i]) / tau) + amount
	_time[i] = _clock
	_colors[i] = color

	if v >= threshold and _live.size() < _surface.max_drips:
		# How far over the line it went decides how big the run is. A line drawn just
		# slowly enough beads up in small dots; a held trigger throws a fat one. Same
		# mechanic, two different-looking mistakes.
		var strength := clampf(v / threshold, 1.0, 2.5)
		var from := _lower_edge(gx, gy, tau, v, radius_cells)
		v -= threshold
		_spawn(from.x, from.y, color, strength)

	_cells[i] = v


## Walk down to the bottom of the wet patch and start the run from there.
##
## Paint piles up thickest in the middle of where you sprayed, so that is where the
## threshold has to be tested — but it runs off the LOWEST edge of what is wet, not out
## of the middle. Starting runs at the trigger cell makes them sprout from the centre of
## a fill like a leaking ceiling.
##
## An earlier version used this as a veto instead of a move — "only spawn if the cell
## below is dry" — which suppressed drips entirely: the centre was blocked by its wet
## neighbour, and the true bottom edge never caught enough paint to trigger.
##
## The walk is bounded twice over, and both bounds matter:
##
## - By the CONE. It may only travel as far as the thing you just sprayed is wide. An
##   unbounded walk marches down through paint from earlier in the session and launches
##   the run half a metre below your hand, detached from any mark — which is exactly
##   what it did on a throw-up, where the fill underneath was still wet.
## - By how WET the ground is compared to the trigger cell. Old thin paint is not part
##   of the puddle you just made and should not carry the run down into it.
func _lower_edge(
	gx: int, gy: int, tau: float, here: float, radius_cells: float
) -> Vector2i:
	var steps := clampi(int(ceilf(radius_cells)), 1, 4)
	var x := gx
	var y := gy
	for step in steps:
		var nx := x + _down_cell.x
		var ny := y + _down_cell.y
		if nx < 0 or nx >= _w or ny < 0 or ny >= _h:
			break
		var j := ny * _w + nx
		var below: float = _cells[j] * exp(-(_clock - _time[j]) / tau)
		if below <= 0.05 or below < here * 0.35:
			break
		x = nx
		y = ny
	return Vector2i(x, y)


func _spawn(gx: int, gy: int, color: Color, strength: float) -> void:
	var d := Drip.new()
	# Jittered inside the cell, or every run on the wall starts on a visible grid.
	d.pos = Vector2(
		(float(gx) + randf()) * _texels_per_cell,
		(float(gy) + randf()) * _texels_per_cell,
	)
	d.prev = d.pos
	d.speed = _surface.drip_speed * _surface.texels_per_meter
	d.radius = (
		_surface.drip_radius
		* _surface.texels_per_meter
		* randf_range(0.75, 1.3)
		* sqrt(strength)  # Area scales with paint, so radius scales with its root.
	)
	# More paint also runs further before it is spent.
	d.life = randf_range(_surface.drip_lifetime.x, _surface.drip_lifetime.y) * strength
	d.hang = randf_range(_surface.drip_hang.x, _surface.drip_hang.y)
	d.drift = randf_range(-1.0, 1.0) * _surface.drip_wander
	d.color = color
	_live.append(d)


func _advance(delta: float) -> void:
	if _live.is_empty():
		return

	# §5.4 is specific that this is world-down projected into the surface, not "+Y in the
	# texture". On a leaning wall those are different directions, and the wrong one reads
	# as broken instantly.
	var down := _surface.down_in_buffer()
	var side := Vector2(-down.y, down.x)
	var accel := _surface.drip_accel * _surface.texels_per_meter
	var height := float(_surface.buffer_size().y)
	var base_taper := _surface.drip_taper
	var bead := _surface.drip_bead

	var i := _live.size() - 1
	while i >= 0:
		var d: Drip = _live[i]
		d.age += delta
		d.prev = d.pos

		# Paint pools before it breaks and runs. Stamping in place for a moment is what
		# gives a run its heavy head instead of starting mid-air at full speed.
		if d.age > d.hang:
			d.speed += accel * delta
			d.pos += (down + side * d.drift).normalized() * d.speed * delta

		if d.age >= d.life or d.pos.y > height + d.radius:
			_live.remove_at(i)
			i -= 1
			continue

		var run := maxf(d.life - d.hang, 0.001)
		var t := clampf((d.age - d.hang) / run, 0.0, 1.0)

		# Squared so it holds its width for the first half and then closes quickly —
		# a linear taper reads as a wedge, not as paint running out.
		var shape := lerpf(1.0, base_taper, t * t)
		# Small bead near the end, where a real run stalls and the paint gathers.
		shape *= 1.0 + bead * exp(-pow((t - 0.86) / 0.1, 2.0))

		var stamp := PaintSurface.Stamp.new()
		stamp.uv_from = _surface.buffer_to_uv(d.prev)
		stamp.uv_to = _surface.buffer_to_uv(d.pos)
		stamp.radius_meters = d.radius / _surface.texels_per_meter * shape
		stamp.stretch = 1.0
		stamp.falloff = 2.4  # Drips have an edge; they are liquid, not aerosol.
		# Only a light fade. The narrowing radius does the tapering, and fading hard on
		# top of it turns the tail into a stray hair instead of thinning paint.
		stamp.peak_alpha = _surface.drip_alpha * (1.0 - 0.25 * t * t)
		stamp.color = d.color
		stamp.spacing = 0.5
		# Critical: a drip must not feed the grid that spawned it, or the first run
		# triggers a second, which triggers a third, and the wall bleeds forever.
		stamp.contributes_thickness = false
		_surface.queue_stamp(stamp)
		i -= 1
