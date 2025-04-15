package baph

import "core:fmt"
import "core:math/rand"
import "zf4"

Breakable :: struct {
	pos:   zf4.Vec_2D,
	life:  int,
	shake: f64,
	type:  Breakable_Type,
}

Breakable_Type :: enum {
	Crate,
}

assert_breakable_validity :: proc(breakable: ^Breakable) {
	assert(breakable.life >= 0)
	assert(breakable.shake >= 0.0)
}

spawn_breakable :: proc(pos: zf4.Vec_2D, type: Breakable_Type, world: ^World) -> bool {
	assert(world != nil)

	if world.breakables_active == BREAKABLE_LIMIT {
		fmt.eprint("Failed to spawn breakable due to insufficient space!")
		return false
	}

	breakable := &world.breakables[world.breakables_active]

	world.breakables[world.breakables_active] = {
		pos  = pos,
		type = type,
	}

	switch breakable.type {
	case .Crate:
		breakable.life = 80
	}

	world.breakables_active += 1

	return true
}

get_breakable_sprite :: proc(type: Breakable_Type) -> Sprite {
	switch type {
	case .Crate:
		return Sprite.Crate
	}

	return nil
}

gen_breakable_solid_collider :: proc(pos: zf4.Vec_2D, type: Breakable_Type) -> zf4.Rect {
	return gen_collider_rect_from_sprite(get_breakable_sprite(type), pos)
}

append_breakable_solid_colliders :: proc(
	colliders: ^[dynamic]zf4.Rect,
	breakables: []Breakable,
) -> bool {
	for &breakable in breakables {
		assert_breakable_validity(&breakable)

		collider := gen_breakable_solid_collider(breakable.pos, breakable.type)

		if _, err := append(colliders, collider); err != nil {
			return false
		}
	}

	return true
}

gen_breakable_hit_collider :: proc(pos: zf4.Vec_2D, type: Breakable_Type) -> zf4.Rect {
	return gen_collider_rect_from_sprite(get_breakable_sprite(type), pos)
}

append_breakable_world_render_tasks :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	breakables: []Breakable,
) -> bool {
	sprite_src_rects := SPRITE_SRC_RECTS

	for &breakable in breakables {
		sprite := get_breakable_sprite(breakable.type)

		shake_offs := zf4.Vec_2D {
			f32(rand.float64_range(-breakable.shake, breakable.shake)),
			f32(rand.float64_range(-breakable.shake, breakable.shake)),
		}

		if !append_world_render_task(tasks, breakable.pos + shake_offs, sprite, breakable.pos.y) {
			return false
		}
	}

	return true
}

