package sanctus

import "core:fmt"
import "zf4"

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

Game :: struct {
	config:       Game_Config,
	in_level:     bool,
	title_screen: Title_Screen,
	level:        Level,
}

Game_Config :: struct {
	a: int,
}

Texture :: enum {
	All,
}

game: Game

texture_index_to_file_path :: proc(index: i32) -> cstring {
	switch Texture(index) {
	case Texture.All:
		return "assets/textures/all.png"

	case:
		return nil
	}
}

init_game :: proc(func_data: ^zf4.Game_Init_Func_Data) -> bool {
	return true
}

exec_game_tick :: proc(func_data: ^zf4.Game_Tick_Func_Data) -> bool {
	level_tick(&game.level, func_data)
	/*if !in_level {
		exec_title_screen_tick(&title_screen)
	}*/

	return true
}

draw_game :: proc(func_data: ^zf4.Game_Draw_Func_Data) -> bool {
	zf4.draw_clear({0.2, 0.3, 0.4, 1.0})

	if !draw_level(&game.level, func_data) {
		return false
	}

	zf4.flush(func_data.draw_phase_state, func_data.pers_render_data)

	return true
}

main :: proc() {
	game_info := zf4.Game_Info {
		perm_mem_arena_size    = 1,
		temp_mem_arena_size    = 1,
		window_init_size       = {1280, 720},
		window_title           = "Sanctus",
		tex_cnt                = len(Texture),
		tex_index_to_file_path = texture_index_to_file_path,
		init_func              = init_game,
		tick_func              = exec_game_tick,
		draw_func              = draw_game,
	}

	zf4.run_game(game_info)
}

