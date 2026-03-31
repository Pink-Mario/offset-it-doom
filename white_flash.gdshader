shader_type canvas_item;

uniform float pulse_speed = 8.0;
uniform float min_alpha = 0.01;
uniform float max_alpha = 0.0;

void fragment() {
	vec4 previous_color = texture(TEXTURE, UV);
	float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
	float alpha = mix(min_alpha, max_alpha, pulse);
	COLOR = vec4(1.0, 1.0, 1.0, previous_color.a * alpha);
}