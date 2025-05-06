#include "gc_game.h"

#define PLAYER_MOVE_SPD 2.0f
#define PLAYER_VEL_LERP_FACTOR 0.2f
#define PLAYER_INV_TIME_LIMIT 20
#define PLAYER_DMG_FLASH_TIME 10

static s_vec_2d CalcPlayerMoveDir(const s_input_state* const input_state) {
    assert(input_state);

    const bool move_right = IsKeyDown(ek_key_code_d, input_state);
    const bool move_left = IsKeyDown(ek_key_code_a, input_state);
    const bool move_down = IsKeyDown(ek_key_code_s, input_state);
    const bool move_up = IsKeyDown(ek_key_code_w, input_state);

    const s_vec_2d move_axis = {
        move_right - move_left,
        move_down - move_up,
    };

    return NormalOrZero(move_axis);
}

void ProcPlayerMovement(s_player* const player, const s_input_state* const input_state) {
    const s_vec_2d move_dir = CalcPlayerMoveDir(input_state);
    const s_vec_2d vel_targ = {move_dir.x * PLAYER_MOVE_SPD, move_dir.y * PLAYER_MOVE_SPD};

    player->vel = LerpVec2D(player->vel, vel_targ, PLAYER_VEL_LERP_FACTOR);

    //proc_solid_collisions(&player.vel, gen_player_movement_collider(player.pos), solid_colliders)

    player->pos.x += player->vel.x;
    player->pos.y += player->vel.y;
}

static float CalcPlayerAlpha(const int inv_time) {
    assert(inv_time >= 0);

    if (inv_time > 0) {
        return inv_time % 2 == 0 ? 0.5f : 0.7f;
    }

    return 1.0f;
}

bool AppendPlayerLayeredRenderTasks(s_layered_render_task_list* const tasks, const s_player* const player) {
    assert(tasks);
    assert(player);
    assert(!player->killed);

    const float sort_depth = player->pos.y + (g_sprite_src_rects[ek_sprite_player].height / 2.0f);

    /*if (!AppendLayeredRenderTask(
        tasks,
        player->pos,
        ek_sprite_player,
        sort_depth,
        CalcPlayerAlpha(player->inv_time),
        flash_time = player.flash_time,
    )) {
        return false
    }*/

    if (!AppendLayeredRenderTask(tasks, player->pos, ek_sprite_player, sort_depth)) {
        return false;
    }

    return true;
}

void DamagePlayer(s_level* const level, const s_damage_info dmg_info) {
    if (level->player.inv_time > 0) {
        return;
    }

    assert(dmg_info.dmg > 0);

    level->player.vel = Vec2DSum(level->player.vel, dmg_info.kb);
    level->player.hp = MAX(level->player.hp - dmg_info.dmg, 0);
    level->player.inv_time = PLAYER_INV_TIME_LIMIT;
    level->player.flash_time = PLAYER_DMG_FLASH_TIME;
}
