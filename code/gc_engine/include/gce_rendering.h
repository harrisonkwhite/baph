#ifndef GCE_RENDERING_H
#define GCE_RENDERING_H

#include <stdint.h>
#include <stdbool.h>
#include <glad/glad.h>
#include <assert.h>
#include "gce_math.h"
#include "gce_utils.h"

#define TEXTURE_CHANNEL_CNT 4

#define FONT_CHR_RANGE_BEGIN 32
#define FONT_CHR_RANGE_LEN 95
#define FONT_TEXTURE_WIDTH 2048
#define FONT_TEXTURE_HEIGHT_LIMIT 2048
 
#define RENDER_BATCH_SHADER_PROG_VERT_CNT 13
#define RENDER_BATCH_SLOT_CNT 2048 // NOTE: There seems to be an issue here.
#define RENDER_BATCH_SLOT_VERT_CNT (RENDER_BATCH_SHADER_PROG_VERT_CNT * 4)
#define RENDER_BATCH_SLOT_VERTS_SIZE (RENDER_BATCH_SLOT_VERT_CNT * RENDER_BATCH_SLOT_CNT * sizeof(float))
#define RENDER_BATCH_SLOT_ELEM_CNT 6

#define RENDER_SURFACE_LIMIT 32

#define WHITE (s_color){1.0f, 1.0f, 1.0f, 1.0f}
#define RED (s_color){1.0f, 0.0f, 0.0f, 1.0f}
#define GREEN (s_color){0.0f, 1.0f, 0.0f, 1.0f}
#define BLUE (s_color){0.0f, 0.0f, 1.0f, 1.0f}
#define BLACK (s_color){0.0f, 0.0f, 0.0f, 1.0f}
#define YELLOW (s_color){1.0f, 1.0f, 0.0f, 1.0f}
#define CYAN (s_color){0.0f, 1.0f, 1.0f, 1.0f}
#define MAGENTA (s_color){1.0f, 0.0f, 1.0f, 1.0f}
#define GRAY (s_color){0.5f, 0.5f, 0.5f, 1.0f}

typedef GLuint t_gl_id;

typedef struct {
    t_gl_id vert_array_gl_id;
    t_gl_id vert_buf_gl_id;
    t_gl_id elem_buf_gl_id;
} s_render_batch_gl_ids;

typedef struct {
    t_gl_id gl_id;
    int proj_uniform_loc;
    int view_uniform_loc;
    int textures_uniform_loc;
} s_render_batch_shader_prog;

typedef struct {
    t_gl_id framebuffer_gl_ids[RENDER_SURFACE_LIMIT];
    t_gl_id framebuffer_tex_gl_ids[RENDER_SURFACE_LIMIT];
} s_render_surfaces;

typedef enum {
    ek_shader_prog_uniform_value_type_int,
    ek_shader_prog_uniform_value_type_float,
    ek_shader_prog_uniform_value_type_v2,
    ek_shader_prog_uniform_value_type_v3,
    ek_shader_prog_uniform_value_type_v4,
    ek_shader_prog_uniform_value_type_mat4x4,
} e_shader_prog_uniform_value_type;

typedef struct {
    e_shader_prog_uniform_value_type type;

    union {
        int as_int;
        float as_float;
        s_vec_2d as_v2;
        s_vec_3d as_v3;
        s_vec_4d as_v4;
        t_matrix_4x4 as_mat4x4;
    };
} s_shader_prog_uniform_value;

typedef struct {
    s_render_batch_shader_prog batch_shader_prog;
    s_render_batch_gl_ids batch_gl_ids;

    s_render_surfaces surfs;
    t_gl_id surf_vert_array_gl_id;
    t_gl_id surf_vert_buf_gl_id;
    t_gl_id surf_elem_buf_gl_id;

    t_gl_id px_tex_gl_id;
} s_pers_render_data;

typedef struct {
    int batch_slots_used_cnt;
    float batch_slot_verts[RENDER_BATCH_SLOT_CNT][RENDER_BATCH_SLOT_VERT_CNT];
    t_gl_id batch_tex_gl_id;

    t_gl_id surf_shader_prog_gl_id; // When a surface is rendered, this shader program is used.
    int surf_index_stack[RENDER_SURFACE_LIMIT];
    int surf_index_stack_height;

    t_matrix_4x4 view_mat;
} s_rendering_state;

typedef struct {
    t_gl_id* gl_ids;
    s_vec_2d_i* sizes;
    int cnt;
} s_textures;

typedef const char* (*t_texture_index_to_file_path)(const int index);

typedef struct {
    int chr_hor_offsets[FONT_CHR_RANGE_LEN];
    int chr_ver_offsets[FONT_CHR_RANGE_LEN];
    int chr_hor_advances[FONT_CHR_RANGE_LEN];
    s_rect_i chr_src_rects[FONT_CHR_RANGE_LEN];
    int line_height;
} s_font_arrangement_info;

typedef struct {
    const char* file_path;
    int height;
} s_font_load_info;

typedef s_font_load_info (*t_font_index_to_load_info)(const int index);

typedef struct {
    s_font_arrangement_info* arrangement_infos;
    t_gl_id* tex_gl_ids;
    int* tex_heights;
    int cnt;
} s_fonts;

typedef struct {
    t_gl_id* gl_ids;
    int cnt;
} s_shader_progs;

typedef struct {
    const char* vs_fp;
    const char* fs_fp;
} s_shader_prog_file_paths;

