#ifndef GC_GAME_H
#define GC_GAME_H

#include <gce_game.h>

#define GAME_TITLE "God Complex"

#define ENEMY_LIMIT 256

#define PROJECTILE_LIMIT 1024

#define CAMERA_SCALE 2.0f

#define PAUSE_SCREEN_BG_ALPHA 0.2f

typedef enum {
    ek_texture_level,
    ek_texture_ui,

    eks_texture_cnt
} e_texture;

typedef enum {
    ek_font_eb_garamond_64,
    ek_font_eb_garamond_80,

    eks_font_cnt
} e_fonts;

typedef enum {
    ek_sprite_player,
    ek_sprite_enemy,
    ek_sprite_projectile,
    ek_sprite_cursor,

    eks_sprite_cnt
} e_sprite;

typedef struct {
    e_texture tex;
    s_rect_i src_rect;
} s_sprite;

typedef struct {
    bool killed;
    s_vec_2d pos;
    float rot;
    s_vec_2d vel;
    int hp;
    int inv_time;
    int flash_time;
} s_player;

typedef struct {
    s_vec_2d pos;
    s_vec_2d vel;
    int hp;
    int flash_time;
} s_enemy;

typedef struct {
    s_enemy buf[ENEMY_LIMIT];
    t_byte activity[BITS_TO_BYTES(ENEMY_LIMIT)];
} s_enemy_list;

typedef struct {
    s_vec_2d pos;
    s_vec_2d vel;
    float rot;
    int dmg;
    bool from_enemy;
} s_projectile;

typedef struct {
    s_vec_2d pos_no_offs;
    s_vec_2d pos_offs;
    float shake;
} s_camera;

typedef struct {
    s_player player;
    s_enemy_list enemy_list;
    s_projectile projectiles[PROJECTILE_LIMIT];
    int proj_cnt;
    s_camera camera;
    bool paused;
} s_level;

typedef struct {
    s_textures textures;
    s_fonts fonts;
    s_level level;
} s_game;

typedef struct {
    int dmg;
    s_vec_2d kb;
} s_damage_info;

extern const s_sprite g_sprites[eks_sprite_cnt];

s_rect GenColliderRectFromSprite(const e_sprite sprite, const s_vec_2d pos, const s_vec_2d origin);
bool PushColliderPolyFromSprite(s_poly* const poly, s_mem_arena* const mem_arena, const e_sprite sprite, const s_vec_2d pos, const s_vec_2d origin, const float rot);

bool InitLevel(s_level* const level);
bool LevelTick(s_game* const game, const s_window_state* const window_state, const s_input_state* const input_state, const s_input_state* const input_state_last, s_mem_arena* const temp_mem_arena);
bool RenderLevel(const s_rendering_context* const rendering_context, const s_level* const level, const s_textures* const textures, const s_fonts* const fonts, s_mem_arena* const temp_mem_arena);
bool SpawnProjectile(s_level* const level, const s_vec_2d pos, const float spd, const float dir, const int dmg, const bool from_enemy);

void ProcPlayerMovement(s_player* const player, const s_input_state* const input_state, const s_camera* const cam, const s_vec_2d_i display_size);
bool ProcPlayerShooting(s_level* const level, const s_vec_2d_i display_size, const s_input_state* const input_state, const s_input_state* const input_state_last);
void RenderPlayer(const s_rendering_context* const rendering_context, const s_player* const player, const s_textures* const textures);
s_rect GenPlayerDamageCollider(const s_vec_2d player_pos);
void DamagePlayer(s_level* const level, const s_damage_info dmg_info);

bool SpawnEnemy(const s_vec_2d pos, s_enemy_list* const enemy_list);
bool ProcEnemyAIs(s_enemy_list* const enemy_list);
void ProcEnemyDeaths(s_level* const level);
void RenderEnemies(const s_rendering_context* const rendering_context, const s_enemy_list* const enemies, const s_textures* const textures);
s_rect GenEnemyDamageCollider(const s_vec_2d enemy_pos);
void DamageEnemy(s_level* const level, const int enemy_index, const s_damage_info dmg_info);

inline bool IsEnemyActive(const int index, const s_enemy_list* const enemy_list) {
    assert(index >= 0 && index < ENEMY_LIMIT);
    assert(enemy_list);
    return IsBitActive(index, enemy_list->activity, ENEMY_LIMIT);
}

void UpdateCamera(s_level* const level, const s_window_state* const window_state, const s_input_state* const input_state);
void InitCameraViewMatrix4x4(t_matrix_4x4* const mat, const s_camera* const cam, const s_vec_2d_i display_size);

inline s_vec_2d CameraSize(const s_vec_2d_i display_size) {
    assert(display_size.x > 0 && display_size.y > 0);
    return (s_vec_2d){ display_size.x / CAMERA_SCALE, display_size.y / CAMERA_SCALE};
}

inline s_vec_2d CameraTopLeft(const s_camera* const cam, const s_vec_2d_i display_size) {
    assert(display_size.x > 0 && display_size.y > 0);
    const s_vec_2d pos = {cam->pos_no_offs.x + cam->pos_offs.x, cam->pos_no_offs.y + cam->pos_offs.y};
    const s_vec_2d size = CameraSize(display_size);
    return (s_vec_2d){ pos.x - (size.x / 2.0f), pos.y - (size.y / 2.0f)};
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

inline void RenderSprite(const s_rendering_context* const context, const int sprite_index, const s_textures* const textures, const s_vec_2d pos, const s_vec_2d origin, const s_vec_2d scale, const float rot, const s_color blend) {
    RenderTexture(
        context,
        g_sprites[sprite_index].tex,
        textures,
        g_sprites[sprite_index].src_rect,
        pos,
        origin,
        scale,
        rot,
        blend
    );
}

#endif
