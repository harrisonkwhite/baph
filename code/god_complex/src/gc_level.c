#include <stdlib.h>
#include <stdio.h>
#include "gc_game.h"
#include "gce_math.h"

bool InitLevel(s_level* const level) {
    assert(IsZero(level, sizeof(*level)));

    if (!SpawnEnemy((s_vec_2d){32.0f, 32.0f}, &level->enemy_list)) {
        return false;
    }

    return true;
}

static s_damage_info GenProjectileDamageInfo(const s_projectile* const proj) {
    return (s_damage_info){
        .dmg = proj->dmg,
        .kb = proj->vel
    };
}

static bool UpdateProjectiles(s_level* const level, s_mem_arena* const temp_mem_arena) {
    assert(level);
    assert(temp_mem_arena && IsMemArenaValid(temp_mem_arena));

    // Process projectile movement.
    for (int i = 0; i < level->proj_cnt; i++) {
        s_projectile* const proj = &level->projectiles[i];
        proj->pos = Vec2DSum(proj->pos, proj->vel);
    }

    // Generate projectile colliders.
    s_poly proj_colliders[PROJECTILE_LIMIT] = {0};

    for (int i = 0; i < level->proj_cnt; i++) {
        const s_projectile* const proj = &level->projectiles[i];

        if (!PushColliderPolyFromSprite(&proj_colliders[i], temp_mem_arena, ek_sprite_projectile, proj->pos, (s_vec_2d){0.5f, 0.5f}, proj->rot)) {
            fprintf(stderr, "Failed to generate projectile collider!\n");
            return false;
        }
    }

    // Handle player collision.
    if (!level->player.killed) {
        const s_rect player_dmg_collider = GenPlayerDamageCollider(level->player.pos);

        for (int i = 0; i < level->proj_cnt; i++) {
            const s_projectile* const proj = &level->projectiles[i];

            if (!proj->from_enemy) {
                continue;
            }

            if (DoesPolyIntersWithRect(&proj_colliders[i], player_dmg_collider)) {
                const s_damage_info proj_dmg_info = GenProjectileDamageInfo(proj);
                DamagePlayer(level, proj_dmg_info);

                level->proj_cnt -= 1;
                level->projectiles[i] = level->projectiles[level->proj_cnt];
                i--;
            }
        }
    }

    // Handle enemy collisions.
    {
        s_rect enemy_dmg_colliders[ENEMY_LIMIT] = {0};

        for (int i = 0; i < ENEMY_LIMIT; i++) {
            const s_enemy* const enemy = &level->enemy_list.buf[i];

            if (!IsEnemyActive(i, &level->enemy_list)) {
                continue;
            }

            enemy_dmg_colliders[i] = GenEnemyDamageCollider(enemy->pos);
        }

        for (int i = 0; i < level->proj_cnt; i++) {
            const s_projectile* const proj = &level->projectiles[i];

            if (proj->from_enemy) {
                continue;
            }

            for (int j = 0; j < ENEMY_LIMIT; j++) {
                if (!IsEnemyActive(j, &level->enemy_list)) {
                    continue;
                }

                if (DoesPolyIntersWithRect(&proj_colliders[i], enemy_dmg_colliders[j])) {
                    const s_damage_info proj_dmg_info = GenProjectileDamageInfo(proj);
                    DamageEnemy(level, j, proj_dmg_info);

                    level->proj_cnt -= 1;
                    level->projectiles[i] = level->projectiles[level->proj_cnt];
                    i--;

                    break;
                }
            }
        }
    }

    return true;
}

bool LevelTick(s_game* const game, const s_window_state* const window_state, const s_input_state* const input_state, const s_input_state* const input_state_last, s_mem_arena* const temp_mem_arena) {
    s_level* const level = &game->level;

    if (IsKeyPressed(ek_key_code_escape, input_state, input_state_last)) {
        level->paused = !level->paused;
    }

    if (level->paused) {
        return true;
    }

    ProcPlayerMovement(&level->player, input_state);

    if (!ProcPlayerShooting(level, window_state->size, input_state, input_state_last)) {
        return false;
    }

    ProcEnemyAIs(&level->enemy_list);
    UpdateProjectiles(level, temp_mem_arena);
    ProcEnemyDeaths(level);
    UpdateCamera(level, window_state, input_state);

    return true;
}

static bool AppendProjectileLayeredRenderTasks(s_layered_render_task_list* const tasks, const s_projectile* const projectiles, const int proj_cnt) {
    assert(tasks && IsLayeredRenderTaskListValid(tasks));
    assert(projectiles);
    assert(proj_cnt >= 0 && proj_cnt <= PROJECTILE_LIMIT);

    for (int i = 0; i < proj_cnt; i++) {
        const s_projectile* const proj = &projectiles[i];

        if (!AppendLayeredRenderTaskExt(
            tasks,
            proj->pos,
            (s_vec_2d){0.5f, 0.5f},
            (s_vec_2d){1.0f, 1.0f},
            proj->rot,
            1.0f,
            ek_sprite_projectile,
            0,
            proj->pos.y
        )) {
            return false;
        }
    }

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

    if (!AppendProjectileLayeredRenderTasks(&render_task_list, level->projectiles, level->proj_cnt)) {
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

    list->buf[list->len] = (s_layered_render_task){
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

bool SpawnProjectile(s_level* const level, const s_vec_2d pos, const float spd, const float dir, const int dmg, const bool from_enemy) {
    assert(level);
    assert(spd > 0.0f);
    assert(dmg > 0);

    if (level->proj_cnt == PROJECTILE_LIMIT) {
        fprintf(stderr, "Failed to spawn projectile due to insufficient space!\n");
        return false;
    }

    level->projectiles[level->proj_cnt] = (s_projectile){
        .pos = pos,
        .vel = LenDir(spd, dir),
        .rot = dir,
        .dmg = dmg,
        .from_enemy = from_enemy
    };
    level->proj_cnt++;

    return true;
}
