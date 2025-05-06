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

bool IsLayeredRenderTaskListValid(const s_layered_render_task_list* const list) {
    assert(list);

    if (IsZero(list, sizeof(*list))) {
        return true;
    }

    return list->buf && list->cap > 0 && list->len >= 0 && list->len <= list->cap;
}

bool AppendLayeredRenderTask(s_layered_render_task_list* const list, const s_vec_2d pos, const e_sprite sprite, const float sort_depth) {
    assert(list);
    assert(IsLayeredRenderTaskListValid(list));

    if (list->len == list->cap) {
        const int cap_new = list->cap == 0 ? 1 : list->cap * 2;
        s_layered_render_task* const buf_new = realloc(list->buf, sizeof(s_layered_render_task) * cap_new);

        if (!buf_new) {
            fprintf(stderr, "Render task list buffer reallocation failed!\n");
            return false;
        }

        list->buf = buf_new;
        list->cap = cap_new;
    }

    list->buf[list->len] = (s_layered_render_task) {
        .pos = pos,
        .origin = {0.5, 0.5},
        .scale = {1.0, 1.0},
        .alpha = 1.0,
        .sprite = sprite,
        .sort_depth = sort_depth,
    };

    /*list->buf[list->len] = (s_render_task) {
        .pos = pos,
        .origin = origin,
        .scale = scale,
        .rot = rot,
        .alpha = alpha,
        .sprite = sprite,
        .flash_time = flash_time,
        .sort_depth = sort_depth,
    };*/

    list->len++;

    return true;
}

void CleanLayeredRenderTaskList(s_layered_render_task_list* const task_list) {
    assert(task_list);
    assert(IsLayeredRenderTaskListValid(task_list));

    if (task_list->buf) {
        free(task_list->buf);
        ZeroOut(task_list, sizeof(*task_list));
    }
}

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

    if (!SpawnEnemy((s_vec_2d){32.0f, 32.0f}, &game->enemy_list)) {
        return false;
    }

    return true;
}

static bool GameTick(const s_game_tick_func_data* const func_data) {
    s_game* const game = func_data->user_mem;
    
    if (IsKeyPressed(ek_key_code_escape, func_data->input_state, func_data->input_state_last)) {
            game->paused = !game->paused;
    }

    if (game->paused) {
        return true;
    }

    ProcPlayerMovement(&game->player, func_data->input_state);
    ProcEnemyAIs(&game->enemy_list);
    ProcEnemyDeaths(game);
    UpdateCamera(game, func_data);

    return true;
}

static void RenderLayeredRenderTasks(const s_rendering_context* const rendering_context, const s_layered_render_task* const tasks, const int task_cnt, const s_textures* const textures) {
    for (int i = 0; i < task_cnt; i++) {
        const s_layered_render_task* const task = &tasks[i];

        RenderTexture(
            rendering_context,
            ek_texture_all,
            textures,
            g_sprite_src_rects[task->sprite],
            task->pos,
            task->origin,
            task->scale,
            task->rot,
            (s_color) {1.0, 1.0, 1.0, task->alpha}
        );
    }
}

static int CompareLayeredRenderTasks(const void* const a_generic, const void* const b_generic) {
    const s_layered_render_task* const a = a_generic;
    const s_layered_render_task* const b = b_generic;

    if (a->sort_depth == b->sort_depth) {
        return 0;
    }

    return a->sort_depth > b->sort_depth ? 1 : -1;
}

static bool RenderGame(const s_game_render_func_data* const func_data) {
    s_game* const game = func_data->user_mem;

    ZeroOut(&func_data->rendering_context.state->view_mat, sizeof(func_data->rendering_context.state->view_mat));
    InitCameraViewMatrix4x4(&func_data->rendering_context.state->view_mat, &game->camera, func_data->rendering_context.display_size);

    RenderClear((s_color){0.2, 0.3, 0.4, 1.0});

    s_layered_render_task_list render_task_list = {0};

    if (!AppendPlayerLayeredRenderTasks(&render_task_list, &game->player)) {
        return false;
    }

    if (!AppendEnemyLayeredRenderTasks(&render_task_list, &game->enemy_list)) {
        return false;
    }

    qsort(render_task_list.buf, render_task_list.len, sizeof(*render_task_list.buf), CompareLayeredRenderTasks);

    RenderLayeredRenderTasks(&func_data->rendering_context, render_task_list.buf, render_task_list.len, &game->textures);

    CleanLayeredRenderTaskList(&render_task_list);

    Flush(&func_data->rendering_context);

    //
    // UI
    //
    ZeroOut(&func_data->rendering_context.state->view_mat, sizeof(func_data->rendering_context.state->view_mat));
    InitIdenMatrix4x4(&func_data->rendering_context.state->view_mat);

    // Render pause screen.
    if (game->paused) {
        RenderRect(&func_data->rendering_context, (s_rect){0, 0, func_data->rendering_context.display_size.x, func_data->rendering_context.display_size.y}, (s_color){0.0f, 0.0f, 0.0f, PAUSE_SCREEN_BG_ALPHA});
        RenderStr(&func_data->rendering_context, "Paused", ek_font_eb_garamond_64, (const s_fonts_view*)&game->fonts, (s_vec_2d){func_data->rendering_context.display_size.x / 2.0f, func_data->rendering_context.display_size.y / 2.0f}, ek_str_hor_align_center, ek_str_ver_align_center, WHITE, func_data->temp_mem_arena);
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
