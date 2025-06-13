#include <stdio.h>
#include "gc_game.h"
#include "gce_math.h"

bool InitLevel(s_level* const level) {
    assert(IsZero(level, sizeof(*level)));

    InitPlayer(&level->player);

    if (!SpawnEnemy((s_vec_2d){32.0f, 32.0f}, &level->enemy_list)) {
        return false;
    }

    for (int y = 10; y < 15; y++) {
        for (int x = 10; x < 15; x++) {
            ActivateTile(&level->tilemap, x, y);
        }
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
        const s_rect player_dmg_collider = GenPlayerCollider(level->player.pos);

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

    ProcPlayerMovement(&level->player, input_state, &level->tilemap, &level->camera, window_state->size);

    if (!ProcPlayerShooting(level, window_state->size, input_state, input_state_last)) {
        return false;
    }

    UpdatePlayerTimers(&level->player);

    if (!UpdateEnemies(level)) {
        return false;
    }

    UpdateProjectiles(level, temp_mem_arena);

    ProcPlayerDeath(level);
    ProcEnemyDeaths(level);

    UpdateCamera(level, window_state, input_state);

    return true;
}

void RenderProjectiles(const s_rendering_context* const rendering_context, const s_projectile* const projectiles, const int proj_cnt, const s_textures* const textures) {
    assert(rendering_context);
    assert(projectiles);
    assert(proj_cnt >= 0 && proj_cnt <= PROJECTILE_LIMIT);

    for (int i = 0; i < proj_cnt; i++) {
        const s_projectile* const proj = &projectiles[i];

        RenderSprite(
            rendering_context,
            ek_sprite_projectile,
            textures,
            proj->pos,
            (s_vec_2d){0.5f, 0.5f},
            (s_vec_2d){1.0f, 1.0f},
            proj->rot,
            WHITE
        );
    }
}

bool RenderLevel(const s_rendering_context* const rendering_context, const s_level* const level, const s_textures* const textures, const s_fonts* const fonts, const s_shader_progs* const shader_progs, s_mem_arena* const temp_mem_arena) {
    ZeroOut(&rendering_context->state->view_mat, sizeof(rendering_context->state->view_mat));
    InitCameraViewMatrix4x4(&rendering_context->state->view_mat, &level->camera, rendering_context->display_size);

    RenderClear((s_color){0.2, 0.3, 0.4, 1.0});

    RenderEnemies(rendering_context, &level->enemy_list, textures, shader_progs);

    if (!level->player.killed) {
        RenderPlayer(rendering_context, &level->player, textures, shader_progs);
    }

    RenderProjectiles(rendering_context, level->projectiles, level->proj_cnt, textures);

    RenderTilemap(rendering_context, &level->tilemap, textures);

    Flush(rendering_context);

    //
    // UI
    //
    ZeroOut(&rendering_context->state->view_mat, sizeof(rendering_context->state->view_mat));
    InitIdenMatrix4x4(&rendering_context->state->view_mat);

    // Render player health.
    {
        const s_vec_2d bar_size = {rendering_context->display_size.x * 0.25f, 20.0f};
        const s_rect bar_rect = {
            (rendering_context->display_size.x - bar_size.x) / 2.0f,
            (rendering_context->display_size.y - bar_size.y) * 0.9f,
            bar_size.x,
            bar_size.y
        };

        RenderBarHor(rendering_context, bar_rect, (float)level->player.hp / PLAYER_HP_LIMIT, ToColorRGB(WHITE), ToColorRGB(BLACK));
    }

    // Render pause screen.
    if (level->paused) {
        RenderRect(rendering_context, (s_rect){0, 0, rendering_context->display_size.x, rendering_context->display_size.y}, (s_color){0.0f, 0.0f, 0.0f, PAUSE_SCREEN_BG_ALPHA});
        RenderStr(rendering_context, "Paused", ek_font_eb_garamond_64, fonts, (s_vec_2d){rendering_context->display_size.x / 2.0f, rendering_context->display_size.y / 2.0f}, ek_str_hor_align_center, ek_str_ver_align_center, WHITE, temp_mem_arena);
    }

    Flush(rendering_context);

    return true;
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
