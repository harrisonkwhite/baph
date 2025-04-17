package baph

import "core:fmt"
import "core:math"
import "zf4"

PLAYER_MOVE_SPD :: 3.0
PLAYER_VEL_LERP_FACTOR :: 0.2
PLAYER_HP_LIMIT :: 100
PLAYER_INV_TIME_LIMIT :: 30
PLAYER_DMG_FLASH_TIME :: 5

Player :: struct {
	killed:     bool,
	pos:        zf4.Vec_2D,
	vel:        zf4.Vec_2D,
	hp:         int,
	inv_time:   int,
	flash_time: int,
	weapon:     Weapon,
}

proc_player_movement :: proc(
	player: ^Player,
	input_state: ^zf4.Input_State,
	solid_colliders: []zf4.Rect,
) {
	move_dir := calc_player_move_dir(input_state)
	vel_targ := move_dir * PLAYER_MOVE_SPD * calc_weapon_move_spd_mult(&player.weapon)
	player.vel = math.lerp(player.vel, vel_targ, f32(PLAYER_VEL_LERP_FACTOR))

	proc_solid_collisions(&player.vel, gen_player_movement_collider(player.pos), solid_colliders)

	player.pos += player.vel
}

calc_player_move_dir :: proc(input_state: ^zf4.Input_State) -> zf4.Vec_2D {
	assert(input_state != nil)

	move_right := zf4.is_key_down(zf4.Key_Code.D, input_state)
	move_left := zf4.is_key_down(zf4.Key_Code.A, input_state)
	move_down := zf4.is_key_down(zf4.Key_Code.S, input_state)
	move_up := zf4.is_key_down(zf4.Key_Code.W, input_state)

	move_axis := zf4.Vec_2D {
		f32(i32(move_right) - i32(move_left)),
		f32(i32(move_down) - i32(move_up)),
	}

	return zf4.calc_normal_or_zero(move_axis)
}

proc_player_death :: proc(player: ^Player, cam: ^Camera) {
	assert(!player.killed)

	if player.hp == 0 {
		apply_camera_shake(cam, 3.0)
		player.killed = true
	}
}

proc_player_door_interaction :: proc(game: ^Game, zf4_data: ^zf4.Game_Tick_Func_Data) {
	if zf4.is_key_pressed(zf4.Key_Code.E, zf4_data.input_state, zf4_data.input_state_last) {
		player_dmg_collider := gen_player_damage_collider(game.player.pos)

		for &building in game.buildings {
			if building.door_open {
				door_solid_collider := gen_door_solid_collider(&building)

				// Cancel if player is in door.
				player_movement_collider := gen_player_movement_collider(game.player.pos)

				if zf4.do_rects_inters(player_movement_collider, door_solid_collider) {
					continue
				}

				// Cancel if enemy is in door.
				enemy_collision_found := false

				for i in 0 ..< game.enemy_cnt {
					enemy := &game.enemies[i]

					enemy_movement_collider := gen_enemy_movement_collider(enemy.type, enemy.pos)

					if zf4.do_rects_inters(enemy_movement_collider, door_solid_collider) {
						enemy_collision_found = true
						break
					}
				}

				if enemy_collision_found {
					break
				}
			}

			door_interaction_collider := gen_door_interaction_collider(&building)

			if zf4.do_rects_inters(player_dmg_collider, door_interaction_collider) {
				building.door_open = !building.door_open
			}
		}
	}
}

append_player_render_tasks :: proc(tasks: ^[dynamic]Render_Task, player: ^Player) -> bool {
	assert(!player.killed)

	character_alpha: f32 = 1.0

	if player.inv_time > 0 {
		character_alpha = player.inv_time % 2 == 0 ? 0.5 : 0.7
	}

	sprite_src_rects := SPRITE_SRC_RECTS
	sort_depth := player.pos.y + (f32(sprite_src_rects[Sprite.Player].height) / 2.0)

	if !append_render_task(
		tasks,
		player.pos,
		Sprite.Player,
		sort_depth,
		alpha = character_alpha,
		flash_time = player.flash_time,
	) {
		return false
	}

	if !append_weapon_render_task(tasks, &player.weapon, player.pos, sort_depth + 1.0) {
		return false
	}

	return true
}

damage_player :: proc(game: ^Game, dmg_info: Damage_Info) {
	assert(game.player.inv_time >= 0)

	if game.player.inv_time > 0 {
		return
	}

	assert(dmg_info.dmg > 0)

	game.player.vel += dmg_info.kb
	game.player.hp = max(game.player.hp - dmg_info.dmg, 0)
	game.player.inv_time = PLAYER_INV_TIME_LIMIT
	game.player.flash_time = PLAYER_DMG_FLASH_TIME

	spawn_damage_text(game, dmg_info.dmg, game.player.pos)

	apply_camera_shake(&game.cam, 2.0)
}

gen_player_movement_collider :: proc(player_pos: zf4.Vec_2D) -> zf4.Rect {
	spr_collider := gen_collider_rect_from_sprite(Sprite.Player, player_pos)

	mv_collider := spr_collider
	mv_collider.height = spr_collider.height / 4.0
	mv_collider.y = zf4.calc_rect_bottom(spr_collider) - mv_collider.height
	return mv_collider
}

gen_player_damage_collider :: proc(player_pos: zf4.Vec_2D) -> zf4.Rect {
	return gen_collider_rect_from_sprite(Sprite.Player, player_pos)
}

