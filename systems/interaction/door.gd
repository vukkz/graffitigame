extends AnimatableBody3D

@export var open_degrees := 90.0
@export var duration := 0.6

var _open := false
var _tween: Tween


func interact() -> void:
	_open = not _open
	var target := deg_to_rad(open_degrees) if _open else 0.0

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation:y", target, duration)
