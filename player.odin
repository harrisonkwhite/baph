package sanctus

import "core:math"
import "core:mem"
import "zf4"

PLAYER_MOVE_SPD :: 3.0
PLAYER_VEL_LERP_FACTOR :: 0.2
PLAYER_HP_LIMIT :: 100
PLAYER_INV_TIME_LIMIT :: 30
PLAYER_SWORD_DMG :: 10
PLAYER_SWORD_KNOCKBACK: f32 : 6.0
PLAYER_SWORD_HITBOX_SIZE :: 32
PLAYER_SWORD_HITBOX_OFFS_DIST: f32 : 40.0
PLAYER_SWORD_OFFS_DIST: f32 : 6.0
PLAYER_SWORD_ROT_OFFS: f32 : 130.0 * math.RAD_PER_DEG
PLAYER_SWORD_ROT_OFFS_LERP: f32 : 0.4
PLAYER_SHIELD_OFFS_DIST: f32 : 9.0
PLAYER_SHIELD_MOVE_SPD_MULT: f32 : 0.6

Player :: struct {
	active:                       bool,
	pos:                          zf4.Vec_2D,
	vel:                          zf4.Vec_2D,
	hp:                           int,
	inv_time:                     int,
	shielding:                    bool,
	aim_dir:                      f32,
	sword_rot_offs:               f32,
	sword_rot_offs_axis_positive: bool,
}

append_player_level_render_tasks :: proc(
	tasks: ^[dynamic]Level_Layered_Render_Task,
	player: ^Player,
) -> bool {
	assert(player.active)

	character_alpha: f32 = 1.0

	if player.inv_time > 0 {
		character_alpha = player.inv_time % 2 == 0 ? 0.5 : 0.7
	}

	character_task := Level_Layered_Render_Task {
		pos        = player.pos,
		origin     = {0.5, 0.5},
		scale      = {1.0, 1.0},
		rot        = 0.0,
		alpha      = character_alpha,
		sprite     = Sprite.Player,
		sort_depth = player.pos.y,
	}

	if n, err := append(tasks, character_task); err != nil {
		return false
	}

	task: Level_Layered_Render_Task

	if !player.shielding {
		sword_rot := player.aim_dir + player.sword_rot_offs

		task = {
			pos        = player.pos + zf4.calc_len_dir(PLAYER_SWORD_OFFS_DIST, sword_rot),
			origin     = {0.0, 0.5},
			scale      = {1.0, 1.0},
			rot        = sword_rot,
			alpha      = 1.0,
			sprite     = Sprite.Sword,
			sort_depth = player.pos.y + 1.0,
		}
	} else {
		task = {
			pos        = player.pos + zf4.calc_len_dir(PLAYER_SHIELD_OFFS_DIST, player.aim_dir),
			origin     = {0.0, 0.5},
			scale      = {1.0, 1.0},
			rot        = player.aim_dir,
			alpha      = 1.0,
			sprite     = Sprite.Shield,
			sort_depth = player.pos.y + 1.0,
		}
	}

	if n, err := append(tasks, task); err != nil {
		return false
	}

	return true
}

spawn_player :: proc(pos: zf4.Vec_2D, level: ^Level) {
	assert(!level.player.active)
	mem.zero_item(&level.player)
	level.player.active = true
	level.player.pos = pos
	level.player.hp = PLAYER_HP_LIMIT
}

damage_player :: proc(level: ^Level, dmg_info: Damage_Info) {
	assert(level.player.inv_time >= 0)

	if level.player.inv_time > 0 {
		return
	}

	assert(dmg_info.dmg > 0)

	level.player.vel += dmg_info.kb
	level.player.hp = max(level.player.hp - dmg_info.dmg, 0)
	level.player.inv_time = PLAYER_INV_TIME_LIMIT

	spawn_damage_text(level, dmg_info.dmg, level.player.pos)
}

gen_player_damage_collider :: proc(player_pos: zf4.Vec_2D) -> zf4.Rect {
	return gen_collider_from_sprite(Sprite.Player, player_pos)
}

