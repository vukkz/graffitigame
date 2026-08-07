extends Node3D
## The can's voice (GDD §10.2). Listens to what the can is doing and plays it.
##
## Every slot is optional. With none filled the game is silent and nothing errors, so the
## wiring can be built and tested before a single sound exists — and dropping the real
## recordings in on Monday is a file assignment, not a code change.
##
## §10.2 wants the sustain's pitch AND a low-pass driven live by pressure. Pitch is here;
## the filter needs an audio bus with an AudioEffectLowPassFilter on it, which belongs
## with the bus layout in M3 rather than hard-coded here. Pitch alone already carries most
## of the "this can is running out" read.

@export var spray_can_path: NodePath

@export_group("Trigger")
## The initial spit as the valve opens — different from the sustain, and its absence is
## why looped-only spray sounds fake.
@export var start_burst: AudioStream
## Held spray. Must loop cleanly; set Loop on the imported file, not here.
@export var sustain_loop: AudioStream
## The hiss trailing off after you let go. Pairs with the cut (§5.3's trigger release).
@export var tail_hiss: AudioStream

@export_group("Can")
## One rattle per shake. Pitch rides paint level — §5.5 calls that free diegetic
## information, and it is: you hear how full the can is without a meter.
@export var ball_rattle: AudioStream
@export var cap_click: AudioStream
@export var empty_click: AudioStream
## Crossfades in under ~15 cm. The wet slap that sells being right up against the wall.
@export var close_splatter: AudioStream

@export_group("Feel")
## Sustain pitch at zero pressure vs full. A dying can drops in pitch and thins out.
@export var pressure_pitch := Vector2(0.72, 1.0)
## Rattle pitch on an empty can vs a full one. A full can is dull and low; an empty one
## rings.
@export var rattle_pitch := Vector2(1.35, 0.85)
@export_range(0.0, 1.0, 0.01) var rattle_pitch_jitter := 0.06

var _can: Node = null
var _sustain: AudioStreamPlayer3D
var _oneshot: AudioStreamPlayer3D
var _rattle: AudioStreamPlayer3D


func _ready() -> void:
	_sustain = _make_player("Sustain")
	_oneshot = _make_player("OneShot")
	_rattle = _make_player("Rattle")

	_can = get_node_or_null(spray_can_path)
	if _can == null:
		push_warning("CanAudio: spray_can_path does not point at a SprayCan.")
		return

	_can.trigger_started.connect(_on_trigger_started)
	_can.trigger_released.connect(_on_trigger_released)
	_can.shaken.connect(_on_shaken)
	_can.cap_changed.connect(func(_cap: Resource) -> void: _play(cap_click))
	_can.emptied.connect(func() -> void: _play(empty_click))


func _process(_delta: float) -> void:
	if _can == null or not _sustain.playing:
		return
	# Live, every frame: the sound sags as the can does. §10.2 asks for exactly this.
	_sustain.pitch_scale = lerpf(pressure_pitch.x, pressure_pitch.y, _can.pressure())


func _on_trigger_started() -> void:
	_play(start_burst)
	if sustain_loop != null:
		_sustain.stream = sustain_loop
		_sustain.play()


func _on_trigger_released() -> void:
	_sustain.stop()
	_play(tail_hiss)


func _on_shaken(_rhythm: float, _mix: float, volume: float) -> void:
	if ball_rattle == null:
		return
	_rattle.stream = ball_rattle
	_rattle.pitch_scale = (
		lerpf(rattle_pitch.x, rattle_pitch.y, volume)
		+ randf_range(-rattle_pitch_jitter, rattle_pitch_jitter)
	)
	_rattle.play()


func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	_oneshot.stream = stream
	_oneshot.play()


func _make_player(name_: String) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = name_
	# The can is in your hand, so it should not fall off with distance the way a sound
	# across the street does.
	player.unit_size = 3.0
	add_child(player)
	return player