typedef s_shader_prog_file_paths (*t_shader_prog_index_to_file_paths)(const int index);

typedef enum {
    ek_str_hor_align_left,
    ek_str_hor_align_center,
    ek_str_hor_align_right
} e_str_hor_align;

typedef enum {
    ek_str_ver_align_top,
    ek_str_ver_align_center,
    ek_str_ver_align_bottom
} e_str_ver_align;

typedef struct {
    s_pers_render_data* pers;
    s_rendering_state* state;
    s_vec_2d_i display_size;
} s_rendering_context;

typedef struct {
    float r;
    float g;
    float b;
    float a;
} s_color;

inline bool IsColorValid(const s_color col) {
    return col.r >= 0.0 && col.r <= 1.0
        && col.g >= 0.0 && col.g <= 1.0
        && col.b >= 0.0 && col.b <= 1.0
        && col.a >= 0.0 && col.a <= 1.0;
}

typedef struct {
    float r;
    float g;
    float b;
} s_color_rgb;

inline bool IsColorRGBValid(const s_color_rgb col) {
    return col.r >= 0.0 && col.r <= 1.0
        && col.g >= 0.0 && col.g <= 1.0
        && col.b >= 0.0 && col.b <= 1.0;
}

bool InitPersRenderData(s_pers_render_data* const render_data, const s_vec_2d_i display_size);
void CleanPersRenderData(s_pers_render_data* const render_data);

s_render_batch_shader_prog LoadRenderBatchShaderProg();
s_render_batch_gl_ids GenRenderBatch();

// NOTE: Might be better if this takes in a pointer to allocated memory instead of doing the allocation/push itself.
bool LoadTexturesFromFiles(s_textures* const textures, s_mem_arena* const mem_arena, const int tex_cnt, const t_texture_index_to_file_path tex_index_to_fp);
void UnloadTextures(s_textures* const textures);

bool LoadFontsFromFiles(s_fonts* const fonts, s_mem_arena* const mem_arena, const int font_cnt, const t_font_index_to_load_info font_index_to_load_info, s_mem_arena* const temp_mem_arena);
void UnloadFonts(s_fonts* const fonts);

bool LoadShaderProgsFromFiles(s_shader_progs* const progs, s_mem_arena* const mem_arena, const int prog_cnt, const t_shader_prog_index_to_file_paths prog_index_to_fps, s_mem_arena* const temp_mem_arena);
void UnloadShaderProgs(s_shader_progs* const progs);

void BeginRendering(s_rendering_state* const state);

void RenderClear(const s_color col);

void Render(const s_rendering_context* const context, const t_gl_id tex_gl_id, const s_rect_edges tex_coords, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin, const float rot, const s_color blend);
void RenderTexture(const s_rendering_context* const context, const int tex_index, const s_textures* const textures, const s_rect_i src_rect, const s_vec_2d pos, const s_vec_2d origin, const s_vec_2d scale, const float rot, const s_color blend);
bool RenderStr(const s_rendering_context* const context, const char* const str, const int font_index, const s_fonts* const fonts, const s_vec_2d pos, const e_str_hor_align hor_align, const e_str_ver_align ver_align, const s_color blend, s_mem_arena* const temp_mem_arena);
void RenderRect(const s_rendering_context* const context, const s_rect rect, const s_color blend);
void RenderRectOutline(const s_rendering_context* const context, const s_rect rect, const s_color blend, const float thickness);
void RenderLine(const s_rendering_context* const context, const s_vec_2d a, const s_vec_2d b, const s_color blend, const float width);
void RenderPolyOutline(const s_rendering_context* const context, const s_poly poly, const s_color blend, const float width);
void RenderBarHor(const s_rendering_context* const context, const s_rect rect, const float perc, const s_color_rgb col_front, const s_color_rgb col_back);

void SetSurface(const s_rendering_context* const rendering_context, const int surf_index);
void UnsetSurface(const s_rendering_context* const rendering_context);
void SetSurfaceShaderProg(const s_rendering_context* const rendering_context, const t_gl_id gl_id);
void SetSurfaceShaderProgUniform(const s_rendering_context* const rendering_context, const char* const name, const s_shader_prog_uniform_value val);
void RenderSurface(const s_rendering_context* const rendering_context, const int surf_index);

void Flush(const s_rendering_context* const context);

bool InitRenderSurfaces(s_render_surfaces* const surfs, const s_vec_2d_i size);
bool ResizeRenderSurfaces(s_render_surfaces* const surfs, const s_vec_2d_i size);

s_rect_edges CalcTextureCoords(const s_rect_i src_rect, const s_vec_2d_i tex_size);

const s_vec_2d* PushStrChrPositions(
    const char* const str,
    s_mem_arena* const mem_arena,
    const int font_index,
    const s_fonts* const fonts,
    const s_vec_2d pos,
    const e_str_hor_align hor_align,
    const e_str_ver_align ver_align
);

bool LoadStrCollider(
    s_rect* const rect,
    const char* const str,
    const int font_index,
    const s_fonts* const fonts,
    const s_vec_2d pos,
    const e_str_hor_align hor_align,
    const e_str_ver_align ver_align,
    s_mem_arena* const temp_mem_arena
); 

inline bool IsOriginValid(const s_vec_2d origin) {
    return origin.x >= 0.0f && origin.y >= 0.0f && origin.x <= 1.0f && origin.y <= 1.0f;
}

#endif
