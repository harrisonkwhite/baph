package apocalypse

import "core:math/rand"
import "zf4"

BUILDING_TILE_SIZE :: 16

Building :: struct {
	rect:      zf4.Rect_I,
	door_x:    int,
	door_open: bool,
	// TODO: Ceiling hidden state?
}

append_building_solid_colliders :: proc(
	colliders: ^[dynamic]zf4.Rect,
	building: ^Building,
) -> bool {
	COLLIDER_THICKNESS := 4

	// Generate back collider.
	back_collider := zf4.Rect {
		f32(building.rect.x * BUILDING_TILE_SIZE),
		f32((building.rect.y * BUILDING_TILE_SIZE) - COLLIDER_THICKNESS),
		f32(building.rect.width * BUILDING_TILE_SIZE),
		f32(COLLIDER_THICKNESS),
	}

	if _, err := append(colliders, back_collider); err != nil {
		return false
	}

	// Generate front colliders.
	{
		left_front_collider := zf4.Rect {
			f32(building.rect.x * BUILDING_TILE_SIZE),
			f32((zf4.calc_rect_i_bottom(building.rect) * BUILDING_TILE_SIZE) - COLLIDER_THICKNESS),
			f32(building.door_x * BUILDING_TILE_SIZE),
			f32(COLLIDER_THICKNESS),
		}

		if _, err := append(colliders, left_front_collider); err != nil {
			return false
		}

		right_front_collider := zf4.Rect {
			f32((building.rect.x + building.door_x + 2) * BUILDING_TILE_SIZE),
			f32((zf4.calc_rect_i_bottom(building.rect) * BUILDING_TILE_SIZE) - COLLIDER_THICKNESS),
			f32((building.rect.width - building.door_x - 2) * BUILDING_TILE_SIZE),
			f32(COLLIDER_THICKNESS),
		}

		if _, err := append(colliders, right_front_collider); err != nil {
			return false
		}

		if !building.door_open {
			door_collider := zf4.Rect {
				f32((building.rect.x + building.door_x) * BUILDING_TILE_SIZE),
				f32(
					(zf4.calc_rect_i_bottom(building.rect) * BUILDING_TILE_SIZE) -
					COLLIDER_THICKNESS,
				),
				f32(2 * BUILDING_TILE_SIZE),
				f32(COLLIDER_THICKNESS),
			}

			if _, err := append(colliders, door_collider); err != nil {
				return false
			}
		}
	}

	// Generate side colliders.
	{
		left_side_collider := zf4.Rect {
			f32(building.rect.x * BUILDING_TILE_SIZE),
			f32(building.rect.y * BUILDING_TILE_SIZE),
			f32(COLLIDER_THICKNESS),
			f32((building.rect.height * BUILDING_TILE_SIZE) - COLLIDER_THICKNESS),
		}

		if _, err := append(colliders, left_side_collider); err != nil {
			return false
		}

		right_side_collider := zf4.Rect {
			f32((zf4.calc_rect_i_right(building.rect) * BUILDING_TILE_SIZE) - COLLIDER_THICKNESS),
			f32(building.rect.y * BUILDING_TILE_SIZE),
			f32(COLLIDER_THICKNESS),
			f32((building.rect.height * BUILDING_TILE_SIZE) - COLLIDER_THICKNESS),
		}

		if _, err := append(colliders, right_side_collider); err != nil {
			return false
		}
	}

	return true
}

append_render_task :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	pos: zf4.Vec_2D,
	sprite: Sprite,
	sort_depth: f32,
	origin := zf4.Vec_2D{0.5, 0.5},
	scale := zf4.Vec_2D{1.0, 1.0},
	rot: f32 = 0.0,
	alpha: f32 = 1.0,
	flash_time := 0,
) -> bool {
	assert(alpha >= 0.0 && alpha <= 1.0)
	assert(flash_time >= 0)

	task := World_Layered_Render_Task {
		pos        = pos,
		origin     = origin,
		scale      = scale,
		rot        = rot,
		alpha      = alpha,
		sprite     = sprite,
		flash_time = flash_time,
		sort_depth = sort_depth,
	}

	if _, err := append(tasks, task); err != nil {
		return false
	}

	return true
}

append_building_render_tasks :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	building: ^Building,
) -> bool {
	//
	// Back
	//
	for xo in 0 ..< building.rect.width {
		pos := building_tile_to_world_pos({building.rect.x + xo, building.rect.y})

		if !append_render_task(tasks, pos, Sprite.Wall, pos.y, origin = {0.0, 1.0}) {
			return false
		}
	}

	//
	// Front
	//
	for xo in 0 ..< building.rect.width {
		pos := building_tile_to_world_pos(
			{building.rect.x + xo, building.rect.y + building.rect.height},
		)

		sprite := Sprite.Wall

		if xo == building.door_x {
			sprite = Sprite.Door_Border_Left
		} else if xo == building.door_x + 1 {
			sprite = Sprite.Door_Border_Right
		}

		if !append_render_task(tasks, pos, sprite, pos.y, origin = {0.0, 1.0}) {
			return false
		}
	}

	// Door
	{
		pos := building_tile_to_world_pos(
			{building.rect.x + building.door_x, building.rect.y + building.rect.height},
		)

		if !append_render_task(
			tasks,
			pos,
			building.door_open ? Sprite.Door_Open : Sprite.Door_Closed,
			pos.y,
			origin = {0.0, 1.0},
		) {
			return false
		}
	}

	//
	// Sides
	//
	for yo in 0 ..< building.rect.height {
		// Left Ceiling Beam
		{
			pos := building_tile_to_world_pos({building.rect.x, building.rect.y + yo})

			if !append_render_task(tasks, pos, Sprite.Left_Ceiling_Beam, pos.y, origin = {}) {
				return false
			}
		}

		// Right Ceiling Beam
		{
			pos := building_tile_to_world_pos(
				{building.rect.x + building.rect.width - 1, building.rect.y + yo},
			)

			if !append_render_task(tasks, pos, Sprite.Right_Ceiling_Beam, pos.y, origin = {}) {
				return false
			}
		}
	}

	return true
}

building_tile_to_world_pos :: proc(pos: zf4.Vec_2D_I) -> zf4.Vec_2D {
	return {f32(pos.x), f32(pos.y)} * BUILDING_TILE_SIZE
}

gen_door_interaction_collider :: proc(building: ^Building) -> zf4.Rect {
	pos := building_tile_to_world_pos(
		{building.rect.x + building.door_x, building.rect.y + building.rect.height},
	)

	return gen_collider_from_sprite(Sprite.Door_Closed, pos, {0.0, 1.0})
}

