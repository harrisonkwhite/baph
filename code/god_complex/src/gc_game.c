#include <stdlib.h>
#include <stdio.h>
#include "gc_game.h"
#include "gce_game.h"
#include "gce_math.h"

const s_sprite g_sprites[eks_sprite_cnt] = {
    (s_sprite){.tex = ek_texture_level, .src_rect = {0, 0, 24, 24}}, // Player
    (s_sprite){.tex = ek_texture_level, .src_rect = {0, 24, 24, 24}}, // Enemy
    (s_sprite){.tex = ek_texture_level, .src_rect = {24, 2, 16, 4}}, // Projectile
    (s_sprite){.tex = ek_texture_level, .src_rect = {0, 48, 16, 16}}, // Tile
    (s_sprite){.tex = ek_texture_ui, .src_rect = {0, 0, 8, 8}} // Cursor
};

static const char* TextureIndexToFilePath(const int index) {
    switch (index) {
        case ek_texture_level: return "assets/textures/level.png";
        case ek_texture_ui: return "assets/textures/ui.png";

        default: return "";
    }
}

static s_font_load_info FontIndexToLoadInfo(const int index) {
    switch (index) {
        case ek_font_eb_garamond_64:
            return (s_font_load_info){
                .file_path = "assets/fonts/eb_garamond.ttf",
                .height = 64
            };

        case ek_font_eb_garamond_80:
            return (s_font_load_info){
                .file_path = "assets/fonts/eb_garamond.ttf",
                .height = 80
            };

        default:
            return (s_font_load_info){0};
    }
}

static s_shader_prog_file_paths ShaderProgIndexToFilePaths(const int index) {
    switch (index) {
        case ek_shader_prog_blend:
            return (s_shader_prog_file_paths){
                .vs_fp = "assets/shaders/blend.vert",
                .fs_fp = "assets/shaders/blend.frag"
            };

        default:
            return (s_shader_prog_file_paths){0};
    }
}

static bool InitGame(const s_game_init_func_data* const func_data) {
    s_game* const game = func_data->user_mem;

    if (!LoadTexturesFromFiles(&game->textures, func_data->perm_mem_arena, eks_texture_cnt, TextureIndexToFilePath)) {
        fprintf(stderr, "Failed to load game textures!\n");
        return false;
    }

    if (!LoadFontsFromFiles(&game->fonts, func_data->perm_mem_arena, eks_font_cnt, FontIndexToLoadInfo, func_data->temp_mem_arena)) {
        fprintf(stderr, "Failed to load game fonts!\n");
        return false;
    }

    if (!LoadShaderProgsFromFiles(&game->shader_progs, func_data->perm_mem_arena, eks_shader_prog_cnt, ShaderProgIndexToFilePaths, func_data->temp_mem_arena)) {
        fprintf(stderr, "Failed to load game shader programs!\n");
        return false;
    }

    if (!InitLevel(&game->level)) {
        return false;
    }

    return true;
}

static bool GameTick(const s_game_tick_func_data* const func_data) {
    s_game* const game = func_data->user_mem;

    if (IsKeyPressed(ek_key_code_r, func_data->input_state, func_data->input_state_last)) {
        ZeroOut(&game->level, sizeof(game->level));

        if (!InitLevel(&game->level)) {
            return false;
        }
    }

    if (!LevelTick(game, &func_data->window_state, func_data->input_state, func_data->input_state_last, func_data->temp_mem_arena)) {
        return false;
    }

    return true;
}

static bool RenderGame(const s_game_render_func_data* const func_data) {
    s_game* const game = func_data->user_mem;

    if (!RenderLevel(&func_data->rendering_context, &game->level, &game->textures, &game->fonts, &game->shader_progs, func_data->temp_mem_arena)) {
        return false;
    }

    // Render cursor.
    RenderTexture(
        &func_data->rendering_context,
        g_sprites[ek_sprite_cursor].tex,
        &game->textures,
        g_sprites[ek_sprite_cursor].src_rect,
        func_data->input_state->mouse_pos,
        (s_vec_2d){0.5, 0.5},
        (s_vec_2d){1.0, 1.0},
        0.0f,
        WHITE
    );
    
    Flush(&func_data->rendering_context);

    return true;
}

static void CleanGame(void* const user_mem) {
}

s_rect GenColliderRectFromSprite(const e_sprite sprite, const s_vec_2d pos, const s_vec_2d origin) {
    return (s_rect){
        pos.x - (g_sprites[sprite].src_rect.width * origin.x),
        pos.y - (g_sprites[sprite].src_rect.height * origin.y),
        g_sprites[sprite].src_rect.width,
        g_sprites[sprite].src_rect.height
    };
}

bool PushColliderPolyFromSprite(s_poly* const poly, s_mem_arena* const mem_arena, const e_sprite sprite, const s_vec_2d pos, const s_vec_2d origin, const float rot) {
    assert(poly);
    assert(IsZero(poly, sizeof(*poly)));
    assert(mem_arena);
    assert(IsMemArenaValid(mem_arena));
    assert(IsOriginValid(origin));

    return PushQuadPolyRotated(poly, mem_arena, pos, (s_vec_2d){g_sprites[sprite].src_rect.width, g_sprites[sprite].src_rect.height}, origin, rot);
}

int main() {
    const s_game_info game_info = {
        .user_mem_size = sizeof(s_game),
        .user_mem_alignment = alignof(s_game),

        .window_init_size = {1280, 720},
        .window_title = GAME_TITLE,
        .window_flags = ek_window_flag_hide_cursor | ek_window_flag_resizable,

        .init_func = InitGame,
        .tick_func = GameTick,
        .render_func = RenderGame,
        .clean_func = CleanGame,
    };

    return RunGame(&game_info) ? EXIT_SUCCESS : EXIT_FAILURE;
}
