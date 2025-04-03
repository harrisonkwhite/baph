package apocalypse

import "core:fmt"
import "core:mem"
import "zf4"

GAME_TITLE :: "Apocalypse"

Game :: struct {
	config:       Game_Config,
	in_world:     bool,
	title_screen: Title_Screen,
	world:        World,
	mouse_pos:    zf4.Vec_2D, // TEMP? Just pass input state into render function?
}

Game_Config :: struct {
	screen_shake:           f32,
	input_binding_settings: [len(Input_Binding)]Input_Binding_Setting,
	fullscreen:             bool,
	res_index:              int,
	resolutions:            []zf4.Vec_2D_I, // NOTE: Maybe this should be elsewhere?
	master_vol:             f32,
	snd_vol:                f32,
	music_vol:              f32,
	ambience_vol:           f32,
}

Texture :: enum {
	All,
}

Font :: enum {
	EB_Garamond_32,
	EB_Garamond_40,
	EB_Garamond_48,
	EB_Garamond_64,
	EB_Garamond_96,
	EB_Garamond_128,
}

Shader_Prog :: enum {
	Blend,
}

Sprite :: enum {
	Player,
	Minion,
	Melee_Enemy,
	Ranger_Enemy,
	Sword,
	Shield,
	Projectile,
	Wall,
	Door_Border_Left,
	Door_Border_Right,
	Door_Closed,
	Door_Open,
	Left_Ceiling_Beam,
	Right_Ceiling_Beam,
	Cursor,
}

SPRITE_SRC_RECTS :: [len(Sprite)]zf4.Rect_I {
	Sprite.Player             = {8, 0, 24, 40},
	Sprite.Minion             = {32, 0, 24, 32},
	Sprite.Melee_Enemy        = {0, 40, 24, 40},
	Sprite.Ranger_Enemy       = {24, 40, 24, 32},
	Sprite.Sword              = {64, 1, 32, 6},
	Sprite.Shield             = {48, 32, 8, 32},
	Sprite.Projectile         = {64, 8, 16, 8},
	Sprite.Wall               = {72, 40, 16, 48},
	Sprite.Door_Border_Left   = {88, 40, 16, 48},
	Sprite.Door_Border_Right  = {104, 40, 16, 48},
	Sprite.Door_Closed        = {72, 88, 32, 48},
	Sprite.Door_Open          = {104, 88, 32, 48},
	Sprite.Left_Ceiling_Beam  = {120, 24, 16, 16},
	Sprite.Right_Ceiling_Beam = {136, 24, 16, 16},
	Sprite.Cursor             = {0, 8, 8, 8},
}

Input_Binding :: enum {
	Move_Right,
	Move_Left,
	Move_Down,
	Move_Up,
	Attack,
	Shield,
}

Input_Binding_Setting :: struct {
	code:     int,
	is_mouse: bool,
}

main :: proc() {
	game_info := zf4.Game_Info {
		perm_mem_arena_size                  = mem.Megabyte * 80,
		user_mem_size                        = size_of(Game),
		user_mem_alignment                   = align_of(Game),
		window_init_size                     = {1280, 720},
		window_min_size                      = {1280, 720},
		window_title                         = GAME_TITLE,
		window_flags                         = {
			zf4.Window_Flag.Resizable,
			zf4.Window_Flag.Hide_Cursor,
		},
		tex_cnt                              = len(Texture),
		tex_index_to_file_path_func          = texture_index_to_file_path,
		font_cnt                             = len(Font),
		font_index_to_load_info_func         = font_index_to_load_info,
		shader_prog_cnt                      = len(Shader_Prog),
		shader_prog_index_to_file_paths_func = shader_prog_index_to_file_paths,
		init_func                            = init_game,
		tick_func                            = exec_game_tick,
		draw_func                            = render_game,
		clean_func                           = clean_game,
	}

	zf4.run_game(game_info)
}

init_game :: proc(zf4_data: ^zf4.Game_Init_Func_Data) -> bool {
	game := (^Game)(zf4_data.user_mem)

	game_config_generated: bool
	game.config, game_config_generated = gen_game_config(zf4_data.perm_allocator)

	if !game_config_generated {
		return false
	}

	if !init_title_screen(&game.title_screen, &game.config) {
		return false
	}

	return true
}

exec_game_tick :: proc(zf4_data: ^zf4.Game_Tick_Func_Data) -> bool {
	game := (^Game)(zf4_data.user_mem)

	game.mouse_pos = zf4_data.input_state.mouse_pos

	if !game.in_world {
		ts_tick_res := title_screen_tick(&game.title_screen, &game.config, zf4_data)

		if ts_tick_res == Title_Screen_Tick_Result.Go_To_World {
			clean_title_screen(&game.title_screen)
			game.in_world = true
			init_world(&game.world)
		} else if ts_tick_res == Title_Screen_Tick_Result.Exit_Game {
			zf4_data.exit_game^ = true
		}
	} else {
		world_tick_res := world_tick(&game.world, &game.config, zf4_data)

		if world_tick_res == World_Tick_Result.Go_To_Title {
			clean_world(&game.world)
			game.in_world = false
			init_title_screen(&game.title_screen, &game.config)
		}
	}

	zf4_data.fullscreen_state_ideal^ = game.config.fullscreen

	return true
}

render_game :: proc(zf4_data: ^zf4.Game_Render_Func_Data) -> bool {
	game := (^Game)(zf4_data.user_mem)

	zf4.render_clear({0.2, 0.3, 0.4, 1.0})

	if !game.in_world {
		if !render_title_screen(&game.title_screen, &game.config, zf4_data) {
			return false
		}
	} else {
		if !render_world(&game.world, zf4_data) {
			return false
		}
	}

	zf4.render_texture(
		&zf4_data.rendering_context,
		int(Texture.All),
		zf4_data.textures,
		SPRITE_SRC_RECTS[Sprite.Cursor],
		game.mouse_pos,
	)

	zf4.flush(&zf4_data.rendering_context)

	return true
}

