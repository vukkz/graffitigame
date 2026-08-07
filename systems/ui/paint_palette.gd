extends Control
## Row of paint swatches along the bottom of the screen, picked with the number keys.
##
## Gray-box scaffolding, like the cap label — §9 designs the real HUD, and §7.1 turns
## this into an inventory of cans you actually bought rather than a free palette. It
## exists now because the paint system cannot be judged in one colour: a throw-up is an
## outline in one can and a fill in another, and you cannot feel whether that works
## until you can switch between them at speed.
##
## Built in code from the can's `palette` so adding a colour is a one-line data change
## rather than scene surgery.

## The SprayCan to read the palette from and follow.
@export var spray_can_path: NodePath
@export var swatch_size := 34.0
@export var swatch_gap := 6.0
## Thickness of the frame drawn around the loaded colour.
@export var frame_width := 3.0

var _can: SprayCan
var _frames: Array[ColorRect] = []


func _ready() -> void:
	_can = get_node_or_null(spray_can_path) as SprayCan
	if _can == null:
		push_warning("PaintPalette: spray_can_path does not point at a SprayCan.")
		return
	_build()
	_can.color_changed.connect(_on_color_changed)
	_can.stance_changed.connect(_on_stance_changed)
	_highlight(_can.color_index())
	# Only on screen while painting. A palette you cannot use is just clutter over the
	# street, and its appearing is half of how the player learns stance exists at all.
	visible = _can.is_painting_stance()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(swatch_gap))
	# Every Control defaults to mouse_filter = STOP, which eats mouse events. With the
	# mouse captured the cursor sits dead centre, so anything under it kills mouse look —
	# that is exactly what the crosshair did. Nothing here is meant to be clicked.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(row)

	for i in _can.palette.size():
		var frame := ColorRect.new()
		frame.custom_minimum_size = Vector2.ONE * (swatch_size + frame_width * 2.0)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.color = Color(0, 0, 0, 0.45)
		row.add_child(frame)

		var swatch := ColorRect.new()
		swatch.color = _can.palette[i]
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
		swatch.offset_left = frame_width
		swatch.offset_top = frame_width
		swatch.offset_right = -frame_width
		swatch.offset_bottom = -frame_width
		frame.add_child(swatch)

		var number := Label.new()
		number.text = str(i + 1)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.set_anchors_preset(Control.PRESET_FULL_RECT)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Readable on both a black and a white swatch.
		number.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		number.add_theme_constant_override("outline_size", 4)
		frame.add_child(number)

		_frames.append(frame)


func _on_color_changed(_color: Color, index: int) -> void:
	_highlight(index)


func _on_stance_changed(active: bool) -> void:
	visible = active


func _highlight(index: int) -> void:
	for i in _frames.size():
		_frames[i].color = (
			Color(1, 1, 1, 0.95) if i == index else Color(0, 0, 0, 0.45)
		)
