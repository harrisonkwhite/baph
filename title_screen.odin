package baph

import "core:fmt"
import "core:mem"
import "zf4"

MEM_ARENA_SIZE :: mem.Megabyte * 2

TITLE_FONT :: Font.EB_Garamond_96
TITLE_Y_PERC :: 0.2

HOME_BUTTON_FONT :: Font.EB_Garamond_48
HOME_BUTTON_CENTER_Y_PERC :: 0.55
HOME_BUTTON_GAP_PERC :: 0.15

OPTIONS_MENU_CATEGORY_BUTTON_FONT :: Font.EB_Garamond_64
OPTIONS_MENU_CATEGORY_BUTTON_GAP_PERC :: 0.15
OPTIONS_MENU_CATEGORY_BUTTON_Y_PERC :: 0.75

OPTIONS_MENU_RETURN_BUTTON_Y_PERC :: 0.9

OPTIONS_MENU_OPT_FONT :: Font.EB_Garamond_40
OPTIONS_MENU_OPT_TOP_Y_PERC :: 0.175
OPTIONS_MENU_OPT_HOR_GAP_PERC :: 0.15
OPTIONS_MENU_OPT_VER_GAP_PERC :: 0.1

Title_Screen :: struct {
	arena_buf:                                   []byte,
	arena:                                       mem.Arena,
	arena_allocator:                             mem.Allocator,
	home_button_hovered_index:                   int,
	options_menu_open:                           bool,
	options_menu_category_selected:              int,
	options_menu_category_button_hovered_index:  int,
	options_menu_category_opts:                  [len(Options_Menu_Category)][]Option,
	options_menu_return_button_hovered:          bool,
	options_menu_opt_interactable_hovered_index: int,
	options_menu_state:                          Options_Menu_State,
}

Title_Screen_Tick_Result :: enum {
	Normal,
	Go_To_World,
	Exit_Game,
}

Home_Button :: enum {
	Play,
	Options,
	Exit,
}

Option :: struct {
	name:      string,
	type_info: Option_Type_Info,
}

Option_Type_Info :: union {
	Toggle_Option_Info,
	List_Option_Info,
	Slider_Option_Info,
	Input_Option_Info,
}

Toggle_Option_Info :: struct {
	set: ^bool,
}

List_Option_Info :: struct {
	index:                ^int,
	cnt:                  int, // NOTE: Another source of truth for array length. Not ideal but solves the problem I guess?
	str_buf_initter_func: proc(buf: []byte, game_config: ^Game_Config),
}

Slider_Option_Info :: struct {
	perc: ^f32,
}

Input_Option_Info :: struct {
	binding_index: int,
}

Options_Menu_State :: enum {
	Normal,
	Dragging_Slider,
	Awaiting_Input,
}

Options_Menu_Category :: enum {
	Gameplay,
	Input,
	Video,
	Audio,
}

init_title_screen :: proc(ts: ^Title_Screen, game_config: ^Game_Config) -> bool {
	assert(ts != nil)
	assert(game_config != nil)

	mem.zero_item(ts)

	arena_buf_alloc_err: mem.Allocator_Error
	ts.arena_buf, arena_buf_alloc_err = mem.alloc_bytes(MEM_ARENA_SIZE)

	if arena_buf_alloc_err != nil {
		return false
	}

	mem.arena_init(&ts.arena, ts.arena_buf)

	ts.arena_allocator = mem.arena_allocator(&ts.arena)

	options_menu_cat_opts_generated: bool
	ts.options_menu_category_opts, options_menu_cat_opts_generated =
		gen_options_menu_category_opts(game_config, ts.arena_allocator)

	ts.home_button_hovered_index = -1
	ts.options_menu_category_button_hovered_index = -1
	ts.options_menu_opt_interactable_hovered_index = -1

	return true
}

