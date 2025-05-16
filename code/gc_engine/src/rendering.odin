package zf4

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"
import stbtt "vendor:stb/truetype"

// IDEA: Have the developer initialise textures and fonts themselves, so they have complete flexibility over it. They might want multiple texture structs for different texture groups, for example.

TEXTURE_CHANNEL_CNT :: 4

FONT_CHR_RANGE_BEGIN :: 32
FONT_CHR_RANGE_LEN :: 95
FONT_TEXTURE_WIDTH :: 2048
FONT_TEXTURE_HEIGHT_LIMIT :: 2048

BATCH_SHADER_PROG_VERT_CNT :: 13
BATCH_SLOT_CNT :: 128
BATCH_SLOT_VERT_CNT :: BATCH_SHADER_PROG_VERT_CNT * 4
BATCH_SLOT_VERTS_SIZE :: BATCH_SLOT_VERT_CNT * BATCH_SLOT_CNT
BATCH_SLOT_ELEM_CNT :: 6

SURFACE_LIMIT :: 32

RENDERABLE_STR_BUF_SIZE :: 1023

WHITE :: Vec_4D{1.0, 1.0, 1.0, 1.0}
BLACK :: Vec_4D{0.0, 0.0, 0.0, 1.0}
GRAY :: Vec_4D{0.5, 0.5, 0.5, 1.0}
RED :: Vec_4D{1.0, 0.0, 0.0, 1.0}
GREEN :: Vec_4D{0.0, 1.0, 0.0, 1.0}
BLUE :: Vec_4D{0.0, 0.0, 1.0, 1.0}
YELLOW :: Vec_4D{1.0, 1.0, 0.0, 1.0}
MAGENTA :: Vec_4D{1.0, 0.0, 1.0, 1.0}
CYAN :: Vec_4D{0.0, 1.0, 1.0, 1.0}

Rendering_Context :: struct {
    pers:         ^Pers_Render_Data,
    state:        ^Rendering_State,
    display_size: Vec_2D_I,
}

Pers_Render_Data :: struct {
    batch_shader_prog:     Batch_Shader_Prog,
    batch_gl_ids:          Batch_GL_IDs,
    surfs:                 Render_Surfaces,
    surf_vert_array_gl_id: u32,
    surf_vert_buf_gl_id:   u32,
    surf_elem_buf_gl_id:   u32,
    px_tex_gl_id:          u32,
}

Rendering_State :: struct {
    batch_slots_used_cnt:    int,
    batch_slot_verts:        [BATCH_SLOT_CNT][BATCH_SLOT_VERT_CNT]f32,
    batch_tex_gl_id:         u32,
    surf_shader_prog_gl_id:  u32, // When a surface is rendered, this shader program is used.
    surf_index_stack:        [SURFACE_LIMIT]int,
    surf_index_stack_height: int,
    view_mat:                matrix[4, 4]f32,
}

Textures :: struct {
    gl_ids: []u32,
    sizes:  []Vec_2D_I,
}

Texture_Index_To_File_Path :: proc(index: int) -> string

Fonts :: struct {
    arrangement_infos: []Font_Arrangement_Info,
    tex_gl_ids:        []u32,
    tex_heights:       []int,
}

Font_Arrangement_Info :: struct {
    chr_hor_offsets:  [FONT_CHR_RANGE_LEN]int,
    chr_ver_offsets:  [FONT_CHR_RANGE_LEN]int,
    chr_hor_advances: [FONT_CHR_RANGE_LEN]int,
    chr_src_rects:    [FONT_CHR_RANGE_LEN]Rect_I,
    line_height:      int,
}

Font_Load_Info :: struct {
    file_path: string,
    height:    int,
}

Font_Index_To_Load_Info :: proc(index: int) -> Font_Load_Info

Shader_Progs :: struct {
    gl_ids: []u32,
}

Shader_Prog_Index_To_File_Paths :: proc(index: int) -> (string, string)

Batch_Shader_Prog :: struct {
    gl_id:                u32,
    proj_uniform_loc:     int,
    view_uniform_loc:     int,
    textures_uniform_loc: int,
}

Batch_GL_IDs :: struct {
    vert_array_gl_id: u32,
    vert_buf_gl_id:   u32,
    elem_buf_gl_id:   u32,
}

Render_Surfaces :: struct {
    framebuffer_gl_ids:     [SURFACE_LIMIT]u32,
    framebuffer_tex_gl_ids: [SURFACE_LIMIT]u32,
}

Shader_Prog_Uniform_Value :: union {
    i32,
    f32,
    Vec_2D,
    Vec_3D,
    Vec_4D,
    matrix[4, 4]f32,
}

Str_Hor_Align :: enum {
    Left,
    Center,
    Right,
}

Str_Ver_Align :: enum {
    Top,
    Center,
    Bottom,
}

