package sanctus

import "core:math"
import "core:math/rand"
import "zf4"

ENEMY_LIMIT :: 256
ENEMY_SPAWN_INTERVAL :: 200
ENEMY_SPAWN_DIST_RANGE: [2]f32 : {256.0, 400.0}

Enemy :: struct {
	pos:         zf4.Vec_2D,
	vel:         zf4.Vec_2D,
	hp:          int,
	type:        Enemy_Type,
	attack_time: int, // TEMP
	flash_time:  int,
}

Enemy_Type :: enum {
	Melee,
	Ranger,
}

Enemy_Type_Flag :: enum {
	Deals_Contact_Damage,
}

Enemy_Type_Flag_Set :: bit_set[Enemy_Type_Flag]

Enemy_Type_Info :: struct {
	sprite:      Sprite,
	hp_limit:    int,
	flags:       Enemy_Type_Flag_Set,
	contact_dmg: int, // NOTE: We might want to assert correctness on things like this, e.g. if the flag is set this should be greater than zero.
	contact_kb:  f32,
}

// NOTE: Consider accessor function instead.
ENEMY_TYPE_INFOS :: [len(Enemy_Type)]Enemy_Type_Info {
	Enemy_Type.Melee = {
		sprite = Sprite.Melee_Enemy,
		hp_limit = 100,
		flags = {Enemy_Type_Flag.Deals_Contact_Damage},
		contact_dmg = 1,
		contact_kb = 8.0,
	},
	Enemy_Type.Ranger = {
		sprite = Sprite.Melee_Enemy,
		hp_limit = 100,
		flags = {Enemy_Type_Flag.Deals_Contact_Damage},
		contact_dmg = 1,
		contact_kb = 8.0,
	},
}

Enemies :: struct {
	buf:      [ENEMY_LIMIT]Enemy,
	activity: [ENEMY_LIMIT]bool, // TEMP: Use a bitset later.
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
			flash_time = enemy.flash_time,
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

		enemy_size := zf4.calc_rect_i_size(sprite_src_rects[type_infos[enemy.type].sprite])

		hp_bar_pos := camera_to_display_pos(
			enemy.pos + {0.0, (f32(enemy_size.y) / 2.0) + 8.0},
			cam,
			rendering_context.display_size,
		)
		hp_bar_size := zf4.Vec_2D{f32(enemy_size.x) - 2.0, 2.0} * CAMERA_SCALE
		hp_bar_rect := zf4.Rect {
			hp_bar_pos.x - (hp_bar_size.x / 2.0),
			hp_bar_pos.y - (hp_bar_size.y / 2.0),
			hp_bar_size.x,
			hp_bar_size.y,
		}

		zf4.render_bar_hor(
			rendering_context,
			hp_bar_rect,
			f32(enemy.hp) / f32(type_infos[enemy.type].hp_limit),
			zf4.WHITE.rgb,
			zf4.BLACK.rgb,
		)
	}
}

spawn_enemy :: proc(type: Enemy_Type, pos: zf4.Vec_2D, level: ^Level) -> bool {
	type_infos := ENEMY_TYPE_INFOS

	for i in 0 ..< ENEMY_LIMIT {
		if !level.enemies.activity[i] {
			level.enemies.buf[i] = {
				pos  = pos,
				hp   = type_infos[type].hp_limit,
				type = type,
			}

			level.enemies.activity[i] = true

			return true
		}
	}

	return false
}

damage_enemy :: proc(enemy_index: int, level: ^Level, dmg_info: Damage_Info) {
	assert(level.enemies.activity[enemy_index])
	assert(dmg_info.dmg > 0)

	enemy := &level.enemies.buf[enemy_index]
	enemy.vel += dmg_info.kb
	enemy.hp = max(enemy.hp - dmg_info.dmg, 0)
	enemy.flash_time = LEVEL_LAYERED_RENDER_TASK_FLASH_TIME_LIMIT

	apply_camera_shake(&level.cam, 1.0)
}

gen_enemy_damage_collider :: proc(type: Enemy_Type, pos: zf4.Vec_2D) -> zf4.Rect {
	type_infos := ENEMY_TYPE_INFOS
	return gen_collider_from_sprite(type_infos[type].sprite, pos)
}