clean_game :: proc(user_mem: rawptr) {
	game := (^Game)(user_mem)

	if !game.in_world {
		clean_title_screen(&game.title_screen)
	} else {
		clean_world(&game.world)
	}
}

texture_index_to_file_path :: proc(index: int) -> string {
	switch Texture(index) {
	case Texture.All:
		return "assets/textures/all.png"

	case:
		return ""
	}
}

font_index_to_load_info :: proc(index: int) -> zf4.Font_Load_Info {
	switch Font(index) {
	case Font.EB_Garamond_32:
		return {"assets/fonts/eb_garamond.ttf", 32}
	case Font.EB_Garamond_40:
		return {"assets/fonts/eb_garamond.ttf", 40}
	case Font.EB_Garamond_48:
		return {"assets/fonts/eb_garamond.ttf", 48}
	case Font.EB_Garamond_64:
		return {"assets/fonts/eb_garamond.ttf", 64}
	case Font.EB_Garamond_96:
		return {"assets/fonts/eb_garamond.ttf", 96}
	case Font.EB_Garamond_128:
		return {"assets/fonts/eb_garamond.ttf", 128}

	case:
		return {}
	}
}

shader_prog_index_to_file_paths :: proc(index: int) -> (string, string) {
	switch Shader_Prog(index) {
	case Shader_Prog.Blend:
		return "assets/shaders/blend.vert", "assets/shaders/blend.frag"

	case:
		return "", ""
	}
}

gen_game_config :: proc(allocator: mem.Allocator) -> (Game_Config, bool) {
	config: Game_Config

	config.screen_shake = 1.0

	config.input_binding_settings = get_default_input_binding_settings()

	config.fullscreen = false

	config.resolutions = gen_resolution_opts(allocator)

	if config.resolutions == nil {
		return config, false
	}

	config.res_index = len(config.resolutions) - 1

	config.master_vol = 1.0
	config.snd_vol = 1.0
	config.music_vol = 1.0
	config.ambience_vol = 1.0

	return config, true
}

get_default_input_binding_settings :: proc() -> [len(Input_Binding)]Input_Binding_Setting {
	settings: [len(Input_Binding)]Input_Binding_Setting

	for i in 0 ..< len(Input_Binding) {
		switch (Input_Binding(i)) {
		case Input_Binding.Move_Right:
			settings[i] = {
				code     = int(zf4.Key_Code.D),
				is_mouse = false,
			}
		case Input_Binding.Move_Left:
			settings[i] = {
				code     = int(zf4.Key_Code.A),
				is_mouse = false,
			}
		case Input_Binding.Move_Down:
			settings[i] = {
				code     = int(zf4.Key_Code.S),
				is_mouse = false,
			}
		case Input_Binding.Move_Up:
			settings[i] = {
				code     = int(zf4.Key_Code.W),
				is_mouse = false,
			}
		case Input_Binding.Attack:
			settings[i] = {
				code     = int(zf4.Mouse_Button_Code.Left),
				is_mouse = true,
			}
		case Input_Binding.Shield:
			settings[i] = {
				code     = int(zf4.Key_Code.Left_Shift),
				is_mouse = false,
			}
		}
	}

	return settings
}

get_input_binding_name :: proc(binding: Input_Binding) -> string {
	switch binding {
	case Input_Binding.Move_Right:
		return "Move Right"
	case Input_Binding.Move_Left:
		return "Move Left"
	case Input_Binding.Move_Down:
		return "Move Down"
	case Input_Binding.Move_Up:
		return "Move Up"
	case Input_Binding.Attack:
		return "Attack"
	case Input_Binding.Shield:
		return "Shield"
	}

	return ""
}

is_input_down :: proc(binding: ^Input_Binding_Setting, input_state: ^zf4.Input_State) -> bool {
	if binding.is_mouse {
		return zf4.is_mouse_button_down(zf4.Mouse_Button_Code(binding.code), input_state)
	} else {
		return zf4.is_key_down(zf4.Key_Code(binding.code), input_state)
	}
}

is_input_pressed :: proc(
	binding: ^Input_Binding_Setting,
	input_state: ^zf4.Input_State,
	input_state_last: ^zf4.Input_State,
) -> bool {
	if binding.is_mouse {
		return zf4.is_mouse_button_pressed(
			zf4.Mouse_Button_Code(binding.code),
			input_state,
			input_state_last,
		)
	} else {
		return zf4.is_key_pressed(zf4.Key_Code(binding.code), input_state, input_state_last)
	}
}

is_input_released :: proc(
	binding: ^Input_Binding_Setting,
	input_state: ^zf4.Input_State,
	input_state_last: ^zf4.Input_State,
) -> bool {
	if binding.is_mouse {
		return zf4.is_mouse_button_released(
			zf4.Mouse_Button_Code(binding.code),
			input_state,
			input_state_last,
		)
	} else {
		return zf4.is_key_released(zf4.Key_Code(binding.code), input_state, input_state_last)
	}
}

gen_resolution_opts :: proc(allocator: mem.Allocator) -> []zf4.Vec_2D_I {
	resolutions := make([]zf4.Vec_2D_I, 2)

	if resolutions != nil {
		// TEMP
		resolutions[0] = {1280, 720}
		resolutions[1] = {1920, 1080}
	}

	return resolutions
}

