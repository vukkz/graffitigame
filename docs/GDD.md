# Game Design Document — Untitled Belgrade Graffiti Game

*Living document. Last revised 2026-08-05.*

## Context

A first commercial indie game: first-person, story-driven, set in mid-2000s Belgrade, following a
17-year-old drawn into graffiti and underground hip-hop while his home and school life come apart.
Built solo by a developer coming from web and mobile — comfortable with scripting, no prior engine
experience.

This document is both the design bible and the production plan. It exists because the failure mode for a
first commercial 3D narrative game is not "bad idea" — it's **scope**. Most such projects die at 40%
completion, 18 months in, with no shippable artifact. So this document is written to be aggressively
scope-disciplined: it defines a small, complete, *finishable* game, and it front-loads the one question
that decides whether the project is worth doing at all (is the painting fun?) into the first three months.

**Decisions locked from the planning conversation:**
- Engine: **Godot 4.x + GDScript** (rationale in §12)
- Hardware: Ryzen 5 5600X / RTX 3050 / 12GB as primary dev machine
- Era: **mid-2000s Belgrade, ~2005–2006**
- Painting skill model: **guided three-pass (outline → fill → highlight), stencil-scored**

---

## 0. The Pitch

> Belgrade, 2005. You're seventeen. Your father drinks in the next room, your mother works two jobs, and
> school has already written you off. At night you go out with a bag of cans and put your name on a city
> that never asked for it. By morning it might be painted over. You go out again.

**Genre:** First-person narrative adventure with a deep tactile core mechanic
**Length:** 3–4 hours
**Price:** €12–15
**Platform:** PC (Steam), Windows first, Linux/Proton-compatible, macOS later if ever
**Rating:** PEGI 16–18 / ESRB M (alcohol, drug references, crime, language, domestic conflict)
**Language:** Serbian VO (deferred), English + Serbian subtitles

