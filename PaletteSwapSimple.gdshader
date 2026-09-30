shader_type canvas_item;

// src = the colour that is painted in the PNG. dst = the colour you want to see instead.
uniform float tolerance = 0.02;

uniform vec4 dark_src : source_color = vec4(0.45, 0.10, 0.10, 1.0);
uniform vec4 base_src : source_color = vec4(0.75, 0.15, 0.15, 1.0);
uniform vec4 light_src : source_color = vec4(0.95, 0.35, 0.30, 1.0);

uniform vec4 dark_dst : source_color = vec4(0.45, 0.10, 0.10, 1.0);
uniform vec4 base_dst : source_color = vec4(0.75, 0.15, 0.15, 1.0);
uniform vec4 light_dst : source_color = vec4(0.95, 0.35, 0.30, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 result = tex;

	if (distance(tex.rgb, dark_src.rgb) < tolerance) {
		result.rgb = dark_dst.rgb;
	} else if (distance(tex.rgb, base_src.rgb) < tolerance) {
		result.rgb = base_dst.rgb;
	} else if (distance(tex.rgb, light_src.rgb) < tolerance) {
		result.rgb = light_dst.rgb;
	}

	COLOR = result;
}
