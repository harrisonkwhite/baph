#include "gce_utils.h"
#include <stdlib.h>
#include <math.h>
#include <stb_image.h>
#include <stb_truetype.h>
#include <gce_rendering.h>

static t_gl_id CreateShaderFromSrc(const char* const src, const bool frag) {
    assert(src);

    const GLenum shader_type = frag ? GL_FRAGMENT_SHADER : GL_VERTEX_SHADER;
    const t_gl_id shader_gl_id = glCreateShader(shader_type);
    glShaderSource(shader_gl_id, 1, &src, NULL);
    glCompileShader(shader_gl_id);

    GLint success;
    glGetShaderiv(shader_gl_id, GL_COMPILE_STATUS, &success);

    if (!success) {
        glDeleteShader(shader_gl_id);
        return 0;
    }

    return shader_gl_id;
}

static t_gl_id CreateShaderProgFromSrcs(const char* const vert_src, const char* const frag_src) {
    assert(vert_src);
    assert(frag_src);

    const t_gl_id vert_shader_gl_id = CreateShaderFromSrc(vert_src, false);

    if (!vert_shader_gl_id) {
        return 0;
    }

    const t_gl_id frag_shader_gl_id = CreateShaderFromSrc(frag_src, true);

    if (!frag_shader_gl_id) {
        glDeleteShader(vert_shader_gl_id);
        return 0;
    }

    const t_gl_id prog_gl_id = glCreateProgram();
    glAttachShader(prog_gl_id, vert_shader_gl_id);
    glAttachShader(prog_gl_id, frag_shader_gl_id);
    glLinkProgram(prog_gl_id);

    glDeleteShader(vert_shader_gl_id);
    glDeleteShader(frag_shader_gl_id);

    return prog_gl_id;
}

static t_gl_id CreateShaderProgFromFiles(const s_shader_prog_file_paths fps, s_mem_arena* const temp_mem_arena) {
    assert(temp_mem_arena);

    const char* const vs_src = (const char*)PushEntireFileContents(fps.vs_fp, temp_mem_arena, true);

    if (!vs_src) {
        return 0;
    }

    const char* const fs_src = (const char*)PushEntireFileContents(fps.fs_fp, temp_mem_arena, true);

    if (!fs_src) {
        return 0;
    }

    return CreateShaderProgFromSrcs(vs_src, fs_src);
}

bool InitPersRenderData(s_pers_render_data* const render_data, const s_vec_2d_i display_size) {
    assert(render_data);
    assert(IsZero(render_data, sizeof(*render_data)));
    assert(display_size.x > 0 && display_size.y > 0);

    render_data->batch_shader_prog = LoadRenderBatchShaderProg();
    render_data->batch_gl_ids = GenRenderBatch();

    glGenTextures(1, &render_data->px_tex_gl_id);
    glBindTexture(GL_TEXTURE_2D, render_data->px_tex_gl_id);

    //
    // Surfaces
    //
    if (!InitRenderSurfaces(&render_data->surfs, display_size)) {
        return false;
    }

    glGenVertexArrays(1, &render_data->surf_vert_array_gl_id);
    glBindVertexArray(render_data->surf_vert_array_gl_id);

    glGenBuffers(1, &render_data->surf_vert_buf_gl_id);
    glBindBuffer(GL_ARRAY_BUFFER, render_data->surf_vert_buf_gl_id);

    {
        const float verts[] = {
            -1.0, -1.0, 0.0, 0.0,
             1.0, -1.0, 1.0, 0.0,
             1.0,  1.0, 1.0, 1.0,
            -1.0,  1.0, 0.0, 1.0
        };

        glBufferData(GL_ARRAY_BUFFER, sizeof(verts), &verts[0], GL_STATIC_DRAW);
    }

    glGenBuffers(1, &render_data->surf_elem_buf_gl_id);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, render_data->surf_elem_buf_gl_id);

    {
        const unsigned short indices[] = {
            0, 1, 2,
            2, 3, 0
        };

        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), &indices[0], GL_STATIC_DRAW);
    }

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, false, sizeof(float) * 4, (const void*)(sizeof(float) * 0));

    glVertexAttribPointer(1, 2, GL_FLOAT, false, sizeof(float) * 4, (const void*)(sizeof(float) * 2));
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);

    //
    //
    //
    const t_byte px_data[TEXTURE_CHANNEL_CNT] = {255, 255, 255, 255};
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, px_data);

    return true;
}

void CleanPersRenderData(s_pers_render_data* const render_data) {
    assert(render_data);

    glDeleteTextures(1, &render_data->px_tex_gl_id);

    glDeleteVertexArrays(1, &render_data->batch_gl_ids.vert_array_gl_id);
    glDeleteBuffers(1, &render_data->batch_gl_ids.vert_buf_gl_id);
    glDeleteBuffers(1, &render_data->batch_gl_ids.elem_buf_gl_id);

    glDeleteProgram(render_data->batch_shader_prog.gl_id);

    ZeroOut(render_data, sizeof(*render_data));
}

