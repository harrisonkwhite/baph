#include "gc_game.h"

#define CAMERA_POS_LERP_FACTOR 0.25f
#define CAMERA_LOOK_DIST_LIMIT 24.0f
#define CAMERA_LOOK_DIST_SCALAR_DIST (CAMERA_LOOK_DIST_LIMIT * 32.0f)

#define CAMERA_SHAKE_MULT 0.9f

static s_vec_2d CalcCameraShakeOffs(const float shake) {
    //return {rand.float32_range(-shake, shake), rand.float32_range(-shake, shake)}
    return (s_vec_2d) { 0 }; // TEMP
}

void UpdateCamera(s_level* const level, const s_window_state* const window_state, const s_input_state* const input_state) {
    s_vec_2d dest = level->camera.pos_no_offs;

    if (!level->player.killed) {
        const s_vec_2d mouse_cam_pos = DisplayToCameraPos(input_state->mouse_pos, &level->camera, window_state->size);
        const float player_to_mouse_cam_pos_dist = Dist(level->player.pos, mouse_cam_pos);
        const s_vec_2d player_to_mouse_cam_pos_dir = NormalOrZero(Vec2DDiff(mouse_cam_pos, level->player.pos));

        const float look_dist = CAMERA_LOOK_DIST_LIMIT * MIN(player_to_mouse_cam_pos_dist / CAMERA_LOOK_DIST_SCALAR_DIST, 1.0f);

        dest = Vec2DSum(level->player.pos, Vec2DScale(player_to_mouse_cam_pos_dir, look_dist));
    }

    level->camera.pos_no_offs = LerpVec2D(level->camera.pos_no_offs, dest, CAMERA_POS_LERP_FACTOR);
    level->camera.pos_offs = CalcCameraShakeOffs(level->camera.shake);

    level->camera.shake *= CAMERA_SHAKE_MULT;
}

void InitCameraViewMatrix4x4(t_matrix_4x4* const mat, const s_camera* const cam, const s_vec_2d_i display_size) {
    assert(mat);
    assert(IsZero(mat, sizeof(*mat))); // NOTE: Make sure this is the actual right size!
    assert(cam);
    assert(display_size.x > 0 && display_size.y > 0);

    const s_vec_2d cam_pos = Vec2DSum(cam->pos_no_offs, cam->pos_offs);

    (*mat)[0][0] = CAMERA_SCALE;
    (*mat)[1][1] = CAMERA_SCALE;
    (*mat)[3][3] = 1.0f;
    (*mat)[3][0] = (-cam_pos.x * CAMERA_SCALE) + (display_size.x / 2.0f);
    (*mat)[3][1] = (-cam_pos.y * CAMERA_SCALE) + (display_size.y / 2.0f);
}
