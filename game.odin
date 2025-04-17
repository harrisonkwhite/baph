package baph

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "zf4"

GAME_TITLE :: "Behold a Pale Horse"

PROJECTILE_LIMIT :: 512

BREAKABLE_LIMIT :: 64

HITMASK_LIMIT :: 64

DAMAGE_TEXT_LIMIT :: 64
DAMAGE_TEXT_FONT :: Font.EB_Garamond_40
DAMAGE_TEXT_SLOWDOWN_MULT :: 0.9
DAMAGE_TEXT_VEL_Y_MIN_FOR_FADE :: 0.2
DAMAGE_TEXT_FADE_MULT :: 0.8

Game :: struct {
	paused:             bool,
	player:             Player,
	enemies:            [ENEMY_LIMIT]Enemy,
	enemy_cnt:          int,
	enemy_spawn_time:   int,
	projectiles:        [PROJECTILE_LIMIT]Projectile,
	proj_cnt:           int,
	hitmasks:           [HITMASK_LIMIT]Hitmask,
	hitmask_active_cnt: int,
	buildings:          []Building,
	dmg_texts:          [DAMAGE_TEXT_LIMIT]Damage_Text,
	cam:                Camera,
	cursor_render_pos:  zf4.Vec_2D,
}

Texture :: enum {
	All,
}

Font :: enum {
	EB_Garamond_32,
	EB_Garamond_40,
	EB_Garamond_48,
	EB_Garamond_64,
	EB_Garamond_96,
	EB_Garamond_128,
}

Shader_Prog :: enum {
	Blend,
}

Sprite :: enum {
	Player,
	Melee_Enemy,
	Ranger_Enemy,
	Pistol,
	Pickaxe,
	Projectile,
	Crate,
	Wall,
	Door_Border_Left,
	Door_Border_Right,
	Door_Closed,
	Door_Open,
	Left_Ceiling_Beam,
	Right_Ceiling_Beam,
	Ceiling,
	Cursor,
}

SPRITE_SRC_RECTS :: [len(Sprite)]zf4.Rect_I {
	Sprite.Player             = {8, 0, 24, 40},
	Sprite.Melee_Enemy        = {0, 40, 24, 40},
	Sprite.Ranger_Enemy       = {24, 40, 24, 32},
	Sprite.Pistol             = {40, 0, 24, 8},
	Sprite.Pickaxe            = {64, 0, 32, 8},
	Sprite.Projectile         = {64, 10, 16, 4},
	Sprite.Crate              = {48, 32, 24, 24},
	Sprite.Wall               = {72, 40, 16, 48},
	Sprite.Door_Border_Left   = {88, 40, 16, 48},
	Sprite.Door_Border_Right  = {104, 40, 16, 48},
	Sprite.Door_Closed        = {72, 88, 32, 48},
	Sprite.Door_Open          = {104, 88, 32, 48},
	Sprite.Left_Ceiling_Beam  = {120, 24, 16, 16},
	Sprite.Right_Ceiling_Beam = {136, 24, 16, 16},
	Sprite.Ceiling            = {120, 40, 16, 16},
	Sprite.Cursor             = {0, 8, 8, 8},
}

Projectile :: struct {
	pos:       zf4.Vec_2D,
	vel:       zf4.Vec_2D,
	rot:       f32,
	dmg:       int,
	dmg_flags: Damage_Flag_Set,
}

Hitmask :: struct {
	collider: zf4.Poly,
	dmg_info: Damage_Info,
	flags:    Damage_Flag_Set,
}

Damage_Flag :: enum {
	Damage_Player,
	Damage_Enemy,
}

Damage_Flag_Set :: bit_set[Damage_Flag]

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

Render_Task :: struct {
	pos:        zf4.Vec_2D,
	origin:     zf4.Vec_2D,
	scale:      zf4.Vec_2D,
	rot:        f32,
	alpha:      f32,
	sprite:     Sprite,
	flash_time: int,
	sort_depth: f32,
}

