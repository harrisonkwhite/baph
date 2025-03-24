package sanctus

import "core:math"
import "zf4"

PLAYER_MOVE_SPD :: 3.0
PLAYER_VEL_LERP_FACTOR :: 0.2
PLAYER_RENDER_TASK_CNT :: 2
PLAYER_SWORD_DMG :: 10
PLAYER_SWORD_KNOCKBACK: f32 : 6.0
PLAYER_SWORD_HITBOX_SIZE :: 32
PLAYER_SWORD_HITBOX_OFFS_DIST: f32 : 40.0
PLAYER_SWORD_ROT_OFFS: f32 : 130.0 * math.RAD_PER_DEG
PLAYER_SWORD_ROT_OFFS_LERP: f32 : 0.4

Player :: struct {
	pos:                          zf4.Vec_2D,
	vel:                          zf4.Vec_2D,
	sword_rot_base:               f32,
	sword_rot_offs:               f32,
	sword_rot_offs_axis_positive: bool,
}

update_player :: proc(
	level: ^Level,
	game_config: ^Game_Config,
	zf4_data: ^zf4.Game_Tick_Func_Data,
) -> bool {
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

	return true
}

append_player_level_render_tasks :: proc(
	tasks: ^[dynamic]Level_Layered_Render_Task,
	player: ^Player,
) -> bool {
	character_task := Level_Layered_Render_Task {
		pos        = player.pos,
		origin     = {0.5, 0.5},
		scale      = {1.0, 1.0},
		rot        = 0.0,
		alpha      = 1.0,
		sprite     = Sprite.Player,
		sort_depth = player.pos.y,
	}

	if n, err := append(tasks, character_task); err != nil {
		return false
	}

	sword_task := Level_Layered_Render_Task {
		pos        = player.pos,
		origin     = {0.0, 0.5},
		scale      = {1.0, 1.0},
		rot        = player.sword_rot_base + player.sword_rot_offs,
		alpha      = 1.0,
		sprite     = Sprite.Sword,
		sort_depth = player.pos.y + 1.0,
	}

	if n, err := append(tasks, sword_task); err != nil {
		return false
	}

	return true
}

/*player_level_render_event :: proc(
	level: ^Level,
	rendering_context: ^zf4.Rendering_Context,
	textures: ^zf4.Textures,
) {
	// Render the character.
	zf4.render_texture(
		rendering_context,
		int(Texture.All),
		textures,
		SPRITE_SRC_RECTS[int(Sprite.Player)],
		level.player.pos,
	)

	// Render the sword.
	zf4.render_texture(
		rendering_context,
		int(Texture.All),
		textures,
		SPRITE_SRC_RECTS[int(Sprite.Sword)],
		level.player.pos,
		level.player.sword_rot,
	)
}*/

gen_player_damage_collider :: proc(player_pos: zf4.Vec_2D) -> zf4.Rect {
	return gen_collider_from_sprite(Sprite.Player, player_pos)
}

