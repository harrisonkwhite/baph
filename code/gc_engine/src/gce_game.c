#include <GLFW/glfw3.h>
#include <assert.h>
#include <stdio.h>
#include <stdbool.h>
#include "gce_game.h"
#include "gce_rendering.h"
#include "gce_utils.h"

#define PERM_MEM_ARENA_SIZE ((1 << 20) * 80)
#define TEMP_MEM_ARENA_SIZE ((1 << 20) * 40)

#define TARG_TICKS_PER_SEC 60
#define TARG_TICK_INTERVAL (1.0 / TARG_TICKS_PER_SEC)

#define GL_VERSION_MAJOR 4
#define GL_VERSION_MINOR 3

typedef struct {
    s_mem_arena* perm_mem_arena;
    s_mem_arena* temp_mem_arena;
    GLFWwindow* glfw_window;
    s_pers_render_data* pers_render_data;
} s_game_cleanup_info;

static void AssertGameInfoValidity(const s_game_info* const info) {
    assert(info->user_mem_size >= 0);
    assert(info->user_mem_alignment >= 0);

    assert(info->window_title);
    assert(info->window_init_size.x > 0 && info->window_init_size.y > 0);

    assert(info->init_func);
    assert(info->tick_func);
    assert(info->render_func);
}

static void CleanGame(const s_game_cleanup_info* const cleanup_info) {
    if (cleanup_info->glfw_window) {
        glfwDestroyWindow(cleanup_info->glfw_window);
    }

    glfwTerminate();

    CleanMemArena(cleanup_info->temp_mem_arena);
    CleanMemArena(cleanup_info->perm_mem_arena);
}

static s_window_state GetWindowState(GLFWwindow* const glfw_window) {
    assert(glfw_window);

    s_window_state state = {
        .fullscreen = glfwGetWindowMonitor(glfw_window) != NULL
    };
    glfwGetWindowPos(glfw_window, &state.pos.x, &state.pos.y);
    glfwGetWindowSize(glfw_window, &state.size.x, &state.size.y);

    return state;
}

