package sanctus

import "core:math"
import "core:mem"
import "zf4"

CAMERA_SCALE :: 2.0

CAMERA_POS_LERP_FACTOR :: 0.25
CAMERA_LOOK_DIST_LIMIT :: 24.0
CAMERA_LOOK_DIST_SCALAR_DIST :: CAMERA_LOOK_DIST_LIMIT * 32.0

Camera :: struct {
	pos: zf4.Vec_2D,
}

update_camera :: proc(
	cam: ^Camera,
	player_pos: zf4.Vec_2D,
	mouse_pos: zf4.Vec_2D,
	display_size: zf4.Vec_2D_I,
) {
	mouse_cam_pos := display_to_camera_pos(mouse_pos, cam.pos, display_size)
	player_to_mouse_cam_pos_dist := zf4.calc_dist(player_pos, mouse_cam_pos)
	player_to_mouse_cam_pos_dir := zf4.calc_normal_or_zero(mouse_cam_pos - player_pos)

	look_dist :=
		CAMERA_LOOK_DIST_LIMIT *
		min(player_to_mouse_cam_pos_dist / CAMERA_LOOK_DIST_SCALAR_DIST, 1.0)

	look_offs := player_to_mouse_cam_pos_dir * look_dist

	dest := player_pos + look_offs

	cam.pos = math.lerp(cam.pos, dest, f32(CAMERA_POS_LERP_FACTOR))
}

calc_camera_size :: proc(window_size: zf4.Vec_2D_I) -> zf4.Vec_2D {
	assert(zf4.is_size_i(window_size))
	return {f32(window_size.x) / CAMERA_SCALE, f32(window_size.y) / CAMERA_SCALE}
}

calc_camera_top_left :: proc(cam_pos: zf4.Vec_2D, window_size: zf4.Vec_2D_I) -> zf4.Vec_2D {
	assert(zf4.is_size_i(window_size))
	return cam_pos - (calc_camera_size(window_size) / 2.0)
}

camera_to_display_pos :: proc(
	pos: zf4.Vec_2D,
	cam_pos: zf4.Vec_2D,
	display_size: zf4.Vec_2D_I,
) -> zf4.Vec_2D {
	assert(zf4.is_size_i(display_size))
	cam_tl := calc_camera_top_left(cam_pos, display_size)
	return (pos - cam_tl) * CAMERA_SCALE
}

display_to_camera_pos :: proc(
	pos: zf4.Vec_2D,
	cam_pos: zf4.Vec_2D,
	display_size: zf4.Vec_2D_I,
) -> zf4.Vec_2D {
	assert(zf4.is_size_i(display_size))
	cam_tl := calc_camera_top_left(cam_pos, display_size)
	return cam_tl + (pos / CAMERA_SCALE)
}

init_camera_view_matrix_4x4 :: proc(
	mat: ^zf4.Matrix_4x4,
	cam_pos: zf4.Vec_2D,
	display_size: zf4.Vec_2D_I,
) {
	assert(zf4.is_size_i(display_size))

	mem.zero(mat, size_of(mat^))
	mat.elems[0][0] = CAMERA_SCALE
	mat.elems[1][1] = CAMERA_SCALE
	mat.elems[3][3] = 1.0
	mat.elems[3][0] = (-cam_pos.x * CAMERA_SCALE) + (f32(display_size.x) / 2.0)
	mat.elems[3][1] = (-cam_pos.y * CAMERA_SCALE) + (f32(display_size.y) / 2.0)
}

