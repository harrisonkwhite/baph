package apocalypse

import "core:mem"
import "zf4"

BUTTON_HOVERED_COLOR := zf4.YELLOW
BUTTON_EMPTY_STR := "None"
BUTTON_EMPTY_COLOR := zf4.GRAY

SLIDER_BAR_COLOR := zf4.GRAY
SLIDER_BALL_COLOR := zf4.WHITE

Button :: struct {
	pos:        zf4.Vec_2D,
	str_buf:    [32]byte,
	font_index: int,
	hor_align:  zf4.Str_Hor_Align,
	ver_align:  zf4.Str_Ver_Align,
}

Slider :: struct {
	pos:       zf4.Vec_2D,
	bar_size:  zf4.Vec_2D,
	ball_size: f32,
	perc:      f32,
}

/*calc_str_len_until_nt :: proc(buf: []u8) -> int {
	for i in 0 ..< len(buf) {
		if buf[i] == 0 {
			return i
		}
	}

	return len(buf)
}*/

is_button_hovered :: proc(btn: ^Button, mouse_pos: zf4.Vec_2D, fonts: ^zf4.Fonts) -> bool {
	str_collider := zf4.gen_str_collider(
		!mem.check_zero(btn.str_buf[:]) ? string(btn.str_buf[:]) : BUTTON_EMPTY_STR,
		btn.font_index,
		fonts,
		btn.pos,
		btn.hor_align,
		btn.ver_align,
	)

	return zf4.is_point_in_rect(mouse_pos, str_collider)
}

/*index_of_first_hovered_button :: proc(
	buttons: []Button,
	mouse_pos: zf4.Vec_2D,
	fonts: ^zf4.Fonts,
) -> int {
	for btn in buttons {
		if is_button_hovered(btn, mouse_pos, fonts) {
			return i
		}
	}

	return -1
}*/

import "core:fmt"

render_button :: proc(
	rendering_context: ^zf4.Rendering_Context,
	btn: ^Button,
	hovered: bool,
	fonts: ^zf4.Fonts,
) {
	str := string(btn.str_buf[:])

	blend := zf4.WHITE

	if mem.check_zero(btn.str_buf[:]) {
		str = BUTTON_EMPTY_STR
		blend = BUTTON_EMPTY_COLOR
	}

	if hovered {
		blend = BUTTON_HOVERED_COLOR
	}

	zf4.render_str(
		rendering_context,
		str,
		btn.font_index,
		fonts,
		btn.pos,
		btn.hor_align,
		btn.ver_align,
		blend,
	)
}

is_slider_valid :: proc(slider: ^Slider) -> bool {
	return(
		slider.bar_size.x > 0.0 &&
		slider.bar_size.y > 0.0 &&
		slider.ball_size > 0.0 &&
		slider.ball_size >= slider.bar_size.y &&
		slider.perc >= 0.0 &&
		slider.perc <= 1.0 \
	)
}

is_slider_hovered :: proc(slider: ^Slider, mouse_pos: zf4.Vec_2D) -> bool {
	assert(is_slider_valid(slider))

	ball_x := calc_slider_ball_x(slider)

	x_min := min(slider.pos.x - (slider.bar_size.x / 2.0), ball_x - (slider.ball_size / 2.0))
	x_max := max(slider.pos.x + (slider.bar_size.x / 2.0), ball_x + (slider.ball_size / 2.0))

	collider := zf4.Rect {
		x_min,
		slider.pos.y - (slider.ball_size / 2.0),
		x_max - x_min,
		slider.ball_size,
	}

	return zf4.is_point_in_rect(mouse_pos, collider)
}

calc_slider_ball_x :: proc(slider: ^Slider) -> f32 {
	assert(is_slider_valid(slider))
	return slider.pos.x + (slider.bar_size.x * (-0.5 + slider.perc))
}

render_slider :: proc(rendering_context: ^zf4.Rendering_Context, slider: ^Slider) {
	assert(is_slider_valid(slider))

	// Slider
	slider_left_center := slider.pos - {slider.bar_size.x / 2.0, 0.0}

	slider_bar_rect := zf4.Rect {
		slider_left_center.x,
		slider_left_center.y - (slider.bar_size.y / 2.0),
		slider.bar_size.x,
		slider.bar_size.y,
	}

	zf4.render_rect(rendering_context, slider_bar_rect, SLIDER_BAR_COLOR)

	// Ball
	slider_ball_pos := slider_left_center + {slider.bar_size.x * slider.perc, 0.0}
	slider_ball_rect := zf4.Rect {
		slider_ball_pos.x - (slider.ball_size / 2.0),
		slider_ball_pos.y - (slider.ball_size / 2.0),
		slider.ball_size,
		slider.ball_size,
	}

	zf4.render_rect(rendering_context, slider_ball_rect, SLIDER_BALL_COLOR)
}

