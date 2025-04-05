package apocalypse

import "core:math/rand"
import "zf4"

BUILDING_TILE_SIZE :: 16
DOOR_WIDTH_IN_TILES :: 2
BUILDING_SIZE_MIN_IN_TILES :: zf4.Vec_2D_I{DOOR_WIDTH_IN_TILES + 2, 4}
BUILDING_COLLIDER_THICKNESS :: 4

Building :: struct {
	rect:           zf4.Rect_I,
	door_x:         int,
	door_open:      bool,
	ceiling_hidden: bool,
	ceiling_alpha:  f32,
}

gen_building :: proc(rect: zf4.Rect_I) -> Building {
	assert(rect.width > DOOR_WIDTH_IN_TILES + 1 && rect.height > 2)

	return {
		rect = rect,
		door_x = int(rand.float64_range(1.0, f64(rect.width - DOOR_WIDTH_IN_TILES))),
		ceiling_alpha = 1.0,
	}
}

gen_buildings_in_grid :: proc(
	grid_size: zf4.Vec_2D_I,
	grid_cell_size_in_tiles: zf4.Vec_2D_I,
	building_size_min: zf4.Vec_2D_I,
	building_size_max: zf4.Vec_2D_I,
	allocator := context.allocator,
) -> []Building {
	assert(grid_size.x > 0 && grid_size.y > 0)
	assert(grid_cell_size_in_tiles.x > 0 && grid_cell_size_in_tiles.y > 0)
	assert(
		building_size_min.x >= BUILDING_SIZE_MIN_IN_TILES.x &&
		building_size_min.y >= BUILDING_SIZE_MIN_IN_TILES.y,
	)
	assert(
		building_size_min.x <= building_size_max.x && building_size_min.y <= building_size_max.y,
	)
	assert(
		building_size_max.x <= grid_cell_size_in_tiles.x &&
		building_size_max.y <= grid_cell_size_in_tiles.y,
	)

	buildings := make([]Building, grid_size.x * grid_size.y, allocator)

	if buildings != nil {
		for y in 0 ..< grid_size.y {
			for x in 0 ..< grid_size.x {
				// TODO: Double check these calculations!

				size := zf4.Vec_2D_I {
					int(rand.float64_range(f64(building_size_min.x), f64(building_size_max.x))),
					int(rand.float64_range(f64(building_size_min.y), f64(building_size_max.y))),
				}

				pos_base := zf4.Vec_2D_I {
					x * grid_cell_size_in_tiles.x,
					y * grid_cell_size_in_tiles.y,
				}

				pos_offs := zf4.Vec_2D_I {
					(grid_cell_size_in_tiles.x - size.x) / 2,
					(grid_cell_size_in_tiles.y - size.y) / 2,
				}

				buildings[(y * grid_size.x) + x] = gen_building(
					{pos_base.x + pos_offs.x, pos_base.y + pos_offs.y, size.x, size.y},
				)
			}
		}
	}

	return buildings
}

append_building_solid_colliders :: proc(
	colliders: ^[dynamic]zf4.Rect,
	building: ^Building,
) -> bool {
	// Generate back collider.
	back_collider := zf4.Rect {
		f32(building.rect.x * BUILDING_TILE_SIZE),
		f32((building.rect.y * BUILDING_TILE_SIZE) - BUILDING_COLLIDER_THICKNESS),
		f32(building.rect.width * BUILDING_TILE_SIZE),
		f32(BUILDING_COLLIDER_THICKNESS),
	}

	if _, err := append(colliders, back_collider); err != nil {
		return false
	}

	// Generate front colliders.
	{
		left_front_collider := zf4.Rect {
			f32(building.rect.x * BUILDING_TILE_SIZE),
			f32(
				(zf4.calc_rect_i_bottom(building.rect) * BUILDING_TILE_SIZE) -
				BUILDING_COLLIDER_THICKNESS,
			),
			f32(building.door_x * BUILDING_TILE_SIZE),
			f32(BUILDING_COLLIDER_THICKNESS),
		}

		if _, err := append(colliders, left_front_collider); err != nil {
			return false
		}

		right_front_collider := zf4.Rect {
			f32((building.rect.x + building.door_x + 2) * BUILDING_TILE_SIZE),
			f32(
				(zf4.calc_rect_i_bottom(building.rect) * BUILDING_TILE_SIZE) -
				BUILDING_COLLIDER_THICKNESS,
			),
			f32((building.rect.width - building.door_x - 2) * BUILDING_TILE_SIZE),
			f32(BUILDING_COLLIDER_THICKNESS),
		}

		if _, err := append(colliders, right_front_collider); err != nil {
			return false
		}

		if !building.door_open {
			door_collider := gen_door_solid_collider(building)

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
			f32(BUILDING_COLLIDER_THICKNESS),
			f32((building.rect.height * BUILDING_TILE_SIZE) - BUILDING_COLLIDER_THICKNESS),
		}

		if _, err := append(colliders, left_side_collider); err != nil {
			return false
		}

		right_side_collider := zf4.Rect {
			f32(
				(zf4.calc_rect_i_right(building.rect) * BUILDING_TILE_SIZE) -
				BUILDING_COLLIDER_THICKNESS,
			),
			f32(building.rect.y * BUILDING_TILE_SIZE),
			f32(BUILDING_COLLIDER_THICKNESS),
			f32((building.rect.height * BUILDING_TILE_SIZE) - BUILDING_COLLIDER_THICKNESS),
		}

		if _, err := append(colliders, right_side_collider); err != nil {
			return false
		}
	}

	return true
}

