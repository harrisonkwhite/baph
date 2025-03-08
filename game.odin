package apocalypse

import "core:fmt"
import "zf4"

init_game :: proc(zf4_data: zf4.Game_Init_Func_Data) -> bool {
    return true
}

game_tick :: proc(zf4_data: zf4.Game_Tick_Func_Data) -> bool {
    return true
}

main :: proc() {
	game_info := zf4.Game_Info {
		perm_mem_arena_size = 1,
		temp_mem_arena_size = 1,
        
		window_init_size    = {1280, 720},
		window_title        = "Apocalypse",

        init_func           = init_game,
        tick_func           = game_tick
	}

	zf4.run_game(game_info)
}
