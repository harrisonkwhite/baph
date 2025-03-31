package apocalypse

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
	shake:       f32,
}

calc_camera_pos :: proc(cam: ^Camera) -> zf4.Vec_2D {
	return cam.pos_no_offs + calc_camera_shake_offs(cam.shake)
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
	pos := calc_camera_pos(cam)
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

init_camera_view_matrix_4x4 :: proc(
	mat: ^zf4.Matrix_4x4,
	cam: ^Camera,
	display_size: zf4.Vec_2D_I,
) {
	assert(zf4.is_size_i(display_size))

	cam_pos := calc_camera_pos(cam)

	mem.zero(mat, size_of(mat^))
	mat.elems[0][0] = CAMERA_SCALE
	mat.elems[1][1] = CAMERA_SCALE
	mat.elems[3][3] = 1.0
	mat.elems[3][0] = (-cam_pos.x * CAMERA_SCALE) + (f32(display_size.x) / 2.0)
	mat.elems[3][1] = (-cam_pos.y * CAMERA_SCALE) + (f32(display_size.y) / 2.0)
}