main :: proc() {
	game_info := zf4.Game_Info {
		perm_mem_arena_size                  = mem.Megabyte * 80,
		user_mem_size                        = size_of(Game),
		user_mem_alignment                   = align_of(Game),
		window_init_size                     = {1280, 720},
		window_min_size                      = {1280, 720},
		window_title                         = GAME_TITLE,
		window_flags                         = {
			zf4.Window_Flag.Resizable,
			zf4.Window_Flag.Hide_Cursor,
		},
		tex_cnt                              = len(Texture),
		tex_index_to_file_path_func          = texture_index_to_file_path,
		font_cnt                             = len(Font),
		font_index_to_load_info_func         = font_index_to_load_info,
		shader_prog_cnt                      = len(Shader_Prog),
		shader_prog_index_to_file_paths_func = shader_prog_index_to_file_paths,
		init_func                            = init_game,
		tick_func                            = game_tick,
		render_func                          = render_game,
	}

	zf4.run_game(&game_info)
}

init_game :: proc(zf4_data: ^zf4.Game_Init_Func_Data) -> bool {
	game := (^Game)(zf4_data.user_mem)

	game.player = {
		hp = PLAYER_HP_LIMIT,
	}

	game.buildings = gen_buildings_in_grid({2, 2}, {20, 20}, {10, 8}, {10, 8})

	if game.buildings == nil {
		return false
	}

	return true
}

game_tick :: proc(zf4_data: ^zf4.Game_Tick_Func_Data) -> bool {
	enemy_type_infos := ENEMY_TYPE_INFOS

	game := (^Game)(zf4_data.user_mem)

	game.cursor_render_pos = zf4_data.input_state.mouse_pos

	if zf4.is_key_pressed(zf4.Key_Code.Escape, zf4_data.input_state, zf4_data.input_state_last) {
		game.paused = !game.paused
	}

	if game.paused {
		return true
	}

	game.hitmask_active_cnt = 0

	// ### Generate solid colliders. ###
	solid_colliders, solid_colliders_generated := gen_solid_colliders(game, context.temp_allocator)

	if !solid_colliders_generated {
		return false
	}
	// ######

	proc_enemy_spawning(game, solid_colliders)

	if !game.player.killed {
		if game.player.inv_time > 0 {
			game.player.inv_time -= 1
		}

		if game.player.flash_time > 0 {
			game.player.flash_time -= 1
		}

		proc_player_movement(&game.player, zf4_data.input_state, solid_colliders)
		update_player_weapon(game, zf4_data)
	}

	if !proc_enemy_ais(game, solid_colliders) {
		return false
	}

	// Player and enemy translations should be completed by this point. Only velocity should be changed.
	when ODIN_DEBUG {
		player_pos_cache := game.player.pos
	}

	update_projectiles(game, solid_colliders)

	proc_hitmask_collisions(game)

	// Hitmasks should never be added after this point.
	when ODIN_DEBUG {
		game.hitmask_active_cnt = 0
	}

	if !game.player.killed {
		proc_player_death(&game.player, &game.cam)
		proc_player_door_interaction(game, zf4_data)
	}

	proc_enemy_deaths(game)

	update_building_ceilings(game)

	update_camera(game, zf4_data)

	// ### Update damage text. ###
	for &dt in game.dmg_texts {
		// TODO: Unnecessary amount of work being done here for invisible damage text.

		dt.pos.y += dt.vel_y
		dt.vel_y *= DAMAGE_TEXT_SLOWDOWN_MULT

		if abs(dt.vel_y) <= DAMAGE_TEXT_VEL_Y_MIN_FOR_FADE {
			dt.alpha *= 0.8
		}
	}
	// ######

	when ODIN_DEBUG {
		assert(game.player.pos == player_pos_cache)
		// TODO: Also make sure enemy positions haven't been changed.

		assert(game.hitmask_active_cnt == 0)
	}

	return true
}