s_render_batch_shader_prog LoadRenderBatchShaderProg() {
    const char* const vert_shader_src = "#version 430 core\n"
        "layout (location = 0) in vec2 a_vert;\n"
        "layout (location = 1) in vec2 a_pos;\n"
        "layout (location = 2) in vec2 a_size;\n"
        "layout (location = 3) in float a_rot;\n"
        "layout (location = 4) in vec2 a_tex_coord;\n"
        "layout (location = 5) in vec4 a_blend;\n"
        "out vec2 v_tex_coord;\n"
        "out vec4 v_blend;\n"
        "uniform mat4 u_view;\n"
        "uniform mat4 u_proj;\n"
        "void main() {\n"
        "    float rot_cos = cos(a_rot);\n"
        "    float rot_sin = -sin(a_rot);\n"
        "    mat4 model = mat4(\n"
        "        vec4(a_size.x * rot_cos, a_size.x * rot_sin, 0.0, 0.0),\n"
        "        vec4(a_size.y * -rot_sin, a_size.y * rot_cos, 0.0, 0.0),\n"
        "        vec4(0.0, 0.0, 1.0, 0.0),\n"
        "        vec4(a_pos.x, a_pos.y, 0.0, 1.0));\n"
        "    gl_Position = u_proj * u_view * model * vec4(a_vert, 0.0, 1.0);\n"
        "    v_tex_coord = a_tex_coord;\n"
        "    v_blend = a_blend;\n"
        "}";

    const char* const frag_shader_src = "#version 430 core\n"
        "in vec2 v_tex_coord;\n"
        "in vec4 v_blend;\n"
        "out vec4 o_frag_color;\n"
        "uniform sampler2D u_tex;\n"
        "void main() {\n"
        "    vec4 tex_color = texture(u_tex, v_tex_coord);\n"
        "    o_frag_color = tex_color * v_blend;\n"
        "}";

    s_render_batch_shader_prog prog = {0};
    prog.gl_id = CreateShaderProgFromSrcs(vert_shader_src, frag_shader_src);
    assert(prog.gl_id != 0);

    prog.proj_uniform_loc = glGetUniformLocation(prog.gl_id, "u_proj");
    prog.view_uniform_loc = glGetUniformLocation(prog.gl_id, "u_view");
    prog.textures_uniform_loc = glGetUniformLocation(prog.gl_id, "u_textures");

    return prog;
}

s_render_batch_gl_ids GenRenderBatch() {
    s_render_batch_gl_ids gl_ids = {0};

    glGenVertexArrays(1, &gl_ids.vert_array_gl_id);
    glBindVertexArray(gl_ids.vert_array_gl_id);

    glGenBuffers(1, &gl_ids.vert_buf_gl_id);
    glBindBuffer(GL_ARRAY_BUFFER, gl_ids.vert_buf_gl_id);
    glBufferData(GL_ARRAY_BUFFER, RENDER_BATCH_SLOT_VERTS_SIZE * RENDER_BATCH_SLOT_CNT, NULL, GL_DYNAMIC_DRAW);

    glGenBuffers(1, &gl_ids.elem_buf_gl_id);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gl_ids.elem_buf_gl_id);

    uint16_t* const indices = malloc(sizeof(uint16_t) * RENDER_BATCH_SLOT_ELEM_CNT * RENDER_BATCH_SLOT_CNT);

    for (int i = 0; i < RENDER_BATCH_SLOT_CNT; ++i) {
        indices[(i * 6) + 0] = (uint16_t)((i * 4) + 0);
        indices[(i * 6) + 1] = (uint16_t)((i * 4) + 1);
        indices[(i * 6) + 2] = (uint16_t)((i * 4) + 2);
        indices[(i * 6) + 3] = (uint16_t)((i * 4) + 2);
        indices[(i * 6) + 4] = (uint16_t)((i * 4) + 3);
        indices[(i * 6) + 5] = (uint16_t)((i * 4) + 0);
    }

    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(uint16_t) * RENDER_BATCH_SLOT_ELEM_CNT * RENDER_BATCH_SLOT_CNT, indices, GL_STATIC_DRAW);
    free(indices);

    const GLsizei stride = sizeof(float) * RENDER_BATCH_SHADER_PROG_VERT_CNT;

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 0));
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 2));
    glEnableVertexAttribArray(1);

    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 4));
    glEnableVertexAttribArray(2);

    glVertexAttribPointer(3, 1, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 6));
    glEnableVertexAttribArray(3);

    glVertexAttribPointer(4, 2, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 7));
    glEnableVertexAttribArray(4);

    glVertexAttribPointer(5, 4, GL_FLOAT, GL_FALSE, stride, (void*)(sizeof(float) * 9));
    glEnableVertexAttribArray(5);

    return gl_ids;
}