gen_pers_render_data :: proc(display_size: Vec_2D_I) -> (Pers_Render_Data, bool) {
    assert(display_size.x > 0 && display_size.y > 0)

    render_data: Pers_Render_Data

    render_data.batch_shader_prog = load_batch_shader_prog()

    render_data.batch_gl_ids = gen_batch()

    {
        gl.GenTextures(1, &render_data.px_tex_gl_id)
        gl.BindTexture(gl.TEXTURE_2D, render_data.px_tex_gl_id)
        px_data := [TEXTURE_CHANNEL_CNT]u8{255, 255, 255, 255}
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, &px_data)
    }

    //
    // Surfaces
    //
    if !init_surfaces(&render_data.surfs, display_size) {
        return render_data, false
    }

    gl.GenVertexArrays(1, &render_data.surf_vert_array_gl_id)
    gl.BindVertexArray(render_data.surf_vert_array_gl_id)

    gl.GenBuffers(1, &render_data.surf_vert_buf_gl_id)
    gl.BindBuffer(gl.ARRAY_BUFFER, render_data.surf_vert_buf_gl_id)

    {
        verts := [?]f32 {
            -1.0,
            -1.0,
            0.0,
            0.0,
            1.0,
            -1.0,
            1.0,
            0.0,
            1.0,
            1.0,
            1.0,
            1.0,
            -1.0,
            1.0,
            0.0,
            1.0,
        }

        gl.BufferData(gl.ARRAY_BUFFER, size_of(verts), &verts[0], gl.STATIC_DRAW)
    }

    gl.GenBuffers(1, &render_data.surf_elem_buf_gl_id)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_data.surf_elem_buf_gl_id)

    {
        indices := []u16{0, 1, 2, 2, 3, 0}
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices[0], gl.STATIC_DRAW)
    }

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(f32) * 4, size_of(f32) * 0)

    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(f32) * 4, size_of(f32) * 2)
    gl.EnableVertexAttribArray(1)

    gl.BindVertexArray(0)

    return render_data, true
}

clean_pers_render_data :: proc(render_data: ^Pers_Render_Data) {
    gl.DeleteTextures(1, &render_data.px_tex_gl_id)

    gl.DeleteFramebuffers(SURFACE_LIMIT, &render_data.surfs.framebuffer_gl_ids[0])
    gl.DeleteTextures(SURFACE_LIMIT, &render_data.surfs.framebuffer_tex_gl_ids[0])

    gl.DeleteVertexArrays(1, &render_data.batch_gl_ids.vert_array_gl_id)
    gl.DeleteBuffers(1, &render_data.batch_gl_ids.vert_buf_gl_id)
    gl.DeleteBuffers(1, &render_data.batch_gl_ids.elem_buf_gl_id)

    gl.DeleteProgram(render_data.batch_shader_prog.gl_id)

    mem.zero_item(render_data)
}

init_surfaces :: proc(surfs: ^Render_Surfaces, display_size: Vec_2D_I) -> bool {
    assert(mem.check_zero_ptr(surfs, size_of(surfs^)))
    assert(display_size.x > 0 && display_size.y > 0)

    gl.GenFramebuffers(SURFACE_LIMIT, &surfs.framebuffer_gl_ids[0])
    gl.GenTextures(SURFACE_LIMIT, &surfs.framebuffer_tex_gl_ids[0])

    for i in 0 ..< SURFACE_LIMIT {
        if !attach_framebuffer_texture(
            surfs.framebuffer_gl_ids[i],
            surfs.framebuffer_tex_gl_ids[i],
            display_size,
        ) {
            return false
        }
    }

    return true
}

resize_surfaces :: proc(surfs: ^Render_Surfaces, window_size: Vec_2D_I) -> bool {
    assert(window_size.x > 0 && window_size.y > 0)

    gl.DeleteTextures(SURFACE_LIMIT, &surfs.framebuffer_tex_gl_ids[0])
    gl.GenTextures(SURFACE_LIMIT, &surfs.framebuffer_tex_gl_ids[0])

    for i in 0 ..< SURFACE_LIMIT {
        if (!attach_framebuffer_texture(
                   surfs.framebuffer_gl_ids[i],
                   surfs.framebuffer_tex_gl_ids[i],
                   window_size,
               )) {
            return false
        }
    }

    return true
}

attach_framebuffer_texture :: proc(fb_gl_id: u32, tex_gl_id: u32, tex_size: Vec_2D_I) -> bool {
    assert(fb_gl_id != 0)
    assert(tex_gl_id != 0)
    assert(tex_size.x > 0 && tex_size.y > 0)

    gl.BindTexture(gl.TEXTURE_2D, tex_gl_id)
    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        i32(tex_size.x),
        i32(tex_size.y),
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        nil,
    )
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    gl.BindFramebuffer(gl.FRAMEBUFFER, fb_gl_id)

    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex_gl_id, 0)

    success := gl.CheckFramebufferStatus(gl.FRAMEBUFFER) == gl.FRAMEBUFFER_COMPLETE

    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

    return success
}

create_shader_from_src :: proc(src: string, frag: bool) -> u32 {
    src_c_str, src_c_str_err := strings.clone_to_cstring(src, context.temp_allocator)

    if src_c_str_err != nil {
        return 0
    }

    shader_type: u32 = frag ? gl.FRAGMENT_SHADER : gl.VERTEX_SHADER

    gl_id := gl.CreateShader(shader_type)

    gl.ShaderSource(gl_id, 1, &src_c_str, nil)
    gl.CompileShader(gl_id)

    compile_success: i32
    gl.GetShaderiv(gl_id, gl.COMPILE_STATUS, &compile_success)

    if compile_success == 0 {
        gl.DeleteShader(gl_id)
        return 0
    }

    return gl_id
}

create_shader_prog_from_srcs :: proc(vert_shader_src: string, frag_shader_src: string) -> u32 {
    vert_shader_gl_id := create_shader_from_src(vert_shader_src, false)

    if vert_shader_gl_id == 0 {
        return 0
    }

    frag_shader_gl_id := create_shader_from_src(frag_shader_src, true)

    if frag_shader_gl_id == 0 {
        gl.DeleteShader(vert_shader_gl_id)
        return 0
    }

    prog_gl_id := gl.CreateProgram()
    gl.AttachShader(prog_gl_id, vert_shader_gl_id)
    gl.AttachShader(prog_gl_id, frag_shader_gl_id)
    gl.LinkProgram(prog_gl_id)

    gl.DeleteShader(vert_shader_gl_id)
    gl.DeleteShader(frag_shader_gl_id)

    return prog_gl_id
}

