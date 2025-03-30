#version 430 core

in vec2 v_tex_coord;
in float v_intensity;
out vec4 o_frag_color;

uniform sampler2D u_tex;
uniform vec3 u_col;
uniform float u_intensity;

void main() {
    vec4 tex_col = texture(u_tex, v_tex_coord);
    o_frag_color = vec4(
        mix(tex_col.r, u_col.r, u_intensity),
        mix(tex_col.g, u_col.g, u_intensity),
        mix(tex_col.b, u_col.b, u_intensity),
        tex_col.a
    );
}
