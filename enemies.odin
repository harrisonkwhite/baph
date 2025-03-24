package sanctus

import "zf4"

ENEMY_LIMIT :: 256

Enemy :: struct {
	pos:  zf4.Vec_2D,
	vel:  zf4.Vec_2D,
	hp:   int,
	type: Enemy_Type,
}

Enemy_Type :: enum {
	Melee,
	Ranger,
}

Enemy_Type_Info :: struct {
	sprite:   Sprite,
	hp_limit: int,
}

// NOTE: Consider accessor function instead.
ENEMY_TYPE_INFOS :: [len(Enemy_Type)]Enemy_Type_Info {
	Enemy_Type.Melee = {sprite = Sprite.Melee_Enemy, hp_limit = 100},
	Enemy_Type.Ranger = {sprite = Sprite.Melee_Enemy, hp_limit = 100},
}

Enemies :: struct {
	buf:      [ENEMY_LIMIT]Enemy,
	activity: [ENEMY_LIMIT]bool, // TEMP: Use a bitset later.
}

update_enemies :: proc(enemies: ^Enemies) {
	for i in 0 ..< ENEMY_LIMIT {
		if !enemies.activity[i] {
			continue
		}

		enemy := &enemies.buf[i]

		enemy.vel *= 0.8
		enemy.pos += enemy.vel
	}
}

proc_enemy_deaths :: proc(enemies: ^Enemies) {
	for i in 0 ..< ENEMY_LIMIT {
		if !enemies.activity[i] {
			continue
		}

		enemy := &enemies.buf[i]

		assert(enemy.hp >= 0)

		if enemy.hp == 0 {
			enemies.activity[i] = false
		}
	}
}

append_enemy_level_render_tasks :: proc(
	tasks: ^[dynamic]Level_Layered_Render_Task,
	enemies: ^Enemies,
) -> bool {
	for i in 0 ..< ENEMY_LIMIT {
		if !enemies.activity[i] {
			continue
		}

		enemy := &enemies.buf[i]

		task := Level_Layered_Render_Task {
			pos        = enemy.pos,
			origin     = {0.5, 0.5},
			scale      = {1.0, 1.0},
			rot        = 0.0,
			alpha      = 1.0,
			sprite     = Sprite.Melee_Enemy,
			sort_depth = enemy.pos.y,
		}

		n, err := append(tasks, task)

		if err != nil {
			return false
		}
	}

	return true
}

render_enemy_hp_bars :: proc(
	rendering_context: ^zf4.Rendering_Context,
	enemies: ^Enemies,
	cam: ^Camera,
	textures: ^zf4.Textures,
) {
	sprite_src_rects := SPRITE_SRC_RECTS
	type_infos := ENEMY_TYPE_INFOS

	for i in 0 ..< ENEMY_LIMIT {
		if !enemies.activity[i] {
			continue
		}

		enemy := &enemies.buf[i]

		enemy_size := zf4.calc_rect_i_size(sprite_src_rects[i])

		hp_bar_pos := camera_to_display_pos(
			enemy.pos + {0.0, (f32(enemy_size.y) / 2.0) + 8.0},
			cam.pos,
			rendering_context.display_size,
		)
		hp_bar_size := zf4.Vec_2D{f32(enemy_size.x) + 8.0, 4.0}
		hp_bar_rect := zf4.Rect {
			hp_bar_pos.x - (hp_bar_size.x / 2.0),
			hp_bar_pos.y - (hp_bar_size.y / 2.0),
			hp_bar_size.x,
			hp_bar_size.y,
		}

		zf4.render_bar_hor(
			rendering_context,
			hp_bar_rect,
			f32(enemy.hp) / f32(type_infos[i].hp_limit),
			zf4.WHITE.rgb,
			zf4.BLACK.rgb,
		)
	}
}

spawn_enemy :: proc(pos: zf4.Vec_2D, level: ^Level) -> bool {
	for i in 0 ..< ENEMY_LIMIT {
		if !level.enemies.activity[i] {
			level.enemies.buf[i] = {
				pos = pos,
				hp  = 100, // TEMP
			}

			level.enemies.activity[i] = true

			return true
		}
	}

	return false
}

damage_enemy :: proc(enemy: ^Enemy, dmg_info: Damage_Info) {
	assert(dmg_info.dmg > 0)

	enemy.vel += dmg_info.kb
	enemy.hp = max(enemy.hp - dmg_info.dmg, 0)
}

gen_enemy_damage_collider :: proc(type: Enemy_Type, pos: zf4.Vec_2D) -> zf4.Rect {
	type_infos := ENEMY_TYPE_INFOS
	return gen_collider_from_sprite(type_infos[type].sprite, pos)
}