load_batch_shader_prog :: proc() -> Batch_Shader_Prog {
    vert_shader_src := `#version 430 core

layout (location = 0) in vec2 a_vert;
layout (location = 1) in vec2 a_pos;
layout (location = 2) in vec2 a_size;
layout (location = 3) in float a_rot;
layout (location = 4) in vec2 a_tex_coord;
layout (location = 5) in vec4 a_blend;

out vec2 v_tex_coord;
out vec4 v_blend;

uniform mat4 u_view;
uniform mat4 u_proj;

void main() {
    float rot_cos = cos(a_rot);
    float rot_sin = -sin(a_rot);

    mat4 model = mat4(
        vec4(a_size.x * rot_cos, a_size.x * rot_sin, 0.0, 0.0),
        vec4(a_size.y * -rot_sin, a_size.y * rot_cos, 0.0, 0.0),
        vec4(0.0, 0.0, 1.0, 0.0),
        vec4(a_pos.x, a_pos.y, 0.0, 1.0)
    );

    gl_Position = u_proj * u_view * model * vec4(a_vert, 0.0, 1.0);
    v_tex_coord = a_tex_coord;
    v_blend = a_blend;
}`


    frag_shader_src := `#version 430 core

in vec2 v_tex_coord;
in vec4 v_blend;

out vec4 o_frag_color;

uniform sampler2D u_tex;

void main() {
    vec4 tex_color = texture(u_tex, v_tex_coord);
    o_frag_color = tex_color * v_blend;
}`


    prog: Batch_Shader_Prog
    prog.gl_id = create_shader_prog_from_srcs(vert_shader_src, frag_shader_src)
    assert(prog.gl_id != 0)

    prog.proj_uniform_loc = int(gl.GetUniformLocation(prog.gl_id, "u_proj"))
    prog.view_uniform_loc = int(gl.GetUniformLocation(prog.gl_id, "u_view"))
    prog.textures_uniform_loc = int(gl.GetUniformLocation(prog.gl_id, "u_textures"))

    return prog
}

gen_batch :: proc() -> Batch_GL_IDs {
    gl_ids: Batch_GL_IDs

    // Generate vertex array.
    gl.GenVertexArrays(1, &gl_ids.vert_array_gl_id)
    gl.BindVertexArray(gl_ids.vert_array_gl_id)

    // Generate vertex buffer.
    gl.GenBuffers(1, &gl_ids.vert_buf_gl_id)
    gl.BindBuffer(gl.ARRAY_BUFFER, gl_ids.vert_buf_gl_id)
    gl.BufferData(gl.ARRAY_BUFFER, BATCH_SLOT_VERTS_SIZE * BATCH_SLOT_CNT, nil, gl.DYNAMIC_DRAW)

    // Generate element buffer.
    gl.GenBuffers(1, &gl_ids.elem_buf_gl_id)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl_ids.elem_buf_gl_id)

    indices: [BATCH_SLOT_ELEM_CNT * BATCH_SLOT_CNT]u16

    for i := 0; i < BATCH_SLOT_CNT; i += 1 {
        indices[(i * 6) + 0] = u16((i * 4) + 0)
        indices[(i * 6) + 1] = u16((i * 4) + 1)
        indices[(i * 6) + 2] = u16((i * 4) + 2)
        indices[(i * 6) + 3] = u16((i * 4) + 2)
        indices[(i * 6) + 4] = u16((i * 4) + 3)
        indices[(i * 6) + 5] = u16((i * 4) + 0)
    }

    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

    // Set vertex attribute pointers.
    verts_stride: i32 = size_of(f32) * BATCH_SHADER_PROG_VERT_CNT

    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, verts_stride, size_of(f32) * 0)
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, verts_stride, size_of(f32) * 2)
    gl.EnableVertexAttribArray(1)

    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, verts_stride, size_of(f32) * 4)
    gl.EnableVertexAttribArray(2)

    gl.VertexAttribPointer(3, 1, gl.FLOAT, gl.FALSE, verts_stride, size_of(f32) * 6)
    gl.EnableVertexAttribArray(3)

    gl.VertexAttribPointer(4, 2, gl.FLOAT, gl.FALSE, verts_stride, size_of(f32) * 7)
    gl.EnableVertexAttribArray(4)

    gl.VertexAttribPointer(5, 4, gl.FLOAT, gl.FALSE, verts_stride, size_of(f32) * 9)
    gl.EnableVertexAttribArray(5)

    return gl_ids
}

load_textures :: proc(
    tex_cnt: int,
    tex_index_to_file_path_func: Texture_Index_To_File_Path,
    allocator := context.allocator,
) -> (
    Textures,
    bool,
) {
    assert(tex_cnt > 0)
    assert(tex_index_to_file_path_func != nil)

    textures: Textures

    textures.gl_ids = make([]u32, tex_cnt, allocator)

    if textures.gl_ids == nil {
        return textures, false
    }

    textures.sizes = make([]Vec_2D_I, tex_cnt, allocator)

    if textures.sizes == nil {
        return textures, false
    }

    gl.GenTextures(i32(tex_cnt), &textures.gl_ids[0])

    for i in 0 ..< tex_cnt {
        fp := tex_index_to_file_path_func(i)

        fp_c_str, fp_c_str_err := strings.clone_to_cstring(fp, context.temp_allocator)

        if fp_c_str_err != nil {
            return textures, false
        }

        width, height, channel_cnt: i32
        px_data := stbi.load(fp_c_str, &width, &height, &channel_cnt, TEXTURE_CHANNEL_CNT)

        if px_data == nil {
            fmt.printf("Failed to load image with file path \"%s\"!\n", fp)
            return textures, false
        }

        defer stbi.image_free(px_data)

        textures.sizes[i] = {int(width), int(height)}

        gl.BindTexture(gl.TEXTURE_2D, textures.gl_ids[i])
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGBA,
            width,
            height,
            0,
            gl.RGBA,
            gl.UNSIGNED_BYTE,
            px_data,
        )
    }

    return textures, true
}

