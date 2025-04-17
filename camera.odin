package baph

import "core:math"
import "core:math/rand"
import "core:mem"
import "zf4"

CAMERA_SCALE :: 2.0

CAMERA_POS_LERP_FACTOR :: 0.25
CAMERA_LOOK_DIST_LIMIT :: 24.0
CAMERA_LOOK_DIST_SCALAR_DIST :: CAMERA_LOOK_DIST_LIMIT * 32.0

CAMERA_SHAKE_MULT :: 0.9

Camera :: struct {
	pos_no_offs: zf4.Vec_2D,
	pos_offs:    zf4.Vec_2D,
	shake:       f32,
}

update_camera :: proc(game: ^Game, zf4_data: ^zf4.Game_Tick_Func_Data) {
	dest := game.cam.pos_no_offs

	if !game.player.killed {
		mouse_cam_pos := display_to_camera_pos(
			zf4_data.input_state.mouse_pos,
			&game.cam,
			zf4_data.window_state_cache.size,
		)
		player_to_mouse_cam_pos_dist := zf4.calc_dist(game.player.pos, mouse_cam_pos)
		player_to_mouse_cam_pos_dir := zf4.calc_normal_or_zero(mouse_cam_pos - game.player.pos)

		look_dist :=
			CAMERA_LOOK_DIST_LIMIT *
			min(player_to_mouse_cam_pos_dist / CAMERA_LOOK_DIST_SCALAR_DIST, 1.0)

		dest = game.player.pos + (player_to_mouse_cam_pos_dir * look_dist)
	}

	game.cam.pos_no_offs = math.lerp(game.cam.pos_no_offs, dest, f32(CAMERA_POS_LERP_FACTOR))
	game.cam.pos_offs = calc_camera_shake_offs(game.cam.shake)

	game.cam.shake *= CAMERA_SHAKE_MULT
}

calc_camera_shake_offs :: proc(shake: f32) -> zf4.Vec_2D {
	return {rand.float32_range(-shake, shake), rand.float32_range(-shake, shake)}
}

calc_camera_size :: proc(window_size: zf4.Vec_2D_I) -> zf4.Vec_2D {
	assert(zf4.is_size_i(window_size))
	return {f32(window_size.x) / CAMERA_SCALE, f32(window_size.y) / CAMERA_SCALE}
}

calc_camera_top_left :: proc(cam: ^Camera, window_size: zf4.Vec_2D_I) -> zf4.Vec_2D {
	assert(zf4.is_size_i(window_size))
	pos := cam.pos_no_offs + cam.pos_offs
	return pos - (calc_camera_size(window_size) / 2.0)
}

apply_camera_shake :: proc(cam: ^Camera, shake: f32) {
	assert(shake > 0.0)
	cam.shake = max(cam.shake, shake)
}

camera_to_display_pos :: proc(
	pos: zf4.Vec_2D,
	cam: ^Camera,
	display_size: zf4.Vec_2D_I,
) -> zf4.Vec_2D {
	assert(zf4.is_size_i(display_size))
	cam_tl := calc_camera_top_left(cam, display_size)
	return (pos - cam_tl) * CAMERA_SCALE
}

display_to_camera_pos :: proc(
	pos: zf4.Vec_2D,
	cam: ^Camera,
	display_size: zf4.Vec_2D_I,
) -> zf4.Vec_2D {
	assert(zf4.is_size_i(display_size))
	cam_tl := calc_camera_top_left(cam, display_size)
	return cam_tl + (pos / CAMERA_SCALE)
}

gen_camera_view_matrix_4x4 :: proc(cam: ^Camera, display_size: zf4.Vec_2D_I) -> matrix[4, 4]f32 {
	assert(cam != nil)
	assert(zf4.is_size_i(display_size))

	cam_pos := cam.pos_no_offs + cam.pos_offs

	mat: matrix[4, 4]f32

	mat[0][0] = CAMERA_SCALE
	mat[1][1] = CAMERA_SCALE
	mat[3][3] = 1.0
	mat[3][0] = (-cam_pos.x * CAMERA_SCALE) + (f32(display_size.x) / 2.0)
	mat[3][1] = (-cam_pos.y * CAMERA_SCALE) + (f32(display_size.y) / 2.0)

	return mat
}

