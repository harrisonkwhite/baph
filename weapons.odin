package apocalypse

import "core:math"
import "zf4"

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
	Sword,
	Bow,
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
		case Weapon_Type.Sword:
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

		case Weapon_Type.Bow:
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
		}
	}

	rot_offs_dest: f32 = 0.0

	if weapon.type == Weapon_Type.Sword {
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
	case Weapon_Type.Sword:
		rot_offs_charge_time := max(
			f32(weapon.charge_time) - (SWORD_CHARGE_TIME * SWORD_CHARGE_ROT_TIME_MULT),
			0.0,
		)
		rot_offs_charge_time_max := f32(SWORD_CHARGE_TIME * (1.0 - SWORD_CHARGE_ROT_TIME_MULT))
		rot_offs_charge_offs :=
			SWORD_CHARGE_ROT_OFFS * (rot_offs_charge_time / rot_offs_charge_time_max)

		sword_rot :=
			weapon.aim_dir + weapon.rot_offs + (rot_offs_charge_offs * math.sign(weapon.rot_offs))

		task = {
			pos        = pos + zf4.calc_len_dir(SWORD_OFFS_DIST, sword_rot),
			origin     = {0.0, 0.5},
			scale      = {1.0, 1.0},
			rot        = sword_rot,
			alpha      = 1.0,
			sprite     = Sprite.Sword,
			sort_depth = sort_depth,
		}

	case Weapon_Type.Bow:
	}

	if n, err := append(tasks, task); err != nil {
		return false
	}

	return true
}

calc_weapon_move_spd_mult :: proc(weapon: ^Weapon) -> f32 {
	mult: f32 = 1.0

	charge_scale := f32(weapon.charge_time) / SWORD_CHARGE_TIME
	mult -= SWORD_CHARGE_MOVE_SPD_SLOWDOWN * charge_scale

	return mult
}