unload_textures :: proc(textures: ^Textures) {
    if len(textures.gl_ids) > 0 {
        gl.DeleteTextures(i32(len(textures.gl_ids)), &textures.gl_ids[0])
    }

    mem.zero_item(textures)
}

get_texture_cnt :: proc(textures: ^Textures) -> int {
    return len(textures.gl_ids)
}

load_fonts :: proc(
    allocator: mem.Allocator,
    font_cnt: int,
    font_index_to_load_info: Font_Index_To_Load_Info,
) -> (
    Fonts,
    bool,
) {
    assert(font_cnt > 0)
    assert(font_index_to_load_info != nil)

    fonts: Fonts

    // Reserve memory for font data.
    fonts.arrangement_infos = make([]Font_Arrangement_Info, font_cnt, allocator)

    if fonts.arrangement_infos == nil {
        return fonts, false
    }

    fonts.tex_gl_ids = make([]u32, font_cnt, allocator)

    if fonts.tex_gl_ids == nil {
        return fonts, false
    }

    fonts.tex_heights = make([]int, font_cnt, allocator)

    if fonts.tex_heights == nil {
        return fonts, false
    }

    // Reserve temporary memory to use as working space to store pixel data for each font texture.
    px_data_scratch_space := make(
        []u8,
        TEXTURE_CHANNEL_CNT * FONT_TEXTURE_WIDTH * FONT_TEXTURE_HEIGHT_LIMIT,
        context.temp_allocator,
    )

    if px_data_scratch_space == nil {
        return fonts, false
    }

    // Generate font textures upfront.
    gl.GenTextures(i32(len(fonts.tex_gl_ids)), &fonts.tex_gl_ids[0])

    // Load each font.
    for i in 0 ..< font_cnt {
        font_load_info := font_index_to_load_info(i)
        assert(font_load_info.height > 0)

        font_file_data, font_file_read_err := os.read_entire_file_from_filename_or_err(
            font_load_info.file_path,
            context.temp_allocator,
        )

        if font_file_read_err != nil {
            return fonts, false
        }

        font_info: stbtt.fontinfo

        if !stbtt.InitFont(
            &font_info,
            &font_file_data[0],
            stbtt.GetFontOffsetForIndex(&font_file_data[0], 0),
        ) {
            return fonts, false
        }

        scale := stbtt.ScaleForPixelHeight(&font_info, f32(font_load_info.height))

        ascent, descent, line_gap: i32
        stbtt.GetFontVMetrics(&font_info, &ascent, &descent, &line_gap)

        fonts.arrangement_infos[i].line_height = int(f32(ascent - descent + line_gap) * scale)

        for y in 0 ..< FONT_TEXTURE_HEIGHT_LIMIT {
            for x in 0 ..< FONT_TEXTURE_WIDTH {
                px_index := ((y * FONT_TEXTURE_WIDTH) + x) * TEXTURE_CHANNEL_CNT

                // Initialise to transparent white.
                px_data_scratch_space[px_index + 0] = 255
                px_data_scratch_space[px_index + 1] = 255
                px_data_scratch_space[px_index + 2] = 255
                px_data_scratch_space[px_index + 3] = 0
            }
        }

        chr_render_pos: Vec_2D_I

        for j in 0 ..< FONT_CHR_RANGE_LEN {
            chr := rune(FONT_CHR_RANGE_BEGIN + j)

            advance: i32
            stbtt.GetCodepointHMetrics(&font_info, chr, &advance, nil)

            fonts.arrangement_infos[i].chr_hor_advances[j] = int(f32(advance) * scale)

            if chr == ' ' {
                continue
            }

            bitmap_width, bitmap_height: i32
            bitmap_offs_x, bitmap_offs_y: i32

            bitmap_raw := stbtt.GetCodepointBitmap(
                &font_info,
                0,
                scale,
                chr,
                &bitmap_width,
                &bitmap_height,
                &bitmap_offs_x,
                &bitmap_offs_y,
            )

            if bitmap_raw == nil {
                return fonts, false
            }

            defer stbtt.FreeBitmap(bitmap_raw, nil)

            bitmap := mem.slice_ptr(
                bitmap_raw,
                int(bitmap_width * bitmap_height * TEXTURE_CHANNEL_CNT),
            )

            fonts.arrangement_infos[i].chr_hor_offsets[j] = int(bitmap_offs_x)
            fonts.arrangement_infos[i].chr_ver_offsets[j] =
                int(bitmap_offs_y) + int(f32(ascent) * scale)

            if chr_render_pos.x + int(bitmap_width) > FONT_TEXTURE_WIDTH {
                chr_render_pos.x = 0
                chr_render_pos.y += fonts.arrangement_infos[i].line_height
            }

            fonts.tex_heights[i] = max(fonts.tex_heights[i], chr_render_pos.y + int(bitmap_height))

            if fonts.tex_heights[i] > FONT_TEXTURE_HEIGHT_LIMIT {
                return fonts, false
            }

            fonts.arrangement_infos[i].chr_src_rects[j] = {
                chr_render_pos.x,
                chr_render_pos.y,
                int(bitmap_width),
                int(bitmap_height),
            }

            for y in 0 ..< int(bitmap_height) {
                for x in 0 ..< int(bitmap_width) {
                    px_pos := Vec_2D_I{chr_render_pos.x + x, chr_render_pos.y + y}
                    px_index := ((px_pos.y * FONT_TEXTURE_WIDTH) + px_pos.x) * TEXTURE_CHANNEL_CNT

                    bitmap_index := (y * int(bitmap_width)) + x
                    px_data_scratch_space[px_index + 3] = bitmap[bitmap_index]
                }
            }

            chr_render_pos.x += int(bitmap_width)
        }

        gl.BindTexture(gl.TEXTURE_2D, fonts.tex_gl_ids[i])
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGBA,
            FONT_TEXTURE_WIDTH,
            i32(fonts.tex_heights[i]),
            0,
            gl.RGBA,
            gl.UNSIGNED_BYTE,
            &px_data_scratch_space[0],
        )
    }

    return fonts, true
}

