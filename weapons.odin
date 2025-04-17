package baph

import "core:math"
import "zf4"

ATTACK_MB_CODE :: zf4.Mouse_Button_Code.Left

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

update_player_weapon :: proc(game: ^Game, zf4_data: ^zf4.Game_Tick_Func_Data) -> bool {
	assert(!game.player.killed)

	weapon := &game.player.weapon

	attack_input_down := zf4.is_mouse_button_down(ATTACK_MB_CODE, zf4_data.input_state)
	attack_input_pressed := zf4.is_mouse_button_pressed(
		ATTACK_MB_CODE,
		zf4_data.input_state,
		zf4_data.input_state_last,
	)
	attack_input_released := zf4.is_mouse_button_released(
		ATTACK_MB_CODE,
		zf4_data.input_state,
		zf4_data.input_state_last,
	)

	mouse_cam_pos := display_to_camera_pos(
		zf4_data.input_state.mouse_pos,
		&game.cam,
		zf4_data.window_state_cache.size,
	)
	mouse_dir_vec := zf4.calc_normal_or_zero(mouse_cam_pos - game.player.pos)
	weapon.aim_dir = zf4.calc_dir(mouse_dir_vec)

	if weapon.attack_break > 0 {
		weapon.attack_break -= 1
	} else {
		switch weapon.type {
		case Weapon_Type.Pistol:
			if attack_input_pressed {
				spawn_projectile(
					game.player.pos,
					12.0,
					weapon.aim_dir,
					1,
					{Damage_Flag.Damage_Enemy},
					game,
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
					game.player.pos + (mouse_dir_vec * SWORD_HITBOX_OFFS_DIST),
					{SWORD_HITBOX_SIZE, SWORD_HITBOX_SIZE},
					dmg_info,
					{Damage_Flag.Damage_Enemy},
					game,
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
	tasks: ^[dynamic]Render_Task,
	weapon: ^Weapon,
	pos: zf4.Vec_2D,
	sort_depth: f32,
) -> bool {
	task: Render_Task

	switch weapon.type {
	case .Pistol:
		if !append_render_task(
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

		if !append_render_task(
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

calc_weapon_move_spd_mult :: proc(weapon: ^Weapon) -> f32 {
	mult: f32 = 1.0

	charge_scale := f32(weapon.charge_time) / SWORD_CHARGE_TIME
	mult -= SWORD_CHARGE_MOVE_SPD_SLOWDOWN * charge_scale

	return mult
}

