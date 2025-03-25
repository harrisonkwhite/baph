package sanctus

import "core:fmt"
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

Level :: struct {
	player:           Player,
	enemies:          Enemies,
	enemy_spawn_time: int,
	hitmasks:         Hitmasks,
	dmg_texts:        [DAMAGE_TEXT_LIMIT]Damage_Text,
	cam:              Camera,
}

Level_Layered_Render_Task :: struct {
	pos:        zf4.Vec_2D,
	origin:     zf4.Vec_2D,
	scale:      zf4.Vec_2D,
	rot:        f32,
	alpha:      f32,
	sprite:     Sprite,
	sort_depth: f32,
}

Level_Tick_Result :: enum {
	Normal,
	Go_To_Title,
	Error,
}

Hitmasks :: struct {
	active_cnt: int,
	colliders:  [HITMASK_LIMIT]zf4.Poly,
	dmg_infos:  [HITMASK_LIMIT]Damage_Info,
}

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
	assert(level != nil)
	assert(zf4_data != nil)

	// Reset hitboxes.
	level.hitmasks.active_cnt = 0

	if level.player.active {
		if !update_player(level, game_config, zf4_data) {
			return Level_Tick_Result.Error
		}
	}

	proc_enemy_spawning(level)

	update_enemies(&level.enemies)

	for i in 0 ..< level.hitmasks.active_cnt {
		hm_collider := level.hitmasks.colliders[i]

		player_dmg_collider := gen_player_damage_collider(level.player.pos)

		if zf4.does_poly_inters_with_rect(hm_collider, player_dmg_collider) {
		}

		for j in 0 ..< ENEMY_LIMIT {
			if !level.enemies.activity[j] {
				continue
			}

			enemy := &level.enemies.buf[j]

			enemy_dmg_collider := gen_enemy_damage_collider(enemy.type, enemy.pos)

			// NOTE: Could cache the collider polygons.
			if zf4.does_poly_inters_with_rect(hm_collider, enemy_dmg_collider) {
				dmg_info := &level.hitmasks.dmg_infos[i]
				damage_enemy(enemy, dmg_info^)
				spawn_damage_text(level, dmg_info.dmg, enemy.pos)
			}
		}
	}

	if level.player.active {
		proc_player_death(&level.player)
	}

	proc_enemy_deaths(&level.enemies)

	update_camera(
		&level.cam,
		level.player.pos,
		zf4_data.input_state.mouse_pos,
		zf4_data.window_state_cache.size,
	)

	// Update damage text.
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
		level.cam.pos,
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

	for i in 0 ..< level.hitmasks.active_cnt {
		zf4.render_poly_outline(&zf4_data.rendering_context, level.hitmasks.colliders[i], zf4.RED)
	}

	zf4.flush(&zf4_data.rendering_context)

	//
	// UI
	//
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
			camera_to_display_pos(dt.pos, level.cam.pos, zf4_data.rendering_context.display_size),
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
	hitmasks: ^Hitmasks,
	allocator := context.allocator, // NOTE: Should this be paired with the hitmasks struct?
) -> bool {
	assert(size.x > 0.0 && size.y > 0.0)
	assert(hitmasks.active_cnt >= 0 && hitmasks.active_cnt <= HITMASK_LIMIT)

	if (hitmasks.active_cnt == HITMASK_LIMIT) {
		return false
	}

	collider_allocated: bool
	hitmasks.colliders[hitmasks.active_cnt], collider_allocated = zf4.alloc_quad_poly(
		pos,
		size,
		{0.5, 0.5},
		allocator,
	)

	if !collider_allocated {
		return false
	}

	hitmasks.dmg_infos[hitmasks.active_cnt] = dmg_info
	hitmasks.active_cnt += 1

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