unload_fonts :: proc(fonts: ^Fonts) {
    if len(fonts.tex_gl_ids) > 0 {
        gl.DeleteTextures(i32(len(fonts.tex_gl_ids)), &fonts.tex_gl_ids[0])
    }

    mem.zero_item(fonts)
}

get_font_cnt :: proc(fonts: ^Fonts) -> int {
    return len(fonts.arrangement_infos)
}

load_shader_progs :: proc(
    allocator: mem.Allocator,
    prog_cnt: int,
    prog_index_to_file_paths_func: Shader_Prog_Index_To_File_Paths,
) -> (
    Shader_Progs,
    bool,
) {
    assert(prog_cnt > 0)
    assert(prog_index_to_file_paths_func != nil)

    progs: Shader_Progs

    progs.gl_ids = make([]u32, prog_cnt, allocator)

    if progs.gl_ids == nil {
        return progs, false
    }

    for i in 0 ..< prog_cnt {
        vert_fp, frag_fp := prog_index_to_file_paths_func(i)

        vert_contents, vert_contents_read_err := os.read_entire_file_from_filename_or_err(
            vert_fp,
            context.temp_allocator,
        )

        if vert_contents_read_err != nil {
            return progs, false
        }

        frag_contents, frag_contents_read_err := os.read_entire_file_from_filename_or_err(
            frag_fp,
            context.temp_allocator,
        )

        if frag_contents_read_err != nil {
            return progs, false
        }

        progs.gl_ids[i] = create_shader_prog_from_srcs(
            string(vert_contents),
            string(frag_contents),
        )

        if progs.gl_ids[i] == 0 {
            return progs, false
        }
    }

    return progs, true
}

unload_shader_progs :: proc(progs: ^Shader_Progs) {
    for i in 0 ..< len(progs.gl_ids) {
        gl.DeleteProgram(progs.gl_ids[i])
    }

    mem.zero_item(progs)
}

begin_rendering :: proc(state: ^Rendering_State) {
    mem.zero_item(state)
    state.view_mat[0][0] = 1.0
    state.view_mat[1][1] = 1.0
    state.view_mat[2][2] = 1.0
    state.view_mat[3][3] = 1.0
}

render_clear :: proc(col := Vec_4D{}) {
    gl.ClearColor(col.x, col.y, col.z, col.w)
    gl.Clear(gl.COLOR_BUFFER_BIT)
}

render :: proc(
    rendering_context: ^Rendering_Context,
    tex_gl_id: u32,
    tex_coords: Rect_Edges,
    pos: Vec_2D,
    size: Vec_2D,
    origin := Vec_2D{0.5, 0.5},
    rot: f32 = 0.0,
    blend := WHITE,
) {
    assert(is_color_valid_4d(blend))

    if rendering_context.state.batch_slots_used_cnt == 0 {
        rendering_context.state.batch_tex_gl_id = tex_gl_id
    } else if rendering_context.state.batch_slots_used_cnt == BATCH_SLOT_CNT ||
       tex_gl_id != rendering_context.state.batch_tex_gl_id {
        flush(rendering_context)
        render(rendering_context, tex_gl_id, tex_coords, pos, size, origin, rot, blend)
        return
    }

    // Submit the vertex data to the batch.
    slot_index := rendering_context.state.batch_slots_used_cnt
    slot_verts := &rendering_context.state.batch_slot_verts[slot_index]

    slot_verts[0] = 0.0 - origin.x
    slot_verts[1] = 0.0 - origin.y
    slot_verts[2] = pos.x
    slot_verts[3] = pos.y
    slot_verts[4] = size.x
    slot_verts[5] = size.y
    slot_verts[6] = rot
    slot_verts[7] = tex_coords.left
    slot_verts[8] = tex_coords.top
    slot_verts[9] = blend.x
    slot_verts[10] = blend.y
    slot_verts[11] = blend.z
    slot_verts[12] = blend.w

    slot_verts[13] = 1.0 - origin.x
    slot_verts[14] = 0.0 - origin.y
    slot_verts[15] = pos.x
    slot_verts[16] = pos.y
    slot_verts[17] = size.x
    slot_verts[18] = size.y
    slot_verts[19] = rot
    slot_verts[20] = tex_coords.right
    slot_verts[21] = tex_coords.top
    slot_verts[22] = blend.x
    slot_verts[23] = blend.y
    slot_verts[24] = blend.z
    slot_verts[25] = blend.w

    slot_verts[26] = 1.0 - origin.x
    slot_verts[27] = 1.0 - origin.y
    slot_verts[28] = pos.x
    slot_verts[29] = pos.y
    slot_verts[30] = size.x
    slot_verts[31] = size.y
    slot_verts[32] = rot
    slot_verts[33] = tex_coords.right
    slot_verts[34] = tex_coords.bottom
    slot_verts[35] = blend.x
    slot_verts[36] = blend.y
    slot_verts[37] = blend.z
    slot_verts[38] = blend.w

    slot_verts[39] = 0.0 - origin.x
    slot_verts[40] = 1.0 - origin.y
    slot_verts[41] = pos.x
    slot_verts[42] = pos.y
    slot_verts[43] = size.x
    slot_verts[44] = size.y
    slot_verts[45] = rot
    slot_verts[46] = tex_coords.left
    slot_verts[47] = tex_coords.bottom
    slot_verts[48] = blend.x
    slot_verts[49] = blend.y
    slot_verts[50] = blend.z
    slot_verts[51] = blend.w

    rendering_context.state.batch_slots_used_cnt += 1
}

