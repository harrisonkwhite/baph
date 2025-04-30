#ifndef GCE_RENDERING_H
#define GCE_RENDERING_H

#include <stdint.h>
#include <stdbool.h>
#include <glad/glad.h>
#include "gce_math.h"
#include "gce_utils.h"

#define TEXTURE_CHANNEL_CNT 4

#define RENDER_BATCH_SHADER_PROG_VERT_CNT 13
#define RENDER_BATCH_SLOT_CNT 2048 // NOTE: There seems to be an issue here.
#define RENDER_BATCH_SLOT_VERT_CNT (RENDER_BATCH_SHADER_PROG_VERT_CNT * 4)
#define RENDER_BATCH_SLOT_VERTS_SIZE (RENDER_BATCH_SLOT_VERT_CNT * RENDER_BATCH_SLOT_CNT * sizeof(float))
#define RENDER_BATCH_SLOT_ELEM_CNT 6

#define WHITE (s_color) {1.0f, 1.0f, 1.0f, 1.0f}
#define RED (s_color) {1.0f, 0.0f, 0.0f, 1.0f}
#define GREEN (s_color) {0.0f, 1.0f, 0.0f, 1.0f}
#define BLUE (s_color) {0.0f, 0.0f, 1.0f, 1.0f}
#define BLACK (s_color) {0.0f, 0.0f, 0.0f, 1.0f}
#define YELLOW (s_color) {1.0f, 1.0f, 0.0f, 1.0f}
#define CYAN (s_color) {0.0f, 1.0f, 1.0f, 1.0f}
#define MAGENTA (s_color) {1.0f, 0.0f, 1.0f, 1.0f}
#define GRAY (s_color) {0.5f, 0.5f, 0.5f, 1.0f}

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
    s_render_batch_shader_prog batch_shader_prog;
    s_render_batch_gl_ids batch_gl_ids;
    t_gl_id px_tex_gl_id;
} s_pers_render_data;

typedef struct {
    int batch_slots_used_cnt;
    float batch_slot_verts[RENDER_BATCH_SLOT_CNT][RENDER_BATCH_SLOT_VERT_CNT];
    t_gl_id batch_tex_gl_id;
    t_matrix_4x4 view_mat;
} s_rendering_state;

typedef struct {
    t_gl_id* gl_ids;
    s_vec_2d_i* sizes;
    int cnt;
} s_textures;

typedef const char* (*t_texture_index_to_file_path)(const int index);

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

typedef struct {
    float r;
    float g;
    float b;
} s_color_rgb;

void InitPersRenderData(s_pers_render_data* const render_data, const s_vec_2d_i display_size);
void CleanPersRenderData(s_pers_render_data* const render_data);

s_render_batch_shader_prog LoadRenderBatchShaderProg();
s_render_batch_gl_ids GenRenderBatch();

bool LoadTexturesFromFiles(s_textures* const textures, s_mem_arena* const mem_arena, const int tex_cnt, const t_texture_index_to_file_path tex_index_to_fp);
void UnloadTextures(s_textures* const textures);

void BeginRendering(s_rendering_state* const state);

void RenderClear(const s_color col);

void Render(const s_rendering_context* const context, const t_gl_id tex_gl_id, const s_rect_edges tex_coords, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin, const float rot, const s_color blend);
void RenderTexture(const s_rendering_context* const context, const int tex_index, const s_textures* const textures, const s_rect_i src_rect, const s_vec_2d pos, const s_vec_2d origin, const s_vec_2d scale, const float rot, const s_color blend);
void RenderRect(const s_rendering_context* const context, const s_rect rect, const s_color blend);
void RenderRectOutline(const s_rendering_context* const context, const s_rect rect, const s_color blend, const float thickness);
void RenderLine(const s_rendering_context* const context, const s_vec_2d a, const s_vec_2d b, const s_color blend, const float width);
void RenderPolyOutline(const s_rendering_context* const context, const s_poly poly, const s_color blend, const float width);
void RenderBarHor(const s_rendering_context* const context, const s_rect rect, const float perc, const s_color_rgb col_front, const s_color_rgb col_back);

void Flush(const s_rendering_context* const context);

s_rect_edges CalcTextureCoords(const s_rect_i src_rect, const s_vec_2d_i tex_size);

inline bool IsOriginValid(const s_vec_2d origin) {
    return origin.x >= 0.0f && origin.y >= 0.0f && origin.x <= 1.0f && origin.y <= 1.0f;
}

inline bool IsColorValid(const s_color col) {
    return col.r >= 0.0 && col.r <= 1.0
        && col.g >= 0.0 && col.g <= 1.0
        && col.b >= 0.0 && col.b <= 1.0
        && col.a >= 0.0 && col.a <= 1.0;
}

inline bool IsColorRGBValid(const s_color_rgb col) {
    return col.r >= 0.0 && col.r <= 1.0
        && col.g >= 0.0 && col.g <= 1.0
        && col.b >= 0.0 && col.b <= 1.0;
}

#endif