title_screen_tick :: proc(
	ts: ^Title_Screen,
	game_config: ^Game_Config,
	zf4_data: ^zf4.Game_Tick_Func_Data,
) -> Title_Screen_Tick_Result {
	tick_res := Title_Screen_Tick_Result.Normal

	//
	// Handle Slider Dragging State
	//
	if ts.options_menu_state == Options_Menu_State.Dragging_Slider {
		if (zf4.is_mouse_button_released(
				   zf4.Mouse_Button_Code.Left,
				   zf4_data.input_state,
				   zf4_data.input_state_last,
			   )) {
			ts.options_menu_opt_interactable_hovered_index = -1
			ts.options_menu_state = Options_Menu_State.Normal
		} else {
			opts := ts.options_menu_category_opts[ts.options_menu_category_selected]
			slider_opt_info := opts[ts.options_menu_opt_interactable_hovered_index].type_info.(Slider_Option_Info)

			opt_slider := gen_options_menu_opt_slider(
				ts.options_menu_opt_interactable_hovered_index,
				opts,
				zf4_data.window_state_cache.size,
			)

			slider_left := opt_slider.pos.x - (opt_slider.bar_size.x / 2.0)

			mouse_x_clamped_within_slider := clamp(
				zf4_data.input_state.mouse_pos.x,
				slider_left,
				opt_slider.pos.x + (opt_slider.bar_size.x / 2.0),
			)

			slider_opt_info.perc^ =
				(mouse_x_clamped_within_slider - slider_left) / opt_slider.bar_size.x

			return tick_res
		}
	}

	//
	// Handle Awaiting Input State
	//

	// BUG: When awaiting input and you click where a button is, interaction with that button is triggered.

	if ts.options_menu_state == Options_Menu_State.Awaiting_Input {
		opts := ts.options_menu_category_opts[ts.options_menu_category_selected]
		input_opt_info := opts[ts.options_menu_opt_interactable_hovered_index].type_info.(Input_Option_Info)

		binding_setting := load_input_binding_setting_from_input(
			zf4_data.input_state,
			zf4_data.input_state_last,
		)

		if binding_setting != {} {
			for i in 0 ..< len(Input_Binding) {
				if binding_setting == game_config.input_binding_settings[i] {
					game_config.input_binding_settings[i] = {}
				}
			}

			game_config.input_binding_settings[input_opt_info.binding_index] = binding_setting
			ts.options_menu_state = Options_Menu_State.Normal
		} else {
			return tick_res
		}
	}

	//
	// Determine Hovered Interactable States
	//
	ts.home_button_hovered_index = -1
	ts.options_menu_category_button_hovered_index = -1
	ts.options_menu_return_button_hovered = false
	ts.options_menu_opt_interactable_hovered_index = -1

	if !ts.options_menu_open {
		home_btns := gen_home_buttons(zf4_data.window_state_cache.size)

		for i in 0 ..< len(home_btns) {
			if is_button_hovered(&home_btns[i], zf4_data.input_state.mouse_pos, zf4_data.fonts) {
				ts.home_button_hovered_index = i
			}
		}
	} else {
		// Check for category button hovering.
		options_menu_cat_btns := gen_options_menu_category_buttons(
			zf4_data.window_state_cache.size,
		)

		for i in 0 ..< len(options_menu_cat_btns) {
			if is_button_hovered(
				&options_menu_cat_btns[i],
				zf4_data.input_state.mouse_pos,
				zf4_data.fonts,
			) {
				ts.options_menu_category_button_hovered_index = i
			}
		}

		// Check for return button hovering.
		return_btn := gen_options_menu_return_button(zf4_data.window_state_cache.size)

		if is_button_hovered(&return_btn, zf4_data.input_state.mouse_pos, zf4_data.fonts) {
			ts.options_menu_return_button_hovered = true
		}

		// Check for option interactables hovering.
		opts := ts.options_menu_category_opts[ts.options_menu_category_selected]

		for i in 0 ..< len(opts) {
			switch _ in opts[i].type_info {
			case Toggle_Option_Info, List_Option_Info, Input_Option_Info:
				opt_btn := gen_options_menu_opt_button(
					i,
					opts,
					zf4_data.window_state_cache.size,
					game_config,
				)

				if is_button_hovered(&opt_btn, zf4_data.input_state.mouse_pos, zf4_data.fonts) {
					ts.options_menu_opt_interactable_hovered_index = i
				}

			case Slider_Option_Info:
				opt_slider := gen_options_menu_opt_slider(
					i,
					opts,
					zf4_data.window_state_cache.size,
				)

				if is_slider_hovered(&opt_slider, zf4_data.input_state.mouse_pos) {
					ts.options_menu_opt_interactable_hovered_index = i
				}
			}
		}
	}

	//
	// Handle Click Event
	//
	if (zf4.is_mouse_button_pressed(
			   zf4.Mouse_Button_Code.Left,
			   zf4_data.input_state,
			   zf4_data.input_state_last,
		   )) {
		if ts.home_button_hovered_index != -1 {
			switch (Home_Button(ts.home_button_hovered_index)) {
			case Home_Button.Play:
				tick_res = Title_Screen_Tick_Result.Go_To_World
			case Home_Button.Options:
				ts.options_menu_open = true
			case Home_Button.Exit:
				tick_res = Title_Screen_Tick_Result.Exit_Game
			}
		}

		if ts.options_menu_category_button_hovered_index != -1 {
			ts.options_menu_category_selected = ts.options_menu_category_button_hovered_index
		}

		if ts.options_menu_return_button_hovered {
			ts.options_menu_open = false
		}

		opts := &ts.options_menu_category_opts[ts.options_menu_category_selected]

		if ts.options_menu_opt_interactable_hovered_index != -1 {
			opt := &opts[ts.options_menu_opt_interactable_hovered_index]

			switch type_info in opt.type_info {
			case Toggle_Option_Info:
				type_info.set^ = !(type_info.set^)
			case List_Option_Info:
				type_info.index^ = (type_info.index^ + 1) % type_info.cnt
			case Slider_Option_Info:
				ts.options_menu_state = Options_Menu_State.Dragging_Slider
			case Input_Option_Info:
				ts.options_menu_state = Options_Menu_State.Awaiting_Input
			}
		}
	}

	return tick_res
}