render_texture :: proc(
    rendering_context: ^Rendering_Context,
    tex_index: int,
    textures: ^Textures,
    src_rect: Rect_I,
    pos: Vec_2D,
    origin := Vec_2D{0.5, 0.5},
    scale := Vec_2D{1.0, 1.0},
    rot: f32 = 0.0,
    blend := WHITE,
) {
    assert(tex_index >= 0 && tex_index < get_texture_cnt(textures))
    assert(is_color_valid_4d(blend))

    tex_size := textures.sizes[tex_index]
    tex_coords := calc_texture_coords(src_rect, tex_size)
    render(
        rendering_context,
        textures.gl_ids[tex_index],
        tex_coords,
        pos,
        {f32(src_rect.width) * scale.x, f32(src_rect.height) * scale.y},
        origin,
        rot,
        blend,
    )
}

render_str :: proc(
    rendering_context: ^Rendering_Context,
    str: string,
    font_index: int,
    fonts: ^Fonts,
    pos: Vec_2D,
    hor_align := Str_Hor_Align.Center,
    ver_align := Str_Ver_Align.Center,
    blend := WHITE,
) {
    assert(is_color_valid_4d(blend))

    chr_positions := gen_str_chr_positions(str, font_index, fonts, pos, hor_align, ver_align)

    font_tex_gl_id := fonts.tex_gl_ids[font_index]
    font_tex_size := Vec_2D_I{FONT_TEXTURE_WIDTH, fonts.tex_heights[font_index]}

    for i in 0 ..< len(str) {
        if str[i] == 0 || str[i] == ' ' {
            continue
        }

        chr_index := str[i] - FONT_CHR_RANGE_BEGIN

        chr_src_rect := fonts.arrangement_infos[font_index].chr_src_rects[chr_index]
        chr_tex_coords := calc_texture_coords(chr_src_rect, font_tex_size)

        render(
            rendering_context,
            fonts.tex_gl_ids[font_index],
            chr_tex_coords,
            chr_positions[i],
            {f32(chr_src_rect.width), f32(chr_src_rect.height)},
            {},
            0.0,
            blend,
        )
    }
}

render_rect :: proc(rendering_context: ^Rendering_Context, rect: Rect, blend := WHITE) {
    assert(rect.width > 0.0 && rect.height > 0.0)
    assert(is_color_valid_4d(blend))

    render(
        rendering_context,
        rendering_context.pers.px_tex_gl_id,
        {0.0, 0.0, 1.0, 1.0},
        calc_rect_pos(rect),
        calc_rect_size(rect),
        {},
        0.0,
        blend,
    )
}

render_rect_outline :: proc(
    rendering_context: ^Rendering_Context,
    rect: Rect,
    inside := false,
    blend := WHITE,
    thickness: f32 = 1.0,
) {
    assert(rect.width > 0.0 && rect.height > 0.0)
    assert(is_color_valid_4d(blend))
    assert(thickness > 0.0)

    rect := rect

    if inside {
        rect = {
            rect.x + thickness,
            rect.y + thickness,
            rect.width - (thickness * 2.0),
            rect.height - (thickness * 2.0),
        }
    }

    outline_top_rect := Rect {
        rect.x - thickness,
        rect.y - thickness,
        thickness + rect.width,
        thickness,
    }

    outline_right_rect := Rect {
        rect.x + rect.width,
        rect.y - thickness,
        thickness,
        thickness + rect.height,
    }

    outline_bottom_rect := Rect{rect.x, rect.y + rect.height, rect.width + thickness, thickness}

    outline_left_rect := Rect{rect.x - thickness, rect.y, thickness, rect.height + thickness}

    render_rect(rendering_context, outline_top_rect, blend)
    render_rect(rendering_context, outline_right_rect, blend)
    render_rect(rendering_context, outline_bottom_rect, blend)
    render_rect(rendering_context, outline_left_rect, blend)
}

render_line :: proc(
    rendering_context: ^Rendering_Context,
    a: Vec_2D,
    b: Vec_2D,
    blend := WHITE,
    width: f32 = 1.0,
) {
    assert(is_color_valid_4d(blend))
    assert(width > 0.0)

    len := calc_dist(a, b)
    rot := calc_dir(b - a)

    render(
        rendering_context,
        rendering_context.pers.px_tex_gl_id,
        {0.0, 0.0, 1.0, 1.0},
        a,
        {len, width},
        {0.0, 0.5},
        rot,
        blend,
    )
}

render_poly_outline :: proc(
    rendering_context: ^Rendering_Context,
    poly: Poly,
    blend := WHITE,
    width: f32 = 1.0,
) {
    assert(is_color_valid_4d(blend))
    assert(width > 0.0)

    for i in 0 ..< len(poly.pts) {
        pt_a := poly.pts[i]
        pt_b := poly.pts[(i + 1) % len(poly.pts)]

        render_line(rendering_context, pt_a, pt_b, blend, width)
    }
}

render_bar_hor :: proc(
    rendering_context: ^Rendering_Context,
    rect: Rect,
    perc: f32,
    col_front: Vec_3D,
    col_back: Vec_3D,
) {
    assert(perc >= 0.0 && perc <= 1.0)
    assert(is_color_valid_3d(col_front))
    assert(is_color_valid_3d(col_back))

    left_rect := Rect{rect.x, rect.y, 0.0, rect.height}

    if perc > 0.0 {
        left_rect.width = rect.width * perc
        render_rect(rendering_context, left_rect, {col_front.r, col_front.g, col_front.b, 1.0})
    }

    if perc < 1.0 {
        right_rect := Rect {
            rect.x + left_rect.width,
            rect.y,
            rect.width - left_rect.width,
            rect.height,
        }
        render_rect(rendering_context, right_rect, {col_back.r, col_back.g, col_back.b, 1.0})
    }
}

