shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size : hint_range(1.0, 64.0) = 8.0;
uniform vec4 dissolve_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    vec2 cell = floor(FRAGCOORD.xy / max(pixel_size, 1.0));
    float noise = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453123);
    float mask = step(noise, progress);
    COLOR = vec4(dissolve_color.rgb, dissolve_color.a * mask);
}
