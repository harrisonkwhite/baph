package apocalypse

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "zf4"

WORLD_MEM_ARENA_SIZE :: 1 * mem.Megabyte

PROJECTILE_LIMIT :: 512

HITMASK_LIMIT :: 64

DAMAGE_TEXT_LIMIT :: 64
DAMAGE_TEXT_FONT :: Font.EB_Garamond_40
DAMAGE_TEXT_SLOWDOWN_MULT :: 0.9
DAMAGE_TEXT_VEL_Y_MIN_FOR_FADE :: 0.2
DAMAGE_TEXT_FADE_MULT :: 0.8

World :: struct {
	mem_arena:           mem.Arena,
	mem_arena_buf:       []byte,
	mem_arena_allocator: mem.Allocator,
	player:              Player,
	minions:             [MINION_CNT]Minion,
	enemies:             Enemies,
	enemy_spawn_time:    int,
	projectiles:         [PROJECTILE_LIMIT]Projectile,
	proj_cnt:            int,
	hitmasks:            [HITMASK_LIMIT]Hitmask,
	hitmask_active_cnt:  int,
	buildings:           []Building,
	dmg_texts:           [DAMAGE_TEXT_LIMIT]Damage_Text,
	cam:                 Camera,
}

World_Layered_Render_Task :: struct {
	pos:        zf4.Vec_2D,
	origin:     zf4.Vec_2D,
	scale:      zf4.Vec_2D,
	rot:        f32,
	alpha:      f32,
	sprite:     Sprite,
	flash_time: int,
	sort_depth: f32,
}