set_surface :: proc(rendering_context: ^Rendering_Context, surf_index: int) {
    // NOTE: Should flushing be a prerequisite to this?

    assert(surf_index >= 0 && surf_index < SURFACE_LIMIT)
    assert(rendering_context.state.surf_index_stack_height < SURFACE_LIMIT)

    // Add the surface index to the stack.
    rendering_context.state.surf_index_stack[rendering_context.state.surf_index_stack_height] =
        surf_index
    rendering_context.state.surf_index_stack_height += 1

    // Bind the surface framebuffer.
    gl.BindFramebuffer(gl.FRAMEBUFFER, rendering_context.pers.surfs.framebuffer_gl_ids[surf_index])
}

unset_surface :: proc(rendering_context: ^Rendering_Context) {
    assert(
        rendering_context.state.batch_slots_used_cnt == 0,
        "The current render batch needs to have been flushed before unsetting render surface!",
    )
    assert(rendering_context.state.surf_index_stack_height > 0)

    rendering_context.state.surf_index_stack_height -= 1

    if (rendering_context.state.surf_index_stack_height == 0) {
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    } else {
        new_surf_index := rendering_context.state.surf_index_stack_height
        fb_gl_id := rendering_context.pers.surfs.framebuffer_gl_ids[new_surf_index]
        gl.BindFramebuffer(
            gl.FRAMEBUFFER,
            rendering_context.pers.surfs.framebuffer_gl_ids[new_surf_index],
        )
    }
}

set_surface_shader_prog :: proc(rendering_context: ^Rendering_Context, gl_id: u32) {
    assert(gl_id != 0)
    // NOTE: Should we also trip an assert if current shader program GL ID is not 0?

    rendering_context.state.surf_shader_prog_gl_id = gl_id
    gl.UseProgram(rendering_context.state.surf_shader_prog_gl_id)
}

set_surface_shader_prog_uniform :: proc(
    rendering_context: ^Rendering_Context,
    name: string,
    val: Shader_Prog_Uniform_Value,
) {
    assert(
        rendering_context.state.surf_shader_prog_gl_id != 0,
        "Surface shader program must be set before modifying uniforms!",
    )

    name_c_str := strings.clone_to_cstring(name, context.temp_allocator)
    loc := gl.GetUniformLocation(rendering_context.state.surf_shader_prog_gl_id, name_c_str)
    assert(loc != -1, "Failed to get location of shader uniform!")

    switch &v in val {
    case i32:
        gl.Uniform1i(loc, v)
    case f32:
        gl.Uniform1f(loc, v)
    case Vec_2D:
        gl.Uniform2f(loc, v.x, v.y)
    case Vec_3D:
        gl.Uniform3f(loc, v.x, v.y, v.z)
    case Vec_4D:
        gl.Uniform4f(loc, v.x, v.y, v.z, v.w)
    case matrix[4, 4]f32:
        gl.UniformMatrix4fv(loc, 1, false, &v[0][0])
    }
}

render_surface :: proc(rendering_context: ^Rendering_Context, surf_index: int) {
    assert(surf_index >= 0 && surf_index < SURFACE_LIMIT)
    assert(
        rendering_context.state.surf_shader_prog_gl_id != 0,
        "Surface shader program must be set before rendering a surface!",
    )

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, rendering_context.pers.surfs.framebuffer_tex_gl_ids[surf_index])

    gl.BindVertexArray(rendering_context.pers.surf_vert_array_gl_id)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rendering_context.pers.surf_elem_buf_gl_id)
    gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_SHORT, nil)
}

flush :: proc(rendering_context: ^Rendering_Context) {
    if rendering_context.state.batch_slots_used_cnt == 0 {
        return
    }

    // Write the batch vertex data to the GPU.
    gl.BindVertexArray(rendering_context.pers.batch_gl_ids.vert_array_gl_id)
    gl.BindBuffer(gl.ARRAY_BUFFER, rendering_context.pers.batch_gl_ids.vert_buf_gl_id)

    write_size := BATCH_SLOT_VERTS_SIZE * rendering_context.state.batch_slots_used_cnt
    gl.BufferSubData(
        gl.ARRAY_BUFFER,
        0,
        int(write_size),
        &rendering_context.state.batch_slot_verts[0][0],
    )

    // Draw the batch.
    prog := &rendering_context.pers.batch_shader_prog

    gl.UseProgram(prog.gl_id)

    proj_mat := gen_ortho_matrix_4x4(
        0.0,
        f32(rendering_context.display_size.x),
        f32(rendering_context.display_size.y),
        0.0,
        -1.0,
        1.0,
    )

    gl.UniformMatrix4fv(i32(prog.proj_uniform_loc), 1, false, &proj_mat[0][0])
    gl.UniformMatrix4fv(
        i32(prog.view_uniform_loc),
        1,
        false,
        &rendering_context.state.view_mat[0][0],
    )

    gl.BindTexture(gl.TEXTURE_2D, rendering_context.state.batch_tex_gl_id)

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rendering_context.pers.batch_gl_ids.elem_buf_gl_id)
    gl.DrawElements(
        gl.TRIANGLES,
        i32(BATCH_SLOT_ELEM_CNT * rendering_context.state.batch_slots_used_cnt),
        gl.UNSIGNED_SHORT,
        nil,
    )

    // Reset batch state.
    rendering_context.state.batch_slots_used_cnt = 0
    rendering_context.state.batch_tex_gl_id = 0
}