bool LoadTexturesFromFiles(s_textures* const textures, s_mem_arena* const mem_arena, const int tex_cnt, const t_texture_index_to_file_path tex_index_to_fp) {
    assert(textures);
    assert(IsZero(textures, sizeof(*textures)));
    assert(mem_arena);
    assert(tex_cnt > 0);
    assert(tex_index_to_fp);

    textures->gl_ids = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, t_gl_id, tex_cnt);

    if (!textures->gl_ids) {
        return false;
    }

    textures->sizes = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, s_vec_2d_i, tex_cnt);

    if (!textures->sizes) {
        return false;
    }

    glGenTextures(tex_cnt, textures->gl_ids);

    for (int i = 0; i < tex_cnt; ++i) {
        const char* const fp = tex_index_to_fp(i);

        int width, height, channel_cnt;
        unsigned char* const px_data = stbi_load(fp, &width, &height, &channel_cnt, TEXTURE_CHANNEL_CNT);

        if (!px_data) {
            fprintf(stderr, "Failed to load image \"%s\"! STB Error: %s\n", fp, stbi_failure_reason());
            return false;
        }

        textures->sizes[i] = (s_vec_2d_i) {width, height};

        glBindTexture(GL_TEXTURE_2D, textures->gl_ids[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, px_data);

        stbi_image_free(px_data);
    }

    textures->cnt = tex_cnt;

    return true;
}

void UnloadTextures(s_textures* const textures) {
    if (textures->gl_ids && textures->cnt > 0) {
        glDeleteTextures(textures->cnt, textures->gl_ids);
    }

    ZeroOut(textures, sizeof(*textures));
}

bool LoadFontsFromFiles(s_fonts* const fonts, s_mem_arena* const mem_arena, const int font_cnt, const t_font_index_to_load_info font_index_to_load_info, s_mem_arena* const temp_mem_arena) {
    assert(fonts);
    assert(IsZero(fonts, sizeof(*fonts)));
    assert(mem_arena);
    assert(font_cnt > 0);
    assert(font_index_to_load_info);

    fonts->arrangement_infos = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, s_font_arrangement_info, font_cnt);

    if (!fonts->arrangement_infos) {
        return false;
    }

    fonts->tex_gl_ids = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, t_gl_id, font_cnt);

    if (!fonts->tex_gl_ids) {
        return false;
    }

    fonts->tex_heights = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, int, font_cnt);

    if (!fonts->tex_heights) {
        return false;
    }

    t_byte* const px_data_scratch_space = MEM_ARENA_PUSH_TYPE_MANY(temp_mem_arena, t_byte, TEXTURE_CHANNEL_CNT * FONT_TEXTURE_WIDTH * FONT_TEXTURE_HEIGHT_LIMIT);

    if (!px_data_scratch_space) {
        return false;
    }

    glGenTextures(font_cnt, fonts->tex_gl_ids);

    for (int i = 0; i < font_cnt; ++i) {
        const s_font_load_info load_info = font_index_to_load_info(i);

        assert(load_info.height > 0);
        assert(load_info.file_path);

        const t_byte* const font_file_data = (const t_byte*)PushEntireFileContents(load_info.file_path, temp_mem_arena, false);

        if (!font_file_data) {
            return false;
        }

        stbtt_fontinfo font_info;

        const int offs = stbtt_GetFontOffsetForIndex(font_file_data, 0);

        if (offs == -1) {
            fprintf(stderr, "Failed to get font offset for font \"%s\"!\n", load_info.file_path);
            return false;
        }

        if (!stbtt_InitFont(&font_info, font_file_data, offs)) {
            fprintf(stderr, "Failed to initialise font \"%s\"!\n", load_info.file_path);
            return false;
        }

        const float scale = stbtt_ScaleForPixelHeight(&font_info, load_info.height);

        int ascent, descent, line_gap;
        stbtt_GetFontVMetrics(&font_info, &ascent, &descent, &line_gap);

        fonts->arrangement_infos[i].line_height = (ascent - descent + line_gap) * scale;

        for (int y = 0; y < FONT_TEXTURE_HEIGHT_LIMIT; ++y) {
            for (int x = 0; x < FONT_TEXTURE_WIDTH; ++x) {
                const int px_index = ((y * FONT_TEXTURE_WIDTH) + x) * TEXTURE_CHANNEL_CNT;

                px_data_scratch_space[px_index + 0] = 255;
                px_data_scratch_space[px_index + 1] = 255;
                px_data_scratch_space[px_index + 2] = 255;
                px_data_scratch_space[px_index + 3] = 0;
            }
        }

        s_vec_2d_i chr_render_pos = {0, 0};

        for (int j = 0; j < FONT_CHR_RANGE_LEN; ++j) {
            const int chr = FONT_CHR_RANGE_BEGIN + j;

            int advance;
            stbtt_GetCodepointHMetrics(&font_info, chr, &advance, NULL);

            fonts->arrangement_infos[i].chr_hor_advances[j] = (int)(advance * scale);

            if (chr == ' ') {
                continue;
            }

            s_vec_2d_i bitmap_size, bitmap_offs;
            t_byte* const bitmap = stbtt_GetCodepointBitmap(&font_info, 0.0f, scale, chr, &bitmap_size.x, &bitmap_size.y, &bitmap_offs.x, &bitmap_offs.y);

            if (!bitmap) {
                return false;
            }

            fonts->arrangement_infos[i].chr_hor_offsets[j] = bitmap_offs.x;
            fonts->arrangement_infos[i].chr_ver_offsets[j] = bitmap_offs.y + (int)(ascent * scale);

            if (chr_render_pos.x + bitmap_size.x > FONT_TEXTURE_WIDTH) {
                chr_render_pos.x = 0;
                chr_render_pos.y += fonts->arrangement_infos[i].line_height;
            }

            const int chr_tex_height = chr_render_pos.y + bitmap_size.y;
            if (chr_tex_height > FONT_TEXTURE_HEIGHT_LIMIT) {
                stbtt_FreeBitmap(bitmap, NULL);
                return false;
            }

            fonts->tex_heights[i] = MAX(fonts->tex_heights[i], chr_tex_height);

            fonts->arrangement_infos[i].chr_src_rects[j] = (s_rect_i){
                .x = chr_render_pos.x,
                .y = chr_render_pos.y,
                .width = bitmap_size.x,
                .height = bitmap_size.y
            };

            for (int y = 0; y < bitmap_size.y; ++y) {
                for (int x = 0; x < bitmap_size.x; ++x) {
                    const int px = chr_render_pos.x + x;
                    const int py = chr_render_pos.y + y;
                    const int px_index = (py * FONT_TEXTURE_WIDTH + px) * TEXTURE_CHANNEL_CNT;
                    const int bitmap_index = y * bitmap_size.x + x;

                    px_data_scratch_space[px_index + 3] = bitmap[bitmap_index];
                }
            }

            chr_render_pos.x += bitmap_size.x;

            stbtt_FreeBitmap(bitmap, NULL);
        }

        glBindTexture(GL_TEXTURE_2D, fonts->tex_gl_ids[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_RGBA,
            FONT_TEXTURE_WIDTH,
            fonts->tex_heights[i],
            0,
            GL_RGBA,
            GL_UNSIGNED_BYTE,
            px_data_scratch_space
        );
    }

    fonts->cnt = font_cnt;

    return true;
}

