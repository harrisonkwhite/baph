package sanctus

import "core:math"
import "core:mem"
import "zf4"

CAMERA_SCALE :: 2.0

PLAYER_MOVE_SPD :: 3.0
PLAYER_VEL_LERP_FACTOR :: 0.2

CAMERA_POS_LERP_FACTOR :: 0.25
CAMERA_LOOK_DIST_LIMIT :: 24.0
CAMERA_LOOK_DIST_SCALAR_DIST :: CAMERA_LOOK_DIST_LIMIT * 32.0

Level :: struct {
	cam_pos: zf4.Vec_2D,
	player:  Player,
}

Player :: struct {
	pos: zf4.Vec_2D,
	vel: zf4.Vec_2D,
}

calc_camera_size :: proc(window_size: zf4.Size_2D) -> zf4.Vec_2D {
	return {f32(window_size.x) / CAMERA_SCALE, f32(window_size.y) / CAMERA_SCALE}
}

calc_camera_top_left :: proc(cam_pos: zf4.Vec_2D, window_size: zf4.Size_2D) -> zf4.Vec_2D {
	return cam_pos - (calc_camera_size(window_size) / 2.0)
}

camera_to_screen_pos :: proc(
	pos: zf4.Vec_2D,
	cam_pos: zf4.Vec_2D,
	window_size: zf4.Size_2D,
) -> zf4.Vec_2D {
	cam_tl := calc_camera_top_left(cam_pos, window_size)
	return (pos - cam_tl) * CAMERA_SCALE
}

screen_to_camera_pos :: proc(
	pos: zf4.Vec_2D,
	cam_pos: zf4.Vec_2D,
	window_size: zf4.Size_2D,
) -> zf4.Vec_2D {
	cam_tl := calc_camera_top_left(cam_pos, window_size)
	return cam_tl + (pos / CAMERA_SCALE)
}

init_camera_view_matrix_4x4 :: proc(
	mat: ^zf4.Matrix_4x4,
	cam_pos: zf4.Vec_2D,
	window_size: zf4.Size_2D,
) {
	mem.zero(mat, size_of(mat^))
	mat.elems[0][0] = CAMERA_SCALE
	mat.elems[1][1] = CAMERA_SCALE
	mat.elems[3][3] = 1.0
	mat.elems[3][0] = (-cam_pos.x * CAMERA_SCALE) + (f32(window_size.x) / 2.0)
	mat.elems[3][1] = (-cam_pos.y * CAMERA_SCALE) + (f32(window_size.y) / 2.0)
}

level_tick :: proc(level: ^Level, zf4_tick_data: ^zf4.Game_Tick_Func_Data) -> bool {
	assert(level != nil)
	assert(zf4_tick_data != nil)

	//
	// Player
	//
	{
		move_axis := zf4.Vec_2D {
			f32(i32(zf4.is_key_down(zf4.Key_Code.D, zf4_tick_data.input_state))) -
			f32(i32(zf4.is_key_down(zf4.Key_Code.A, zf4_tick_data.input_state))),
			f32(i32(zf4.is_key_down(zf4.Key_Code.S, zf4_tick_data.input_state))) -
			f32(i32(zf4.is_key_down(zf4.Key_Code.W, zf4_tick_data.input_state))),
		}

		vel_lerp_targ := move_axis * PLAYER_MOVE_SPD
		level.player.vel = math.lerp(level.player.vel, vel_lerp_targ, f32(PLAYER_VEL_LERP_FACTOR))

		level.player.pos += level.player.vel
	}

	//
	// Camera
	//
	{
		mouse_cam_pos := screen_to_camera_pos(
			zf4_tick_data.input_state.mouse_pos,
			level.cam_pos,
			{1280, 720},
		)
		player_to_mouse_cam_pos_dist := zf4.calc_dist(level.player.pos, mouse_cam_pos)
		player_to_mouse_cam_pos_dir := zf4.calc_normal_or_zero(mouse_cam_pos - level.player.pos)

		look_dist :=
			CAMERA_LOOK_DIST_LIMIT *
			min(player_to_mouse_cam_pos_dist / CAMERA_LOOK_DIST_SCALAR_DIST, 1.0)

		look_offs := player_to_mouse_cam_pos_dir * look_dist

		dest := level.player.pos + look_offs

		level.cam_pos = math.lerp(level.cam_pos, dest, f32(CAMERA_POS_LERP_FACTOR))
	}

	return true
}

draw_level :: proc(level: ^Level, zf4_draw_data: ^zf4.Game_Draw_Func_Data) -> bool {
	init_camera_view_matrix_4x4(
		&zf4_draw_data.draw_phase_state.view_mat,
		level.cam_pos,
		{1280, 720},
	)

	zf4.draw_texture(
		i32(Texture.All),
		SPRITE_SRC_RECTS[int(Sprite.Player)],
		level.player.pos,
		zf4_draw_data.draw_phase_state,
		zf4_draw_data.pers_render_data,
	)

	return true
}

