shader_type canvas_item;

// src = the colour that is painted in the PNG. dst = the colour you want to see instead.
// (No source_color hint on purpose: it can convert the values to linear, and then they would never match the PNG.)
uniform float tolerance = 0.04;

uniform vec4 dark_src = vec4(0.345, 0.031, 0.094, 1.0);   // #580818
uniform vec4 base_src = vec4(0.533, 0.094, 0.188, 1.0);   // #881830
uniform vec4 light_src = vec4(0.784, 0.251, 0.345, 1.0);  // #c84058

uniform vec4 dark_dst = vec4(0.345, 0.031, 0.094, 1.0);
uniform vec4 base_dst = vec4(0.533, 0.094, 0.188, 1.0);
uniform vec4 light_dst = vec4(0.784, 0.251, 0.345, 1.0);

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
