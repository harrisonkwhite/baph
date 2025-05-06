#include <assert.h>
#include <stdio.h>
#include "gc_game.h"

#define ENEMY_LIMIT 256

static inline bool IsEnemyActive(const int enemy_index, const s_enemy_list* const list) {
    assert(enemy_index >= 0 && enemy_index < ENEMY_LIMIT);
    assert(list);
    return IsBitActive(enemy_index, list->activity, ENEMY_LIMIT);
}

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

bool ProcEnemyAIs(s_enemy_list* const enemy_list) {
    assert(enemy_list);
    
    for (int i = 0; i < ENEMY_LIMIT; i++) {
        if (!IsEnemyActive(i, enemy_list)) {
            continue;
        }
        
        s_enemy* const enemy = &enemy_list->buf[i];

        if (enemy->flash_time > 0) {
            enemy->flash_time -= 1;
        }

        enemy->pos = Vec2DSum(enemy->pos, enemy->vel);
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

bool AppendEnemyLayeredRenderTasks(s_layered_render_task_list* const tasks, const s_enemy_list* const enemy_list) {
    assert(tasks);
    assert(enemy_list);

    for (int i = 0; i < ENEMY_LIMIT; i++) {
        if (!IsEnemyActive(i, enemy_list)) {
            continue;
        }

        const s_enemy* const enemy = &enemy_list->buf[i];

        const float sort_depth = enemy->pos.y + (g_sprite_src_rects[ek_sprite_enemy].height / 2.0f);

        if (!AppendLayeredRenderTask(tasks, enemy->pos, ek_sprite_enemy, sort_depth)) {
            return false;
        }
    }
    
    return true;
}