World_Tick_Result :: enum {
	Normal,
	Go_To_Title,
	Error,
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

init_world :: proc(world: ^World) -> bool {
	assert(world != nil)
	mem.zero_item(world)

	world.mem_arena_buf = make([]byte, WORLD_MEM_ARENA_SIZE)

	if (world.mem_arena_buf == nil) {
		fmt.eprintln("Failed to allocate memory for the world memory arena!")
		return false
	}

	mem.arena_init(&world.mem_arena, world.mem_arena_buf)

	world.mem_arena_allocator = mem.arena_allocator(&world.mem_arena)

	BUILDING_GRID_SIZE :: zf4.Vec_2D_I{2, 2}
	BUILDING_GRID_CELL_SIZE_IN_TILES :: zf4.Vec_2D_I{20, 20}

	world.buildings = gen_buildings_in_grid(
		BUILDING_GRID_SIZE,
		BUILDING_GRID_CELL_SIZE_IN_TILES,
		{8, 5},
		{12, 9},
		world.mem_arena_allocator,
	)

	if world.buildings == nil {
		return false
	}

	spawn_player(
		{
			f32(BUILDING_GRID_SIZE.x * BUILDING_GRID_CELL_SIZE_IN_TILES.x * BUILDING_TILE_SIZE) *
			0.5,
			f32(BUILDING_GRID_SIZE.y * BUILDING_GRID_CELL_SIZE_IN_TILES.y * BUILDING_TILE_SIZE) *
			0.5,
		},
		world,
	)

	world.cam.pos_no_offs = world.player.pos

	return true
}

world_tick :: proc(
	world: ^World,
	game_config: ^Game_Config,
	zf4_data: ^zf4.Game_Tick_Func_Data,
) -> World_Tick_Result {
	enemy_type_infos := ENEMY_TYPE_INFOS

	mouse_cam_pos := display_to_camera_pos(
		zf4_data.input_state.mouse_pos,
		&world.cam,
		zf4_data.window_state_cache.size,
	)

	world.hitmask_active_cnt = 0

	solid_colliders, solid_colliders_generated := gen_world_solid_colliders(
		world,
		context.temp_allocator,
	)

	if !solid_colliders_generated {
		return World_Tick_Result.Error
	}

	//
	// Enemy Spawning
	//
	proc_enemy_spawning(world, solid_colliders)

	//
	// Player
	//
	if world.player.active {
		if !run_player_tick(world, solid_colliders, game_config, zf4_data) {
			return World_Tick_Result.Error
		}
	}

	update_minions(world, solid_colliders) // TEMP

	update_buildings(world)

	//
	// Enemy AI
	//
	for i in 0 ..< ENEMY_LIMIT {
		if !world.enemies.activity[i] {
			continue
		}

		enemy := &world.enemies.buf[i]

		if !enemy_type_infos[enemy.type].ai_func(i, world, solid_colliders) {
			return World_Tick_Result.Error
		}

		if enemy.flash_time > 0 {
			enemy.flash_time -= 1
		}
	}

	//
	// Player and Enemy Collisions
	//
	for i in 0 ..< ENEMY_LIMIT {
		if !world.enemies.activity[i] {
			continue
		}

		enemy := &world.enemies.buf[i]
		enemy_type_info := enemy_type_infos[enemy.type]

		if Enemy_Type_Flag.Deals_Contact_Damage not_in enemy_type_info.flags {
			continue
		}

		enemy_dmg_collider := gen_enemy_damage_collider(enemy.type, enemy.pos)

		if zf4.do_rects_inters(gen_player_damage_collider(world.player.pos), enemy_dmg_collider) {
			kb_dir := zf4.calc_normal_or_zero(world.player.pos - enemy.pos)

			dmg_info := Damage_Info {
				dmg = enemy_type_info.contact_dmg,
				kb  = kb_dir * enemy_type_info.contact_kb,
			}

			damage_player(world, dmg_info)

			break
		}
	}

	//
	// Projectiles
	//
	// TODO: Set up some nice system in which projectile colliders (and colliders for other things too) only need to be set up once.
	for i in 0 ..< world.proj_cnt {
		proj := &world.projectiles[i]
		proj.pos += proj.vel

		proj_collider, proj_collider_generated := alloc_projectile_collider(
			proj,
			context.temp_allocator,
		)

		if !proj_collider_generated {
			return World_Tick_Result.Error
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
				if world.player.active {
					player_dmg_collider := gen_player_damage_collider(world.player.pos)

					if zf4.does_poly_inters_with_rect(proj_collider, player_dmg_collider) {
						damage_player(world, dmg_info)
						collided = true
					}
				}
			}

			// Handle enemy collisions.
			if Damage_Flag.Damage_Enemy in proj.dmg_flags {
				for j in 0 ..< ENEMY_LIMIT {
					if !world.enemies.activity[j] {
						continue
					}

					enemy := &world.enemies.buf[j]
					enemy_dmg_collider := gen_enemy_damage_collider(enemy.type, enemy.pos)

					if zf4.does_poly_inters_with_rect(proj_collider, enemy_dmg_collider) {
						damage_enemy(j, world, dmg_info)
						collided = true
						break
					}
				}
			}
		}

		// Destroy the projectile.
		if collided {
			world.proj_cnt -= 1
			world.projectiles[i] = world.projectiles[world.proj_cnt]
		}
	}

	//
	// Hitmask Collisions
	//
	for i in 0 ..< world.hitmask_active_cnt {
		hm := &world.hitmasks[i]

		if Damage_Flag.Damage_Player in hm.flags {
			if zf4.does_poly_inters_with_rect(
				hm.collider,
				gen_player_damage_collider(world.player.pos),
			) {
				damage_player(world, hm.dmg_info)
			}
		}

		if Damage_Flag.Damage_Enemy in hm.flags {
			for j in 0 ..< ENEMY_LIMIT {
				if !world.enemies.activity[j] {
					continue
				}

				enemy := &world.enemies.buf[j]

				enemy_dmg_collider := gen_enemy_damage_collider(enemy.type, enemy.pos)

				// NOTE: Could cache the collider polygons.
				if zf4.does_poly_inters_with_rect(hm.collider, enemy_dmg_collider) {
					damage_enemy(j, world, hm.dmg_info)
				}
			}
		}
	}

	//
	// Player Death
	//
	assert(world.player.hp >= 0)

	if world.player.hp == 0 {
		world.player.active = false
	}

	//
	// Enemy Deaths
	//
	for i in 0 ..< ENEMY_LIMIT {
		if !world.enemies.activity[i] {
			continue
		}

		enemy := &world.enemies.buf[i]

		assert(enemy.hp >= 0)

		if enemy.hp == 0 {
			apply_camera_shake(&world.cam, 3.0)
			world.enemies.activity[i] = false
		}
	}

	//
	// Camera
	//
	{
		dest := world.player.pos

		if world.player.active {
			mouse_cam_pos := display_to_camera_pos(
				zf4_data.input_state.mouse_pos,
				&world.cam,
				zf4_data.window_state_cache.size,
			)
			player_to_mouse_cam_pos_dist := zf4.calc_dist(world.player.pos, mouse_cam_pos)
			player_to_mouse_cam_pos_dir := zf4.calc_normal_or_zero(
				mouse_cam_pos - world.player.pos,
			)

			look_dist :=
				CAMERA_LOOK_DIST_LIMIT *
				min(player_to_mouse_cam_pos_dist / CAMERA_LOOK_DIST_SCALAR_DIST, 1.0)

			dest += player_to_mouse_cam_pos_dir * look_dist
		}

		world.cam.pos_no_offs = math.lerp(world.cam.pos_no_offs, dest, f32(CAMERA_POS_LERP_FACTOR))

		world.cam.shake *= CAMERA_SHAKE_MULT
	}

	//
	// Damage Text
	//
	for &dt in world.dmg_texts {
		dt.pos.y += dt.vel_y
		dt.vel_y *= DAMAGE_TEXT_SLOWDOWN_MULT

		if abs(dt.vel_y) <= DAMAGE_TEXT_VEL_Y_MIN_FOR_FADE {
			dt.alpha *= 0.8
		}
	}

	// Handle title screen change request.
	if zf4.is_key_pressed(zf4.Key_Code.Escape, zf4_data.input_state, zf4_data.input_state_last) {
		return World_Tick_Result.Go_To_Title
	}

	return World_Tick_Result.Normal
}

