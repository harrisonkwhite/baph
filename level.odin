package sanctus

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "zf4"

HITMASK_LIMIT :: 64

Level :: struct {
	player:   Player,
	enemies:  Enemies,
	hitmasks: Hitmasks,
	cam:      Camera,
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

/*Level_Render_Event :: proc(
	level: ^Level,
	rendering_context: ^zf4.Rendering_Context,
	textures: ^zf4.Textures,
)*/

Hitmasks :: struct {
	active_cnt: int,
	colliders:  [HITMASK_LIMIT]zf4.Poly,
	dmg_infos:  [HITMASK_LIMIT]Damage_Info,
}

Damage_Info :: struct {
	dmg: int,
	kb:  zf4.Vec_2D,
}

init_level :: proc(level: ^Level) -> bool {
	assert(level != nil)
	mem.zero_item(level)

	spawn_player({}, level)

	if !spawn_enemy({}, level) {
		return false
	}

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

	update_enemies(&level.enemies)

	{
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
					damage_enemy(enemy, level.hitmasks.dmg_infos[i])
				}
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

