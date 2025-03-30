package sanctus

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "zf4"

HITMASK_LIMIT :: 64

DAMAGE_TEXT_LIMIT :: 64
DAMAGE_TEXT_FONT :: Font.EB_Garamond_40
DAMAGE_TEXT_SLOWDOWN_MULT :: 0.9
DAMAGE_TEXT_VEL_Y_MIN_FOR_FADE :: 0.2
DAMAGE_TEXT_FADE_MULT :: 0.8

LEVEL_LAYERED_RENDER_TASK_FLASH_TIME_LIMIT :: 10 // TEMP?

Level :: struct {
	player:             Player,
	enemies:            Enemies,
	enemy_spawn_time:   int,
	hitmasks:           [HITMASK_LIMIT]Hitmask,
	hitmask_active_cnt: int,
	dmg_texts:          [DAMAGE_TEXT_LIMIT]Damage_Text,
	cam:                Camera,
}

Level_Layered_Render_Task :: struct {
	pos:        zf4.Vec_2D,
	origin:     zf4.Vec_2D,
	scale:      zf4.Vec_2D,
	rot:        f32,
	alpha:      f32,
	sprite:     Sprite,
	flash_time: int,
	sort_depth: f32,
}

Level_Tick_Result :: enum {
	Normal,
	Go_To_Title,
	Error,
}

Hitmask :: struct {
	collider: zf4.Poly,
	dmg_info: Damage_Info,
	flags:    Hitmask_Flag_Set,
}

Hitmask_Flag :: enum {
	Damage_Player,
	Damage_Enemy,
}

Hitmask_Flag_Set :: bit_set[Hitmask_Flag]

Damage_Info :: struct {
	dmg: int,
	kb:  zf4.Vec_2D,
}

Damage_Text :: struct {
	dmg:   int,
	pos:   zf4.Vec_2D,
	vel_y: f32,
	alpha: f32,
}

init_level :: proc(level: ^Level) -> bool {
	assert(level != nil)
	mem.zero_item(level)

	spawn_player({}, level)

	return true
}

