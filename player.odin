package apocalypse

import "core:math"
import "zf4"

Player :: struct {
	active:     bool,
	pos:        zf4.Vec_2D,
	vel:        zf4.Vec_2D,
	hp:         int,
	inv_time:   int,
	flash_time: int,
	weapon:     Weapon,
}

run_player_tick :: proc(
	world: ^World,
	game_config: ^Game_Config,
	zf4_data: ^zf4.Game_Tick_Func_Data,
) -> bool {
	player := &world.player

	assert(player.active)

	move_right := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Move_Right],
		zf4_data.input_state,
	)

	move_left := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Move_Left],
		zf4_data.input_state,
	)

	move_down := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Move_Down],
		zf4_data.input_state,
	)

	move_up := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Move_Up],
		zf4_data.input_state,
	)

	move_axis := zf4.Vec_2D {
		f32(i32(move_right) - i32(move_left)),
		f32(i32(move_down) - i32(move_up)),
	}

	move_dir := zf4.calc_normal_or_zero(move_axis)

	vel_lerp_targ := move_dir * PLAYER_MOVE_SPD * calc_weapon_move_spd_mult(&player.weapon)
	player.vel = math.lerp(player.vel, vel_lerp_targ, f32(PLAYER_VEL_LERP_FACTOR))

	player.pos += player.vel

	if player.inv_time > 0 {
		player.inv_time -= 1
	}

	if player.flash_time > 0 {
		player.flash_time -= 1
	}


	// TEMP:
	if zf4.is_key_pressed(zf4.Key_Code.Tab, zf4_data.input_state, zf4_data.input_state_last) {
		world.player.weapon = {
			type = Weapon_Type.Bow,
		}
	}


	if !run_weapon_tick(world, game_config, zf4_data) {
		return false
	}

	return true
}

append_player_render_tasks :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	player: ^Player,
) -> bool {
	assert(player.active)

	character_alpha: f32 = 1.0

	if player.inv_time > 0 {
		character_alpha = player.inv_time % 2 == 0 ? 0.5 : 0.7
	}

	sprite_src_rects := SPRITE_SRC_RECTS

	task := World_Layered_Render_Task {
		pos        = player.pos,
		origin     = {0.5, 0.5},
		scale      = {1.0, 1.0},
		rot        = 0.0,
		alpha      = character_alpha,
		sprite     = Sprite.Player,
		flash_time = player.flash_time,
		sort_depth = player.pos.y + (f32(sprite_src_rects[Sprite.Player].height) / 2.0),
	}

	if n, err := append(tasks, task); err != nil {
		return false
	}

	if !append_weapon_render_task(tasks, &player.weapon, player.pos, task.sort_depth + 1.0) {
		return false
	}

	return true
}

spawn_player :: proc(pos: zf4.Vec_2D, world: ^World) {
	assert(!world.player.active)

	world.player = {
		active = true,
		pos    = pos,
		hp     = PLAYER_HP_LIMIT,
	}
}

damage_player :: proc(world: ^World, dmg_info: Damage_Info) {
	assert(world.player.inv_time >= 0)

	if world.player.inv_time > 0 {
		return
	}

	assert(dmg_info.dmg > 0)

	world.player.vel += dmg_info.kb
	world.player.hp = max(world.player.hp - dmg_info.dmg, 0)
	world.player.inv_time = PLAYER_INV_TIME_LIMIT
	world.player.flash_time = PLAYER_DMG_FLASH_TIME

	spawn_damage_text(world, dmg_info.dmg, world.player.pos)

	apply_camera_shake(&world.cam, 2.0)
}

gen_player_damage_collider :: proc(player_pos: zf4.Vec_2D) -> zf4.Rect {
	return gen_collider_from_sprite(Sprite.Player, player_pos)
}