void UnloadFonts(s_fonts* const fonts) {
    assert(fonts);

    if (fonts->cnt > 0 && fonts->tex_gl_ids) {
        glDeleteTextures(fonts->cnt, fonts->tex_gl_ids);
    }

    ZeroOut(fonts, sizeof(*fonts));
}

bool LoadShaderProgsFromFiles(s_shader_progs* const progs, s_mem_arena* const mem_arena, const int prog_cnt, const t_shader_prog_index_to_file_paths prog_index_to_fps, s_mem_arena* const temp_mem_arena) {
    assert(progs);
    assert(IsZero(progs, sizeof(*progs)));
    assert(mem_arena);
    assert(prog_cnt > 0);
    assert(prog_index_to_fps);
    assert(temp_mem_arena);

    progs->gl_ids = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, t_gl_id, prog_cnt);

    if (!progs->gl_ids) {
        return false;
    }

    progs->cnt = prog_cnt;

    for (int i = 0; i < prog_cnt; i++) {
        const s_shader_prog_file_paths fps = prog_index_to_fps(i);

        progs->gl_ids[i] = CreateShaderProgFromFiles(fps, temp_mem_arena);

        if (!progs->gl_ids[i]) {
            return false;
        }
    }

    return true;
}

void UnloadShaderProgs(s_shader_progs* const progs) {
    assert(progs);

    for (int i = 0; i < progs->cnt; i++) {
        glDeleteProgram(progs->gl_ids[i]);
    }

    ZeroOut(progs, sizeof(*progs));
}

void BeginRendering(s_rendering_state* const state) {
    assert(state);
    ZeroOut(state, sizeof(*state));
    InitIdenMatrix4x4(&state->view_mat);
}

void RenderClear(const s_color col) {
    assert(IsColorValid(col));

    glClearColor(col.r, col.g, col.b, col.a);
    glClear(GL_COLOR_BUFFER_BIT);
}