level_tick :: proc(
	level: ^Level,
	game_config: ^Game_Config,
	zf4_data: ^zf4.Game_Tick_Func_Data,
) -> Level_Tick_Result {
	enemy_type_infos := ENEMY_TYPE_INFOS

	mouse_cam_pos := display_to_camera_pos(
		zf4_data.input_state.mouse_pos,
		&level.cam,
		zf4_data.window_state_cache.size,
	)

	level.hitmask_active_cnt = 0

	//
	// Enemy Spawning
	//
	if level.enemy_spawn_time < ENEMY_SPAWN_INTERVAL {
		level.enemy_spawn_time += 1
	} else {
		spawn_offs_dir := rand.float32_range(0.0, math.PI * 2.0)
		spawn_offs_dist := rand.float32_range(ENEMY_SPAWN_DIST_RANGE[0], ENEMY_SPAWN_DIST_RANGE[1])
		spawn_pos := level.cam.pos_no_offs + zf4.calc_len_dir(spawn_offs_dist, spawn_offs_dir)

		// NOTE: Not handling fail case here.
		spawn_enemy(Enemy_Type.Melee, spawn_pos, level)

		level.enemy_spawn_time = 0
	}

	//
	// Player
	//
	if level.player.active {
		level.player.shielding = is_input_down(
			&game_config.input_binding_settings[Input_Binding.Shield],
			zf4_data.input_state,
		)

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

		move_axis := zf4.Vec_2D {
			f32(i32(key_right) - i32(key_left)),
			f32(i32(key_down) - i32(key_up)),
		}

		move_dir := zf4.calc_normal_or_zero(move_axis)

		vel_lerp_targ :=
			move_dir *
			PLAYER_MOVE_SPD *
			(level.player.shielding ? PLAYER_SHIELD_MOVE_SPD_MULT : 1.0)
		level.player.vel = math.lerp(level.player.vel, vel_lerp_targ, f32(PLAYER_VEL_LERP_FACTOR))

		level.player.pos += level.player.vel

		mouse_dir_vec := zf4.calc_normal_or_zero(mouse_cam_pos - level.player.pos)

		level.player.aim_dir = zf4.calc_dir(mouse_dir_vec)

		if !level.player.shielding {
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
					{Hitmask_Flag.Damage_Enemy},
					level,
				) {
					return Level_Tick_Result.Error
				}

				level.player.sword_rot_offs_axis_positive =
				!level.player.sword_rot_offs_axis_positive
			}
		}

		sword_rot_offs_dest :=
			level.player.sword_rot_offs_axis_positive ? PLAYER_SWORD_ROT_OFFS : -PLAYER_SWORD_ROT_OFFS

		level.player.sword_rot_offs +=
			(sword_rot_offs_dest - level.player.sword_rot_offs) * PLAYER_SWORD_ROT_OFFS_LERP

		if level.player.inv_time > 0 {
			level.player.inv_time -= 1
		}

		if level.player.flash_time > 0 {
			level.player.flash_time -= 1
		}
	}

	//
	// Enemy AI
	//
	for i in 0 ..< ENEMY_LIMIT {
		if !level.enemies.activity[i] {
			continue
		}

		enemy := &level.enemies.buf[i]

		enemy.vel *= 0.8
		enemy.pos += enemy.vel

		if enemy.attack_time < 60 {
			enemy.attack_time += 1
		} else {
			attack_dir := zf4.calc_normal_or_zero(level.player.pos - enemy.pos)
			ATTACK_HITBOX_OFFS_DIST :: 32.0
			ATTACK_KNOCKBACK :: 6.0

			if !spawn_hitmask_quad(
				enemy.pos + (attack_dir * ATTACK_HITBOX_OFFS_DIST),
				{32.0, 32.0},
				{dmg = 1, kb = attack_dir * ATTACK_KNOCKBACK},
				{Hitmask_Flag.Damage_Player},
				level,
			) {
				return Level_Tick_Result.Error
			}

			enemy.attack_time = 0
		}

		// NOTE: Should the below be elsewhere?
		if enemy.flash_time > 0 {
			enemy.flash_time -= 1
		}
	}

	//
	// Player and Enemy Collisions
	//
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

		if zf4.do_rects_inters(gen_player_damage_collider(level.player.pos), enemy_dmg_collider) {
			kb_dir := zf4.calc_normal_or_zero(level.player.pos - enemy.pos)

			dmg_info := Damage_Info {
				dmg = enemy_type_info.contact_dmg,
				kb  = kb_dir * enemy_type_info.contact_kb,
			}

			damage_player(level, dmg_info)

			break
		}
	}

	//
	// Hitmask Collisions
	//
	for i in 0 ..< level.hitmask_active_cnt {
		hm := &level.hitmasks[i]

		if Hitmask_Flag.Damage_Player in hm.flags {
			if zf4.does_poly_inters_with_rect(
				hm.collider,
				gen_player_damage_collider(level.player.pos),
			) {
				damage_player(level, hm.dmg_info)
			}
		}

		if Hitmask_Flag.Damage_Enemy in hm.flags {
			for j in 0 ..< ENEMY_LIMIT {
				if !level.enemies.activity[j] {
					continue
				}

				enemy := &level.enemies.buf[j]

				enemy_dmg_collider := gen_enemy_damage_collider(enemy.type, enemy.pos)

				// NOTE: Could cache the collider polygons.
				if zf4.does_poly_inters_with_rect(hm.collider, enemy_dmg_collider) {
					damage_enemy(j, level, hm.dmg_info)
					spawn_damage_text(level, hm.dmg_info.dmg, enemy.pos)
				}
			}
		}
	}

	//
	// Player Death
	//
	assert(level.player.hp >= 0)

	if level.player.hp == 0 {
		level.player.active = false
	}

	//
	// Enemy Deaths
	//
	for i in 0 ..< ENEMY_LIMIT {
		if !level.enemies.activity[i] {
			continue
		}

		enemy := &level.enemies.buf[i]

		assert(enemy.hp >= 0)

		if enemy.hp == 0 {
			apply_camera_shake(&level.cam, 3.0)
			level.enemies.activity[i] = false
		}
	}

	//
	// Camera
	//
	{
		mouse_cam_pos := display_to_camera_pos(
			zf4_data.input_state.mouse_pos,
			&level.cam,
			zf4_data.window_state_cache.size,
		)
		player_to_mouse_cam_pos_dist := zf4.calc_dist(level.player.pos, mouse_cam_pos)
		player_to_mouse_cam_pos_dir := zf4.calc_normal_or_zero(mouse_cam_pos - level.player.pos)

		look_dist :=
			CAMERA_LOOK_DIST_LIMIT *
			min(player_to_mouse_cam_pos_dist / CAMERA_LOOK_DIST_SCALAR_DIST, 1.0)

		look_offs := player_to_mouse_cam_pos_dir * look_dist

		dest := level.player.pos + look_offs
		level.cam.pos_no_offs = math.lerp(level.cam.pos_no_offs, dest, f32(CAMERA_POS_LERP_FACTOR))

		level.cam.shake *= CAMERA_SHAKE_MULT
	}

	//
	// Damage Text
	//
	for &dt in level.dmg_texts {
		dt.pos.y += dt.vel_y
		dt.vel_y *= DAMAGE_TEXT_SLOWDOWN_MULT

		if abs(dt.vel_y) <= DAMAGE_TEXT_VEL_Y_MIN_FOR_FADE {
			dt.alpha *= 0.8
		}
	}

	// Handle title screen change request.
	if zf4.is_key_pressed(zf4.Key_Code.Escape, zf4_data.input_state, zf4_data.input_state_last) {
		return Level_Tick_Result.Go_To_Title
	}

	return Level_Tick_Result.Normal
}