render_game :: proc(zf4_data: ^zf4.Game_Render_Func_Data) -> bool {
	game := (^Game)(zf4_data.user_mem)

	zf4.render_clear({0.2, 0.3, 0.4, 1.0})

	zf4_data.rendering_context.state.view_mat = gen_camera_view_matrix_4x4(
		&game.cam,
		zf4_data.rendering_context.display_size,
	)

	render_tasks: [dynamic]Render_Task
	render_tasks.allocator = context.temp_allocator

	if !game.player.killed && !append_player_render_tasks(&render_tasks, &game.player) {
		return false
	}

	if !append_enemy_render_tasks(&render_tasks, game.enemies[:game.enemy_cnt]) {
		return false
	}

	if !append_projectile_render_tasks(&render_tasks, game.projectiles[:game.proj_cnt]) {
		return false
	}

	for &building in game.buildings {
		if !append_building_render_tasks(&render_tasks, &building) {
			return false
		}
	}

	// IDEA: Add optional rendering of colliders, for debugging purposes.

	slice.sort_by(render_tasks[:], proc(task_a: Render_Task, task_b: Render_Task) -> bool {
		return task_a.sort_depth < task_b.sort_depth
	})

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

	for i in 0 ..< game.hitmask_active_cnt {
		zf4.render_poly_outline(&zf4_data.rendering_context, game.hitmasks[i].collider, zf4.RED)
	}

	zf4.flush(&zf4_data.rendering_context)

	//
	// UI
	//
	// TODO: There should be an assert tripped if we change view matrix without flushing beforehand.
	zf4_data.rendering_context.state.view_mat = zf4.gen_iden_matrix_4x4()

	render_enemy_hp_bars(
		&zf4_data.rendering_context,
		game.enemies[:game.enemy_cnt],
		&game.cam,
		zf4_data.textures,
	)

	// Render damage text.
	for dt in game.dmg_texts {
		dt_str_buf: [16]u8
		dt_str := fmt.bprintf(dt_str_buf[:], "%d", -dt.dmg)

		zf4.render_str(
			&zf4_data.rendering_context,
			dt_str,
			int(DAMAGE_TEXT_FONT),
			zf4_data.fonts,
			camera_to_display_pos(dt.pos, &game.cam, zf4_data.rendering_context.display_size),
			blend = {1.0, 1.0, 1.0, dt.alpha},
		)
	}

	// Render player health bar.
	player_hp_bar_height: f32 = 20.0
	player_hp_bar_rect := zf4.Rect {
		f32(zf4_data.rendering_context.display_size.x) * 0.05,
		(f32(zf4_data.rendering_context.display_size.y) * 0.9) - (player_hp_bar_height / 2.0),
		f32(zf4_data.rendering_context.display_size.x) * 0.2,
		player_hp_bar_height,
	}
	zf4.render_bar_hor(
		&zf4_data.rendering_context,
		player_hp_bar_rect,
		f32(game.player.hp) / PLAYER_HP_LIMIT,
		zf4.WHITE.rgb,
		zf4.BLACK.rgb,
	)

	player_hp_str_buf: [16]byte
	player_hp_str := fmt.bprintf(player_hp_str_buf[:], "%d/%d", game.player.hp, PLAYER_HP_LIMIT)
	zf4.render_str(
		&zf4_data.rendering_context,
		player_hp_str,
		int(Font.EB_Garamond_40),
		zf4_data.fonts,
		zf4.calc_rect_center_right(player_hp_bar_rect) + {12.0, 0.0},
		zf4.Str_Hor_Align.Left,
	)

	zf4.render_texture(
		&zf4_data.rendering_context,
		int(Texture.All),
		zf4_data.textures,
		SPRITE_SRC_RECTS[Sprite.Cursor],
		game.cursor_render_pos,
	)

	zf4.flush(&zf4_data.rendering_context)

	return true
}

texture_index_to_file_path :: proc(index: int) -> string {
	switch Texture(index) {
	case Texture.All:
		return "assets/textures/all.png"

	case:
		return ""
	}
}

font_index_to_load_info :: proc(index: int) -> zf4.Font_Load_Info {
	switch Font(index) {
	case Font.EB_Garamond_32:
		return {"assets/fonts/eb_garamond.ttf", 32}
	case Font.EB_Garamond_40:
		return {"assets/fonts/eb_garamond.ttf", 40}
	case Font.EB_Garamond_48:
		return {"assets/fonts/eb_garamond.ttf", 48}
	case Font.EB_Garamond_64:
		return {"assets/fonts/eb_garamond.ttf", 64}
	case Font.EB_Garamond_96:
		return {"assets/fonts/eb_garamond.ttf", 96}
	case Font.EB_Garamond_128:
		return {"assets/fonts/eb_garamond.ttf", 128}

	case:
		return {}
	}
}

shader_prog_index_to_file_paths :: proc(index: int) -> (string, string) {
	switch Shader_Prog(index) {
	case Shader_Prog.Blend:
		return "assets/shaders/blend.vert", "assets/shaders/blend.frag"

	case:
		return "", ""
	}
}