static void GLFWKeyCallback(GLFWwindow* const window, const int key, const int scancode, const int action, const int mods) {
    s_input_state* const input_state = glfwGetWindowUserPointer(window);

    e_key_code code;

    switch (key) {
        case GLFW_KEY_SPACE: code = ek_key_code_space; break;
        case GLFW_KEY_0: code = ek_key_code_0; break;
        case GLFW_KEY_1: code = ek_key_code_1; break;
        case GLFW_KEY_2: code = ek_key_code_2; break;
        case GLFW_KEY_3: code = ek_key_code_3; break;
        case GLFW_KEY_4: code = ek_key_code_4; break;
        case GLFW_KEY_5: code = ek_key_code_5; break;
        case GLFW_KEY_6: code = ek_key_code_6; break;
        case GLFW_KEY_7: code = ek_key_code_7; break;
        case GLFW_KEY_8: code = ek_key_code_8; break;
        case GLFW_KEY_9: code = ek_key_code_9; break;
        case GLFW_KEY_A: code = ek_key_code_a; break;
        case GLFW_KEY_B: code = ek_key_code_b; break;
        case GLFW_KEY_C: code = ek_key_code_c; break;
        case GLFW_KEY_D: code = ek_key_code_d; break;
        case GLFW_KEY_E: code = ek_key_code_e; break;
        case GLFW_KEY_F: code = ek_key_code_f; break;
        case GLFW_KEY_G: code = ek_key_code_g; break;
        case GLFW_KEY_H: code = ek_key_code_h; break;
        case GLFW_KEY_I: code = ek_key_code_i; break;
        case GLFW_KEY_J: code = ek_key_code_j; break;
        case GLFW_KEY_K: code = ek_key_code_k; break;
        case GLFW_KEY_L: code = ek_key_code_l; break;
        case GLFW_KEY_M: code = ek_key_code_m; break;
        case GLFW_KEY_N: code = ek_key_code_n; break;
        case GLFW_KEY_O: code = ek_key_code_o; break;
        case GLFW_KEY_P: code = ek_key_code_p; break;
        case GLFW_KEY_Q: code = ek_key_code_q; break;
        case GLFW_KEY_R: code = ek_key_code_r; break;
        case GLFW_KEY_S: code = ek_key_code_s; break;
        case GLFW_KEY_T: code = ek_key_code_t; break;
        case GLFW_KEY_U: code = ek_key_code_u; break;
        case GLFW_KEY_V: code = ek_key_code_v; break;
        case GLFW_KEY_W: code = ek_key_code_w; break;
        case GLFW_KEY_X: code = ek_key_code_x; break;
        case GLFW_KEY_Y: code = ek_key_code_y; break;
        case GLFW_KEY_Z: code = ek_key_code_z; break;
        case GLFW_KEY_ESCAPE: code = ek_key_code_escape; break;
        case GLFW_KEY_ENTER: code = ek_key_code_enter; break;
        case GLFW_KEY_TAB: code = ek_key_code_tab; break;
        case GLFW_KEY_RIGHT: code = ek_key_code_right; break;
        case GLFW_KEY_LEFT: code = ek_key_code_left; break;
        case GLFW_KEY_DOWN: code = ek_key_code_down; break;
        case GLFW_KEY_UP: code = ek_key_code_up; break;
        case GLFW_KEY_F1: code = ek_key_code_f1; break;
        case GLFW_KEY_F2: code = ek_key_code_f2; break;
        case GLFW_KEY_F3: code = ek_key_code_f3; break;
        case GLFW_KEY_F4: code = ek_key_code_f4; break;
        case GLFW_KEY_F5: code = ek_key_code_f5; break;
        case GLFW_KEY_F6: code = ek_key_code_f6; break;
        case GLFW_KEY_F7: code = ek_key_code_f7; break;
        case GLFW_KEY_F8: code = ek_key_code_f8; break;
        case GLFW_KEY_F9: code = ek_key_code_f9; break;
        case GLFW_KEY_F10: code = ek_key_code_f10; break;
        case GLFW_KEY_F11: code = ek_key_code_f11; break;
        case GLFW_KEY_F12: code = ek_key_code_f12; break;
        case GLFW_KEY_LEFT_SHIFT: code = ek_key_code_left_shift; break;
        case GLFW_KEY_LEFT_CONTROL: code = ek_key_code_left_control; break;
        case GLFW_KEY_LEFT_ALT: code = ek_key_code_left_alt; break;
        case GLFW_KEY_RIGHT_SHIFT: code = ek_key_code_right_shift; break;
        case GLFW_KEY_RIGHT_CONTROL: code = ek_key_code_right_control; break;
        case GLFW_KEY_RIGHT_ALT: code = ek_key_code_right_alt; break;

        default: return;
    }

    const t_keys_down_bits key_bit = (t_keys_down_bits)1 << code;

    if (action == GLFW_PRESS) {
        input_state->keys_down |= key_bit;
    } else if (action == GLFW_RELEASE) {
        input_state->keys_down &= ~key_bit;
    }
}

static void GLFWMouseButtonCallback(GLFWwindow* const window, const int button, const int action, const int mods) {
    s_input_state* const input_state = glfwGetWindowUserPointer(window);

    e_mouse_button_code code;

    switch (button) {
        case GLFW_MOUSE_BUTTON_LEFT: code = ek_mouse_button_code_left; break;
        case GLFW_MOUSE_BUTTON_RIGHT: code = ek_mouse_button_code_right; break;
        case GLFW_MOUSE_BUTTON_MIDDLE: code = ek_mouse_button_code_middle; break;

        default: return;
    }

    const t_mouse_buttons_down_bits button_down_bit = (t_mouse_buttons_down_bits)1 << code;

    if (action == GLFW_PRESS) {
        input_state->mouse_buttons_down |= button_down_bit;
    } else if (action == GLFW_RELEASE) {
        input_state->mouse_buttons_down &= ~button_down_bit;
    }
}

static void GLFWCursorPosCallback(GLFWwindow* const window, const double x, const double y) {
    s_input_state* const input_state = glfwGetWindowUserPointer(window);
    input_state->mouse_pos.x = x;
    input_state->mouse_pos.y = y;
}

