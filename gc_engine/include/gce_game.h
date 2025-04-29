#ifndef GCE_GAME_H
#define GCE_GAME_H

#include <stdbool.h>
#include <stdint.h>
#include <GLFW/glfw3.h>
#include "gce_math.h"
#include "gce_rendering.h"
#include "gce_utils.h"

typedef uint64_t t_keys_down_bits;
typedef uint8_t t_mouse_buttons_down_bits;

typedef enum {
    ek_window_flag_resizable = 1 << 0,
    ek_window_flag_hide_cursor = 1 << 1
} e_window_flags;

typedef enum {
    ek_mouse_scroll_state_none,
    ek_mouse_scroll_state_down,
    ek_mouse_scroll_state_up
} e_mouse_scroll_state;

typedef enum {
    ek_key_code_space,
    ek_key_code_0,
    ek_key_code_1,
    ek_key_code_2,
    ek_key_code_3,
    ek_key_code_4,
    ek_key_code_5,
    ek_key_code_6,
    ek_key_code_7,
    ek_key_code_8,
    ek_key_code_9,
    ek_key_code_a,
    ek_key_code_b,
    ek_key_code_c,
    ek_key_code_d,
    ek_key_code_e,
    ek_key_code_f,
    ek_key_code_g,
    ek_key_code_h,
    ek_key_code_i,
    ek_key_code_j,
    ek_key_code_k,
    ek_key_code_l,
    ek_key_code_m,
    ek_key_code_n,
    ek_key_code_o,
    ek_key_code_p,
    ek_key_code_q,
    ek_key_code_r,
    ek_key_code_s,
    ek_key_code_t,
    ek_key_code_u,
    ek_key_code_v,
    ek_key_code_w,
    ek_key_code_x,
    ek_key_code_y,
    ek_key_code_z,
    ek_key_code_escape,
    ek_key_code_enter,
    ek_key_code_tab,
    ek_key_code_right,
    ek_key_code_left,
    ek_key_code_down,
    ek_key_code_up,
    ek_key_code_f1,
    ek_key_code_f2,
    ek_key_code_f3,
    ek_key_code_f4,
    ek_key_code_f5,
    ek_key_code_f6,
    ek_key_code_f7,
    ek_key_code_f8,
    ek_key_code_f9,
    ek_key_code_f10,
    ek_key_code_f11,
    ek_key_code_f12,
    ek_key_code_left_shift,
    ek_key_code_left_control,
    ek_key_code_left_alt,
    ek_key_code_right_shift,
    ek_key_code_right_control,
    ek_key_code_right_alt,
} e_key_code;

typedef enum {
    ek_mouse_button_code_left,
    ek_mouse_button_code_right,
    ek_mouse_button_code_middle
} e_mouse_button_code;

typedef struct {
    t_keys_down_bits keys_down;
    t_mouse_buttons_down_bits mouse_buttons_down;
    s_vec_2d mouse_pos;
    e_mouse_scroll_state mouse_scroll;
} s_input_state;

typedef struct s_window_state {
    s_vec_2d_i pos;
    s_vec_2d_i size;
    bool fullscreen;
} s_window_state;

typedef struct s_game_init_func_data {
    void* user_mem;
    s_mem_arena* perm_mem_arena;
    s_mem_arena* temp_mem_arena;
    s_window_state window_state;
} s_game_init_func_data;

typedef struct s_game_tick_func_data {
    void* user_mem;
    s_mem_arena* perm_mem_arena;
    s_mem_arena* temp_mem_arena;
    s_window_state window_state;
    const s_input_state* input_state;
    const s_input_state* input_state_last;
} s_game_tick_func_data;

typedef struct s_game_render_func_data {
    void* user_mem;
    s_mem_arena* perm_mem_arena;
    s_mem_arena* temp_mem_arena;
    s_rendering_context rendering_context;
    const s_input_state* input_state;
} s_game_render_func_data;

typedef struct {
    int user_mem_size;
    int user_mem_alignment;

    s_vec_2d_i window_init_size;
    const char* window_title;
    e_window_flags window_flags;

    bool (*init_func)(const s_game_init_func_data* const func_data);
    bool (*tick_func)(const s_game_tick_func_data* const func_data);
    bool (*render_func)(const s_game_render_func_data* const func_data);
    void (*clean_func)(void* const user_mem);
} s_game_info;

bool RunGame(const s_game_info* info);
const char* KeyCodeName(e_key_code kc);
const char* MouseButtonCodeName(e_mouse_button_code mbc);
bool IsKeyDown(e_key_code key_code, const s_input_state* st);
bool IsKeyPressed(e_key_code key_code, const s_input_state* st, const s_input_state* last);
bool IsKeyReleased(e_key_code key_code, const s_input_state* st, const s_input_state* last);
bool IsMouseButtonDown(e_mouse_button_code mbc, const s_input_state* st);
bool IsMouseButtonPressed(e_mouse_button_code mbc, const s_input_state* st, const s_input_state* last);
bool IsMouseButtonReleased(e_mouse_button_code mbc, const s_input_state* st, const s_input_state* last);

#endif
