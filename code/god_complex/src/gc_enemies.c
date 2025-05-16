#include <assert.h>
#include <stdio.h>
#include "gc_game.h"
#include "gce_math.h"

#define ENEMY_VEL_LERP_FACTOR 0.2f
#define ENEMY_SHOOT_INTERVAL 120
#define ENEMY_DMG_FLASH_TIME 10

bool SpawnEnemy(const s_vec_2d pos, s_enemy_list* const enemy_list) {
    const int enemy_index = FirstInactiveBitIndex(enemy_list->activity, sizeof(enemy_list->activity));

    if (enemy_index == -1) {
        fprintf(stderr, "Failed to spawn enemy due to insufficient space!\n");
        return false;
    }

    s_enemy* const enemy = &enemy_list->buf[enemy_index];
    assert(IsZero(enemy, sizeof(*enemy)));
    enemy->pos = pos;
    enemy->hp = 100;

    ActivateBit(enemy_index, enemy_list->activity, ENEMY_LIMIT);
    
    return true;
}

bool UpdateEnemies(s_level* const level) {
    assert(level);
    
    for (int i = 0; i < ENEMY_LIMIT; i++) {
        if (!IsEnemyActive(i, &level->enemy_list)) {
            continue;
        }
        
        s_enemy* const enemy = &level->enemy_list.buf[i];

        enemy->vel = LerpVec2D(enemy->vel, VEC_2D_ZERO, ENEMY_VEL_LERP_FACTOR);
        enemy->pos = Vec2DSum(enemy->pos, enemy->vel);

        if (enemy->shoot_time < ENEMY_SHOOT_INTERVAL) {
            enemy->shoot_time++;
        } else {
            const float shoot_dir = DirFrom(enemy->pos, level->player.pos);

            if (!SpawnProjectile(level, enemy->pos, 12.0f, shoot_dir, 4, true)) {
                return false;
            }

            enemy->shoot_time = 0;
        }

        if (enemy->flash_time > 0) {
            enemy->flash_time -= 1;
        }
    }

    return true;
}

void ProcEnemyDeaths(s_level* const level) {
    assert(level);
    
    for (int i = 0; i < ENEMY_LIMIT; i++) {
        if (!IsEnemyActive(i, &level->enemy_list)) {
            continue;
        }

        s_enemy* const enemy = &level->enemy_list.buf[i];

        assert(enemy->hp >= 0);

        if (enemy->hp == 0) {
            DeactivateBit(i, level->enemy_list.activity, ENEMY_LIMIT);
            ZeroOut(enemy, sizeof(*enemy));
        }
    }
}

void RenderEnemies(const s_rendering_context* const rendering_context, const s_enemy_list* const enemies, const s_textures* const textures, const s_shader_progs* const shader_progs) {
    assert(rendering_context);
    assert(enemies);
    assert(textures);
    assert(shader_progs);

    for (int i = 0; i < ENEMY_LIMIT; i++) {
        if (!IsEnemyActive(i, enemies)) {
            continue;
        }

        const s_enemy* const enemy = &enemies->buf[i];

        if (enemy->flash_time > 0) {
            Flush(rendering_context);

            SetSurface(rendering_context, 0);

            RenderClear((s_color){0});
        } 

        RenderSprite(
            rendering_context,
            ek_sprite_enemy,
            textures,
            enemy->pos,
            (s_vec_2d){0.5f, 0.5f},
            (s_vec_2d){1.0f, 1.0f},
            0.0f,
            WHITE
        );

        if (enemy->flash_time > 0) {
            Flush(rendering_context);

            UnsetSurface(rendering_context);

            SetSurfaceShaderProg(rendering_context, shader_progs->gl_ids[ek_shader_prog_blend]);

            SetSurfaceShaderProgUniform(
                rendering_context,
                "u_col",
                (s_shader_prog_uniform_value){
                    .type = ek_shader_prog_uniform_value_type_v3,
                    .as_v3 = {1.0f, 1.0f, 1.0f}
                }
            );

            RenderSurface(rendering_context, 0);
        }
    }
}

s_rect GenEnemyDamageCollider(const s_vec_2d enemy_pos) {
    return GenColliderRectFromSprite(ek_sprite_enemy, enemy_pos, (s_vec_2d){0.5f, 0.5f});
}

void DamageEnemy(s_level* const level, const int enemy_index, const s_damage_info dmg_info) {
    assert(level);
    assert(enemy_index >= 0 && enemy_index < ENEMY_LIMIT);
    assert(IsEnemyActive(enemy_index, &level->enemy_list));
    assert(dmg_info.dmg > 0);

    s_enemy* const enemy = &level->enemy_list.buf[enemy_index];
    enemy->vel = Vec2DSum(enemy->vel, dmg_info.kb);
    enemy->hp = MAX(enemy->hp - dmg_info.dmg, 0);
    enemy->flash_time = ENEMY_DMG_FLASH_TIME;
}
