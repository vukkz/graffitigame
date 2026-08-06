# Project context for Claude

First commercial indie game, built solo. First-person narrative game set in Belgrade, 2005.
**Read [`docs/GDD.md`](docs/GDD.md) before proposing anything.** [`README.md`](README.md) has the
milestone checklist and current status.

## Stack

- **Godot 4.x, Forward+ renderer** — standard build, NOT .NET/C#
- **GDScript** — the developer has web/mobile background (JS, Python-ish comfort), no C++/C#,
  no prior game engine experience
- Blender → glTF (.glb) · Krita for textures and piece sketches · Git + Git LFS

## How to work on this project

- **Challenge scope.** The developer explicitly asked for pushback on over-ambitious features.
  Say plainly when something is too big, propose the cheaper alternative that keeps most of the
  value. Cuts and their reasoning are recorded in the GDD appendix — do not let cut features
  quietly return.
- **One testable slice at a time.** Never batch weeks of untested work. Smallest playable thing
  first, polish it, then extend.
- **Teach, don't just deliver.** During M0/M1 the developer is learning the engine. Explain why
  code works, not just what to paste. Code they don't understand is code they can't debug at 2am
  in month fourteen.
- Scope contract from the GDD: 13 missions · 5 verbs · 8 characters · 5 hubs · 3–4 hours.
  These are contracts, not estimates.

## Godot 4 vs Godot 3 — check every snippet against this

Most tutorials and much training data are Godot 3. These will silently fail or error:

| Godot 3 (wrong) | Godot 4 (correct) |
|---|---|
| `KinematicBody` / `KinematicBody2D` | `CharacterBody3D` / `CharacterBody2D` |
| `move_and_slide(vel, Vector3.UP)` | set `velocity` property, then call `move_and_slide()` |
| `Spatial` | `Node3D` |
| `Viewport` | `SubViewport` |
| `export var speed = 5` | `@export var speed = 5` |
| `onready var x = $Node` | `@onready var x = $Node` |
| `yield(get_tree(), "idle_frame")` | `await get_tree().process_frame` |
| `scene.instance()` | `scene.instantiate()` |
| `Tween` node | `create_tween()` |
| `connect("sig", self, "_on_sig")` | `sig.connect(_on_sig)` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |
| `PoolByteArray` | `PackedByteArray` |
| `.empty()` | `.is_empty()` |
| `rand_range()` | `randf_range()` |
| shader: `hint_albedo` | shader: `source_color` |
| shader: `SCREEN_TEXTURE` | shader: `hint_screen_texture` uniform |

If a snippet doesn't work, this table is the first thing to check.

## Current status

**M0 — Engine literacy.** No game code exists yet by design. Do not start the paint system until
M0 is done and the developer understands nodes, scenes, and signals.

The paint system (GDD §5) is the make-or-break feature and gets built at M1, in a gray box, with
no story or art attached. It must be fun standing alone before anything else is built on top.