**Title candidates:** `PREKO` (to go over another's piece — the central metaphor) · `TIHI` (the quiet one —
the protagonist's tag) · `BETON` (concrete) · `NOĆNA SMENA` (night shift). Recommend deciding at Milestone 4,
not now — the title should come from the finished thing.

**The hook, in one line:** *the only game where spraying a wall actually feels like spraying a wall.*
That's the marketing, that's the review-quote, that's the reason someone picks this over a thousand other
narrative indies. Everything below serves it.

---

## 1. Core Gameplay Loop

Three nested loops. Every design decision should be traceable to one of them.

### 1.1 Moment-to-moment (seconds) — *the Can*
```
aim → judge distance → pull trigger → watch paint land → feel pressure drop
   → manage the drip forming → release → step / re-angle → repeat
```
This is where 60% of the player's total input happens. It must be good in a gray box with no context.

### 1.2 Session (minutes) — *the Piece*
```
approach spot → read it (sightlines, reach, wall surface, heat)
  → pick sketch + palette + caps → OUTLINE pass → FILL pass → HIGHLIGHT pass
  → tag it → photograph it → get out
```

### 1.3 Chapter (30–45 min) — *the Life*
```
HOME (obligation, pressure, a request you can't meet)
  → SOCIAL (school / street / crew — information and relationships)
  → MATERIALS (money vs. paint vs. what mom needs — the real choice)
  → APPROACH (get to the spot)
  → PAINT (the session loop)
  → CONSEQUENCE (cred ↑, heat ↑, someone notices, someone is hurt)
  → HOME (the world has changed slightly)
```

**The thesis:** graffiti is the *verb*; the home scenes are the *point*. If the player is only having fun
in the paint sections, the game has failed at being what it claims to be. If the player is only interested
in the story, the game has no reason to be a game. Both must land.

---

## 2. Story Structure

### 2.1 Setting

Belgrade, roughly 2005–2006. Deliberately chosen: post-Milošević, post-Đinđić, the country in a grey
limbo. Serbia and Montenegro dissolves in 2006. The hip-hop scene is genuinely exploding. Nokia 3310s,
prepaid credit, SMS, dial-up, burned CDs, internet cafés, mp3 CDs traded at school. Turbo-folk on the
splavovi as the cultural enemy. The city is broke, grey, and enormously alive at 3am.

**Politics stays ambient, never plot.** Posters, graffiti, TV noise through a window, a father's bitter
monologue. The moment the game becomes About Serbian Politics, it stops being about a kid and his mother,
and you lose both the story and half the audience.

### 2.2 Themes

- **Being seen.** A boy nobody looks at, writing his name ten feet tall.
- **Everything gets buffed.** The city erases you. You do it anyway. That's not despair, that's the point.
- **Making vs. destroying.** The game never resolves this for you. Neither does life.
- **Stuckness.** Vuk is 22 and washing cars. Stefan can see his own future in him.

### 2.3 Three-act spine

**ACT I — "Tvoje ime" / Your Name** (≈45 min, 3 missions)
Stefan tags out of boredom and anger — small, ugly, alone. Vuk catches him mid-tag and doesn't beat him
up; he corrects his hand position. First real wall. First time something he made outlived the night.
Home: mother asks for money for the electric bill. He has money — for paint.
*Ends on:* his first piece photographed by Milica, and his father finding cans under the bed.

**ACT II — "Krv i beton" / Blood and Concrete** (≈2h, 7 missions)
Crew life. Spots escalate: wall → shop shutter → rooftop → the quay → the tram depot.
Kobra's crew goes over Stefan's best piece with a line through his name.
Boban starts offering money for errands — small, then not small.
Milica's photos get the crew attention from a magazine / a nascent scene blog.
School disciplinary track closes in; Prof. Jovanović offers one last off-ramp.
*Midpoint:* an offer to paint something commercial and legal for real money. Sell out, or stay.
*Act II low point:* the reckless spot goes wrong. Someone is caught, hurt, or gone. Vuk's fault. Or Stefan's.

**ACT III — "Preko" / Over** (≈45 min, 3 missions)
Home crisis peaks — the father's health, or an eviction notice, or the mother's ultimatum.
The final piece: a memorial/statement on the most visible, most dangerous spot in the game.
The player chooses *what* to paint from options that mean different things — an apology, a name, a scream.
*Ends on:* not victory. A morning. Whether the piece is still there is not the question the ending asks.

### 2.4 Branching — and the hard limit on it

**Rule: wide-in, narrow-out.** Scenes let the player express a lot; outcomes converge. Divergent branching
dialogue is the #1 scope killer for solo devs — every branch is writing, VO, animation, testing, and bug
surface, multiplied.

**The entire game tracks five floats:** `mother`, `vuk`, `milica`, `integrity`, `notoriety`.
Dialogue reads them; **three (max four) endings** are selected by thresholds at the end of Act III.
No branch is longer than one scene before it reconverges. This gives real felt consequence at maybe 15%
of the production cost of true branching.

---

## 3. Mission Progression

**13 missions, ~3.5 hours.** A first commercial indie is better at 3 polished hours than 8 thin ones.
Short-and-dense is also the correct commercial position at €12–15.

**Only five verbs exist in the whole game.** Every mission is a recombination. Adding a sixth verb
is a scope decision that must be argued for, not assumed.

| # | Verb | What it is | Systems required |
|---|------|-----------|------------------|
| 1 | **PAINT** | The core loop | Paint system, scoring, passes |
| 2 | **REACH** | Get to a spot: climbing set-pieces, timing past a guard, fitting through a gap | Simple traversal, scripted patrols, LOS cone |
| 3 | **TALK** | Home/school/crew scenes, walk-and-talks with choices | Dialogue system, relationship floats |
| 4 | **ACQUIRE** | Buy, beg, work for, or steal paint and materials | Economy, shop UI, one racking minigame |
| 5 | **WITNESS** | Low-interaction scenes: a cypher, a show at Akademija, a fight you can't stop | Scripted sequences, audio |

### 3.1 Mission list (production checklist)

| # | Act | Title | Verbs | New thing it teaches |
|---|-----|-------|-------|---------------------|
| 1 | I | Zid iza škole | PAINT, TALK | Can basics, shake, one cap |
| 2 | I | Vuk | TALK, PAINT | Outline pass, cap swap, mentor |
| 3 | I | Struja *(the electric bill)* | ACQUIRE, TALK | Money as moral choice |
| 4 | II | Roletna *(the shutter)* | ACQUIRE, PAINT | Fill pass, commissions, colour |
| 5 | II | Krov *(the roof)* | REACH, PAINT | Height, reach limits, heat |
| 6 | II | Kej *(the quay)* | PAINT, WITNESS | Highlight pass, big canvas, crew |
| 7 | II | Kobra | TALK, PAINT | Going-over, rivalry, spill scoring |
| 8 | II | Boban | ACQUIRE, TALK | Compromise, integrity float |
| 9 | II | Akademija | WITNESS, TALK | Music scene, Milica, the offer |
| 10 | II | Depo *(tram depot)* | REACH, PAINT | Peak risk, guide-off multiplier |
| 11 | II | Buff | WITNESS, TALK | The low point. Loss. |
| 12 | III | Kuća *(home)* | TALK | The confrontation. No painting. |
| 13 | III | Preko | REACH, PAINT | Final piece, player chooses meaning |

**Note on Mission 12:** a full mission with no painting, late in the game, is deliberate. If the game has
worked, the player will feel that absence.

### 3.2 Gating

Missions unlock linearly by chapter. Within a chapter, 1–2 optional side spots are available (free walls,
small commissions) that feed Cred and money. **No open-ended mission generator.** Procedural missions are
how a 3-hour game becomes an unshippable 3-year game.

---

## 4. Characters

Eight speaking characters. Every additional character costs a model, a rig, animations, writing, VO, and
bug surface. Eight is already generous.

| Character | Age | Role | The one thing that makes them real |
|-----------|-----|------|-----------------------------------|
| **Stefan Marić — "TIHI"** | 17 | Player | Never speaks at home. Draws in the margins of every notebook. His tag means "the quiet one" and it's a joke only he gets. |
| **Vuk Perić — "RUS"** | 22 | Mentor, friend | Works at a car wash. Knows everyone. Generous with everything he doesn't have. He is what happens if you never leave — and he knows it, which is why he pushes Stefan out. |
| **Milica Stanković** | 17 | Photographer | Has her grandfather's film camera. Documents the scene because she wants out and thinks a portfolio is the door. Not a prize; a person with her own exit plan. Romance optional and understated. |
| **Dejan — "KOBRA"** | 19 | Rival | Bigger crew, football-terrace adjacent. Not a villain — he's Stefan with two more years and no Prof. Jovanović. Goes over Stefan's work because that's the language he has. |
| **Vesna Marić** | 44 | Mother | Two jobs. Comes home at 11 and cooks. Loves him and has no idea who he is. **The relationship the game is actually about.** |
| **Dragan Marić** | 49 | Father | Was an engineer at a factory that closed in '01. Drinks. **Critically: not a monster.** He is ordinary, disappointed, and occasionally kind, which is worse. If he reads as a cartoon abuser the whole story collapses into melodrama. |
| **Boban** | 35 | Fixer | Runs things out of a kafana. Never threatens. Just keeps being useful until you owe him. |
| **Prof. Jovanović** | 50s | Teacher | Small role, heavy weight. Sees the drawings. Offers one real off-ramp. The player can take it or not. |

Plus 3–4 non-speaking crew members for barks and crowd presence (reuse one body, swap heads/jackets).

**Player representation:** first-person throughout. Stefan is seen only in mirrors, in Milica's
photographs, and as hands/forearms. This is a deliberate art-budget decision — no full-body player
model, no IK rig, no third-person animation set — and it also serves the theme (a boy who is not seen).

---

## 5. Graffiti Mechanics — *the heart of the game*

This is the section to over-engineer. Everything else can be adequate; this must be excellent.

### 5.1 Design principle: tactile, not simulated

Real spraying is slow, physically punishing, and unforgiving. A faithful simulation would be tedious.

> **Simulate the *feedback* honestly. Abstract the *labour*.**

| Simulate faithfully | Abstract away |
|---|---|
| Pressure drop and sputter | Arm fatigue |
| Distance → cone width and density | Real-time piece duration (compress 40 min → 4 min) |
| Drips from over-application | Fume effects, weather |
| Wall texture resisting paint | Exact paint chemistry, temperature |
| Overspray haze | Precise nozzle fluid dynamics |
| Wet sheen drying over ~30s | Multi-day cure |
| The ball rattle, the cap click | — |

### 5.2 Surface data model

Each paintable wall is a `PaintSurface` with a unique non-overlapping UV1 channel.

**Two accumulation textures**, held in a `SubViewport` with `CLEAR_MODE_NEVER`:

- **`PaintColor` (RGBA8)** — RGB = deposited colour, A = coverage/opacity
- **`PaintData` (RGBA8)** — R = wetness (drives drips + sheen, decays over ~30s), G = thickness (drives
  drip threshold, slight normal perturbation), B = age, A = pass ID (which of the three passes laid it —
  used for scoring)

The wall's surface shader composites `PaintColor` over the base albedo, drives roughness from
`PaintData.R` (wet paint is glossy — this single line does an enormous amount of convincing work), and
perturbs the normal slightly from `PaintData.G` (thick paint has body).

### 5.3 The spray tick

Each physics frame while the trigger is held:

1. **Raycast** from camera through crosshair → hit point, hit normal, hit UV.
2. `dist = |hit − nozzle|`; `incidence = dot(−ray_dir, hit_normal)`.
3. **Cone radius in UV** = `f(dist, cap_type)`. Skinny cap: tight radius, sharp falloff exponent.
   Fat cap: 3–4× radius, soft falloff.
4. **Deposition rate** = `pressure × cap_flow × dt / radius²`.
   *Conserving paint across the cone area is the single line that gives you correct behaviour for free* —
   close means dense and fast, far means thin and hazy. Do not fudge this with hand-tuned curves.
5. **Angle stretch:** when `incidence < ~0.4`, stretch the brush into an ellipse along the projected ray
   direction. This is what makes spraying into corners and along walls feel right.
6. **Stamp:** draw a radial-falloff brush quad at the hit UV. Accumulate into `PaintColor.A`, lerp
   `PaintColor.RGB` toward the can colour. **Modulate deposition by sampling the wall's own roughness/AO
   map** so mortar lines, pits and rough concrete resist paint. This is the "wall fights back" feel and
   it is a bigger authenticity win than it sounds.
7. **Overspray:** a second, much wider, very-low-alpha stamp. Non-negotiable — real spray always hazes,
   and its absence is instantly readable as fake.
8. **Accumulate** wetness and thickness into `PaintData`.
9. **Pressure:** `pressure −= drain × dt`. Below ~25% → sputter: audio changes, stamp alpha gets noisy,
   radius shrinks and jitters. Shaking restores pressure (mixing, not refilling). **Paint volume** is a
   separate, slower resource; at zero the can is dead and you throw it away.

### 5.4 Drips — the money feature

Maintain a coarse CPU-side accumulator (64×64 per wall) mirroring deposition. When a cell crosses a
thickness threshold, spawn a `Drip` agent: a UV position, a downward velocity, a shrinking radius.
Each frame it advances along **world-down projected into UV** (this matters on angled walls) and stamps
a small thinning trail. Lifetime 1–3s. Cap ~30 live drips.

Drips cost you score — *and they look incredible*. Deliberately dripping should be a viable expressive
style (a "drippy" aesthetic), not purely a failure. This is the difference between a mechanic that
punishes and a mechanic that has a voice.

### 5.5 Shake

Rhythmic input: 8–12 presses at roughly 2Hz, led by the ball-rattle audio and a subtle can animation.
The ball rattle's pitch changes with how full the can is — free information, delivered diegetically.

**Under-shaking is allowed** and produces a visibly worse can: sputtery, uneven, patchy colour. That's
the entire teaching mechanism. A shake minigame you can't fail is a chore; one that changes the picture
is a mechanic.

*(Rejected: motion-based shaking via mouse waggle. More tactile in theory, awkward on gamepad, and
genuinely RSI-adjacent over a 3-hour game.)*

### 5.6 Body and reach

The camera has a height. Crouch lowers it; you can stand on crates, dumpsters, and a boost from Vuk.
Max comfortable reach ≈ 2.2m from your feet. Above that: arm fully extended, more sway, less control.

Cheap to implement, and it does three jobs at once — it's realistic, it gates composition, and it
generates the "I need to get higher" beat that drives half the level design.

### 5.7 The three passes, and how scoring works

The mission supplies a **sketch** from Stefan's blackbook, which provides a `GuideMask` (a filled shape
layer plus a line-art layer, authored in Krita).