render_title_screen :: proc(
	ts: ^Title_Screen,
	game_config: ^Game_Config,
	zf4_data: ^zf4.Game_Render_Func_Data,
) -> bool {
	if !ts.options_menu_open {
		title_pos := zf4.Vec_2D {
			f32(zf4_data.rendering_context.display_size.x) / 2.0,
			f32(zf4_data.rendering_context.display_size.y) * TITLE_Y_PERC,
		}

		zf4.render_str(
			&zf4_data.rendering_context,
			GAME_TITLE,
			int(TITLE_FONT),
			zf4_data.fonts,
			title_pos,
		)

		home_btns := gen_home_buttons(zf4_data.rendering_context.display_size)

		for i in 0 ..< len(home_btns) {
			render_button(
				&zf4_data.rendering_context,
				&home_btns[i],
				ts.home_button_hovered_index == i,
				zf4_data.fonts,
			)
		}
	} else {
		category_btns := gen_options_menu_category_buttons(zf4_data.rendering_context.display_size)

		for i in 0 ..< len(category_btns) {
			render_button(
				&zf4_data.rendering_context,
				&category_btns[i],
				ts.options_menu_category_selected == i ||
				ts.options_menu_category_button_hovered_index == i,
				zf4_data.fonts,
			)
		}

		return_btn := gen_options_menu_return_button(zf4_data.rendering_context.display_size)
		render_button(
			&zf4_data.rendering_context,
			&return_btn,
			ts.options_menu_return_button_hovered,
			zf4_data.fonts,
		)

		opts := &ts.options_menu_category_opts[ts.options_menu_category_selected]

		for i in 0 ..< len(opts) {
			pos_base := zf4.Vec_2D {
				f32(zf4_data.rendering_context.display_size.x / 2.0),
				f32(zf4_data.rendering_context.display_size.y) *
				(OPTIONS_MENU_OPT_TOP_Y_PERC + (f32(i) * OPTIONS_MENU_OPT_VER_GAP_PERC)),
			}

			pos_hor_offs_size := f32(zf4_data.rendering_context.display_size.x) * 0.15

			zf4.render_str(
				&zf4_data.rendering_context,
				opts[i].name,
				int(OPTIONS_MENU_OPT_FONT),
				zf4_data.fonts,
				pos_base - {pos_hor_offs_size, 0.0},
			)

			switch opt_type in opts[i].type_info {
			case Toggle_Option_Info, List_Option_Info, Input_Option_Info:
				btn := gen_options_menu_opt_button(
					i,
					opts^,
					zf4_data.rendering_context.display_size,
					game_config,
				)
				render_button(
					&zf4_data.rendering_context,
					&btn,
					ts.options_menu_opt_interactable_hovered_index == i,
					zf4_data.fonts,
				)

			case Slider_Option_Info:
				slider := gen_options_menu_opt_slider(
					i,
					opts^,
					zf4_data.rendering_context.display_size,
				)
				render_slider(&zf4_data.rendering_context, &slider)

				str_buf: [5]byte
				str := fmt.bprintf(str_buf[:], "%d%%", int(slider.perc * 100.0))

				zf4.render_str(
					&zf4_data.rendering_context,
					str,
					int(Font.EB_Garamond_40),
					zf4_data.fonts,
					slider.pos + {(slider.bar_size.x / 2.0) + 16.0, 0.0},
					zf4.Str_Hor_Align.Left,
				)
			}
		}
	}

	return true
}

clean_title_screen :: proc(ts: ^Title_Screen) {
	if (len(ts.arena_buf) > 0) {
		mem.free_bytes(ts.arena_buf)
	}
}

