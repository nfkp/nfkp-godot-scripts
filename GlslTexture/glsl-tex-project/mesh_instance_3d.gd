extends MeshInstance3D

var a = [false, false, false]
var fullscreen : bool = false

func set_texture(path : String) -> void:
	var tex := GlslTexture.glsl_write_to_texture(path, 2048)
	var mat : ShaderMaterial = get_active_material(0)
	mat.set_shader_parameter("tex", tex)

func _ready() -> void:
	Engine.max_fps = DisplayServer.screen_get_refresh_rate() as int
	set_texture("res://shader.glsl")
	GlslTexture.cleanup_gpu()
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_ESCAPE:
					get_tree().quit()
				KEY_F4:
					if fullscreen:
						DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
						fullscreen = false
					else:
						DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
						fullscreen = true
