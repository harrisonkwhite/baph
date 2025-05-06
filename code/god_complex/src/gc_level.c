#include <stdlib.h>
#include <stdio.h>
#include "gc_game.h"

bool InitLevel(s_level* const level) {
    if (!SpawnEnemy((s_vec_2d){32.0f, 32.0f}, &level->enemy_list)) {
        return false;
    }

    return true;
}

bool LevelTick(s_game* const game, const s_game_tick_func_data* const func_data) {
    s_level* const level = &game->level;

    if (IsKeyPressed(ek_key_code_escape, func_data->input_state, func_data->input_state_last)) {
        level->paused = !level->paused;
    }

    if (level->paused) {
        return true;
    }

    ProcPlayerMovement(&level->player, func_data->input_state);
    ProcEnemyAIs(&level->enemy_list);
    ProcEnemyDeaths(level);
    UpdateCamera(level, func_data);

    return true;
}

static int CompareLayeredRenderTasks(const void* const a_generic, const void* const b_generic) {
    const s_layered_render_task* const a = a_generic;
    const s_layered_render_task* const b = b_generic;

    if (a->sort_depth == b->sort_depth) {
        return 0;
    }

    return a->sort_depth > b->sort_depth ? 1 : -1;
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
            (s_color){1.0, 1.0, 1.0, task->alpha}
        );
    }
}

bool RenderLevel(const s_rendering_context* const rendering_context, const s_level* const level, const s_textures* const textures, const s_fonts* const fonts, s_mem_arena* const temp_mem_arena) {
    ZeroOut(&rendering_context->state->view_mat, sizeof(rendering_context->state->view_mat));
    InitCameraViewMatrix4x4(&rendering_context->state->view_mat, &level->camera, rendering_context->display_size);

    RenderClear((s_color){0.2, 0.3, 0.4, 1.0});

    s_layered_render_task_list render_task_list = {0};

    if (!AppendPlayerLayeredRenderTasks(&render_task_list, &level->player)) {
        return false;
    }

    if (!AppendEnemyLayeredRenderTasks(&render_task_list, &level->enemy_list)) {
        return false;
    }

    qsort(render_task_list.buf, render_task_list.len, sizeof(*render_task_list.buf), CompareLayeredRenderTasks);

    RenderLayeredRenderTasks(rendering_context, render_task_list.buf, render_task_list.len, textures);

    CleanLayeredRenderTaskList(&render_task_list);

    Flush(rendering_context);

    //
    // UI
    //
    ZeroOut(&rendering_context->state->view_mat, sizeof(rendering_context->state->view_mat));
    InitIdenMatrix4x4(&rendering_context->state->view_mat);

    // Render pause screen.
    if (level->paused) {
        RenderRect(rendering_context, (s_rect){0, 0, rendering_context->display_size.x, rendering_context->display_size.y}, (s_color){0.0f, 0.0f, 0.0f, PAUSE_SCREEN_BG_ALPHA});
        RenderStr(rendering_context, "Paused", ek_font_eb_garamond_64, fonts, (s_vec_2d){rendering_context->display_size.x / 2.0f, rendering_context->display_size.y / 2.0f}, ek_str_hor_align_center, ek_str_ver_align_center, WHITE, temp_mem_arena);
    }
    
    Flush(rendering_context);

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

bool AppendLayeredRenderTask(s_layered_render_task_list* const list, const s_vec_2d pos, const e_sprite sprite, const float sort_depth) {
    return AppendLayeredRenderTaskExt(
        list,
        pos,
        (s_vec_2d){0.5f, 0.5f},
        (s_vec_2d){1.0f, 1.0f},
        0.0f,
        1.0f,
        sprite,
        0,
        sort_depth
    );
}

bool AppendLayeredRenderTaskExt(
    s_layered_render_task_list* const list,
    const s_vec_2d pos,
    const s_vec_2d origin,
    const s_vec_2d scale,
    const float rot,
    const float alpha,
    const e_sprite sprite,
    const int flash_time,
    const float sort_depth
) {
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
        .origin = origin,
        .scale = scale,
        .rot = rot,
        .alpha = alpha,
        .sprite = sprite,
        .flash_time = flash_time,
        .sort_depth = sort_depth
    };

    list->len++;

    return true;
}

bool IsLayeredRenderTaskListValid(const s_layered_render_task_list* const list) {
    assert(list);

    if (IsZero(list, sizeof(*list))) {
        return true;
    }

    return list->buf && list->cap > 0 && list->len >= 0 && list->len <= list->cap;
}