gen_solid_colliders :: proc(game: ^Game, allocator := context.allocator) -> ([]zf4.Rect, bool) {
	colliders: [dynamic]zf4.Rect
	colliders.allocator = allocator

	for &building in game.buildings {
		if !append_building_solid_colliders(&colliders, &building) {
			return colliders[:], false
		}
	}

	return colliders[:], true
}

append_render_task :: proc(
	tasks: ^[dynamic]Render_Task,
	pos: zf4.Vec_2D,
	sprite: Sprite,
	sort_depth: f32,
	origin := zf4.Vec_2D{0.5, 0.5},
	scale := zf4.Vec_2D{1.0, 1.0},
	rot: f32 = 0.0,
	alpha: f32 = 1.0,
	flash_time := 0,
) -> bool {
	assert(alpha >= 0.0 && alpha <= 1.0)
	assert(flash_time >= 0)

	task := Render_Task {
		pos        = pos,
		origin     = origin,
		scale      = scale,
		rot        = rot,
		alpha      = alpha,
		sprite     = sprite,
		flash_time = flash_time,
		sort_depth = sort_depth,
	}

	if _, err := append(tasks, task); err != nil {
		return false
	}

	return true
}

proc_solid_collisions :: proc(vel: ^zf4.Vec_2D, collider: zf4.Rect, other_colliders: []zf4.Rect) {
	collider_hor := zf4.Rect{collider.x + vel.x, collider.y, collider.width, collider.height}

	for oc in other_colliders {
		if zf4.do_rects_inters(collider_hor, oc) {
			vel.x = 0.0
			break
		}
	}

	collider_ver := zf4.Rect{collider.x, collider.y + vel.y, collider.width, collider.height}

	for oc in other_colliders {
		if zf4.do_rects_inters(collider_ver, oc) {
			vel.y = 0.0
			break
		}
	}

	if vel.x != 0.0 && vel.y != 0.0 {
		collider_diag := zf4.Rect {
			collider.x + vel.x,
			collider.y + vel.y,
			collider.width,
			collider.height,
		}

		for oc in other_colliders {
			if zf4.do_rects_inters(collider_diag, oc) {
				vel.x = 0.0
				break
			}
		}
	}
}

