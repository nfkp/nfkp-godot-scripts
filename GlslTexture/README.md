# Write GLSL to Texture
Write to a texture with GLSL shader code in Godot. This may be used as a material to save performance by not having the GPU calculate a fragment shader for every frame while having the benefits of the disk space efficiency that comes with making shader materials.
## How to use
It's a little like a c++ object but doesn't take care of it's own memory.

Use this function to write to a texture variable:
```GDScript
func glsl_write_to_texture(path: String, resolution: int = 512, uniform_data : PackedByteArray = PackedByteArray([])) -> ImageTexture
```

Ex:
```GDScript
#Set texture rapidly at ready to one shader to another and then back to the last.
func set_texture(path : String) -> void:
	var tex := GlslTexture.glsl_write_to_texture(path, 2048)
	var mat : ShaderMaterial = get_active_material(0)
	mat.set_shader_parameter("tex", tex)

func _ready() -> void:
	set_texture("res://shader.glsl")
	set_texture("res://shader2.glsl")
	set_texture("res://shader.glsl")
	GlslTexture.cleanup_gpu()
```
Use `cleanup_gpu()` to avoid leaking in memory the Resource IDs that were generated as a result of calling the write function for the first time. Do this after you finish writing to all your texture variables.
## Parameters
### path
path to glsl file. Ex: `"res://shader.glsl"`
### resolution
Resolution of texture. The shader writes to a square texture, since UV coordinates go from 0.0 to 1.0. The default value is 512
### uniform_data
Data sent to the uniform buffer, whose memory is organized in the std140 layout. By default the `glsl_write_to_texture()` function sends a uniform with the resolution in it. The sort of Vulkan that Godot uses doesn't have the `GL_EXT_scalar_block_layout` extension loaded, so the size of uniform buffers are rounded up to a multiple of the size of a vec4. You'll have to add filler data so the data is organized in blocks of 16 bytes.

[From wiki:](https://www.khronos.org/opengl/wiki/Interface_Block_(GLSL))
The rules for std140 layout are covered quite well in the OpenGL specification ([OpenGL 4.5, Section 7.6.2.2, page 137](https://registry.khronos.org/OpenGL/specs/gl/glspec45.core.pdf#page=159)). Among the most important is the fact that arrays of types are not necessarily tightly packed. An array of floats in such a block will not be the equivalent to an array of floats in C/C++. The array stride (the bytes between array elements) is always rounded up to the size of a vec4 (ie: 16-bytes). So arrays will only match their C/C++ definitions if the type is a multiple of 16 bytes
	**Warning:** Implementations sometimes get the std140 layout wrong for vec3 components. You are advised to manually pad your structures/arrays out and avoid using vec3 at all.

Ex:
```GDScript
# The default uniform data inside glsl_write_to_texture():
var u_data := PackedFloat32Array([1. / float(resolution)]).to_byte_array()
u_data.append_array(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])) # filler for std140
```
## GLSL Shader template
There is a vertex shader I copied and pasted from Vulkan Tutorial which makes a triangle, except I made it cover the whole screen.

The fragment shader starts with the GLSL version. FragColor is the equivalent of the `vec3 out ALBEDO` variable from GDShaders.
Ex:
```GLSL
#[vertex] // Use these heading tags to seperate vertex and fragment shaders
#version 460

vec2 positions[3] = vec2[](
    vec2(0., -3.),
    vec2(3., 3.),
    vec2(-3., 3.)
);

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
}

#[fragment]
#version 460

layout(location = 0) out vec4 FragColor;

// This is the uniform buffer that needs to match the data being sent
layout(set = 0, binding = 0, std140) uniform uniform_buffer {
    float px_size;
} u_buffer;

// Up to this point is basically the format. The rest is sort of like a GDShader.
#define PI 3.14159265359
float random(in vec2 st) {
    vec3 p3  = fract(vec3(st.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

mat2 rotate2d(const in float r){
    float c = cos(r);
    float s = sin(r);
    return mat2(c, s, -s, c);
}

void main() {
	vec2 st = gl_FragCoord.xy * u_buffer.px_size; st.y = 1. - st.y;
    st.x *= 1.5;
    st *= 10.;

    vec2 i = floor(st);
    vec2 f = fract(st);
    f -= 0.5;
    float rand = random(i);;
    rand = floor(rand * 4.) * 0.5 * PI + 0.25 * PI;
    f = rotate2d(rand) * f;
    float pct = sign(-f.x);
    FragColor = vec4(vec3(pct) * 0.5, 1.0);
}
```
# Bibliography
[Godot Heightmap Demo](https://github.com/godotengine/godot-demo-projects/blob/master/misc/compute_shader_heightmap/main.gd)