**Guide visible** = a faint ghost projected on the wall. Diegetically honest — writers really do ghost
their outline first. **Guide hidden** = a large score multiplier. That's where the skill ceiling lives.

| Pass | Cap | Goal | Scored on |
|------|-----|------|-----------|
| **1. Outline** | Skinny | Trace the letter forms | Line-width consistency, deviation from guide path |
| **2. Fill** | Fat | Cover the interior | Coverage inside mask, spill outside mask |
| **3. Highlight / 3D** | Skinny | Offset accents, depth, final outline | Placement accuracy against a second mask layer |

**Score at mission end:**
- `Coverage` — mean alpha inside mask (want high)
- `Spill` — mean alpha outside mask, weighted by distance from the edge (want low; slight haze is fine,
  that's overspray and it should not be punished)
- `LineQuality` — variance of stroke width along the outline (want low)
- `Drips` — count (a few = character; many = sloppy)
- `Time` vs. the spot's heat budget

**Tiers:** Toy → Solid → Clean → **Burner**. (In-fiction Serbian equivalents in dialogue.)

This is transparent, cheap, readable, and it's how graffiti is actually made. Compare the alternative —
"the game evaluates your freehand art" — which is an unsolved computer-vision problem, is gameable, and
would feel arbitrary and hostile to playtesters. That path is where this project would die.

### 5.8 Persistence and going-over

On mission complete, bake final `PaintColor` to a PNG in the save directory keyed by wall ID. On level
load, walls with a stored PNG load it as a **static texture** — only the *currently active* wall gets a
live SubViewport. This is the answer to the performance problem: one render target at a time, ever.

**Going-over:** between chapters, Kobra's crew paints over your work — loaded as a decal composited on
top of your saved PNG. It costs almost nothing to implement and it is the theme of the entire game made
mechanical. When the player walks past their best piece with a line through it, that's the game working.

---

## 6. World Design

**Five hub locations. Not an open world.** An explorable Belgrade is a 100+ person-year project; GTA
comparisons are how indie games die. These are small, dense, hand-crafted spaces connected by loads,
scripted bus rides, and cuts.

| Hub | What it is | Approx. size | Mood |
|-----|-----------|--------------|------|
| **Stan** (the apartment) | Novi Beograd flat: two rooms, kitchen, tiny balcony, the stairwell | 60m² + stairwell | Terrazzo, green oil-paint dado, one bare bulb, TV noise |
| **Blok** | The block outside: parking, playground, kiosk (trafika), bakery, underpass | ~150×150m | Sodium orange, fog, distant boulevard |
| **Centar** | Two streets of Dorćol/Savamala: peeling facades, courtyard, shop shutters | 2 corridor streets | Warmer, older, cobbles, tighter |
| **Kej** | The quay: concrete flood wall, the river, a splav thumping across the water | 1 long strip | Wide, dark, wind, water |
| **Depo** | Tram depot at night: fences, wagons, floodlights, a guard | ~100×100m | Cold white light, hard shadow, tension |

Plus **3 interior set-pieces** reusing the interior kit: the school corridor, Akademija (the club),
Boban's kafana.

**Belgrade authenticity checklist** (this is your marketing advantage — get it right):
Cyrillic signage · trafike · burek at 3am · terrazzo stairwells · that specific green stairwell paint ·
satellite dishes and laundry lines on brutalist balconies · tiny two-person elevators · the 200-year-old
buildings next to concrete slabs · trolleybus wires · splav bass across the water · football-crew
graffiti everywhere (invent the crews — see §14) · "kod konja" as the meeting point.

**Level design rules:**
- Every hub has 2–4 paintable walls, only some of them mission-critical.
- Vertical reach is the primary level-design puzzle (§5.6).
- Sightlines matter: a wall visible from a lit street is higher heat and higher cred.
- **Darkness is a level design tool AND an asset budget.** You don't model what you don't light.

**Explicitly cut:** driving, fast travel network, a day/night cycle (fixed time-of-day per scene — this
is what lets you bake lighting, the single largest visual-quality-per-hour lever available to you),
weather systems, NPC crowd simulation, interiors you can't see into from the story.

---

## 7. Economy

**Three currencies. The economy exists to create one specific feeling: *there is never enough.***

### 7.1 Dinari (RSD) — scarce, moral

**Sources:** scraps of allowance · Boban's errands (pays well, costs `integrity`) · selling blackbook
sketches · shop-shutter commissions · **racking** (stealing from the paint shop — a short tense sequence
with a real fail state: heat + a permanently burned relationship with the shop).

**Sinks:** cans (colour-specific, ~250–400 RSD in fiction) · caps (cheap, consumable, and each cap type
is a real tactical choice) · markers · **film rolls and developing** (an authentically 2005 cost that
gates how much of your work gets documented — and documentation is how Cred happens) · bus tickets ·
club entry · **and the one that matters: mom asks for money for the electric bill.**

That last sink is the entire reason the economy exists. "Paint or the bill" is the game's thesis
expressed as a number.

**Hard rule: no grind.** Every repeatable income activity is capped per chapter with diminishing returns.
The moment a player can farm money, the moral weight evaporates and you've built a chore. Money must
always feel *slightly* insufficient — never impossibly so (that's just frustrating), never comfortably
so (that's no game at all).

### 7.2 Cred — earned, never bought

`Cred = piece_tier × spot_risk × visibility`

Where `visibility` = did it get photographed, is the spot seen, did it survive. **Unlocks:** crew
missions, dialogue options, access to better spots, how people talk to you. **Cannot be purchased.**

### 7.3 Heat — pressure, not punishment

Rises with bold spots and near-misses; decays over in-game days. Gates spot access ("that one's hot
this week"). **Design rule: heat reroutes you, it never hard-blocks you.** A currency that can lock a
player out of progress is a bug wearing a design hat.

---

## 8. Save System

**Structure:** one JSON file + one folder of wall PNGs, per slot. **3 manual slots + 1 autosave.**

**Save points:** the bed at home, chapter boundaries, and manual save anywhere *except* during timed or
scripted sequences. For a narrative game, generous saving is correct; the complexity cost is low if the
state model is disciplined from day one.

**Serialized state:**
```
save_version        ← MUST exist from the very first build
chapter, mission_id, mission_state_machine
flags: Dictionary[String, Variant]
inventory: cans (colour, volume), caps, markers, film
currencies: dinari, cred, heat
relationships: mother, vuk, milica, integrity, notoriety
player: scene_path, transform
walls: [ { id, png_path, tier, palette, pass_scores, timestamp, gone_over: bool } ]
```
Settings live in a **separate** file, never in the save.

**Two warnings, both learned the hard way by everyone who skips them:**

1. **`save_version` from day one.** Retrofitting migration onto a shipped save format is genuinely
   miserable. Write the version field and a `migrate()` stub in the very first save you ever write.
2. **Painted-wall persistence is the trickiest part of the system — budget it in Milestone 2, not later.**
   Storage math: a 1024² PNG is 200KB–1MB; 40 walls is up to 40MB per slot. **Mitigation: store at 512²,
   cap at 40 walls → ~10MB/slot.** Acceptable. *(Considered and rejected: storing a replayable command
   log of brush stamps. Far smaller, but replay is fragile against any tuning change to the paint system,
   and you will be tuning that system until the day you ship.)*

---

## 9. UI

**Diegetic-first. No persistent HUD.** The player's interface is a set of objects they own.

| Element | Design |
|---|---|
| **The blackbook** | The heart of the UI. A physical sketchbook: mission piece designs, tag practice, doodles that change with the story, photographs tucked between pages. **Spend your UI art love here.** This is the object players will remember. |
| **The phone** | A Nokia-style handset. **SMS is the mission delivery system** — perfect for 2005, and an SMS from your mother is the single most efficient guilt-delivery mechanism available to a game designer. Contacts, inbox, nothing else. |
| **The map** | A folded paper city map with hand annotations and biro circles. No GPS, no minimap, no waypoint arrow. Correct for the era and a far better object than a UI panel. |
| **Spray "HUD"** | Almost none. Cap type is visible on the can model. Colour is visible because you can see it. Pressure is read from sound and the can's shake. *(Optional accessibility toggle: a numeric pressure ring.)* |
| **Interaction prompt** | Small, contextual, fades out after first use per verb. |
| **Pause menu** | Minimal. Resume / Save / Settings / Quit. |

### 9.1 Accessibility — cheap now, expensive later, refund-driving if skipped

- Fully remappable input (keyboard + gamepad)
- FOV slider
- **Film grain, chromatic aberration, and head-bob toggles.** Your chosen art style will make some people
  physically ill. This is not optional and it is a direct driver of refunds and negative reviews.
- Subtitle size + background opacity; speaker names always on
- Hold-vs-toggle for spray and sprint
- Colourblind-safe UI accents (note: the *paint colours* are content, not UI — don't compromise those)

### 9.2 Typography — a specific trap

Pick a font with **full Serbian Cyrillic + Latin coverage on day one.** And specifically: **Serbian
Cyrillic has locale-specific italic glyph forms** (б, г, д, п, т render differently in `sr` than in `ru`).
A font that doesn't handle the `sr` locale will look subtly, immediately wrong to every Serbian player —
which is your entire core audience. This costs nothing to get right at the start and is a nightmare to
fix at the end.

---

## 10. Audio

**Audio is 50% of this game's atmosphere and it is the cheapest large win available to a solo dev.**
A mediocre-looking game with exceptional sound reads as atmospheric. The reverse reads as broken.

### 10.1 Ambience

3–5 layered beds per zone: a boulevard traffic bed · a tram · near-field events (a dog, a TV through a
window, an argument two floors up, the elevator motor, a splav thumping across the river). Beds
cross-fade on zone transitions via an `AudioDirector` autoload.

### 10.2 The can — a full SFX set, not one loop

`cap_click_on` · `ball_rattle` (**pitch varies with fill level** — free diegetic information) ·
`spray_start_burst` · `spray_sustain_loop` (**pitch and low-pass filter driven live by pressure**) ·
`close_splatter` (crossfades in under ~15cm — the wet slap that sells proximity) · `spray_tail_hiss_out` ·
`sputter` · `empty_click`

### 10.3 The backpack — a mechanic disguised as a sound

**Cans clink in your bag as you walk.** Louder when you run. It is unmistakable and instantly authentic —
*and it's a stealth liability during REACH missions.* One sound asset doing three jobs.

### 10.4 Footsteps, music, score

- Footsteps by material: terrazzo, concrete, gravel, wet asphalt, stairs, grass, metal fence.
- **Music: sparse and diegetic.** A discman with a small library of tracks you acquire as burned CDs from
  friends. Car stereos, the club, a kafana TV.
- **Commission 6–10 original tracks from actual Belgrade underground artists rather than licensing
  existing ones.** Cheaper, more authentic, cleanly rights-managed, and those artists become your
  marketing channel. Licensing real 2005 Serbian hip-hop is expensive, slow, and legally fiddly for a
  first-time solo developer — and you don't need it. The *culture* is free to reference; the *recordings*
  are not.
- **Score: ~15 minutes total.** Sparse, tape-saturated, dub-adjacent, occasional piano. Restraint.

### 10.5 Middleware

**Use Godot's built-in audio buses. Skip FMOD/Wwise for v1.** They're excellent and they're an extra
system to learn, integrate, license, and debug. Godot's buses handle everything described above.

### 10.6 One strong recommendation

**Go record real reference in Belgrade.** A cheap handheld recorder, a few nights out. Stairwells,
kiosks, the underpass, the quay at 2am, a real can. It costs nothing, it will beat any sound library,
and it is the difference between "atmospheric indie game" and "this is actually my city."

---

## 11. Art Direction

**Reference:** Cry of Fear · Silent Hill 1–2 · early Source-engine mods. Low-poly, low-res, heavy fog,
aggressive darkness, film grain.

**This is not a compromise — it is a strategy.** The look hides low-poly faces, forgives crude animation,
eliminates the need for detailed distant geometry, and it happens to be exactly right for grey 2005
Belgrade at night. Lean into it hard rather than apologising for it.

### 11.1 Budgets

| Asset | Budget |
|---|---|
| Characters | 3–6k tris, 1024² texture, minimal blendshapes |
| Environment props | 200–2,000 tris, 512² |
| Hero props (the can, the blackbook, the camera) | Up to 4k, 1024² |
| Texture sets | One atlas per kit (interior kit, street kit, industrial kit) |

### 11.2 Lighting

**Baked lightmaps are your single largest visual-quality-per-hour lever.** Your RTX 3050 bakes fine.
Fixed time-of-day per scene is what makes this possible — which is exactly why §6 cuts the day/night cycle.

A handful of dynamic lights only: a swinging bulb, car headlights, the depot floodlights, a lighter.

### 11.3 Post and palette

Film grain (togglable) · vignette · subtle chromatic aberration · **one LUT per zone**.

**Three colour schemes for the entire game:**
1. **Blok exterior night** — sodium orange vs. deep cold blue, heavy fog
2. **Interior / stairwell** — sickly green fluorescent, warm bare bulb pools
3. **Spot / wall** — whatever light the wall has, and your paint as the only saturation in frame

Palette discipline is what reads as "art direction." Variety reads as "asset store." **Fog is your best
friend**: it hides draw distance, unifies the palette, sets the mood, and costs nothing.

### 11.4 The honest bottleneck

**Art is the biggest solo-dev bottleneck — bigger than code.** Plan for it explicitly:
learn Blender for low-poly (it's genuinely approachable at this fidelity, and your fidelity target is
low by design) · kitbash aggressively · use CC0 sources (Poly Haven, Kenney, ambientCG) for textures ·
and **budget real money for a 3D artist** for the eight characters if the project passes its Milestone 4
validation gate. Characters are where solo art most visibly fails.

---

## 12. Technical Scope

### 12.1 Stack

| Layer | Choice | Why |
|---|---|---|
| **Engine** | **Godot 4.x, Forward+ renderer** | See §12.2 |
| **Language** | GDScript | Python-like; your JS background transfers in days |
| **Dialogue** | **Ink** (inkle) via a Godot integration, or **Dialogic** addon | Do not hand-roll a dialogue system. Ink separates writing from code, which matters enormously when you rewrite the script eleven times. |
| **Modelling** | Blender → glTF (.glb) | Free, excellent Godot pipeline |
| **Textures / sketches** | Krita (free) or Photoshop | Piece sketches and guide masks live here |
| **Audio** | Reaper or Audacity | Reaper is €60 and worth it |
| **VCS** | **Git + Git LFS from day one** | See §12.4 |
| **Steam** | GodotSteam | Mature, widely shipped |

### 12.2 Why Godot over Unity (the decision, recorded)

Unity genuinely wins on: Asset Store depth, tutorial volume, Mixamo/animation maturity, official console
ports. Those are real.

Godot wins on the things that decide *this* project:
- **Iteration speed.** No domain reload. Unity costs you 15–30s per script edit; over two years that
  compounds into more lost time than the Asset Store ever saves.
- **GDScript vs. C#.** C# is a real second thing to learn *while* learning an engine.
- **The scene tree works like the DOM** — it maps onto your existing mental model directly.
- **12 GB RAM.** Godot's editor sits at 0.5–1.5 GB; Unity's routinely at 4–6 GB. With Blender open, that's
  the difference between working and swapping.
- **Decisive: the graffiti system is a render-target-and-shader problem.** Godot's `SubViewport` →
  `ViewportTexture` accumulation buffer plus a plain-text shader with hot reload is dramatically simpler
  than Unity's `CommandBuffer`/`RenderTexture`/`Blit` plumbing wrapped in URP's `ScriptableRendererFeature`
  ceremony. For the most important system in the game, Godot is the easier engine.

Unity's renderer ceiling is higher. Irrelevant — this game never approaches either engine's ceiling.

*(Unreal 5 was rejected: its default high-fidelity look actively fights this art direction and inflates
asset costs, and solo-shipping small narrative games in UE5 is a well-documented trap. three.js was
rejected: Steam distribution needs an Electron wrapper, the asset pipeline is a constant fight, and none
of it transfers to a second game.)*

### 12.3 Architecture

```
Main.tscn
├── SceneLoader          swaps level scenes, handles fades
└── Autoloads (singletons)
    ├── GameState        flags, currencies, relationships, mission state
    ├── SaveManager      serialize/deserialize, versioning, migration
    ├── AudioDirector    ambience beds, crossfades, music
    ├── DialogueRunner   Ink/Dialogic bridge
    └── PaintRegistry    wall IDs → saved PNGs, active SubViewport management

Systems/
├── Paint/               PaintSurface, SprayCan, DripSolver, PassController, Scorer
├── Player/              FPController (write this yourself — ~200 lines, you must understand it)
├── Interaction/         raycast interactor, prompt UI
└── Mission/             mission state machines, objective tracking
```

**Write yourself:** the paint system (non-negotiable — it's the game), the player controller (you need
to understand it), the interaction system, the save system.
**Don't write yourself:** dialogue, Steam integration, common shader utilities.

### 12.4 Immediate housekeeping

- **Your `git` is 2.15.0 (2017).** Update it.
- **Git LFS is not installed.** Install it and configure it *before the first commit* — retrofitting LFS
  onto a repo with binary history is painful. Track `*.png *.jpg *.wav *.ogg *.blend *.glb *.mp3`.
- `.gitignore`: `.godot/`, `.import/`, `export_presets.cfg` (contains signing paths), OS junk.
- **Buy 16 GB more RAM (~€50–70).** Highest value-per-euro purchase in this entire project.

### 12.5 Performance targets

1080p / 60fps on a GTX 1060-class GPU. This is trivially achievable given the art direction and gives
you enormous headroom for the paint system. **Only one live paint SubViewport at a time, ever** (§5.8).

---

## 13. Risks

Ranked by expected damage, with the mitigation that actually works.

| # | Risk | Severity | Mitigation |
|---|------|----------|-----------|
| 1 | **The project doesn't ship.** Base rates for a solo first commercial 3D narrative game are genuinely poor — most die around 40% completion at 18 months. | Critical | The milestone ladder in §15 exists entirely for this. **Hard go/no-go gates at M1 and M4.** Permission to stop at a gate is not failure; it's the plan working. |
| 2 | **The painting isn't fun.** Everything rests on one mechanic that has never been prototyped. | Critical | **M1 answers this in 4–6 weeks before anything else is built.** Gray box, 5 external testers, watch them play. |
| 3 | **Art production volume.** The largest hour-sink in solo dev, by a wide margin. | High | Low-poly by design · darkness as budget · aggressive kitbashing · CC0 sources · budget cash for character art after M4. |
| 4 | **Scope creep from story ambition.** The story wants to be a 12-hour epic. The budget is 3 hours. | High | 13 missions, 5 verbs, 8 characters, 5 hubs — these are contracts, not estimates. Adding a sixth verb must be *argued for*, not assumed. |
| 5 | **Painted-wall persistence + save complexity.** | Medium | Built and proven in M2, not deferred. `save_version` from the first write. |
| 6 | **Timeline reality.** 18–30 months part-time for 3–4 hours of content. | Medium | Plan for it honestly now rather than discovering it at month 14. |
| 7 | **Marketing.** A finished game nobody knows about earns nothing. | Medium | **Steam page live at M4, ~12 months before launch.** Wishlists are the actual currency. Build in public: the paint mechanic is extraordinarily GIF-able, and "Belgrade 2005" is a hook that writes its own coverage. |
| 8 | **Serbian Cyrillic / localisation.** | Low-if-early | §9.2. Nearly free at the start, painful at the end. |
| 9 | **VO.** | Low-if-deferred | **Never record a line before the script is content-locked.** Serbian VO with English subtitles is both cheaper and a stronger marketing identity than English VO. |

---

## 14. Legal & Content Notes

- **Depicting graffiti is fine.** *Getting Up*, *Jet Set Radio*, and *Bomb Rush Cyberfunk* all shipped.
- **Invent the paint brands.** Do not use Montana, Molotow, etc. without a license. Inventing them is
  also more authentic — 2005 Belgrade writers were mostly using whatever was cheap anyway.
- **Do not reproduce real crews' tags, real people, or real photographs.**
- **Football-terrace graffiti:** reference the *phenomenon*, invent the group names. Real ultras
  organisations are not entities to name in a commercial product.
- **Rating:** PEGI 16–18 / ESRB M. Steam has no issue with this content.
- **Age of protagonist (17):** keep any romance content non-explicit. This also avoids storefront friction.

---

## 15. MVP and the Milestone Ladder

The user's stated MVP — *"one apartment, one street, one wall, one NPC, one mission, paint one piece, go
home"* — is the right instinct and is still **two projects**. Inside it is a smaller thing that decides
whether the whole game is worth making. That comes first.

### M0 — Engine literacy · 2–3 weeks
Godot fundamentals. One room, a first-person controller, a door that opens, a UI panel, one build export.
**Goal:** stop being confused by the editor. Nothing here is kept.

### M1 — **THE TOY** · 4–6 weeks · ⛔ GO/NO-GO GATE
A gray-box room. One wall. That's it.
- Spray paint accumulating into a render target
- Distance → cone width and density; angle → ellipse stretch
- Two cap types (skinny, fat)
- Shake minigame, pressure, sputter, empty
- Drips
- Wet sheen drying
- Wall texture resisting paint
- **The full can audio set** (§10.2)

**No story. No NPC. No street. No apartment. No scoring. No art.**

> **THE GATE:** Put it in front of five people. Say nothing. Watch.
> **If they don't spontaneously keep painting for ten minutes, stop and rethink the entire project.**
> This is the most valuable two hours in the whole production, and it happens in month three instead
> of month eighteen.

### M2 — **THE LOOP** · 6–8 weeks
The user's stated MVP, in gray box.
Apartment → stairwell → street → wall → paint → home. One NPC (Vuk) with a short scripted conversation.
One mission with all three passes and scoring. **Save/load including the painted wall** (§8).
Still placeholder art throughout.

### M3 — **THE SLICE** · 10–14 weeks
Art pass, baked lighting, audio pass, blackbook UI, phone UI, polish.
**Target: 12–15 minutes that look and sound exactly like the shipped game.**

### M4 — **VALIDATE** · 2–4 weeks · ⛔ GO/NO-GO GATE
Steam page live. Free demo on itch.io. Show it to Serbian gaming communities, graffiti forums, and
r/Serbia. Gather wishlists. Post the paint mechanic as GIFs everywhere.

> **THE GATE:** *Then*, and only then, decide whether to commit to the remaining ~18 months.
> **Do not build three hours of content before you know anyone wants it.** This is the single most
> important piece of professional advice in this document.

### M5+ — Full production · ~12–18 months
13 missions · 5 hubs · 8 characters · ~25 piece sketches · Serbian VO after content lock · Steam launch.

---

## 16. What I'm Recommending We Build First

**Milestone 0 and Milestone 1 only.** Concretely, the first coding session should produce:

| File | Purpose |
|---|---|
| `project.godot` | Godot 4.x project, Forward+ renderer |
| `.gitignore` / `.gitattributes` | LFS tracking configured before the first commit |
| `docs/GDD.md` | This document, committed into the repo |
| `scenes/proto/paint_room.tscn` | Gray-box room, one paintable wall |
| `systems/player/fp_controller.gd` | First-person controller, written by hand |
| `systems/paint/paint_surface.gd` | SubViewport accumulation buffer, UV raycast |
| `systems/paint/spray_can.gd` | Pressure, volume, caps, shake state machine |
| `systems/paint/brush.gdshader` | Deposition, falloff, overspray, wall-roughness modulation |
| `systems/paint/wall_surface.gdshader` | Composite paint over albedo, wetness → roughness |
| `systems/paint/drip_solver.gd` | Coarse accumulator + drip agents |

**Verification (how we know M1 passed):**
1. Run the project; walk to the wall; spray. Paint appears at the crosshair with no visible latency.
2. Back away — the cone widens and thins. Approach — it tightens and saturates. This should be
   *immediately legible* without instruction.
3. Spray at a steep angle to the wall — the deposit stretches into an ellipse.
4. Hold on one spot for ~2s — a drip forms and runs down. Fresh paint is glossy; it dulls over ~30s.
5. Spray without shaking — output is visibly sputtery and patchy. Shake — it cleans up.
6. Empty the can — pressure sputters out, then the empty click.
7. Swap skinny → fat cap — line width changes by 3–4×.
8. Framerate holds at 60fps while spraying continuously for two minutes.
9. **Five external testers. Watch, don't explain. Ten minutes of unprompted play = GO.**

---

## Appendix: Things Deliberately Cut, and Why

Recorded so they don't quietly return in month nine.

| Cut | Why |
|---|---|
| Open-world Belgrade | 100+ person-years. This is how indie games die. |
| Full police AI / wanted level | Scripted patrols and one LOS cone deliver 90% of the tension for 5% of the cost. |
| Multiplayer / shared walls / online gallery | Server costs, and **you become a content moderator overnight** — players will paint genitals and hate speech, and you'd carry the legal exposure alone. |
| AI-judged freehand art | Unsolved CV problem, gameable, feels arbitrary. Project-killer. |
| Day/night cycle | Forfeits baked lighting — the single biggest visual-quality lever available. |
| Driving / vehicles | Whole new system, whole new bug class, serves nothing. |
| Character creator | Fixed protagonist. This is a story about a specific boy. |
| Procedural graffiti / mission generation | Turns a 3-hour game into an unshippable 3-year one. |
| Third-person / full player body | No IK rig, no third-person animation set. First-person also serves the theme. |
| FMOD / Wwise | Godot's buses are sufficient; middleware is a system to learn, license, and debug. |
| Licensed real 2005 Serbian hip-hop | Expensive, slow, legally fiddly. Commission originals instead — cheaper, more authentic, and the artists become marketing allies. |
| Rhythm/cypher minigame | Rhythm games are their own discipline. Make the music scenes WITNESS scenes with exceptional audio instead. |
| Console ports | Godot needs a third-party porting house. Ship on Steam first, or never. |
| English VO | Serbian VO with English subtitles is cheaper *and* a stronger identity. And no VO at all before content lock. |