calc_texture_coords :: proc(src_rect: Rect_I, tex_size: Vec_2D_I) -> Rect_Edges {
    assert(src_rect.width > 0 && src_rect.height > 0 && tex_size.x > 0 && tex_size.y > 0)

    return {
        f32(src_rect.x) / f32(tex_size.x),
        f32(src_rect.y) / f32(tex_size.y),
        f32(calc_rect_i_right(src_rect)) / f32(tex_size.x),
        f32(calc_rect_i_bottom(src_rect)) / f32(tex_size.y),
    }
}

gen_str_chr_positions :: proc(
    str: string,
    font_index: int,
    fonts: ^Fonts,
    pos: Vec_2D,
    hor_align := Str_Hor_Align.Center,
    ver_align := Str_Ver_Align.Center,
) -> [RENDERABLE_STR_BUF_SIZE]Vec_2D {
    apply_hor_align_offs_to_line :: proc(
        line_chr_positions: []Vec_2D,
        hor_align: Str_Hor_Align,
        line_end_x: f32,
    ) {
        line_width := line_end_x - line_chr_positions[0].x
        align_offs := -(f32(line_width) * f32(hor_align) * 0.5)

        for i in 0 ..< len(line_chr_positions) {
            line_chr_positions[i].x += align_offs
        }
    }

    assert(font_index >= 0 && font_index < get_font_cnt(fonts))

    str_len := len(str)
    assert(str_len > 0 && str_len <= RENDERABLE_STR_BUF_SIZE)

    chr_positions: [RENDERABLE_STR_BUF_SIZE]Vec_2D

    font_ai := &fonts.arrangement_infos[font_index]

    cur_line_begin_chr_index := 0

    chr_base_pos_pen: Vec_2D

    for i in 0 ..< str_len {
        chr := str[i]

        if chr == 0 {
            continue
        }

        if chr == '\n' {
            // Apply horizontal alignment offset to the past line.
            line_chr_positions := mem.slice_ptr(
                &chr_positions[cur_line_begin_chr_index],
                i - cur_line_begin_chr_index,
            )

            cur_line_begin_chr_index = i + 1

            apply_hor_align_offs_to_line(line_chr_positions, hor_align, chr_base_pos_pen.x + pos.x)

            // Move the pen down to the next line.
            chr_base_pos_pen.x = 0.0
            chr_base_pos_pen.y += f32(font_ai.line_height)

            continue
        }

        chr_index := int(chr) - FONT_CHR_RANGE_BEGIN

        chr_positions[i] = {
            chr_base_pos_pen.x + pos.x + f32(font_ai.chr_hor_offsets[chr_index]),
            chr_base_pos_pen.y + pos.y + f32(font_ai.chr_ver_offsets[chr_index]),
        }

        chr_base_pos_pen.x += f32(font_ai.chr_hor_advances[chr_index])
    }

    apply_hor_align_offs_to_line(
        mem.slice_ptr(
            &chr_positions[cur_line_begin_chr_index],
            str_len - cur_line_begin_chr_index,
        ),
        hor_align,
        chr_base_pos_pen.x + pos.x,
    )

    // Apply vertical alignment offset to all characters.
    height := chr_base_pos_pen.y + f32(font_ai.line_height)
    ver_align_offs := -(f32(height) * f32(ver_align) * 0.5)

    for i in 0 ..< str_len {
        chr_positions[i].y += ver_align_offs
    }

    return chr_positions
}

gen_str_collider :: proc(
    str: string,
    font_index: int,
    fonts: ^Fonts,
    pos: Vec_2D,
    hor_align := Str_Hor_Align.Center,
    ver_align := Str_Ver_Align.Center,
) -> Rect {
    str_len := len(str)
    assert(str_len > 0)

    chr_positions := gen_str_chr_positions(str, font_index, fonts, pos, hor_align, ver_align)

    str_collider_edges: Rect_Edges
    str_collider_edges_initted: bool

    for i in 0 ..< str_len {
        if str[i] == 0 || str[i] == '\n' {
            continue
        }

        chr_index := int(str[i]) - FONT_CHR_RANGE_BEGIN

        chr_src_rect_size := calc_rect_i_size(
            fonts.arrangement_infos[font_index].chr_src_rects[chr_index],
        )

        chr_collider_edges := Rect_Edges {
            chr_positions[i].x,
            chr_positions[i].y,
            chr_positions[i].x + f32(chr_src_rect_size.x),
            chr_positions[i].y + f32(chr_src_rect_size.y),
        }

        if !str_collider_edges_initted {
            str_collider_edges = chr_collider_edges
            str_collider_edges_initted = true
        } else {
            str_collider_edges.left = min(chr_collider_edges.left, str_collider_edges.left)
            str_collider_edges.top = min(chr_collider_edges.top, str_collider_edges.top)
            str_collider_edges.right = max(chr_collider_edges.right, str_collider_edges.right)
            str_collider_edges.bottom = max(chr_collider_edges.bottom, str_collider_edges.bottom)
        }
    }

    assert(str_collider_edges_initted)

    return {
        str_collider_edges.left,
        str_collider_edges.top,
        str_collider_edges.right - str_collider_edges.left,
        str_collider_edges.bottom - str_collider_edges.top,
    }
}

is_color_valid_3d :: proc(col: Vec_3D) -> bool {
    return(
        col.r >= 0.0 &&
        col.r <= 1.0 &&
        col.g >= 0.0 &&
        col.g <= 1.0 &&
        col.b >= 0.0 &&
        col.b <= 1.0 \
    )
}

is_color_valid_4d :: proc(col: Vec_4D) -> bool {
    return is_color_valid_3d(col.rgb) && col.a >= 0.0 && col.a <= 1.0
}

