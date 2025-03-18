package sanctus

import "core:fmt"
import "core:mem"
import "zf4"

Game :: struct {
	config:       Game_Config,
	in_level:     bool,
	title_screen: Title_Screen,
	level:        Level,
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

Sprite :: enum {
	Player,
	Melee_Enemy,
	Ranger_Enemy,
	Sword,
	Shield,
	Projectile,
	Wall,
	Door_Left,
	Door_Right,
	Left_Ceiling_Beam,
	Right_Ceiling_Beam,
	Cursor,
}

SPRITE_SRC_RECTS :: [?]zf4.Rect_I {
	{8, 0, 24, 40},
	{0, 40, 24, 40},
	{24, 40, 24, 32},
	{64, 1, 32, 6},
	{48, 32, 8, 32},
	{64, 8, 16, 8},
	{72, 40, 16, 48},
	{88, 40, 16, 48},
	{104, 40, 16, 48},
	{120, 24, 16, 64},
	{136, 24, 16, 64},
	{0, 8, 8, 8},
}

Input_Binding :: enum {
	Move_Right,
	Move_Left,
	Move_Down,
	Move_Up,
	Attack,
}

Input_Binding_Setting :: struct {
	code:     int,
	is_mouse: bool,
}

main :: proc() {
	game_info := zf4.Game_Info {
		perm_mem_arena_size          = mem.Megabyte * 80,
		temp_mem_arena_size          = mem.Megabyte * 40,
		user_mem_size                = size_of(Game),
		user_mem_alignment           = align_of(Game),
		window_init_size             = {1280, 720},
		window_title                 = "Sanctus",
		tex_cnt                      = len(Texture),
		tex_index_to_file_path_func  = texture_index_to_file_path,
		font_cnt                     = len(Font),
		font_index_to_load_info_func = font_index_to_load_info,
		init_func                    = init_game,
		tick_func                    = exec_game_tick,
		draw_func                    = render_game,
		clean_func                   = clean_game,
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

	if !game.in_level {
		ts_tick_res := title_screen_tick(&game.title_screen, &game.config, zf4_data)

		if ts_tick_res == Title_Screen_Tick_Result.Go_To_Level {
			clean_title_screen(&game.title_screen)
			game.in_level = true
			init_level(&game.level)
		} else if ts_tick_res == Title_Screen_Tick_Result.Exit_Game {
			zf4_data.exit_game^ = true
		}
	} else {
		if (!level_tick(&game.level, zf4_data)) {
			return false
		}
	}

	return true
}

render_game :: proc(zf4_data: ^zf4.Game_Render_Func_Data) -> bool {
	game := (^Game)(zf4_data.user_mem)

	zf4.render_clear({0.2, 0.3, 0.4, 1.0})

	if !game.in_level {
		if !render_title_screen(&game.title_screen, &game.config, zf4_data) {
			return false
		}
	} else {
		if !render_level(&game.level, zf4_data) {
			return false
		}
	}

	zf4.flush(&zf4_data.rendering_context)

	return true
}

clean_game :: proc(user_mem: rawptr) {
	game := (^Game)(user_mem)

	if !game.in_level {
		clean_title_screen(&game.title_screen)
	} else {
		clean_level(&game.level)
	}
}

texture_index_to_file_path :: proc(index: int) -> cstring {
	switch Texture(index) {
	case Texture.All:
		return "assets/textures/all.png"

	case:
		return nil
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
	}

	return ""
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