render_level :: proc(level: ^Level, zf4_data: ^zf4.Game_Render_Func_Data) -> bool {
	assert(level != nil)
	assert(zf4_data != nil)

	init_camera_view_matrix_4x4(
		&zf4_data.rendering_context.state.view_mat,
		&level.cam,
		zf4_data.rendering_context.display_size,
	)

	render_tasks: [dynamic]Level_Layered_Render_Task
	render_tasks.allocator = context.temp_allocator

	if level.player.active {
		if !append_player_level_render_tasks(&render_tasks, &level.player) {
			return false
		}
	}

	if !append_enemy_level_render_tasks(&render_tasks, &level.enemies) {
		return false
	}

	slice.sort_by(
		render_tasks[:],
		proc(task_a: Level_Layered_Render_Task, task_b: Level_Layered_Render_Task) -> bool {
			return task_a.sort_depth < task_b.sort_depth
		},
	)

	sprite_src_rects := SPRITE_SRC_RECTS

	for &task in render_tasks {
		if task.flash_time > 0 {
			zf4.flush(&zf4_data.rendering_context)
			zf4.set_surface(&zf4_data.rendering_context, 0)

			zf4.render_clear()

			zf4.render_texture(
				&zf4_data.rendering_context,
				int(Texture.All),
				zf4_data.textures,
				sprite_src_rects[task.sprite],
				task.pos,
				task.origin,
				task.scale,
				task.rot,
				{1.0, 1.0, 1.0, task.alpha},
			)

			zf4.flush(&zf4_data.rendering_context)

			zf4.unset_surface(&zf4_data.rendering_context)

			zf4.set_surface_shader_prog(
				&zf4_data.rendering_context,
				zf4_data.shader_progs.gl_ids[Shader_Prog.Blend],
			)
			zf4.set_surface_shader_prog_uniform(
				&zf4_data.rendering_context,
				"u_col",
				zf4.WHITE.rgb,
			)
			zf4.set_surface_shader_prog_uniform(
				&zf4_data.rendering_context,
				"u_intensity",
				f32(task.flash_time) / (LEVEL_LAYERED_RENDER_TASK_FLASH_TIME_LIMIT / 2.0),
			)
			zf4.render_surface(&zf4_data.rendering_context, 0)
		} else {
			zf4.render_texture(
				&zf4_data.rendering_context,
				int(Texture.All),
				zf4_data.textures,
				sprite_src_rects[task.sprite],
				task.pos,
				task.origin,
				task.scale,
				task.rot,
				{1.0, 1.0, 1.0, task.alpha},
			)
		}
	}

	for i in 0 ..< level.hitmask_active_cnt {
		zf4.render_poly_outline(&zf4_data.rendering_context, level.hitmasks[i].collider, zf4.RED)
	}

	zf4.flush(&zf4_data.rendering_context)

	//
	// UI
	//
	// TODO: There should be an assert tripped if we change view matrix without flushing beforehand.
	zf4.init_iden_matrix_4x4(&zf4_data.rendering_context.state.view_mat)

	render_enemy_hp_bars(
		&zf4_data.rendering_context,
		&level.enemies,
		&level.cam,
		zf4_data.textures,
	)

	for dt in level.dmg_texts {
		dt_str_buf: [16]u8
		dt_str := fmt.bprintf(dt_str_buf[:], "%d", -dt.dmg)

		zf4.render_str(
			&zf4_data.rendering_context,
			dt_str,
			int(DAMAGE_TEXT_FONT),
			zf4_data.fonts,
			camera_to_display_pos(dt.pos, &level.cam, zf4_data.rendering_context.display_size),
			blend = {1.0, 1.0, 1.0, dt.alpha},
		)
	}

	return true
}