void Render(const s_rendering_context* const context, const t_gl_id tex_gl_id, const s_rect_edges tex_coords, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin, const float rot, const s_color blend) {
    assert(IsOriginValid(origin));
    assert(IsColorValid(blend));

    s_rendering_state* const state = context->state;

    if (state->batch_slots_used_cnt == 0) {
        state->batch_tex_gl_id = tex_gl_id;
    } else if (state->batch_slots_used_cnt == RENDER_BATCH_SLOT_CNT || tex_gl_id != state->batch_tex_gl_id) {
        Flush(context);
        Render(context, tex_gl_id, tex_coords, pos, size, origin, rot, blend);
        return;
    }

    const int slot_index = state->batch_slots_used_cnt;
    float* const slot_verts = state->batch_slot_verts[slot_index];

    slot_verts[0] = 0.0f - origin.x;
    slot_verts[1] = 0.0f - origin.y;
    slot_verts[2] = pos.x;
    slot_verts[3] = pos.y;
    slot_verts[4] = size.x;
    slot_verts[5] = size.y;
    slot_verts[6] = rot;
    slot_verts[7] = tex_coords.left;
    slot_verts[8] = tex_coords.top;
    slot_verts[9] = blend.r;
    slot_verts[10] = blend.g;
    slot_verts[11] = blend.b;
    slot_verts[12] = blend.a;

    slot_verts[13] = 1.0f - origin.x;
    slot_verts[14] = 0.0f - origin.y;
    slot_verts[15] = pos.x;
    slot_verts[16] = pos.y;
    slot_verts[17] = size.x;
    slot_verts[18] = size.y;
    slot_verts[19] = rot;
    slot_verts[20] = tex_coords.right;
    slot_verts[21] = tex_coords.top;
    slot_verts[22] = blend.r;
    slot_verts[23] = blend.g;
    slot_verts[24] = blend.b;
    slot_verts[25] = blend.a;

    slot_verts[26] = 1.0f - origin.x;
    slot_verts[27] = 1.0f - origin.y;
    slot_verts[28] = pos.x;
    slot_verts[29] = pos.y;
    slot_verts[30] = size.x;
    slot_verts[31] = size.y;
    slot_verts[32] = rot;
    slot_verts[33] = tex_coords.right;
    slot_verts[34] = tex_coords.bottom;
    slot_verts[35] = blend.r;
    slot_verts[36] = blend.g;
    slot_verts[37] = blend.b;
    slot_verts[38] = blend.a;

    slot_verts[39] = 0.0f - origin.x;
    slot_verts[40] = 1.0f - origin.y;
    slot_verts[41] = pos.x;
    slot_verts[42] = pos.y;
    slot_verts[43] = size.x;
    slot_verts[44] = size.y;
    slot_verts[45] = rot;
    slot_verts[46] = tex_coords.left;
    slot_verts[47] = tex_coords.bottom;
    slot_verts[48] = blend.r;
    slot_verts[49] = blend.g;
    slot_verts[50] = blend.b;
    slot_verts[51] = blend.a;

    state->batch_slots_used_cnt++;
}

void RenderTexture(const s_rendering_context* const context, const int tex_index, const s_textures* const textures, const s_rect_i src_rect, const s_vec_2d pos, const s_vec_2d origin, const s_vec_2d scale, const float rot, const s_color blend) {
    assert(tex_index >= 0 && tex_index < textures->cnt);
    assert(IsOriginValid(origin));
    assert(IsColorValid(blend));

    const s_vec_2d_i tex_size = textures->sizes[tex_index];
    const s_rect_edges tex_coords = CalcTextureCoords(src_rect, tex_size);

    const s_vec_2d size_scaled = {src_rect.width * scale.x, src_rect.height * scale.y};

    Render(context, textures->gl_ids[tex_index], tex_coords, pos, size_scaled, origin, rot, blend);
}

bool RenderStr(
    const s_rendering_context* const context,
    const char* const str,
    const int font_index,
    const s_fonts* const fonts,
    const s_vec_2d pos,
    const e_str_hor_align hor_align,
    const e_str_ver_align ver_align,
    const s_color blend,
    s_mem_arena* const temp_mem_arena
) {
    assert(context);
    assert(str);
    assert(fonts);
    assert(IsColorValid(blend));

    if (!str[0]) {
        return true;
    }

    const int str_len = strlen(str);
    const s_vec_2d* const str_chr_positions = PushStrChrPositions(str, temp_mem_arena, font_index, fonts, pos, hor_align, ver_align);

    if (!str_chr_positions) {
        return false;
    }

    const t_gl_id font_tex_gl_id = fonts->tex_gl_ids[font_index];

    const s_vec_2d_i font_tex_size = {
        .x = FONT_TEXTURE_WIDTH,
        .y = fonts->tex_heights[font_index]
    };

    for (int i = 0; i < str_len; ++i) {
        const char c = str[i];

        if (c == '\0' || c == ' ') {
            continue;
        }

        const int chr_index = c - FONT_CHR_RANGE_BEGIN;
        const s_rect_i chr_src_rect = fonts->arrangement_infos[font_index].chr_src_rects[chr_index];
        const s_rect_edges chr_tex_coords = CalcTextureCoords(chr_src_rect, font_tex_size);

        Render(
            context,
            font_tex_gl_id,
            chr_tex_coords,
            str_chr_positions[i],
            (s_vec_2d){chr_src_rect.width, chr_src_rect.height},
            VEC_2D_ZERO,
            0.0f,
            blend
        );
    }

    return true;
}
 
void RenderRect(const s_rendering_context* const context, const s_rect rect, const s_color blend) {
    assert(rect.width > 0.0f && rect.height > 0.0f);
    assert(IsColorValid(blend));

    const s_vec_2d pos = {rect.x, rect.y};
    const s_vec_2d size = {rect.width, rect.height};

    const s_rect_edges tex_coords = {0.0f, 0.0f, 1.0f, 1.0f};

    const s_vec_2d origin = {0.0f, 0.0f};
    Render(context, context->pers->px_tex_gl_id, tex_coords, pos, size, origin, 0.0f, blend);
}

void RenderRectOutline(const s_rendering_context* const context, const s_rect rect, const s_color blend, const float thickness) {
    assert(rect.width > 0.0f && rect.height > 0.0f);
    assert(IsColorValid(blend));
    assert(thickness > 0.0f);

    const s_rect top = {rect.x - thickness, rect.y - thickness, rect.width + thickness, thickness};
    const s_rect right = {rect.x + rect.width, rect.y - thickness, thickness, rect.height + thickness};
    const s_rect bottom = {rect.x, rect.y + rect.height, rect.width + thickness, thickness};
    const s_rect left = {rect.x - thickness, rect.y, thickness, rect.height + thickness};

    RenderRect(context, top, blend);
    RenderRect(context, right, blend);
    RenderRect(context, bottom, blend);
    RenderRect(context, left, blend);
}

