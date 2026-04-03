shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform vec4 color_b : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float squares = 16.0;
uniform float dim_amount : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 uv_scaled = UV * squares;
    float check = mod(floor(uv_scaled.x) + floor(uv_scaled.y), 2.0);
    vec4 base_color = mix(color_a, color_b, check);
    
    float margin = 0.25;
    vec2 inside = step(vec2(margin), UV) * step(UV, vec2(1.0 - margin));
    float is_inside = inside.x * inside.y;
    
    float brightness = mix(dim_amount, 1.0, is_inside);
    
    COLOR = vec4(base_color.rgb * brightness, base_color.a);
}