clean_level :: proc(level: ^Level) {
	assert(level != nil)
}

gen_collider_from_sprite :: proc(
	sprite: Sprite,
	pos: zf4.Vec_2D,
	origin := zf4.Vec_2D{0.5, 0.5},
) -> zf4.Rect {
	src_rects := SPRITE_SRC_RECTS

	return {
		pos.x - (f32(src_rects[sprite].width) * origin.x),
		pos.y - (f32(src_rects[sprite].height) * origin.y),
		f32(src_rects[sprite].width),
		f32(src_rects[sprite].height),
	}
}

spawn_hitmask_quad :: proc(
	pos: zf4.Vec_2D,
	size: zf4.Vec_2D,
	dmg_info: Damage_Info,
	flags: Hitmask_Flag_Set,
	level: ^Level,
	allocator := context.allocator,
) -> bool {
	assert(size.x > 0.0 && size.y > 0.0)
	assert(level.hitmask_active_cnt >= 0 && level.hitmask_active_cnt <= HITMASK_LIMIT)
	assert(flags != {})

	if (level.hitmask_active_cnt == HITMASK_LIMIT) {
		return false
	}

	hm := &level.hitmasks[level.hitmask_active_cnt]

	collider_allocated: bool
	hm.collider, collider_allocated = zf4.alloc_quad_poly(pos, size, {0.5, 0.5}, allocator)

	if !collider_allocated {
		return false
	}

	hm.dmg_info = dmg_info
	hm.flags = flags
	level.hitmask_active_cnt += 1

	return true
}

spawn_damage_text :: proc(
	level: ^Level,
	dmg: int,
	pos: zf4.Vec_2D,
	vel_y_range: [2]f32 = {-6.0, -4.0},
) -> bool {
	assert(level != nil)
	assert(dmg > 0)
	assert(vel_y_range[0] <= vel_y_range[1])
	assert(vel_y_range[0] <= 0.0 && vel_y_range[1] <= 0.0)

	for &dt in level.dmg_texts {
		if dt.alpha <= 0.01 {
			dt = {
				dmg   = dmg,
				pos   = pos,
				vel_y = rand.float32_range(vel_y_range[0], vel_y_range[1]),
				alpha = 1.0,
			}

			return true
		}
	}

	return false
}