update_buildings :: proc(world: ^World) {
	for &building in world.buildings {
		// Update ceiling visibility.
		building.ceiling_hidden = false

		if world.player.active {
			inside_collider := zf4.Rect {
				f32(building.rect.x * BUILDING_TILE_SIZE),
				f32(building.rect.y * BUILDING_TILE_SIZE),
				f32(building.rect.width * BUILDING_TILE_SIZE),
				f32(building.rect.height * BUILDING_TILE_SIZE),
			}

			player_movement_collider := gen_player_movement_collider(world.player.pos)

			if zf4.do_rects_inters(inside_collider, player_movement_collider) {
				building.ceiling_hidden = true
			}
		}

		// Update ceiling alpha.
		ALPHA_LERP_FACTOR: f32 : 0.2

		dest_alpha: f32 = building.ceiling_hidden ? 0.0 : 1.0
		building.ceiling_alpha += (dest_alpha - building.ceiling_alpha) * ALPHA_LERP_FACTOR
	}
}

append_building_render_tasks :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	building: ^Building,
) -> bool {
	sprite_src_rects := SPRITE_SRC_RECTS
	assert(sprite_src_rects[Sprite.Wall].height % BUILDING_TILE_SIZE == 0)
	wall_tile_height := sprite_src_rects[Sprite.Wall].height / BUILDING_TILE_SIZE

	//
	// Back
	//
	for xo in 0 ..< building.rect.width {
		pos := building_tile_to_world_pos({building.rect.x + xo, building.rect.y})

		if !append_world_render_task(tasks, pos, Sprite.Wall, pos.y, origin = {0.0, 1.0}) {
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

		if !append_world_render_task(tasks, pos, sprite, pos.y, origin = {0.0, 1.0}) {
			return false
		}
	}

	// Door
	{
		pos := building_tile_to_world_pos(
			{building.rect.x + building.door_x, building.rect.y + building.rect.height},
		)

		if !append_world_render_task(
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
			pos := building_tile_to_world_pos(
				{building.rect.x, building.rect.y - wall_tile_height + yo},
			)

			if !append_world_render_task(
				tasks,
				pos,
				Sprite.Left_Ceiling_Beam,
				pos.y + f32(BUILDING_TILE_SIZE * (wall_tile_height + 1)),
				origin = {},
			) {
				return false
			}
		}

		// Right Ceiling Beam
		{
			pos := building_tile_to_world_pos(
				{
					building.rect.x + building.rect.width - 1,
					building.rect.y - wall_tile_height + yo,
				},
			)

			if !append_world_render_task(
				tasks,
				pos,
				Sprite.Right_Ceiling_Beam,
				pos.y + f32(BUILDING_TILE_SIZE * (wall_tile_height + 1)),
				origin = {},
			) {
				return false
			}
		}
	}

	//
	// Ceiling
	//
	if building.ceiling_alpha > 0.0 {
		for yo in 0 ..< building.rect.height {
			for xo in 0 ..< building.rect.width {
				pos := building_tile_to_world_pos(
					{building.rect.x + xo, building.rect.y - wall_tile_height + yo},
				)

				if !append_world_render_task(
					tasks,
					pos,
					Sprite.Ceiling,
					pos.y + f32(BUILDING_TILE_SIZE * (wall_tile_height + 1)) - 1.0,
					origin = {},
					alpha = building.ceiling_alpha,
				) {
					return false
				}
			}
		}
	}

	return true
}

building_tile_to_world_pos :: proc(pos: zf4.Vec_2D_I) -> zf4.Vec_2D {
	return {f32(pos.x), f32(pos.y)} * BUILDING_TILE_SIZE
}

gen_door_solid_collider :: proc(building: ^Building) -> zf4.Rect {
	return {
		f32((building.rect.x + building.door_x) * BUILDING_TILE_SIZE),
		f32(
			(zf4.calc_rect_i_bottom(building.rect) * BUILDING_TILE_SIZE) -
			BUILDING_COLLIDER_THICKNESS,
		),
		f32(2 * BUILDING_TILE_SIZE),
		f32(BUILDING_COLLIDER_THICKNESS),
	}
}

gen_door_interaction_collider :: proc(building: ^Building) -> zf4.Rect {
	pos := building_tile_to_world_pos(
		{building.rect.x + building.door_x, building.rect.y + building.rect.height},
	)

	return gen_collider_from_sprite(Sprite.Door_Closed, pos, {0.0, 1.0})
}