void RenderLine(const s_rendering_context* const context, const s_vec_2d a, const s_vec_2d b, const s_color blend, const float width) {
    assert(IsColorValid(blend));
    assert(width > 0.0f);

    const float dx = b.x - a.x;
    const float dy = b.y - a.y;
    const float len = sqrtf(dx * dx + dy * dy);
    const float rot = atan2f(dy, dx);

    const s_vec_2d size = {len, width};
    const s_vec_2d origin = {0.0f, 0.5f};

    const s_rect_edges tex_coords = {0.0f, 0.0f, 1.0f, 1.0f};

    Render(context, context->pers->px_tex_gl_id, tex_coords, a, size, origin, rot, blend);
}

void RenderPolyOutline(const s_rendering_context* const context, const s_poly poly, const s_color blend, const float width) {
    assert(IsColorValid(blend));
    assert(width > 0.0f);

    for (int i = 0; i < poly.cnt; i++) {
        const s_vec_2d a = poly.pts[i];
        const s_vec_2d b = poly.pts[(i + 1) % poly.cnt];
        RenderLine(context, a, b, blend, width);
    }
}

void RenderBarHor(const s_rendering_context* const context, const s_rect rect, const float perc, const s_color_rgb col_front, const s_color_rgb col_back) {
    assert(perc >= 0.0f && perc <= 1.0f);
    assert(IsColorRGBValid(col_front));
    assert(IsColorRGBValid(col_back));

    s_rect left_rect = {rect.x, rect.y, 0.0f, rect.height};

    if (perc > 0.0f) {
        left_rect.width = rect.width * perc;
        s_color col = {col_front.r, col_front.g, col_front.b, 1.0f};
        RenderRect(context, left_rect, col);
    }

    if (perc < 1.0f) {
        s_rect right_rect = {rect.x + left_rect.width, rect.y, rect.width - left_rect.width, rect.height};
        s_color col = {col_back.r, col_back.g, col_back.b, 1.0f};
        RenderRect(context, right_rect, col);
    }
}

void SetSurface(const s_rendering_context* const rendering_context, const int surf_index) {
    // NOTE: Should flushing be a prerequisite to this?

    assert(rendering_context);

    s_rendering_state* const rs = rendering_context->state;

    assert(surf_index >= 0 && surf_index < RENDER_SURFACE_LIMIT);
    assert(rs->surf_index_stack_height < RENDER_SURFACE_LIMIT);

    // Add the surface index to the stack.
    rs->surf_index_stack[rs->surf_index_stack_height] = surf_index;
    rs->surf_index_stack_height++;

    // Bind the surface framebuffer.
    glBindFramebuffer(GL_FRAMEBUFFER, rendering_context->pers->surfs.framebuffer_gl_ids[surf_index]);
}

void UnsetSurface(const s_rendering_context* const rendering_context) {
    assert(rendering_context);

    s_rendering_state* const rs = rendering_context->state;

    assert(rs->batch_slots_used_cnt == 0);
    assert(rs->surf_index_stack_height > 0);

    rs->surf_index_stack_height--;

    if (rs->surf_index_stack_height == 0) {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    } else {
        const int new_surf_index = rs->surf_index_stack_height;
        const t_gl_id fb_gl_id = rendering_context->pers->surfs.framebuffer_gl_ids[new_surf_index];
        glBindFramebuffer(GL_FRAMEBUFFER, rendering_context->pers->surfs.framebuffer_gl_ids[new_surf_index]);
    }
}

void SetSurfaceShaderProg(const s_rendering_context* const rendering_context, const t_gl_id gl_id) {
    assert(gl_id != 0);
    // NOTE: Should we also trip an assert if current shader program GL ID is not 0?

    rendering_context->state->surf_shader_prog_gl_id = gl_id;
    glUseProgram(rendering_context->state->surf_shader_prog_gl_id);
}

void SetSurfaceShaderProgUniform(const s_rendering_context* const rendering_context, const char* const name, const s_shader_prog_uniform_value val) {
    assert(rendering_context->state->surf_shader_prog_gl_id != 0 && "Surface shader program must be set before modifying uniforms!");

    const int loc = glGetUniformLocation(rendering_context->state->surf_shader_prog_gl_id, name);
    assert(loc != -1 && "Failed to get location of shader uniform!");

    switch (val.type) {
        case ek_shader_prog_uniform_value_type_int:
            glUniform1i(loc, val.as_int);
            break;

        case ek_shader_prog_uniform_value_type_float:
            glUniform1f(loc, val.as_float);
            break;

        case ek_shader_prog_uniform_value_type_v2:
            glUniform2f(loc, val.as_v2.x, val.as_v2.y);
            break;

        case ek_shader_prog_uniform_value_type_v3:
            glUniform3f(loc, val.as_v3.x, val.as_v3.y, val.as_v3.z);
            break;

        case ek_shader_prog_uniform_value_type_v4:
            glUniform4f(loc, val.as_v4.x, val.as_v4.y, val.as_v4.z, val.as_v4.w);
            break;

        case ek_shader_prog_uniform_value_type_mat4x4:
            glUniformMatrix4fv(loc, 1, false, &val.as_mat4x4[0][0]);
            break;
    }
}