gen_collider_rect_from_sprite :: proc(
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

gen_collider_poly_from_sprite :: proc(
	sprite: Sprite,
	pos: zf4.Vec_2D,
	origin := zf4.Vec_2D{0.5, 0.5},
	rot: f32 = 0.0,
	allocator := context.allocator,
) -> (
	zf4.Poly,
	bool,
) {
	src_rects := SPRITE_SRC_RECTS
	return zf4.alloc_quad_poly_rotated(
		pos,
		{f32(src_rects[sprite].width), f32(src_rects[sprite].height)},
		origin,
		rot,
		allocator,
	)
}

spawn_projectile :: proc(
	pos: zf4.Vec_2D,
	spd: f32,
	dir: f32,
	dmg: int,
	dmg_flags: Damage_Flag_Set,
	game: ^Game,
) -> bool {
	assert(game != nil)

	if game.proj_cnt == PROJECTILE_LIMIT {
		fmt.print("Failed to spawn projectile due to insufficient space!")
		return false
	}

	proj := &game.projectiles[game.proj_cnt]
	game.proj_cnt += 1
	proj^ = {
		pos       = pos,
		vel       = zf4.calc_len_dir(spd, dir),
		rot       = dir,
		dmg       = dmg,
		dmg_flags = dmg_flags,
	}
	return true
}

update_projectiles :: proc(game: ^Game, solid_colliders: []zf4.Rect) -> bool {
	// TODO: Set up some nice system in which projectile colliders (and colliders for other things too) only need to be set up once.
	for i := 0; i < game.proj_cnt; i += 1 {
		proj := &game.projectiles[i]
		proj.pos += proj.vel

		proj_collider, proj_collider_allocated := alloc_projectile_collider(
			proj,
			context.temp_allocator,
		)

		if !proj_collider_allocated {
			return false
		}

		dmg_info := Damage_Info {
			dmg = proj.dmg,
			kb  = proj.vel / 2.0,
		}

		collided := false

		// Handle solid collisions.
		for solid_collider in solid_colliders {
			if zf4.does_poly_inters_with_rect(proj_collider, solid_collider) {
				collided = true
				break
			}
		}

		if !collided {
			// Handle player collision.
			if Damage_Flag.Damage_Player in proj.dmg_flags {
				player_dmg_collider := gen_player_damage_collider(game.player.pos)

				if zf4.does_poly_inters_with_rect(proj_collider, player_dmg_collider) {
					damage_player(game, dmg_info)
					collided = true
				}
			}

			// Handle enemy collisions.
			if Damage_Flag.Damage_Enemy in proj.dmg_flags {
				for j in 0 ..< game.enemy_cnt {
					enemy := &game.enemies[j]
					enemy_dmg_collider := gen_enemy_damage_collider(enemy.type, enemy.pos)

					if zf4.does_poly_inters_with_rect(proj_collider, enemy_dmg_collider) {
						damage_enemy(j, game, dmg_info)
						collided = true
						break
					}
				}
			}
		}

		// Destroy the projectile.
		if collided {
			game.proj_cnt -= 1
			game.projectiles[i] = game.projectiles[game.proj_cnt]
			i -= 1
		}
	}

	return true
}

alloc_projectile_collider :: proc(
	proj: ^Projectile,
	allocator := context.allocator,
) -> (
	zf4.Poly,
	bool,
) {
	sprite_src_rects := SPRITE_SRC_RECTS
	sprite_src_rect := sprite_src_rects[Sprite.Projectile]

	return zf4.alloc_quad_poly_rotated(
		proj.pos,
		{f32(sprite_src_rect.width), f32(sprite_src_rect.height)},
		{0.5, 0.5},
		proj.rot,
		allocator,
	)
}

append_projectile_render_tasks :: proc(
	tasks: ^[dynamic]Render_Task,
	projectiles: []Projectile,
) -> bool {
	sprite_src_rects := SPRITE_SRC_RECTS

	for &proj in projectiles {
		sprite := Sprite.Projectile

		task := Render_Task {
			pos        = proj.pos,
			origin     = {0.5, 0.5},
			scale      = {1.0, 1.0},
			rot        = proj.rot,
			alpha      = 1.0,
			sprite     = sprite,
			sort_depth = proj.pos.y,
		}

		n, err := append(tasks, task)

		if err != nil {
			return false
		}
	}

	return true
}

spawn_hitmask_quad :: proc(
	pos: zf4.Vec_2D,
	size: zf4.Vec_2D,
	dmg_info: Damage_Info,
	flags: Damage_Flag_Set,
	game: ^Game,
	allocator := context.allocator,
) -> bool {
	assert(size.x > 0.0 && size.y > 0.0)
	assert(game.hitmask_active_cnt >= 0 && game.hitmask_active_cnt <= HITMASK_LIMIT)
	assert(flags != {})

	if (game.hitmask_active_cnt == HITMASK_LIMIT) {
		return false
	}

	hm := &game.hitmasks[game.hitmask_active_cnt]

	collider_allocated: bool
	hm.collider, collider_allocated = zf4.alloc_quad_poly(pos, size, {0.5, 0.5}, allocator)

	if !collider_allocated {
		return false
	}

	hm.dmg_info = dmg_info
	hm.flags = flags
	game.hitmask_active_cnt += 1

	return true
}

proc_hitmask_collisions :: proc(game: ^Game) {
	for i in 0 ..< game.hitmask_active_cnt {
		hm := &game.hitmasks[i]

		if Damage_Flag.Damage_Player in hm.flags {
			if zf4.does_poly_inters_with_rect(
				hm.collider,
				gen_player_damage_collider(game.player.pos),
			) {
				damage_player(game, hm.dmg_info)
			}
		}

		if Damage_Flag.Damage_Enemy in hm.flags {
			for j in 0 ..< game.enemy_cnt {
				enemy := &game.enemies[j]

				enemy_dmg_collider := gen_enemy_damage_collider(enemy.type, enemy.pos)

				// NOTE: Could cache the collider polygons.
				if zf4.does_poly_inters_with_rect(hm.collider, enemy_dmg_collider) {
					damage_enemy(j, game, hm.dmg_info)
				}
			}
		}
	}
}

spawn_damage_text :: proc(
	game: ^Game,
	dmg: int,
	pos: zf4.Vec_2D,
	vel_y_range: [2]f32 = {-6.0, -4.0},
) -> bool {
	assert(game != nil)
	assert(dmg > 0)
	assert(vel_y_range[0] <= vel_y_range[1])
	assert(vel_y_range[0] <= 0.0 && vel_y_range[1] <= 0.0)

	for &dt in game.dmg_texts {
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

