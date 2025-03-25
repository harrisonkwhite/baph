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

Player :: struct {
	active:                       bool,
	pos:                          zf4.Vec_2D,
	vel:                          zf4.Vec_2D,
	hp:                           int,
	inv_time:                     int,
	sword_rot_base:               f32,
	sword_rot_offs:               f32,
	sword_rot_offs_axis_positive: bool,
}

update_player :: proc(
	level: ^Level,
	game_config: ^Game_Config,
	zf4_data: ^zf4.Game_Tick_Func_Data,
) -> bool {
	assert(level.player.active)

	//
	// Movement
	//
	key_right := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Move_Right],
		zf4_data.input_state,
	)

	key_left := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Move_Left],
		zf4_data.input_state,
	)

	key_down := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Move_Down],
		zf4_data.input_state,
	)

	key_up := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Move_Up],
		zf4_data.input_state,
	)

	move_axis := zf4.Vec_2D{f32(i32(key_right) - i32(key_left)), f32(i32(key_down) - i32(key_up))}

	move_dir := zf4.calc_normal_or_zero(move_axis)

	vel_lerp_targ := move_dir * PLAYER_MOVE_SPD
	level.player.vel = math.lerp(level.player.vel, vel_lerp_targ, f32(PLAYER_VEL_LERP_FACTOR))

	level.player.pos += level.player.vel

	//
	// Attacking
	//
	mouse_cam_pos := display_to_camera_pos(
		zf4_data.input_state.mouse_pos,
		level.cam.pos,
		zf4_data.window_state_cache.size,
	)

	mouse_dir_vec := zf4.calc_normal_or_zero(mouse_cam_pos - level.player.pos)
	mouse_dir := zf4.calc_dir(mouse_dir_vec)

	level.player.sword_rot_base = mouse_dir

	if is_input_pressed(
		&game_config.input_binding_settings[Input_Binding.Attack],
		zf4_data.input_state,
		zf4_data.input_state_last,
	) {
		attack_dir := zf4.calc_normal_or_zero(mouse_cam_pos - level.player.pos)

		if !spawn_hitmask_quad(
			level.player.pos + (attack_dir * PLAYER_SWORD_HITBOX_OFFS_DIST),
			{PLAYER_SWORD_HITBOX_SIZE, PLAYER_SWORD_HITBOX_SIZE},
			{dmg = PLAYER_SWORD_DMG, kb = attack_dir * PLAYER_SWORD_KNOCKBACK},
			&level.hitmasks,
		) {
			return false
		}

		level.player.sword_rot_offs_axis_positive = !level.player.sword_rot_offs_axis_positive
	}

	//
	//
	//
	sword_rot_offs_dest :=
		level.player.sword_rot_offs_axis_positive ? PLAYER_SWORD_ROT_OFFS : -PLAYER_SWORD_ROT_OFFS

	level.player.sword_rot_offs +=
		(sword_rot_offs_dest - level.player.sword_rot_offs) * PLAYER_SWORD_ROT_OFFS_LERP

	//
	// Processing Enemy Contacts
	//
	if level.player.inv_time > 0 {
		level.player.inv_time -= 1
	} else {
		player_collider := gen_player_damage_collider(level.player.pos)

		enemy_type_infos := ENEMY_TYPE_INFOS

		for i in 0 ..< ENEMY_LIMIT {
			if !level.enemies.activity[i] {
				continue
			}

			enemy := &level.enemies.buf[i]
			enemy_type_info := enemy_type_infos[enemy.type]

			if Enemy_Type_Flag.Deals_Contact_Damage not_in enemy_type_info.flags {
				continue
			}

			enemy_dmg_collider := gen_enemy_damage_collider(enemy.type, enemy.pos)

			if zf4.do_rects_inters(player_collider, enemy_dmg_collider) {
				kb_dir := zf4.calc_normal_or_zero(level.player.pos - enemy.pos)

				dmg_info := Damage_Info {
					dmg = enemy_type_info.contact_dmg,
					kb  = kb_dir * enemy_type_info.contact_kb,
				}

				damage_player(&level.player, dmg_info)

				spawn_damage_text(level, dmg_info.dmg, level.player.pos)

				break
			}
		}
	}

	return true
}

proc_player_death :: proc(player: ^Player) {
	assert(player != nil)
	assert(player.active)

	if player.hp == 0 {
		player.active = false
	}
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

	sword_rot := player.sword_rot_base + player.sword_rot_offs

	sword_task := Level_Layered_Render_Task {
		pos        = player.pos + zf4.calc_len_dir(PLAYER_SWORD_OFFS_DIST, sword_rot),
		origin     = {0.0, 0.5},
		scale      = {1.0, 1.0},
		rot        = sword_rot,
		alpha      = 1.0,
		sprite     = Sprite.Sword,
		sort_depth = player.pos.y + 1.0,
	}

	if n, err := append(tasks, sword_task); err != nil {
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

can_damage_player :: proc(player: ^Player) -> bool {
	return player.inv_time == 0
}

damage_player :: proc(player: ^Player, dmg_info: Damage_Info) {
	assert(can_damage_player(player))
	assert(dmg_info.dmg > 0)

	player.vel += dmg_info.kb
	player.hp = max(player.hp - dmg_info.dmg, 0)
	player.inv_time = PLAYER_INV_TIME_LIMIT
}

gen_player_damage_collider :: proc(player_pos: zf4.Vec_2D) -> zf4.Rect {
	return gen_collider_from_sprite(Sprite.Player, player_pos)
}