gen_home_buttons :: proc(display_size: zf4.Vec_2D_I) -> [len(Home_Button)]Button {
	buttons: [len(Home_Button)]Button

	gap := f32(display_size.y) * HOME_BUTTON_GAP_PERC
	ver_span := gap * (len(Home_Button) - 1)
	base_pos := zf4.Vec_2D {
		f32(display_size.x) / 2.0,
		(f32(display_size.y) * HOME_BUTTON_CENTER_Y_PERC) - (ver_span / 2.0),
	}

	for i in 0 ..< len(buttons) {
		buttons[i] = {
			pos        = base_pos + {0.0, gap * f32(i)},
			font_index = int(HOME_BUTTON_FONT),
			hor_align  = zf4.Str_Hor_Align.Center,
			ver_align  = zf4.Str_Ver_Align.Center,
		}

		switch Home_Button(i) {
		case Home_Button.Play:
			fmt.bprint(buttons[i].str_buf[:], "Play")
		case Home_Button.Options:
			fmt.bprint(buttons[i].str_buf[:], "Options")
		case Home_Button.Exit:
			fmt.bprint(buttons[i].str_buf[:], "Exit")
		}
	}

	return buttons
}

gen_options_menu_category_buttons :: proc(
	display_size: zf4.Vec_2D_I,
) -> [len(Options_Menu_Category)]Button {
	buttons: [len(Options_Menu_Category)]Button

	hor_gap := f32(display_size.x) * OPTIONS_MENU_CATEGORY_BUTTON_GAP_PERC
	hor_span := hor_gap * (len(buttons) - 1)
	base_pos := zf4.Vec_2D {
		(f32(display_size.x) - hor_span) / 2.0,
		f32(display_size.y) * OPTIONS_MENU_CATEGORY_BUTTON_Y_PERC,
	}

	for i in 0 ..< len(buttons) {
		buttons[i] = {
			pos        = base_pos + {f32(i) * hor_gap, 0.0},
			font_index = int(OPTIONS_MENU_CATEGORY_BUTTON_FONT),
			hor_align  = zf4.Str_Hor_Align.Center,
			ver_align  = zf4.Str_Ver_Align.Center,
		}

		switch Options_Menu_Category(i) {
		case Options_Menu_Category.Gameplay:
			fmt.bprint(buttons[i].str_buf[:], "Gameplay")
		case Options_Menu_Category.Input:
			fmt.bprint(buttons[i].str_buf[:], "Input")
		case Options_Menu_Category.Video:
			fmt.bprint(buttons[i].str_buf[:], "Video")
		case Options_Menu_Category.Audio:
			fmt.bprint(buttons[i].str_buf[:], "Audio")
		}
	}

	return buttons
}

gen_options_menu_return_button :: proc(display_size: zf4.Vec_2D_I) -> Button {
	btn := Button {
		pos        = {
			f32(display_size.x) / 2.0,
			f32(display_size.y) * OPTIONS_MENU_RETURN_BUTTON_Y_PERC,
		},
		font_index = int(HOME_BUTTON_FONT),
		hor_align  = zf4.Str_Hor_Align.Center,
		ver_align  = zf4.Str_Ver_Align.Center,
	}

	fmt.bprint(btn.str_buf[:], "Return")

	return btn
}

