extends CanvasLayer

@onready var _menu: Control = $PauseMenu


func _ready() -> void:
	_menu.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_paused(not _menu.visible)
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	_menu.visible = paused
	get_tree().paused = paused
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	)


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_quit_pressed() -> void:
	get_tree().quit()
