shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.8, 0.8, 0.8, 0.05);
uniform vec4 color_b : source_color = vec4(0.4, 0.4, 0.4, 0.1);
uniform float squares = 32.0;

void fragment() {
    vec2 uv = UV * squares;
    float check = mod(floor(uv.x) + floor(uv.y), 2.0);
    COLOR = mix(color_a, color_b, check);
}