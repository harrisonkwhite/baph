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

static void GLFWKeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) {
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

static void GLFWMouseButtonCallback(GLFWwindow* window, int button, int action, int mods) {
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

static void GLFWCursorPosCallback(GLFWwindow* window, double x, double y) {
    s_input_state* const input_state = glfwGetWindowUserPointer(window);
    input_state->mouse_pos.x = x;
    input_state->mouse_pos.y = y;
}

static void GLFWScrollCallback(GLFWwindow* window, double xoffset, double yoffset) {
    s_input_state* const input_state = glfwGetWindowUserPointer(window);

    if (yoffset > 0.0) {
        input_state->mouse_scroll = ek_mouse_scroll_state_up;
    } else if (yoffset < 0.0) {
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

/*package zf4

import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"

import gl "vendor:OpenGL"
import "vendor:glfw"

GL_VERS_MAJOR :: 4
GL_VERS_MINOR :: 3

TARG_TICKS_PER_SEC :: 60
TARG_TICK_DUR_SECS :: f64(1.0) / f64(TARG_TICKS_PER_SEC)

// TODO: Update validity checking.
Game_Info :: struct {
    perm_mem_arena_size:                  int,
    user_mem_size:                        int,
    user_mem_alignment:                   int,
    window_init_size:                     Vec_2D_I,
    window_min_size:                      Vec_2D_I,
    window_title:                         string,
    window_flags:                         Window_Flag_Set,
    tex_cnt:                              int,
    tex_index_to_file_path_func:          Texture_Index_To_File_Path,
    font_cnt:                             int,
    font_index_to_load_info_func:         Font_Index_To_Load_Info,
    shader_prog_cnt:                      int,
    shader_prog_index_to_file_paths_func: Shader_Prog_Index_To_File_Paths,
    init_func:                            proc(func_data: ^Game_Init_Func_Data) -> bool,
    tick_func:                            proc(func_data: ^Game_Tick_Func_Data) -> bool,
    render_func:                          proc(func_data: ^Game_Render_Func_Data) -> bool,
    clean_func:                           proc(user_mem: rawptr),
}

Game_Init_Func_Data :: struct {
    user_mem:           rawptr,
    window_state_cache: Window_State,
    input_state:        ^Input_State,
    perm_allocator:     mem.Allocator,
}

Game_Tick_Func_Data :: struct {
    user_mem:               rawptr,
    window_state_cache:     Window_State,
    fullscreen_state_ideal: ^bool,
    input_state:            ^Input_State,
    input_state_last:       ^Input_State,
    textures:               ^Textures,
    fonts:                  ^Fonts,
    shader_progs:           ^Shader_Progs,
    perm_allocator:         mem.Allocator,
    exit_game:              ^bool,
}

Game_Render_Func_Data :: struct {
    user_mem:          rawptr,
    rendering_context: Rendering_Context,
    textures:          ^Textures,
    fonts:             ^Fonts,
    shader_progs:      ^Shader_Progs,
}

Window_State :: struct {
    pos:        Vec_2D_I,
    size:       Vec_2D_I,
    fullscreen: bool,
}

Window_Flag :: enum {
    Resizable,
    Hide_Cursor,
}

Window_Flag_Set :: bit_set[Window_Flag]

Key_Code :: enum {
    None,
    Space,
    Num_0,
    Num_1,
    Num_2,
    Num_3,
    Num_4,
    Num_5,
    Num_6,
    Num_7,
    Num_8,
    Num_9,
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
    Escape,
    Enter,
    Tab,
    Right,
    Left,
    Down,
    Up,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    Left_Shift,
    Left_Control,
    Left_Alt,
    Right_Shift,
    Right_Control,
    Right_Alt,
}

Mouse_Button_Code :: enum {
    None,
    Left,
    Right,
    Middle,
}

Input_State :: struct {
    keys_down:          Keys_Down_Set,
    mouse_buttons_down: Mouse_Buttons_Down_Set,
    mouse_pos:          Vec_2D,
    mouse_scroll:       Mouse_Scroll_State,
}

Keys_Down_Set :: bit_set[Key_Code]
Mouse_Buttons_Down_Set :: bit_set[Mouse_Button_Code]

Mouse_Scroll_State :: enum {
    No_Scroll,
    Down,
    Up,
}

assert_game_info_validity :: proc(info: ^Game_Info) {
    assert(info.perm_mem_arena_size > 0)

    assert(info.user_mem_size >= 0)
    assert(info.user_mem_alignment > 0 && math.is_power_of_two(info.user_mem_alignment))

    assert(info.window_init_size.x > 0 && info.window_init_size.y > 0)
    assert(
        info.window_min_size == {} || (info.window_min_size.x > 0 && info.window_min_size.y > 0),
    )

    assert(
        (info.tex_cnt == 0 && info.tex_index_to_file_path_func == nil) ||
        (info.tex_cnt > 0 && info.tex_index_to_file_path_func != nil),
    )

    assert(
        (info.font_cnt == 0 && info.font_index_to_load_info_func == nil) ||
        (info.font_cnt > 0 && info.font_index_to_load_info_func != nil),
    )

    assert(
        (info.shader_prog_cnt == 0 && info.shader_prog_index_to_file_paths_func == nil) ||
        (info.shader_prog_cnt > 0 && info.shader_prog_index_to_file_paths_func != nil),
    )

    assert(info.init_func != nil)
    assert(info.tick_func != nil)
    assert(info.render_func != nil)
}

run_game :: proc(info: ^Game_Info) -> bool {
    assert_game_info_validity(info)

    //
    // Initialisation
    //
    fmt.println("Initialising...")

    // Set up the permanent memory arena.
    perm_mem_arena_buf := make([]byte, info.perm_mem_arena_size)

    if (perm_mem_arena_buf == nil) {
        fmt.eprintln("Failed to allocate memory for the main memory arena!")
        return false
    }

    defer delete(perm_mem_arena_buf)

    perm_mem_arena: mem.Arena
    mem.arena_init(&perm_mem_arena, perm_mem_arena_buf)

    perm_mem_arena_allocator := mem.arena_allocator(&perm_mem_arena)

    //
    if (!glfw.Init()) {
        return false
    }

    defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_VERS_MAJOR)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_VERS_MINOR)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.VISIBLE, false)

    window_title_c_str, window_title_c_str_alloc_err := strings.clone_to_cstring(
        info.window_title,
        perm_mem_arena_allocator,
    )

    if window_title_c_str_alloc_err != nil {
        return false
    }

    glfw_window := glfw.CreateWindow(
        c.int(info.window_init_size.x),
        c.int(info.window_init_size.y),
        window_title_c_str,
        nil,
        nil,
    )

    if glfw_window == nil {
        return false
    }

    defer glfw.DestroyWindow(glfw_window)

    glfw.MakeContextCurrent(glfw_window)

    glfw.SwapInterval(1) // Enables VSync.

    if info.window_min_size != {} {
        glfw.SetWindowSizeLimits(
            glfw_window,
            i32(info.window_min_size.x),
            i32(info.window_min_size.y),
            glfw.DONT_CARE,
            glfw.DONT_CARE,
        )
    }

    glfw.SetWindowAttrib(
        glfw_window,
        glfw.RESIZABLE,
        Window_Flag.Resizable in info.window_flags ? 1 : 0,
    )
    glfw.SetInputMode(
        glfw_window,
        glfw.CURSOR,
        Window_Flag.Hide_Cursor in info.window_flags ? glfw.CURSOR_HIDDEN : glfw.CURSOR_NORMAL,
    )

    //
    gl.load_up_to(GL_VERS_MAJOR, GL_VERS_MINOR, glfw.gl_set_proc_address)

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    pers_render_data, pers_render_data_generated := gen_pers_render_data(info.window_init_size)
    defer clean_pers_render_data(&pers_render_data)

    if !pers_render_data_generated {
        return false
    }

    textures, textures_loaded := load_textures(
        info.tex_cnt,
        info.tex_index_to_file_path_func,
        perm_mem_arena_allocator,
    )

    defer unload_textures(&textures)

    if !textures_loaded {
        return false
    }

    fonts, fonts_loaded := load_fonts(
        perm_mem_arena_allocator,
        info.font_cnt,
        info.font_index_to_load_info_func,
    )

    defer unload_fonts(&fonts)

    if !fonts_loaded {
        return false
    }

    shader_progs, shader_progs_loaded := load_shader_progs(
        perm_mem_arena_allocator,
        info.shader_prog_cnt,
        info.shader_prog_index_to_file_paths_func,
    )

    defer unload_shader_progs(&shader_progs)

    if !shader_progs_loaded {
        return false
    }

    user_mem, user_mem_alloc_err := mem.alloc(
        info.user_mem_size,
        info.user_mem_alignment,
        perm_mem_arena_allocator,
    )

    if user_mem == nil {
        return false
    }

    defer mem.free(user_mem, perm_mem_arena_allocator)

    if info.clean_func != nil {
        defer info.clean_func(user_mem)
    }

    //
    input_state: Input_State

    glfw.SetWindowUserPointer(glfw_window, &input_state)
    glfw.SetKeyCallback(
        glfw_window,
        proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: c.int) {
            input_state := (^Input_State)(glfw.GetWindowUserPointer(window))

            key_code: Key_Code

            switch key {
            case glfw.KEY_SPACE:
                key_code = Key_Code.Space
            case glfw.KEY_0:
                key_code = Key_Code.Num_0
            case glfw.KEY_1:
                key_code = Key_Code.Num_1
            case glfw.KEY_2:
                key_code = Key_Code.Num_2
            case glfw.KEY_3:
                key_code = Key_Code.Num_3
            case glfw.KEY_4:
                key_code = Key_Code.Num_4
            case glfw.KEY_5:
                key_code = Key_Code.Num_5
            case glfw.KEY_6:
                key_code = Key_Code.Num_6
            case glfw.KEY_7:
                key_code = Key_Code.Num_7
            case glfw.KEY_8:
                key_code = Key_Code.Num_8
            case glfw.KEY_9:
                key_code = Key_Code.Num_9

            case glfw.KEY_A:
                key_code = Key_Code.A
            case glfw.KEY_B:
                key_code = Key_Code.B
            case glfw.KEY_C:
                key_code = Key_Code.C
            case glfw.KEY_D:
                key_code = Key_Code.D
            case glfw.KEY_E:
                key_code = Key_Code.E
            case glfw.KEY_F:
                key_code = Key_Code.F
            case glfw.KEY_G:
                key_code = Key_Code.G
            case glfw.KEY_H:
                key_code = Key_Code.H
            case glfw.KEY_I:
                key_code = Key_Code.I
            case glfw.KEY_J:
                key_code = Key_Code.J
            case glfw.KEY_K:
                key_code = Key_Code.K
            case glfw.KEY_L:
                key_code = Key_Code.L
            case glfw.KEY_M:
                key_code = Key_Code.M
            case glfw.KEY_N:
                key_code = Key_Code.N
            case glfw.KEY_O:
                key_code = Key_Code.O
            case glfw.KEY_P:
                key_code = Key_Code.P
            case glfw.KEY_Q:
                key_code = Key_Code.Q
            case glfw.KEY_R:
                key_code = Key_Code.R
            case glfw.KEY_S:
                key_code = Key_Code.S
            case glfw.KEY_T:
                key_code = Key_Code.T
            case glfw.KEY_U:
                key_code = Key_Code.U
            case glfw.KEY_V:
                key_code = Key_Code.V
            case glfw.KEY_W:
                key_code = Key_Code.W
            case glfw.KEY_X:
                key_code = Key_Code.X
            case glfw.KEY_Y:
                key_code = Key_Code.Y
            case glfw.KEY_Z:
                key_code = Key_Code.Z

            case glfw.KEY_ESCAPE:
                key_code = Key_Code.Escape
            case glfw.KEY_ENTER:
                key_code = Key_Code.Enter
            case glfw.KEY_TAB:
                key_code = Key_Code.Tab

            case glfw.KEY_RIGHT:
                key_code = Key_Code.Right
            case glfw.KEY_LEFT:
                key_code = Key_Code.Left
            case glfw.KEY_DOWN:
                key_code = Key_Code.Down
            case glfw.KEY_UP:
                key_code = Key_Code.Up

            case glfw.KEY_F1:
                key_code = Key_Code.F1
            case glfw.KEY_F2:
                key_code = Key_Code.F2
            case glfw.KEY_F3:
                key_code = Key_Code.F3
            case glfw.KEY_F4:
                key_code = Key_Code.F4
            case glfw.KEY_F5:
                key_code = Key_Code.F5
            case glfw.KEY_F6:
                key_code = Key_Code.F6
            case glfw.KEY_F7:
                key_code = Key_Code.F7
            case glfw.KEY_F8:
                key_code = Key_Code.F8
            case glfw.KEY_F9:
                key_code = Key_Code.F9
            case glfw.KEY_F10:
                key_code = Key_Code.F10
            case glfw.KEY_F11:
                key_code = Key_Code.F11
            case glfw.KEY_F12:
                key_code = Key_Code.F12

            case glfw.KEY_LEFT_SHIFT:
                key_code = Key_Code.Left_Shift
            case glfw.KEY_LEFT_CONTROL:
                key_code = Key_Code.Left_Control
            case glfw.KEY_LEFT_ALT:
                key_code = Key_Code.Left_Alt

            case glfw.KEY_RIGHT_SHIFT:
                key_code = Key_Code.Right_Shift
            case glfw.KEY_RIGHT_CONTROL:
                key_code = Key_Code.Right_Control
            case glfw.KEY_RIGHT_ALT:
                key_code = Key_Code.Right_Alt

            case:
                return
            }

            if action == glfw.PRESS {
                input_state.keys_down += {key_code}
            } else if action == glfw.RELEASE {
                input_state.keys_down -= {key_code}
            }
        },
    )
    glfw.SetMouseButtonCallback(
        glfw_window,
        proc "c" (window: glfw.WindowHandle, button, action, mods: c.int) {
            input_state := (^Input_State)(glfw.GetWindowUserPointer(window))

            mb_code: Mouse_Button_Code

            switch button {
            case glfw.MOUSE_BUTTON_LEFT:
                mb_code = Mouse_Button_Code.Left
            case glfw.MOUSE_BUTTON_RIGHT:
                mb_code = Mouse_Button_Code.Right
            case glfw.MOUSE_BUTTON_MIDDLE:
                mb_code = Mouse_Button_Code.Middle
            }

            if action == glfw.PRESS {
                input_state.mouse_buttons_down += {mb_code}
            } else if action == glfw.RELEASE {
                input_state.mouse_buttons_down -= {mb_code}
            }
        },
    )
    glfw.SetCursorPosCallback(glfw_window, proc "c" (window: glfw.WindowHandle, x, y: f64) {
        input_state := (^Input_State)(glfw.GetWindowUserPointer(window))
        input_state.mouse_pos = {f32(x), f32(y)}
    })
    glfw.SetScrollCallback(glfw_window, proc "c" (window: glfw.WindowHandle, offs_x, offs_y: f64) {
        input_state := (^Input_State)(glfw.GetWindowUserPointer(window))

        if offs_y == 0.0 {
            input_state.mouse_scroll = Mouse_Scroll_State.No_Scroll
        } else {
            input_state.mouse_scroll =
                offs_y > 0.0 ? Mouse_Scroll_State.Up : Mouse_Scroll_State.Down
        }
    })

    {
        func_data := Game_Init_Func_Data {
            user_mem           = user_mem,
            window_state_cache = load_window_state(glfw_window),
            input_state        = &input_state,
        }

        if (!info.init_func(&func_data)) {
            return false
        }
    }

    glfw.ShowWindow(glfw_window)

    free_all(context.temp_allocator)

    //
    // Main Loop
    //
    frame_time := glfw.GetTime()
    frame_dur_accum := TARG_TICK_DUR_SECS // Make sure that we begin with a tick.

    rendering_state := new(Rendering_State, perm_mem_arena_allocator)

    if rendering_state == nil {
        fmt.eprintf("Failed to allocate memory for render state data!")
        return false
    }

    window_pos_fullscreen_switch_cache: Vec_2D_I
    window_size_fullscreen_switch_cache: Vec_2D_I

    input_state_last: Input_State

    fmt.println("Entering the main loop...")

    for (!glfw.WindowShouldClose(glfw_window)) {
        window_state_cache := load_window_state(glfw_window)
        fullscreen_state_ideal := window_state_cache.fullscreen

        frame_time_last := frame_time
        frame_time = glfw.GetTime()

        frame_dur := frame_time - frame_time_last
        frame_dur_accum += frame_dur

        if frame_dur_accum >= TARG_TICK_DUR_SECS {
            for frame_dur_accum >= TARG_TICK_DUR_SECS {
                exit_game: bool

                func_data := Game_Tick_Func_Data {
                    user_mem               = user_mem,
                    window_state_cache     = window_state_cache,
                    fullscreen_state_ideal = &fullscreen_state_ideal,
                    input_state            = &input_state,
                    input_state_last       = &input_state_last,
                    textures               = &textures,
                    fonts                  = &fonts,
                    shader_progs           = &shader_progs,
                    exit_game              = &exit_game,
                }

                if !info.tick_func(&func_data) {
                    return false
                }

                free_all(context.temp_allocator)

                if exit_game {
                    return true
                }

                frame_dur_accum -= TARG_TICK_DUR_SECS
            }

            input_state_last = input_state
            input_state.mouse_scroll = Mouse_Scroll_State.No_Scroll

            begin_rendering(rendering_state)

            {
                func_data := Game_Render_Func_Data {
                    user_mem     = user_mem,
                    textures     = &textures,
                    fonts        = &fonts,
                    shader_progs = &shader_progs,
                }

                func_data.rendering_context = {
                    pers         = &pers_render_data,
                    state        = rendering_state,
                    display_size = window_state_cache.size,
                }

                if !info.render_func(&func_data) {
                    return false
                }

                free_all(context.temp_allocator)
            }

            assert(rendering_state.batch_slots_used_cnt == 0) // Make sure that we flushed.

            glfw.SwapBuffers(glfw_window)
        }

        // BUG: Maximise on a secondary monitor and go fullscreen; every time you click the window disappears.

        if fullscreen_state_ideal && !window_state_cache.fullscreen {
            monitor := glfw.GetPrimaryMonitor()
            vid_mode := glfw.GetVideoMode(monitor)

            glfw.SetWindowMonitor(
                glfw_window,
                monitor,
                0,
                0,
                vid_mode.width,
                vid_mode.height,
                vid_mode.refresh_rate,
            )

            fmt.println("Going fullscreen...")
        } else if !fullscreen_state_ideal && window_state_cache.fullscreen {
            glfw.SetWindowMonitor(
                glfw_window,
                nil,
                i32(window_pos_fullscreen_switch_cache.x),
                i32(window_pos_fullscreen_switch_cache.y),
                i32(window_size_fullscreen_switch_cache.x),
                i32(window_size_fullscreen_switch_cache.y),
                0,
            )

            fmt.println("Going windowed...")
        }

        glfw.PollEvents()

        // Handle any window state changes.
        window_state_after_poll_events := load_window_state(glfw_window)

        if window_state_after_poll_events.size != {} &&
           window_state_after_poll_events.size != window_state_cache.size {
            gl.Viewport(
                0,
                0,
                i32(window_state_after_poll_events.size.x),
                i32(window_state_after_poll_events.size.y),
            )

            if !resize_surfaces(&pers_render_data.surfs, window_state_after_poll_events.size) {
                return false
            }
        }

        if window_state_after_poll_events.fullscreen && !window_state_cache.fullscreen {
            window_pos_fullscreen_switch_cache = window_state_cache.pos
            window_size_fullscreen_switch_cache = window_state_cache.size
        }
    }

    return true
}

load_window_state :: proc(glfw_window: glfw.WindowHandle) -> Window_State {
    assert(glfw_window != nil)

    x, y := glfw.GetWindowPos(glfw_window)
    width, height := glfw.GetWindowSize(glfw_window)

    return {
        pos = {int(x), int(y)},
        size = {int(width), int(height)},
        fullscreen = glfw.GetWindowMonitor(glfw_window) != nil,
    }
}

get_key_code_name :: proc(kc: Key_Code) -> string {
    switch kc {
    case Key_Code.None:
        break

    case Key_Code.Space:
        return "Space"

    case Key_Code.Num_0:
        return "0"
    case Key_Code.Num_1:
        return "1"
    case Key_Code.Num_2:
        return "2"
    case Key_Code.Num_3:
        return "3"
    case Key_Code.Num_4:
        return "4"
    case Key_Code.Num_5:
        return "5"
    case Key_Code.Num_6:
        return "6"
    case Key_Code.Num_7:
        return "7"
    case Key_Code.Num_8:
        return "8"
    case Key_Code.Num_9:
        return "9"

    case Key_Code.A:
        return "A"
    case Key_Code.B:
        return "B"
    case Key_Code.C:
        return "C"
    case Key_Code.D:
        return "D"
    case Key_Code.E:
        return "E"
    case Key_Code.F:
        return "F"
    case Key_Code.G:
        return "G"
    case Key_Code.H:
        return "H"
    case Key_Code.I:
        return "I"
    case Key_Code.J:
        return "J"
    case Key_Code.K:
        return "K"
    case Key_Code.L:
        return "L"
    case Key_Code.M:
        return "M"
    case Key_Code.N:
        return "N"
    case Key_Code.O:
        return "O"
    case Key_Code.P:
        return "P"
    case Key_Code.Q:
        return "Q"
    case Key_Code.R:
        return "R"
    case Key_Code.S:
        return "S"
    case Key_Code.T:
        return "T"
    case Key_Code.U:
        return "U"
    case Key_Code.V:
        return "V"
    case Key_Code.W:
        return "W"
    case Key_Code.X:
        return "X"
    case Key_Code.Y:
        return "Y"
    case Key_Code.Z:
        return "Z"

    case Key_Code.Escape:
        return "Escape"
    case Key_Code.Enter:
        return "Enter"
    case Key_Code.Tab:
        return "Tab"

    case Key_Code.Right:
        return "Right"
    case Key_Code.Left:
        return "Left"
    case Key_Code.Down:
        return "Down"
    case Key_Code.Up:
        return "Up"

    case Key_Code.F1:
        return "F1"
    case Key_Code.F2:
        return "F2"
    case Key_Code.F3:
        return "F3"
    case Key_Code.F4:
        return "F4"
    case Key_Code.F5:
        return "F5"
    case Key_Code.F6:
        return "F6"
    case Key_Code.F7:
        return "F7"
    case Key_Code.F8:
        return "F8"
    case Key_Code.F9:
        return "F9"
    case Key_Code.F10:
        return "F10"
    case Key_Code.F11:
        return "F11"
    case Key_Code.F12:
        return "F12"

    case Key_Code.Left_Shift:
        return "Left Shift"
    case Key_Code.Left_Control:
        return "Left Control"
    case Key_Code.Left_Alt:
        return "Left Alt"

    case Key_Code.Right_Shift:
        return "Right Shift"
    case Key_Code.Right_Control:
        return "Right Control"
    case Key_Code.Right_Alt:
        return "Right Alt"
    }

    return ""
}

get_mouse_button_code_name :: proc(mbc: Mouse_Button_Code) -> string {
    switch mbc {
    case Mouse_Button_Code.None:
        break

    case Mouse_Button_Code.Left:
        return "Left Mouse Button"
    case Mouse_Button_Code.Right:
        return "Right Mouse Button"
    case Mouse_Button_Code.Middle:
        return "Middle Mouse Button"
    }

    return ""
}

// TODO: Remove, maybe?
is_key_down :: proc(key_code: Key_Code, input_state: ^Input_State) -> bool {
    return key_code in input_state.keys_down
}

is_key_pressed :: proc(
    key_code: Key_Code,
    input_state: ^Input_State,
    input_state_last: ^Input_State,
) -> bool {
    return is_key_down(key_code, input_state) && !is_key_down(key_code, input_state_last)
}

is_key_released :: proc(
    key_code: Key_Code,
    input_state: ^Input_State,
    input_state_last: ^Input_State,
) -> bool {
    return !is_key_down(key_code, input_state) && is_key_down(key_code, input_state_last)
}

// TODO: Remove, maybe?
is_mouse_button_down :: proc(
    mouse_button_code: Mouse_Button_Code,
    input_state: ^Input_State,
) -> bool {
    return mouse_button_code in input_state.mouse_buttons_down
}

is_mouse_button_pressed :: proc(
    mouse_button_code: Mouse_Button_Code,
    input_state: ^Input_State,
    input_state_last: ^Input_State,
) -> bool {
    return(
        is_mouse_button_down(mouse_button_code, input_state) &&
        !is_mouse_button_down(mouse_button_code, input_state_last) \
    )
}

is_mouse_button_released :: proc(
    mouse_button_code: Mouse_Button_Code,
    input_state: ^Input_State,
    input_state_last: ^Input_State,
) -> bool {
    return(
        !is_mouse_button_down(mouse_button_code, input_state) &&
        is_mouse_button_down(mouse_button_code, input_state_last) \
    )
}*/

