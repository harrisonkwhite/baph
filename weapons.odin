package apocalypse

import "core:math"
import "zf4"

WEAPON_DROP_LIMIT :: 8

SWORD_DMG :: 10
SWORD_KNOCKBACK: f32 : 6.0
SWORD_HITBOX_SIZE :: 32.0
SWORD_HITBOX_OFFS_DIST: f32 : 40.0
SWORD_OFFS_DIST: f32 : 8.0
SWORD_ROT_OFFS: f32 : 125.0 * math.RAD_PER_DEG
SWORD_ROT_OFFS_LERP: f32 : 0.4
SWORD_CHARGE_TIME :: 30
SWORD_CHARGE_MOVE_SPD_SLOWDOWN :: 0.4
SWORD_CHARGE_ROT_TIME_MULT :: 0.4 // The percentage point in the time-up at which charge rotation starts.
SWORD_CHARGE_ROT_OFFS :: 25.0 * math.RAD_PER_DEG
SWORD_CHARGE_DMG_INCREASE :: 5
SWORD_CHARGE_KNOCKBACK_SCALE :: 1.5

Weapon :: struct {
	type:                   Weapon_Type,
	aim_dir:                f32,
	rot_offs:               f32,
	rot_offs_axis_positive: bool,
	attack_break:           int,
	charge_time:            int,
}

Weapon_Type :: enum {
	Pistol,
	Pickaxe,
}

Weapon_Drop :: struct {
	type: Weapon_Type,
	pos:  zf4.Vec_2D,
	rot:  f32,
}

Weapon_Drops :: struct {
	buf:     [WEAPON_DROP_LIMIT]Weapon_Drop,
	actives: bit_set[0 ..< WEAPON_DROP_LIMIT],
}

get_weapon_name :: proc(type: Weapon_Type) -> string {
	switch type {
	case .Pistol:
		return "Pistol"
	case .Pickaxe:
		return "Pickaxe"
	}

	return ""
}

get_weapon_sprite :: proc(type: Weapon_Type) -> Sprite {
	switch type {
	case .Pistol:
		return Sprite.Pistol
	case .Pickaxe:
		return Sprite.Pickaxe
	}

	return nil
}

run_weapon_tick :: proc(
	world: ^World,
	game_config: ^Game_Config,
	zf4_data: ^zf4.Game_Tick_Func_Data,
) -> bool {
	assert(world.player.active)

	weapon := &world.player.weapon

	attack_input_down := is_input_down(
		&game_config.input_binding_settings[Input_Binding.Attack],
		zf4_data.input_state,
	)

	attack_input_pressed := is_input_pressed(
		&game_config.input_binding_settings[Input_Binding.Attack],
		zf4_data.input_state,
		zf4_data.input_state_last,
	)

	attack_input_released := is_input_released(
		&game_config.input_binding_settings[Input_Binding.Attack],
		zf4_data.input_state,
		zf4_data.input_state_last,
	)

	mouse_cam_pos := display_to_camera_pos(
		zf4_data.input_state.mouse_pos,
		&world.cam,
		zf4_data.window_state_cache.size,
	)
	mouse_dir_vec := zf4.calc_normal_or_zero(mouse_cam_pos - world.player.pos)
	weapon.aim_dir = zf4.calc_dir(mouse_dir_vec)

	if weapon.attack_break > 0 {
		weapon.attack_break -= 1
	} else {
		switch weapon.type {
		case Weapon_Type.Pistol:
			if attack_input_pressed {
				spawn_projectile(
					world.player.pos,
					12.0,
					weapon.aim_dir,
					1,
					{Damage_Flag.Damage_Enemy},
					world,
				)
			}
		case Weapon_Type.Pickaxe:
			if attack_input_down {
				if weapon.charge_time < SWORD_CHARGE_TIME {
					weapon.charge_time += 1
				}
			} else if attack_input_released {
				dmg_info := Damage_Info {
					dmg = SWORD_DMG,
					kb  = mouse_dir_vec * SWORD_KNOCKBACK,
				}

				charge_scalar := f32(weapon.charge_time) / SWORD_CHARGE_TIME

				dmg_info.dmg += int(SWORD_CHARGE_DMG_INCREASE * charge_scalar)
				dmg_info.kb *= ((f32(SWORD_CHARGE_KNOCKBACK_SCALE) - 1.0) * charge_scalar) + 1.0

				if !spawn_hitmask_quad(
					world.player.pos + (mouse_dir_vec * SWORD_HITBOX_OFFS_DIST),
					{SWORD_HITBOX_SIZE, SWORD_HITBOX_SIZE},
					dmg_info,
					{Damage_Flag.Damage_Enemy},
					world,
				) {
					return false
				}

				weapon.charge_time = 0
				weapon.rot_offs_axis_positive = !weapon.rot_offs_axis_positive
			}
		}
	}

	rot_offs_dest: f32 = 0.0

	if weapon.type == Weapon_Type.Pickaxe {
		// TEMP
		rot_offs_dest = weapon.rot_offs_axis_positive ? SWORD_ROT_OFFS : -SWORD_ROT_OFFS
	}

	weapon.rot_offs += (rot_offs_dest - weapon.rot_offs) * SWORD_ROT_OFFS_LERP

	return true
}