render_world :: proc(world: ^World, zf4_data: ^zf4.Game_Render_Func_Data) -> bool {
	assert(world != nil)
	assert(zf4_data != nil)

	init_camera_view_matrix_4x4(
		&zf4_data.rendering_context.state.view_mat,
		&world.cam,
		zf4_data.rendering_context.display_size,
	)

	render_tasks: [dynamic]World_Layered_Render_Task
	render_tasks.allocator = context.temp_allocator

	if world.player.active {
		if !append_player_render_tasks(&render_tasks, &world.player) {
			return false
		}
	}

	if !append_minion_world_render_tasks(&render_tasks, world.minions[:]) {
		return false
	}

	if !append_enemy_world_render_tasks(&render_tasks, &world.enemies) {
		return false
	}

	if !append_projectile_world_render_tasks(&render_tasks, world.projectiles[:world.proj_cnt]) {
		return false
	}

	for &building in world.buildings {
		if !append_building_render_tasks(&render_tasks, &building) {
			return false
		}
	}

	// IDEA: Add optional rendering of colliders, for debugging purposes.

	slice.sort_by(
		render_tasks[:],
		proc(task_a: World_Layered_Render_Task, task_b: World_Layered_Render_Task) -> bool {
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
			/*zf4.set_surface_shader_prog_uniform(
				&zf4_data.rendering_context,
				"u_intensity",
				min(
					f32(task.flash_time) / (WORLD_LAYERED_RENDER_TASK_FLASH_TIME_LIMIT / 2.0),
					1.0,
				),
			)*/
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

	for i in 0 ..< world.hitmask_active_cnt {
		zf4.render_poly_outline(&zf4_data.rendering_context, world.hitmasks[i].collider, zf4.RED)
	}

	zf4.flush(&zf4_data.rendering_context)

	//
	// UI
	//
	// TODO: There should be an assert tripped if we change view matrix without flushing beforehand.
	zf4.init_iden_matrix_4x4(&zf4_data.rendering_context.state.view_mat)

	render_enemy_hp_bars(
		&zf4_data.rendering_context,
		&world.enemies,
		&world.cam,
		zf4_data.textures,
	)

	for dt in world.dmg_texts {
		dt_str_buf: [16]u8
		dt_str := fmt.bprintf(dt_str_buf[:], "%d", -dt.dmg)

		zf4.render_str(
			&zf4_data.rendering_context,
			dt_str,
			int(DAMAGE_TEXT_FONT),
			zf4_data.fonts,
			camera_to_display_pos(dt.pos, &world.cam, zf4_data.rendering_context.display_size),
			blend = {1.0, 1.0, 1.0, dt.alpha},
		)
	}

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
		f32(world.player.hp) / PLAYER_HP_LIMIT,
		zf4.WHITE.rgb,
		zf4.BLACK.rgb,
	)

	player_hp_str_buf: [16]byte
	player_hp_str := fmt.bprintf(player_hp_str_buf[:], "%d/%d", world.player.hp, PLAYER_HP_LIMIT)
	zf4.render_str(
		&zf4_data.rendering_context,
		player_hp_str,
		int(Font.EB_Garamond_40),
		zf4_data.fonts,
		zf4.calc_rect_center_right(player_hp_bar_rect) + {12.0, 0.0},
		zf4.Str_Hor_Align.Left,
	)

	return true
}

clean_world :: proc(world: ^World) {
	assert(world != nil)
	delete(world.mem_arena_buf)
}

gen_world_solid_colliders :: proc(
	world: ^World,
	allocator := context.allocator,
) -> (
	[]zf4.Rect,
	bool,
) {
	colliders: [dynamic]zf4.Rect
	colliders.allocator = allocator

	for &building in world.buildings {
		if !append_building_solid_colliders(&colliders, &building) {
			return colliders[:], false
		}
	}

	return colliders[:], true
}

append_world_render_task :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
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

	task := World_Layered_Render_Task {
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

spawn_projectile :: proc(
	pos: zf4.Vec_2D,
	spd: f32,
	dir: f32,
	dmg: int,
	dmg_flags: Damage_Flag_Set,
	world: ^World,
) -> bool {
	assert(world != nil)

	if world.proj_cnt == PROJECTILE_LIMIT {
		fmt.print("Failed to spawn projectile due to insufficient space!")
		return false
	}

	proj := &world.projectiles[world.proj_cnt]
	world.proj_cnt += 1
	proj^ = {
		pos       = pos,
		vel       = zf4.calc_len_dir(spd, dir),
		rot       = dir,
		dmg       = dmg,
		dmg_flags = dmg_flags,
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

append_projectile_world_render_tasks :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	projectiles: []Projectile,
) -> bool {
	sprite_src_rects := SPRITE_SRC_RECTS

	for &proj in projectiles {
		sprite := Sprite.Projectile

		task := World_Layered_Render_Task {
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
	world: ^World,
	allocator := context.allocator,
) -> bool {
	assert(size.x > 0.0 && size.y > 0.0)
	assert(world.hitmask_active_cnt >= 0 && world.hitmask_active_cnt <= HITMASK_LIMIT)
	assert(flags != {})

	if (world.hitmask_active_cnt == HITMASK_LIMIT) {
		return false
	}

	hm := &world.hitmasks[world.hitmask_active_cnt]

	collider_allocated: bool
	hm.collider, collider_allocated = zf4.alloc_quad_poly(pos, size, {0.5, 0.5}, allocator)

	if !collider_allocated {
		return false
	}

	hm.dmg_info = dmg_info
	hm.flags = flags
	world.hitmask_active_cnt += 1

	return true
}

spawn_damage_text :: proc(
	world: ^World,
	dmg: int,
	pos: zf4.Vec_2D,
	vel_y_range: [2]f32 = {-6.0, -4.0},
) -> bool {
	assert(world != nil)
	assert(dmg > 0)
	assert(vel_y_range[0] <= vel_y_range[1])
	assert(vel_y_range[0] <= 0.0 && vel_y_range[1] <= 0.0)

	for &dt in world.dmg_texts {
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

