#ifndef GC_GAME_H
#define GC_GAME_H

#include <gce_game.h>

#define GAME_TITLE "God Complex"

#define CAMERA_SCALE 2.0f

typedef enum {
    ek_texture_all,
    eks_texture_cnt
} e_texture;

typedef enum {
    ek_sprite_player,
    ek_sprite_cursor,
    eks_sprite_cnt
} e_sprite;

typedef struct {
    s_vec_2d pos;
    s_vec_2d origin;
    s_vec_2d scale;
    float rot;
    float alpha;
    e_sprite sprite;
    int flash_time;
    float sort_depth;
} s_layered_render_task;

typedef struct {
    s_layered_render_task* buf;
    int cap;
    int len;
} s_layered_render_task_list;

typedef struct {
    bool killed;
    s_vec_2d pos;
    s_vec_2d vel;
    int hp;
    int inv_time;
    int flash_time;
} s_player;

typedef struct {
    s_vec_2d pos_no_offs;
    s_vec_2d pos_offs;
    float shake;
} s_camera;

typedef struct {
    s_textures textures;
    s_player player;
    s_camera camera;
} s_game;

extern const s_rect_i g_sprite_src_rects[eks_sprite_cnt];

bool AppendLayeredRenderTask(s_layered_render_task_list* const list, const s_vec_2d pos, const e_sprite sprite, const float sort_depth);

void ProcPlayerMovement(s_player* const player, const s_input_state* const input_state);
bool AppendPlayerLayeredRenderTasks(s_layered_render_task_list* const tasks, const s_player* const player);

void UpdateCamera(s_game* const game, const s_game_tick_func_data* const tick_data);
void InitCameraViewMatrix4x4(t_matrix_4x4* const mat, const s_camera* const cam, const s_vec_2d_i display_size);

inline s_vec_2d CameraSize(const s_vec_2d_i display_size) {
    assert(display_size.x > 0 && display_size.y > 0);
    return (s_vec_2d) { display_size.x / CAMERA_SCALE, display_size.y / CAMERA_SCALE };
}

inline s_vec_2d CameraTopLeft(const s_camera* const cam, const s_vec_2d_i display_size) {
    assert(display_size.x > 0 && display_size.y > 0);
    const s_vec_2d pos = {cam->pos_no_offs.x + cam->pos_offs.x, cam->pos_no_offs.y + cam->pos_offs.y};
    const s_vec_2d size = CameraSize(display_size);
    return (s_vec_2d) { pos.x - (size.x / 2.0f), pos.y - (size.y / 2.0f) };
}

inline s_vec_2d CameraToDisplayPos(const s_vec_2d pos, const s_camera* const cam, const s_vec_2d_i display_size) {
    assert(display_size.x > 0 && display_size.y > 0);
    const s_vec_2d cam_tl = CameraTopLeft(cam, display_size);
    return (s_vec_2d) {
        (pos.x - cam_tl.x)* CAMERA_SCALE,
        (pos.y - cam_tl.y)* CAMERA_SCALE
    };
}

inline s_vec_2d DisplayToCameraPos(const s_vec_2d pos, const s_camera* const cam, const s_vec_2d_i display_size) {
    assert(display_size.x > 0 && display_size.y > 0);
    const s_vec_2d cam_tl = CameraTopLeft(cam, display_size);
    return (s_vec_2d) {
        cam_tl.x + (pos.x / CAMERA_SCALE),
        cam_tl.y + (pos.y / CAMERA_SCALE)
    };
}

#endif