append_weapon_render_task :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	weapon: ^Weapon,
	pos: zf4.Vec_2D,
	sort_depth: f32,
) -> bool {
	task: World_Layered_Render_Task

	switch weapon.type {
	case .Pistol:
		if !append_world_render_task(
			tasks,
			pos,
			Sprite.Pistol,
			sort_depth,
			origin = {0.0, 0.5},
			rot = weapon.aim_dir,
		) {
			return false
		}

	case .Pickaxe:
		rot_offs_charge_time := max(
			f32(weapon.charge_time) - (SWORD_CHARGE_TIME * SWORD_CHARGE_ROT_TIME_MULT),
			0.0,
		)
		rot_offs_charge_time_max := f32(SWORD_CHARGE_TIME * (1.0 - SWORD_CHARGE_ROT_TIME_MULT))
		rot_offs_charge_offs :=
			SWORD_CHARGE_ROT_OFFS * (rot_offs_charge_time / rot_offs_charge_time_max)

		sword_rot :=
			weapon.aim_dir + weapon.rot_offs + (rot_offs_charge_offs * math.sign(weapon.rot_offs))

		if !append_world_render_task(
			tasks,
			pos + zf4.calc_len_dir(SWORD_OFFS_DIST, sword_rot),
			Sprite.Pickaxe,
			sort_depth,
			origin = {0.0, 0.5},
			rot = sword_rot,
		) {
			return false
		}
	}

	return true
}

spawn_weapon_drop :: proc(
	type: Weapon_Type,
	pos: zf4.Vec_2D,
	weapon_drops: ^Weapon_Drops,
) -> bool {
	for i in 0 ..< WEAPON_DROP_LIMIT {
		if i in weapon_drops.actives {
			continue
		}

		weapon_drops.buf[i] = {
			type = type,
			pos  = pos,
		}

		weapon_drops.actives += {i}

		return true
	}

	return false
}

get_selected_weapon_drop :: proc(
	weapon_drops: ^Weapon_Drops,
	player_pos: zf4.Vec_2D,
) -> (
	int,
	bool,
) {
	player_collider := gen_player_movement_collider(player_pos)

	wd_selected_index := -1

	for i in 0 ..< WEAPON_DROP_LIMIT {
		wd := &weapon_drops.buf[i]

		if i not_in weapon_drops.actives {
			continue
		}

		wd_sprite := get_weapon_sprite(wd.type)
		wd_collider, wd_collider_generated := gen_collider_poly_from_sprite(
			wd_sprite,
			wd.pos,
			rot = wd.rot,
			allocator = context.temp_allocator,
		)

		if !wd_collider_generated {
			return wd_selected_index, false
		}

		if zf4.does_poly_inters_with_rect(wd_collider, player_collider) {
			wd_selected_index = i
		}
	}

	return wd_selected_index, true
}

render_weapon_drops :: proc(
	weapon_drops: ^Weapon_Drops,
	rendering_context: ^zf4.Rendering_Context,
	textures: ^zf4.Textures,
) {
	sprite_src_rects := SPRITE_SRC_RECTS

	for i in 0 ..< WEAPON_DROP_LIMIT {
		if i not_in weapon_drops.actives {
			continue
		}

		wd := &weapon_drops.buf[i]
		sprite := get_weapon_sprite(wd.type)

		zf4.render_texture(
			rendering_context,
			int(Texture.All),
			textures,
			sprite_src_rects[sprite],
			wd.pos,
		)
	}
}

calc_weapon_move_spd_mult :: proc(weapon: ^Weapon) -> f32 {
	mult: f32 = 1.0

	charge_scale := f32(weapon.charge_time) / SWORD_CHARGE_TIME
	mult -= SWORD_CHARGE_MOVE_SPD_SLOWDOWN * charge_scale

	return mult
}

