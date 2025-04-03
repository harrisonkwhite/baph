package apocalypse

import "core:math/rand"
import "zf4"

BUILDING_TILE_SIZE :: 16

Building_Info :: struct {
	rect:   zf4.Rect_I,
	door_x: int,
}

Building_Environmental :: struct {
	type: Building_Environmental_Type,
	pos:  zf4.Vec_2D,
	open: bool, // Only used for doors.
}

Building_Environmental_Type :: enum {
	Wall,
	Door_Border_Left,
	Door_Border_Right,
	Door,
	Left_Ceiling_Beam,
	Right_Ceiling_Beam,
}

gen_building_infos :: proc(
	cnt_hor: int,
	cnt_ver: int,
	allocator := context.allocator,
) -> []Building_Info {
	assert(cnt_hor > 0)
	assert(cnt_ver > 0)

	// NOTE: All very much temporary. Not sure how actual world generation will work yet.
	infos := make([]Building_Info, cnt_hor * cnt_ver, allocator)

	if infos != nil {
		for y in 0 ..< cnt_ver {
			for x in 0 ..< cnt_hor {
				info := &infos[(y * cnt_hor) + x]

				info.rect.x = x * 20
				info.rect.y = y * 20
				info.rect.width = int(rand.float32_range(8.0, 11.0))
				info.rect.height = int(rand.float32_range(4.0, 6.0))
				info.door_x = int(rand.float32_range(1.0, f32(info.rect.width) - 2.0))
			}
		}
	}

	return infos
}

gen_buildings :: proc(
	infos: []Building_Info,
	allocator := context.allocator,
) -> []Building_Environmental {
	envs := make([]Building_Environmental, calc_building_env_cnt(infos))

	if envs != nil {
		env_cnter := 0

		for &bi in infos {
			// Generate back.
			for xo in 0 ..< bi.rect.width {
				envs[env_cnter] = {
					type = Building_Environmental_Type.Wall,
					pos  = zf4.Vec_2D{f32(bi.rect.x + xo), f32(bi.rect.y)} * BUILDING_TILE_SIZE,
				}
				env_cnter += 1
			}

			// Generate front.
			for xo in 0 ..< bi.rect.width {
				envs[env_cnter] = {
					type = Building_Environmental_Type.Wall,
					pos  = zf4.Vec_2D {
						f32(bi.rect.x + xo),
						f32(bi.rect.y + bi.rect.height),
					} * BUILDING_TILE_SIZE,
				}

				if xo == bi.door_x {
					envs[env_cnter].type = Building_Environmental_Type.Door_Border_Left
				} else if xo == bi.door_x + 1 {
					envs[env_cnter].type = Building_Environmental_Type.Door_Border_Right
				}

				env_cnter += 1
			}

			envs[env_cnter] = {
				type = Building_Environmental_Type.Door,
				pos  = zf4.Vec_2D {
					f32(bi.rect.x + bi.door_x),
					f32(bi.rect.y + bi.rect.height),
				} * BUILDING_TILE_SIZE,
			}

			env_cnter += 1

			// Generate ceiling beams.
			for yo in 0 ..< bi.rect.height {
				left_ceiling_beam := Building_Environmental {
					type = Building_Environmental_Type.Left_Ceiling_Beam,
					pos  = zf4.Vec_2D{f32(bi.rect.x), f32(bi.rect.y + yo)} * BUILDING_TILE_SIZE,
				}

				envs[env_cnter] = left_ceiling_beam
				env_cnter += 1

				right_ceiling_beam := Building_Environmental {
					type = Building_Environmental_Type.Right_Ceiling_Beam,
					pos  = zf4.Vec_2D {
						f32(bi.rect.x + bi.rect.width - 1),
						f32(bi.rect.y + yo),
					} * BUILDING_TILE_SIZE,
				}

				envs[env_cnter] = right_ceiling_beam
				env_cnter += 1
			}
		}

		assert(env_cnter == len(envs)) // Make sure we haven't overestimated how much space was needed.
	}

	return envs
}

calc_building_env_cnt :: proc(infos: []Building_Info) -> int {
	cnt := 0

	for &info in infos {
		assert_building_info_validity(&info)
		cnt += (info.rect.width * 2) + (info.rect.height * 2) + 1
	}

	return cnt
}

door_interaction :: proc(world: ^World, zf4_data: ^zf4.Game_Tick_Func_Data) {
	if !world.player.active {
		return
	}

	if zf4.is_key_pressed(zf4.Key_Code.E, zf4_data.input_state, zf4_data.input_state_last) {
		player_dmg_collider := gen_player_damage_collider(world.player.pos)
		sprite_src_rects := SPRITE_SRC_RECTS

		for &env in world.building_envs {
			assert_building_env_validity(&env)

			if env.type != Building_Environmental_Type.Door {
				continue
			}

			door_collider := gen_collider_from_sprite(Sprite.Door_Closed, env.pos, {0.0, 1.0})

			if zf4.do_rects_inters(player_dmg_collider, door_collider) {
				env.open = !env.open
			}
		}
	}
}

append_building_env_render_tasks :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	envs: []Building_Environmental,
) -> bool {
	sprite_src_rects := SPRITE_SRC_RECTS

	for &env in envs {
		assert_building_env_validity(&env)

		task := World_Layered_Render_Task {
			pos        = env.pos,
			scale      = {1.0, 1.0},
			rot        = 0.0,
			alpha      = 1.0,
			sort_depth = env.pos.y,
		}

		elevation := 0 // TEMP?

		switch env.type {
		case .Wall:
			task.sprite = Sprite.Wall
			task.origin = {0.0, 1.0}
		case .Door_Border_Left:
			task.sprite = Sprite.Door_Border_Left
			task.origin = {0.0, 1.0}
		case .Door_Border_Right:
			task.sprite = Sprite.Door_Border_Right
			task.origin = {0.0, 1.0}
		case .Door:
			task.sprite = env.open ? Sprite.Door_Open : Sprite.Door_Closed
			task.origin = {0.0, 1.0}
		case .Left_Ceiling_Beam:
			task.sprite = Sprite.Left_Ceiling_Beam
			elevation = sprite_src_rects[Sprite.Wall].height / BUILDING_TILE_SIZE
		case .Right_Ceiling_Beam:
			task.sprite = Sprite.Right_Ceiling_Beam
			elevation = sprite_src_rects[Sprite.Wall].height / BUILDING_TILE_SIZE
		}

		task.pos.y -= f32(BUILDING_TILE_SIZE * elevation)

		if _, err := append(tasks, task); err != nil {
			return false
		}
	}

	return true
}

assert_building_info_validity :: proc(info: ^Building_Info) {
	assert(info.rect.width > 0 && info.rect.height > 0)
	assert(info.door_x > 0 && info.door_x < info.rect.width - 2)
}

assert_building_env_validity :: proc(env: ^Building_Environmental) {
	assert(env.type == Building_Environmental_Type.Door || !env.open)
}

