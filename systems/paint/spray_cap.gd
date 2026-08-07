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

## Edge hardness of the cone. High is a crisp skinny line, low is a soft cloud.
## Changing this does not change how much paint comes out; see the can's
## _falloff_normalisation().
@export_range(0.2, 8.0, 0.1) var falloff := 2.0

## How much wider the haze is than the cone itself. §5.3 step 7 calls overspray
## non-negotiable: real spray always hazes, and its absence reads instantly as fake.
@export_range(1.0, 6.0, 0.1) var overspray_radius_mult := 2.4

## Share of flow leaving as haze instead of as line. Taken out of the core, not added
## on top, so the total is still one can's worth of paint.
@export_range(0.0, 0.9, 0.01) var overspray_share := 0.13

## Edge hardness of the haze. Keep it well below `falloff` — overspray has no edge,
## that is what makes it read as overspray and not as a second, wider line.
@export_range(0.2, 8.0, 0.1) var overspray_falloff := 1.1
