# Untitled Belgrade Graffiti Game

First-person narrative game. Belgrade, 2005. A 17-year-old, a bag of cans, and a city that
paints over everything you make.

**Design bible:** [`docs/GDD.md`](docs/GDD.md) — read §5 (Graffiti Mechanics) before writing any paint code.

| | |
|---|---|
| **Engine** | Godot 4.x, Forward+ |
| **Language** | GDScript |
| **Target** | PC / Steam · 1080p60 on GTX 1060-class |
| **Scope** | 3–4 hours · 13 missions · 5 verbs · 8 characters · 5 hubs |
| **Status** | **M0 — Engine literacy** |

---

## Milestone ladder

Two hard gates. Stopping at a gate is the plan working, not the plan failing.

### M0 — Engine literacy · 2–3 weeks
Nothing here is kept. The goal is to stop being confused by the editor.

- [ ] Install Godot 4.x (standard build, **not** the .NET/C# build)
- [ ] Work through the official "Your first 3D game" tutorial end to end
- [ ] One room, walls, a floor, a light
- [ ] A first-person controller you wrote yourself (mouse look + WASD + crouch)
- [ ] A door that opens when you look at it and press E
- [ ] One UI panel that shows and hides
- [ ] Export a Windows build and run it

### M1 — THE TOY · 4–6 weeks · ⛔ GATE
Gray box. One wall. No story, no NPC, no street, no scoring, no art.

- [ ] Paint accumulating into a `SubViewport` render target
- [ ] Raycast → UV, brush stamp with radial falloff
- [ ] Deposition `= pressure × cap_flow × dt / radius²` (conserves paint — do not hand-tune this)
- [ ] Distance → cone width and density
- [ ] Angle → ellipse stretch when incidence < ~0.4
- [ ] Overspray halo (wide, very low alpha — non-negotiable)
- [ ] Wall roughness/AO map resists paint
- [ ] Two cap types: skinny, fat
- [ ] Shake minigame — under-shaking produces visibly worse paint
- [ ] Pressure drain → sputter below 25% → empty
- [ ] Drips (coarse 64×64 accumulator → drip agents, world-down projected into UV)
- [ ] Wet sheen: `PaintData.R` → roughness, decaying over ~30s
- [ ] Full can audio set: cap click, ball rattle, start burst, pressure-driven sustain,
      close splatter, tail hiss, sputter, empty click

> **THE GATE:** five people, no explanation, watch them.
> Ten minutes of unprompted painting = GO. Anything less = stop and rethink.

### M2 — THE LOOP · 6–8 weeks
Apartment → stairwell → street → wall → paint → home. Still gray box.

- [ ] Scene loading + fades
- [ ] `GameState` / `SaveManager` autoloads — `save_version` field from the very first write
- [ ] One NPC (Vuk), one scripted conversation, dialogue system integrated (Ink or Dialogic)
- [ ] Three passes: outline → fill → highlight, with the guide mask
- [ ] Scoring: coverage / spill / line quality / drips / time → Toy · Solid · Clean · Burner
- [ ] Save & load **including the painted wall** (512² PNG per wall, cap 40)

### M3 — THE SLICE · 10–14 weeks
- [ ] Art pass · baked lightmaps · fog · LUT per zone · film grain
- [ ] Audio pass: ambience beds, footsteps by material, backpack clink
- [ ] Blackbook UI · phone UI · paper map
- [ ] Accessibility: grain/CA/head-bob toggles, remappable input, FOV, subtitle size

**Target: 12–15 minutes that look and sound exactly like the shipped game.**

### M4 — VALIDATE · 2–4 weeks · ⛔ GATE
- [ ] Steam page live
- [ ] Free demo on itch.io
- [ ] Shown to Serbian gaming + graffiti communities
- [ ] Paint-mechanic GIFs posted everywhere

> **THE GATE:** only now decide whether to commit to the remaining ~18 months.
> Do not build three hours of content before you know anyone wants it.

### M5+ — Full production · ~12–18 months

---

## First-time setup

```bash
brew install git git-lfs && git lfs install
```

Then, from this directory:

```bash
git init && git add -A && git commit -m "Design document and repo setup"
```

`.gitattributes` must be committed **before** any binary assets land, or LFS won't catch them.

## Hardware notes

Primary dev machine: Ryzen 5 5600X / RTX 3050 / 12 GB.
**Buy 16 GB more RAM before M3** — Godot plus Blender on 12 GB will swap. Best €60 in the project.