void RenderSurface(const s_rendering_context* const rendering_context, const int surf_index) {
    assert(surf_index >= 0 && surf_index < RENDER_SURFACE_LIMIT);
    assert(rendering_context->state->surf_shader_prog_gl_id != 0 && "Surface shader program must be set before rendering a surface!");

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, rendering_context->pers->surfs.framebuffer_tex_gl_ids[surf_index]);

    glBindVertexArray(rendering_context->pers->surf_vert_array_gl_id);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, rendering_context->pers->surf_elem_buf_gl_id);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, NULL);
}

void Flush(const s_rendering_context* const context) {
    if (context->state->batch_slots_used_cnt == 0) {
        return;
    }

    glBindVertexArray(context->pers->batch_gl_ids.vert_array_gl_id);
    glBindBuffer(GL_ARRAY_BUFFER, context->pers->batch_gl_ids.vert_buf_gl_id);

    // NOTE: There's something wrong with the below? Try a high slot limit.
    const GLsizeiptr write_size = RENDER_BATCH_SLOT_VERTS_SIZE * context->state->batch_slots_used_cnt;
    glBufferSubData(GL_ARRAY_BUFFER, 0, write_size, &context->state->batch_slot_verts[0][0]);

    const s_render_batch_shader_prog* const prog = &context->pers->batch_shader_prog;

    glUseProgram(prog->gl_id);

    t_matrix_4x4 proj_mat = {0};
    InitOrthoMatrix4x4(&proj_mat, 0.0f, (float)context->display_size.x, (float)context->display_size.y, 0.0f, -1.0f, 1.0f);

    glUniformMatrix4fv(prog->proj_uniform_loc, 1, GL_FALSE, &proj_mat[0][0]);
    glUniformMatrix4fv(prog->view_uniform_loc, 1, GL_FALSE, &context->state->view_mat[0][0]);

    glBindTexture(GL_TEXTURE_2D, context->state->batch_tex_gl_id);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, context->pers->batch_gl_ids.elem_buf_gl_id);

    glDrawElements(GL_TRIANGLES, RENDER_BATCH_SLOT_ELEM_CNT * context->state->batch_slots_used_cnt, GL_UNSIGNED_SHORT, NULL);

    context->state->batch_slots_used_cnt = 0;
    context->state->batch_tex_gl_id = 0;
}

static bool AttachFramebufferTexture(const t_gl_id fb_gl_id, const t_gl_id tex_gl_id, const s_vec_2d_i tex_size) {
    assert(fb_gl_id != 0);
    assert(tex_gl_id != 0);
    assert(tex_size.x > 0 && tex_size.y > 0);

    glBindTexture(GL_TEXTURE_2D, tex_gl_id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, tex_size.x, tex_size.y, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glBindFramebuffer(GL_FRAMEBUFFER, fb_gl_id);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex_gl_id, 0);

    const bool success = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;

    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    return success;
}

bool InitRenderSurfaces(s_render_surfaces* const surfs, const s_vec_2d_i size) {
    assert(surfs && IsZero(surfs, sizeof(*surfs)));
    assert(size.x > 0 && size.y > 0);

    glGenFramebuffers(RENDER_SURFACE_LIMIT, &surfs->framebuffer_gl_ids[0]);
    glGenTextures(RENDER_SURFACE_LIMIT, &surfs->framebuffer_tex_gl_ids[0]);

    for (int i = 0; i < RENDER_SURFACE_LIMIT; i++) {
        if (!AttachFramebufferTexture(surfs->framebuffer_gl_ids[i], surfs->framebuffer_tex_gl_ids[i], size)) {
            return false;
        }
    }

    return true;
}

bool ResizeRenderSurfaces(s_render_surfaces* const surfs, const s_vec_2d_i size) {
    assert(surfs);
    assert(size.x > 0 && size.y > 0);

    // Delete old textures.
    glDeleteTextures(RENDER_SURFACE_LIMIT, surfs->framebuffer_tex_gl_ids);

    // Generate new ones with the given size.
    glGenTextures(RENDER_SURFACE_LIMIT, surfs->framebuffer_tex_gl_ids);

    for (int i = 0; i < RENDER_SURFACE_LIMIT; i++) {
        if (!AttachFramebufferTexture(surfs->framebuffer_gl_ids[i], surfs->framebuffer_tex_gl_ids[i], size)) {
            return false;
        }
    }

    return true;
}

static void ApplyHorAlignOffsToLine(
    s_vec_2d* const line_chr_positions,
    const int count,
    const e_str_hor_align hor_align,
    const float line_end_x
) {
    assert(line_chr_positions);
    assert(count > 0);

    const float line_width = line_end_x - line_chr_positions[0].x;
    const float align_offs = -(line_width * (float)hor_align * 0.5f);

    for (int i = 0; i < count; ++i) {
        line_chr_positions[i].x += align_offs;
    }
}