gen_options_menu_category_opts :: proc(
	game_config: ^Game_Config,
	allocator := context.allocator,
) -> (
	[len(Options_Menu_Category)][]Option,
	bool,
) {
	category_opts: [len(Options_Menu_Category)][]Option

	for i in 0 ..< len(Options_Menu_Category) {
		opt_cnt: int

		switch Options_Menu_Category(i) {
		case Options_Menu_Category.Gameplay:
			opt_cnt = 1
		case Options_Menu_Category.Input:
			opt_cnt = len(Input_Binding)
		case Options_Menu_Category.Video:
			opt_cnt = 2
		case Options_Menu_Category.Audio:
			opt_cnt = 4
		}

		category_opts[i] = make_slice([]Option, opt_cnt, allocator)

		if category_opts[i] == nil {
			return category_opts, false
		}

		switch Options_Menu_Category(i) {
		case Options_Menu_Category.Gameplay:
			category_opts[i][0] = {
				name = "Screen Shake",
				type_info = Slider_Option_Info{perc = &game_config.screen_shake},
			}

		case Options_Menu_Category.Input:
			for j in 0 ..< len(Input_Binding) {
				category_opts[i][j] = {
					name = get_input_binding_name(Input_Binding(j)),
					type_info = Input_Option_Info{binding_index = j},
				}
			}

		case Options_Menu_Category.Video:
			category_opts[i][0] = {
				name = "Fullscreen",
				type_info = Toggle_Option_Info{set = &game_config.fullscreen},
			}

			category_opts[i][1] = {
				name = "Resolution",
				type_info = List_Option_Info {
					index = &game_config.res_index,
					cnt = len(game_config.resolutions),
					str_buf_initter_func = proc(buf: []byte, game_config: ^Game_Config) {
						res := game_config.resolutions[game_config.res_index]
						fmt.bprintf(buf, "%dx%d", res.x, res.y)
					},
				},
			}

		case Options_Menu_Category.Audio:
			category_opts[i][0] = {
				name = "Master Volume",
				type_info = Slider_Option_Info{perc = &game_config.master_vol},
			}

			category_opts[i][1] = {
				name = "Sound Volume",
				type_info = Slider_Option_Info{perc = &game_config.snd_vol},
			}

			category_opts[i][2] = {
				name = "Music Volume",
				type_info = Slider_Option_Info{perc = &game_config.music_vol},
			}

			category_opts[i][3] = {
				name = "Ambience Volume",
				type_info = Slider_Option_Info{perc = &game_config.ambience_vol},
			}
		}
	}

	return category_opts, true
}

calc_options_menu_opt_thing_pos :: proc(
	opt_index: int,
	display_size: zf4.Vec_2D_I,
	right: bool,
) -> zf4.Vec_2D {
	hor_perc: f32 = 0.5 + (OPTIONS_MENU_OPT_HOR_GAP_PERC * (right ? 1.0 : -1.0))

	return {
		f32(display_size.x) * hor_perc,
		f32(display_size.y) *
		(OPTIONS_MENU_OPT_TOP_Y_PERC + (f32(opt_index) * OPTIONS_MENU_OPT_VER_GAP_PERC)),
	}
}

gen_options_menu_opt_button :: proc(
	opt_index: int,
	opts: []Option,
	display_size: zf4.Vec_2D_I,
	game_config: ^Game_Config,
) -> Button {
	btn := Button {
		pos        = calc_options_menu_opt_thing_pos(opt_index, display_size, true),
		font_index = int(OPTIONS_MENU_OPT_FONT),
		hor_align  = zf4.Str_Hor_Align.Center,
		ver_align  = zf4.Str_Ver_Align.Center,
	}

	switch type_info in opts[opt_index].type_info {
	case Toggle_Option_Info:
		fmt.bprintf(btn.str_buf[:], type_info.set^ ? "Enabled" : "Disabled")
	case List_Option_Info:
		type_info.str_buf_initter_func(btn.str_buf[:], game_config)
	case Slider_Option_Info:
		assert(false, "Attempting to generate a button of a slider option.")
	case Input_Option_Info:
		binding_setting := game_config.input_binding_settings[type_info.binding_index]

		if binding_setting.is_mouse {
			fmt.bprintf(
				btn.str_buf[:],
				zf4.get_mouse_button_code_name(zf4.Mouse_Button_Code(binding_setting.code)),
			)
		} else {
			fmt.bprintf(btn.str_buf[:], zf4.get_key_code_name(zf4.Key_Code(binding_setting.code)))
		}
	}

	return btn
}

gen_options_menu_opt_slider :: proc(
	opt_index: int,
	opts: []Option,
	display_size: zf4.Vec_2D_I,
) -> Slider {
	slider := Slider {
		pos      = calc_options_menu_opt_thing_pos(opt_index, display_size, true),
		bar_size = {f32(display_size.x) * 0.1, 6.0},
	}

	slider.ball_size = slider.bar_size.y * 2.0

	slider_opt_type := opts[opt_index].type_info.(Slider_Option_Info)
	slider.perc = slider_opt_type.perc^

	return slider
}

load_input_binding_setting_from_input :: proc(
	input_state: ^zf4.Input_State,
	input_state_last: ^zf4.Input_State,
) -> Input_Binding_Setting {
	for i in 0 ..< len(zf4.Key_Code) {
		if (zf4.is_key_pressed(zf4.Key_Code(i), input_state, input_state_last)) {
			return {code = i, is_mouse = false}
		}
	}

	for i in 0 ..< len(zf4.Mouse_Button_Code) {
		if (zf4.is_mouse_button_pressed(zf4.Mouse_Button_Code(i), input_state, input_state_last)) {
			return {code = i, is_mouse = true}
		}
	}

	return {}
}

