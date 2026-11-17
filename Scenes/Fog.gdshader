shader_type canvas_item;


uniform sampler2D noise_texture: repeat_enable, filter_nearest;

uniform float density: hint_range(0.0,0.5) = 0.6;
uniform vec2 speed = vec2(0.02,0.03);

void fragment() {
	
	vec2 uv = UV + speed * TIME;
	
	float noise = texture(noise_texture, uv).r;
	
	float fog = clamp(noise * 2.0 - 1.0, 0.0, 1.0);
	
	COLOR.a *= fog * density;
	// Called for every pixel the material is visible on.
}