const s_vec_2d* PushStrChrPositions(
    const char* const str,
    s_mem_arena* const mem_arena,
    const int font_index,
    const s_fonts* const fonts,
    const s_vec_2d pos,
    const e_str_hor_align hor_align,
    const e_str_ver_align ver_align
) {
    assert(str);
    assert(mem_arena);
    assert(font_index >= 0 && font_index < fonts->cnt);
    assert(fonts);

    const int str_len = (int)strlen(str);
    assert(str_len > 0);

    s_vec_2d* const chr_positions = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, s_vec_2d, str_len);

    if (!chr_positions) {
        return NULL;
    }

    const s_font_arrangement_info* const font_ai = &fonts->arrangement_infos[font_index];

    int cur_line_begin_chr_index = 0;
    s_vec_2d chr_base_pos_pen = VEC_2D_ZERO;

    for (int i = 0; i < str_len; ++i) {
        const char chr = str[i];

        if (chr == '\0') {
            continue;
        }

        if (chr == '\n') {
            const int line_count = i - cur_line_begin_chr_index;
            ApplyHorAlignOffsToLine(
                &chr_positions[cur_line_begin_chr_index],
                line_count,
                hor_align,
                chr_base_pos_pen.x + pos.x
            );

            cur_line_begin_chr_index = i + 1;
            chr_base_pos_pen.x = 0.0f;
            chr_base_pos_pen.y += (float)font_ai->line_height;
            continue;
        }

        const int chr_index = chr - FONT_CHR_RANGE_BEGIN;

        chr_positions[i].x = chr_base_pos_pen.x + pos.x + (float)font_ai->chr_hor_offsets[chr_index];
        chr_positions[i].y = chr_base_pos_pen.y + pos.y + (float)font_ai->chr_ver_offsets[chr_index];

        chr_base_pos_pen.x += font_ai->chr_hor_advances[chr_index];
    }

    const int remaining_count = str_len - cur_line_begin_chr_index;

    ApplyHorAlignOffsToLine(
        &chr_positions[cur_line_begin_chr_index],
        remaining_count,
        hor_align,
        chr_base_pos_pen.x + pos.x
    );

    const float total_height = chr_base_pos_pen.y + (float)font_ai->line_height;
    const float ver_align_offs = -(total_height * (float)ver_align * 0.5f);

    for (int i = 0; i < str_len; ++i) {
        chr_positions[i].y += ver_align_offs;
    }

    return chr_positions;
}

bool LoadStrCollider(
    s_rect* const rect,
    const char* const str,
    const int font_index,
    const s_fonts* const fonts,
    const s_vec_2d pos,
    const e_str_hor_align hor_align,
    const e_str_ver_align ver_align,
    s_mem_arena* const temp_mem_arena
) {
    assert(rect);
    assert(str);
    assert(fonts);

    const int str_len = strlen(str);
    assert(str_len > 0);

    const s_vec_2d* const chr_positions = MEM_ARENA_PUSH_TYPE_MANY(temp_mem_arena, s_vec_2d, str_len);

    if (!chr_positions) {
        return NULL;
    }

    s_rect_edges collider_edges;
    bool initted = false;

    for (int i = 0; i < str_len; ++i) {
        const char chr = str[i];

        if (chr == '\n') {
            continue;
        }

        const int chr_index = (int)chr - FONT_CHR_RANGE_BEGIN;
        const s_vec_2d_i size = RectISize(&fonts->arrangement_infos[font_index].chr_src_rects[chr_index]);

        const float left = chr_positions[i].x;
        const float top = chr_positions[i].y;
        const float right = left + (float)size.x;
        const float bottom = top + (float)size.y;

        if (!initted) {
            collider_edges.left = left;
            collider_edges.top = top;
            collider_edges.right = right;
            collider_edges.bottom = bottom;
            initted = true;
        } else {
            collider_edges.left = fminf(collider_edges.left, left);
            collider_edges.top = fminf(collider_edges.top, top);
            collider_edges.right = fmaxf(collider_edges.right, right);
            collider_edges.bottom = fmaxf(collider_edges.bottom, bottom);
        }
    }

    assert(initted);

    const float width = collider_edges.right - collider_edges.left;
    const float height = collider_edges.bottom - collider_edges.top;

    *rect = (s_rect){
        .x = collider_edges.left,
        .y = collider_edges.top,
        .width = width,
        .height = height
    };

    return true;
}

s_rect_edges CalcTextureCoords(const s_rect_i src_rect, const s_vec_2d_i tex_size) {
    assert(src_rect.width > 0 && src_rect.height > 0);
    assert(tex_size.x > 0 && tex_size.y > 0);

    return (s_rect_edges){
        .left = (float)src_rect.x / tex_size.x,
        .top = (float)src_rect.y / tex_size.y,
        .right = (float)(src_rect.x + src_rect.width) / tex_size.x,
        .bottom = (float)(src_rect.y + src_rect.height) / tex_size.y
    };
}
