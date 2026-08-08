class_name SprayCap
extends Resource
## One cap — everything that changes when you twist a different nozzle onto the can
## (GDD §5.3, §5.7).
##
## These live as .tres files in systems/paint/caps/ so skinny and fat can be tuned
## against each other and independently, which is the whole point: §5.7 assigns a cap
## per pass, so outline and fill are different tools, not one slider at two settings.

## Shown in the HUD on swap. Keep it short.
@export var display_name := "Skinny"

## Half-angle of the spray cone — the only thing deciding how fast the line widens with
## distance (§5.3 step 3).
##
## Calibrated for where a first-person player stands, NOT for a real can. Real writers
## work 15–40 cm from the wall; in first person you naturally stand back about a metre,
## so the cone must be narrower than life to give a believable line at the range you are
## actually at.
##
## Line width at 0.8 m:  2.2° ≈ 8 cm skinny · 5.6° ≈ 17 cm fat. §16 point 7 wants a cap
## swap to change line width by 3–4×, and that pair is ~2×; a genuinely fat cap goes
## above 5.6 and belongs to a can you have to find, not the starting one.
##
## 1.6° is a hairline — too fine to write with comfortably as a default, but exactly
## right as a specialist cap earned later (a banana / NY thin). Keep the number.
@export_range(0.2, 15.0, 0.1) var cone_half_angle_deg := 1.6

## Radius of the cone as it leaves the nozzle, metres. Its real job is keeping the
## radius² divide from exploding when the wall is 2 cm from your face.
@export var nozzle_radius := 0.006

## Seconds a held cone takes to cover the wall solid at the can's reference distance.
##
## This is §5.3's `cap_flow` in a unit you can feel. Flow is derived as
## `cap_flow = C × radius(reference_distance)²`, so the reference radius is a constant
## and deposition still falls off as exactly 1/radius² — this picks the constant and
## changes nothing about the curve the GDD calls non-negotiable.
##
## Deriving it also closes a trap: with a raw flow number, widening the cone divides
## your paint by the square of the change, so a "fat cap" came out as a faint smudge
## instead of a fat line. Real fat caps have bigger orifices and push more paint; tying
## flow to the cone keeps that true without anyone having to remember it.
##
## LOWER IS STRONGER — and lower also RUNS SOONER. The drip grid reads this as how hard
## the cap pushes paint at the wall, so a fat cap that covers twice as fast also starts
## dripping on a held trigger in about half the time. That is one number doing both jobs
## on purpose: in life they are the same fact about the orifice.
@export_range(0.005, 0.5, 0.005) var seconds_to_solid := 0.035

## Edge hardness of the cone's SHOULDER. High is a crisp skinny line, low is a soft
## cloud. Changing this does not change how much paint comes out; see the can's
## _cone_normalisation().
@export_range(0.2, 8.0, 0.1) var falloff := 2.0

## Fraction of the cone that lands at FULL strength before the shoulder starts.
##
## The single most important number for whether paint reads as paint. A pure falloff
## curve peaks at one point, so a moving stroke saturates only along its centreline and
## the rest of the width is a ramp — over grey concrete that composites to mid grey, and
## the line reads as wax crayon rather than as spray.
##
## Real cones have a saturated core and a shoulder where the spray breaks up. Tighter
## caps have a proportionally bigger core (less air, less turbulence); fat caps are
## cloudier, so theirs is smaller.
##
## Costs nothing: the can pins peak alpha to `seconds_to_solid` whatever the profile is,
## so widening the core widens the SOLID part of the line without touching how fast the
## centre covers. 0.0 is the old pure-falloff behaviour, kept so it can be A/B'd.
@export_range(0.0, 0.95, 0.01) var core_frac := 0.5

## How much wider the powder is than the cone itself. §5.3 step 7 calls overspray
## non-negotiable: real spray always hazes, and its absence reads instantly as fake.
##
## REACH IS THE SAFETY VALVE, not `overspray_share`. The paint buffer blends
## dst = src + dst*(1 − src.a), which climbs to fully opaque at ANY rate given enough
## passes — nothing in it ever stops. So every point inside this disc goes solid
## eventually, and the only question is how far out "eventually" reaches. At 2.4–2.6 it
## reached far enough to swallow the gaps between letters, which is why a piece turned to
## grey mush the longer it was worked on. Keep this under ~2.0 and the buildup stays a
## fringe hugging the line, where paint belongs.
@export_range(1.0, 6.0, 0.1) var overspray_radius_mult := 2.0

## Share of flow leaving as powder instead of as line. Taken out of the core, not added
## on top, so the total is still one can's worth of paint.
##
## This is the "high pressure blows dry paint past the line" effect, and it is a real
## part of how a fat cap reads — a fat line without it looks printed. Fatter caps get
## more, which is also why they are the caps that make a mess of a wall.
##
## Small numbers: the powder is spread over mult² times the area of the core, and it
## BUILDS, so what is invisible on one pass is obvious after twenty. Tune it by painting
## a whole throw-up and looking at the wall afterwards, never by spraying one line.
##
## Note the soft edge of a line is NOT this — that is the cone's own shoulder, see
## `core_frac`. Those were one stamp doing two jobs, and no single value could satisfy
## both: what reads on one pass buries the wall by pass thirty.
@export_range(0.0, 0.2, 0.0005) var overspray_share := 0.004

## How speckled the powder is, 0 = smooth haze, 1 = heavy grit.
##
## What makes overspray read as POWDER rather than as fog. Real overspray is dry paint
## that lost its momentum — it lands as particles, not as a wash. The noise is anchored
## to the wall (same field the core uses for `wall_grain`), so repeated passes reinforce
## the same speckle instead of averaging into a smooth grey, which is the whole
## difference between "dusty" and "dirty".
##
## Fat caps push harder and atomise worse, so theirs is coarser.
@export_range(0.0, 1.0, 0.01) var overspray_grain := 0.55

## How fast this cap eats paint and pressure, relative to the skinny cap at 1.0.
##
## A fat cap has a bigger orifice: it covers faster because it dumps more paint, and it
## empties the can to match. This is the cost that makes cap choice a decision rather
## than a free upgrade — the fat cap fills in a third of the time and buys it with two
## thirds of your can.
##
## It could be derived from flow × cone area (the numbers are all here), but that comes
## out at ~14x between skinny and fat, which is true of real cans and miserable in a
## game. Exposed instead so the spread stays a design choice.
##
## Paint scales with this directly; PRESSURE scales with its square root, because gas
## escapes more slowly than paint does — and because a fat cap that needed re-shaking
## every nine seconds would undo the whole point of a long pressure life.
@export_range(0.1, 12.0, 0.1) var drain_rate := 1.0

## Edge hardness of the haze. Keep it well below `falloff` — overspray has no edge,
## that is what makes it read as overspray and not as a second, wider line.
@export_range(0.2, 8.0, 0.1) var overspray_falloff := 1.1
