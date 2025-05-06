#include <stdlib.h>
#include <stdio.h>
#include "gc_game.h"
#include "gce_game.h"
#include "gce_math.h"

const s_rect_i g_sprite_src_rects[eks_sprite_cnt] = {
    {8, 0, 24, 40}, // Player
    {8, 0, 24, 40}, // Enemy
    {0, 8, 8, 8} // Cursor
};

static const char* TextureIndexToFilePath(const int index) {
    switch (index) {
        case ek_texture_all:
            return "assets/textures/all.png";

        default:
            return "";
    }
}

static s_font_load_info FontIndexToLoadInfo(const int index) {
    switch (index) {
        case ek_font_eb_garamond_64:
            return (s_font_load_info) {
                .file_path = "assets/fonts/eb_garamond.ttf",
                .height = 64
            };

        default:
            return (s_font_load_info){0};
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

    if (!InitLevel(&game->level)) {
        return false;
    }

    return true;
}

static bool GameTick(const s_game_tick_func_data* const func_data) {
    s_game* const game = func_data->user_mem;

    if (!LevelTick(game, func_data)) {
        return false;
    }

    return true;
}

static bool RenderGame(const s_game_render_func_data* const func_data) {
    s_game* const game = func_data->user_mem;

    if (!RenderLevel(&func_data->rendering_context, &game->level, &game->textures, &game->fonts, func_data->temp_mem_arena)) {
        return false;
    }

    // Render cursor.
    RenderTexture(
        &func_data->rendering_context,
        ek_texture_all,
        &game->textures,
        g_sprite_src_rects[ek_sprite_cursor],
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
        pos.x - (g_sprite_src_rects[sprite].width * origin.x),
        pos.y - (g_sprite_src_rects[sprite].height * origin.y),
        g_sprite_src_rects[sprite].width,
        g_sprite_src_rects[sprite].height
    };
}

bool PushColliderPolyFromSprite(s_poly* const poly, s_mem_arena* const mem_arena, const e_sprite sprite, const s_vec_2d pos, const s_vec_2d origin, const float rot) {
    assert(poly);
    assert(IsZero(poly, sizeof(*poly)));
    assert(mem_arena);
    assert(IsMemArenaValid(mem_arena));
    assert(IsOriginValid(origin));

    return PushQuadPolyRotated(poly, mem_arena, pos, (s_vec_2d){g_sprite_src_rects[sprite].width, g_sprite_src_rects[sprite].height}, origin, rot);
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