static void GLFWScrollCallback(GLFWwindow* const window, const double offs_x, const double offs_y) {
    s_input_state* const input_state = glfwGetWindowUserPointer(window);

    if (offs_y > 0.0) {
        input_state->mouse_scroll = ek_mouse_scroll_state_up;
    } else if (offs_y < 0.0) {
        input_state->mouse_scroll = ek_mouse_scroll_state_down;
    } else {
        input_state->mouse_scroll = ek_mouse_scroll_state_none;
    }
}

bool RunGame(const s_game_info* const info) {
    assert(info);
    AssertGameInfoValidity(info);

    s_game_cleanup_info cleanup_info = {0};

    //
    // Initialisation
    //
    printf("Initialising...\n");

    s_mem_arena perm_mem_arena = {0};

    if (!InitMemArena(&perm_mem_arena, PERM_MEM_ARENA_SIZE)) {
        fprintf(stderr, "Failed to initialise the permanent memory arena!\n");
        CleanGame(&cleanup_info);
        return false;
    }

    cleanup_info.perm_mem_arena = &perm_mem_arena;

    s_mem_arena temp_mem_arena = {0};

    if (!InitMemArena(&temp_mem_arena, TEMP_MEM_ARENA_SIZE)) {
        fprintf(stderr, "Failed to initialise the temporary memory arena!\n");
        CleanGame(&cleanup_info);
        return false;
    }

    cleanup_info.temp_mem_arena = &temp_mem_arena;

    if (!glfwInit()) {
        fprintf(stderr, "Failed to initialise GLFW!\n");
        CleanGame(&cleanup_info);
        return false;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, GL_VERSION_MAJOR);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, GL_VERSION_MINOR);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);

    GLFWwindow* const glfw_window = glfwCreateWindow(
        info->window_init_size.x,
        info->window_init_size.y,
        info->window_title,
        NULL,
        NULL
    );

    if (!glfw_window) {
        fprintf(stderr, "Failed to create a GLFW window!\n");
        CleanGame(&cleanup_info);
        return false;
    }

    cleanup_info.glfw_window = glfw_window;

    glfwMakeContextCurrent(glfw_window);

    glfwSwapInterval(1); // Enables VSync.

    glfwSetWindowAttrib(glfw_window, GLFW_RESIZABLE, info->window_flags & ek_window_flag_resizable ? GLFW_TRUE : GLFW_FALSE);
    glfwSetInputMode(glfw_window, GLFW_CURSOR, info->window_flags & ek_window_flag_hide_cursor ? GLFW_CURSOR_HIDDEN : GLFW_CURSOR_NORMAL);

    s_input_state input_state = {0};

    glfwSetWindowUserPointer(glfw_window, &input_state);
    glfwSetKeyCallback(glfw_window, GLFWKeyCallback);
    glfwSetMouseButtonCallback(glfw_window, GLFWMouseButtonCallback);
    glfwSetCursorPosCallback(glfw_window, GLFWCursorPosCallback);
    glfwSetScrollCallback(glfw_window, GLFWScrollCallback);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        fprintf(stderr, "Failed to load OpenGL function pointers!\n");
        return false;
    }

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    s_pers_render_data pers_render_data = {0};
    InitPersRenderData(&pers_render_data, info->window_init_size);

    s_rendering_state* const rendering_state = MEM_ARENA_PUSH_TYPE(&perm_mem_arena, s_rendering_state);

    if (!rendering_state) {
        return false;
    }

    void* const user_mem = PushToMemArena(&perm_mem_arena, info->user_mem_size, info->user_mem_alignment);

    if (!user_mem) {
        fprintf(stderr, "Failed to allocate user memory!\n");
        return false;
    }

    {
        const s_game_init_func_data func_data = {
            .user_mem = user_mem,
            .perm_mem_arena = &perm_mem_arena,
            .temp_mem_arena = &temp_mem_arena,
            .window_state = GetWindowState(glfw_window)
        };

        if (!info->init_func(&func_data)) {
            fprintf(stderr, "Provided game initialisation function failed!\n");
            CleanGame(&cleanup_info);
            return false;
        }
    }

    glfwShowWindow(glfw_window);

    //
    // Main Loop
    //
    double frame_time_last = glfwGetTime();
    double frame_dur_accum = 0.0;

    s_input_state input_state_last = input_state;

    printf("Entering the main loop...\n");

    while (!glfwWindowShouldClose(glfw_window)) {
        const s_window_state window_state_at_frame_begin = GetWindowState(glfw_window);

        const double frame_time = glfwGetTime();
        frame_dur_accum += frame_time - frame_time_last;
        frame_time_last = frame_time;

        if (frame_dur_accum >= TARG_TICK_INTERVAL) {
            while (frame_dur_accum >= TARG_TICK_INTERVAL) {
                const s_game_tick_func_data func_data = {
                    .user_mem = user_mem,
                    .perm_mem_arena = &perm_mem_arena,
                    .temp_mem_arena = &temp_mem_arena,
                    .window_state = window_state_at_frame_begin,
                    .input_state = &input_state,
                    .input_state_last = &input_state_last
                };

                if (!info->tick_func(&func_data)) {
                    CleanGame(&cleanup_info);
                    return false;
                }

                frame_dur_accum -= TARG_TICK_INTERVAL;
            }

            input_state_last = input_state;
            input_state.mouse_scroll = ek_mouse_scroll_state_none;

            BeginRendering(rendering_state);

            {
                const s_game_render_func_data func_data = {
                    .user_mem = user_mem,
                    .perm_mem_arena = &perm_mem_arena,
                    .temp_mem_arena = &temp_mem_arena,
                    .rendering_context = {
                        .pers = &pers_render_data,
                        .state = rendering_state,
                        .display_size = window_state_at_frame_begin.size
                    },
                    .input_state = &input_state
                };

                if (!info->render_func(&func_data)) {
                    CleanGame(&cleanup_info);
                    return false;
                }

                ResetMemArena(&temp_mem_arena);
            }

            assert(rendering_state->batch_slots_used_cnt == 0); // Make sure that we flushed.

            glfwSwapBuffers(glfw_window);
        }

        glfwPollEvents(); // NOTE: Move up, so that input state is updated prior to first tick?

        // Handle any window state changes.
        const s_window_state window_state_after_poll_events = GetWindowState(glfw_window);

        if (!Vec2DIsEqual(window_state_after_poll_events.size, VEC_2D_I_ZERO)
            && !Vec2DIsEqual(window_state_after_poll_events.size, window_state_at_frame_begin.size)) {
            glViewport(0, 0, window_state_after_poll_events.size.x, window_state_after_poll_events.size.y);

            if (!ResizeRenderSurfaces(&pers_render_data.surfs, window_state_after_poll_events.size)) {
                fprintf(stderr, "Failed to resize render surfaces!\n");
                return false;
            }
        }
    }

    CleanGame(&cleanup_info);

    return true;
}

bool IsKeyDown(const e_key_code kc, const s_input_state* input_state) {
    return (input_state->keys_down & (1ULL << kc)) != 0;
}

bool IsKeyPressed(e_key_code key_code, const s_input_state* st, const s_input_state* last) {
    return IsKeyDown(key_code, st) && !IsKeyDown(key_code, last);
}

bool IsKeyReleased(e_key_code key_code, const s_input_state* st, const s_input_state* last) {
    return !IsKeyDown(key_code, st) && IsKeyDown(key_code, last);
}

bool IsMouseButtonDown(e_mouse_button_code mbc, const s_input_state* st) {
    return (st->mouse_buttons_down & (1U << mbc)) != 0;
}

bool IsMouseButtonPressed(e_mouse_button_code mbc, const s_input_state* st, const s_input_state* last) {
    return IsMouseButtonDown(mbc, st) && !IsMouseButtonDown(mbc, last);
}

bool IsMouseButtonReleased(e_mouse_button_code mbc, const s_input_state* st, const s_input_state* last) {
    return !IsMouseButtonDown(mbc, st) && IsMouseButtonDown(mbc, last);
}
