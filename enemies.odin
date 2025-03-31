package apocalypse

import "core:math"
import "core:math/rand"
import "zf4"

ENEMY_LIMIT :: 256
ENEMY_SPAWN_INTERVAL :: 200
ENEMY_SPAWN_DIST_RANGE: [2]f32 : {256.0, 400.0}
ENEMY_DMG_FLASH_TIME :: 5

// NOTE: Consider accessor function instead.
ENEMY_TYPE_INFOS :: [len(Enemy_Type)]Enemy_Type_Info {
	Enemy_Type.Melee = {
		ai_func = melee_enemy_ai,
		sprite = Sprite.Melee_Enemy,
		hp_limit = 100,
		flags = {Enemy_Type_Flag.Deals_Contact_Damage},
		contact_dmg = 2,
		contact_kb = 9.0,
	},
	Enemy_Type.Ranger = {
		ai_func = ranger_enemy_ai,
		sprite = Sprite.Ranger_Enemy,
		hp_limit = 70,
		flags = {Enemy_Type_Flag.Deals_Contact_Damage},
		contact_dmg = 1,
		contact_kb = 4.0,
	},
}

Enemy :: struct {
	pos:         zf4.Vec_2D,
	vel:         zf4.Vec_2D,
	hp:          int,
	attacking:   bool,
	attack_time: int,
	moving:      bool,
	move_time:   int,
	move_dir:    zf4.Vec_2D,
	flash_time:  int,
	type:        Enemy_Type,
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
	ai_func:     Enemy_Type_AI_Func,
	sprite:      Sprite,
	hp_limit:    int,
	flags:       Enemy_Type_Flag_Set,
	contact_dmg: int, // NOTE: We might want to assert correctness on things like this, e.g. if the flag is set this should be greater than zero.
	contact_kb:  f32,
}

Enemy_Type_AI_Func :: proc(enemy_index: int, world: ^World) -> bool

Enemies :: struct {
	buf:      [ENEMY_LIMIT]Enemy,
	activity: [ENEMY_LIMIT]bool, // TEMP: Use a bitset later.
	versions: [ENEMY_LIMIT]int,
}

Enemy_ID :: struct {
	index:   int,
	version: int,
}

gen_enemy_id :: proc(index: int, enemies: ^Enemies) -> Enemy_ID {
	assert(index >= 0 && index < ENEMY_LIMIT)
	assert(enemies != nil)
	assert(enemies.activity[index])
	return {index = index, version = enemies.versions[index]}
}

get_enemy :: proc(id: Enemy_ID, enemies: ^Enemies) -> ^Enemy {
	if !does_enemy_exist(id, enemies) {
		return nil
	}

	return &enemies.buf[id.index]
}

does_enemy_exist :: proc(id: Enemy_ID, enemies: ^Enemies) -> bool {
	assert(enemies != nil)
	return enemies.activity[id.index] && enemies.versions[id.index] == id.version
}

melee_enemy_ai :: proc(enemy_index: int, world: ^World) -> bool {
	assert(enemy_index >= 0 && enemy_index < ENEMY_LIMIT)
	assert(world != nil)
	assert(world.enemies.activity[enemy_index])

	enemy := &world.enemies.buf[enemy_index]

	assert(enemy.type == Enemy_Type.Melee)

	if !world.player.active {
		enemy.attacking = false
	}

	MOVE_SPD: f32 = 2.0

	vel_targ: zf4.Vec_2D

	if enemy.attacking {
		player_dist := zf4.calc_dist(enemy.pos, world.player.pos)
		player_dir := zf4.calc_normal_or_zero(world.player.pos - enemy.pos)

		if player_dist > 40.0 {
			vel_targ = player_dir * MOVE_SPD
		}

		enemy.moving = false
		enemy.move_time = 0
	} else {
		if enemy.move_time > 0 {
			enemy.move_time -= 1
		} else {
			enemy.moving = !enemy.moving
			enemy.move_time = 60
			enemy.move_dir = zf4.calc_len_dir(1.0, rand.float32() * math.TAU)
		}

		vel_targ = enemy.moving ? enemy.move_dir * MOVE_SPD : {}

		enemy.attack_time = 0
	}

	enemy.vel += (vel_targ - enemy.vel) * 0.2
	enemy.pos += enemy.vel

	if enemy.attacking {
		if enemy.attack_time < 60 {
			enemy.attack_time += 1
		} else {
			attack_dir := zf4.calc_normal_or_zero(world.player.pos - enemy.pos)
			ATTACK_HITBOX_OFFS_DIST :: 32.0
			ATTACK_HITBOX_SIZE :: 32.0
			ATTACK_KNOCKBACK :: 6.0

			if !spawn_hitmask_quad(
				enemy.pos + (attack_dir * ATTACK_HITBOX_OFFS_DIST),
				{ATTACK_HITBOX_SIZE, ATTACK_HITBOX_SIZE},
				{dmg = 1, kb = attack_dir * ATTACK_KNOCKBACK},
				{Hitmask_Flag.Damage_Player},
				world,
			) {
				return false
			}

			enemy.attack_time = 0
		}
	}

	return true
}

ranger_enemy_ai :: proc(enemy_index: int, world: ^World) -> bool {
	assert(enemy_index >= 0 && enemy_index < ENEMY_LIMIT)
	assert(world != nil)
	assert(world.enemies.activity[enemy_index])

	enemy := &world.enemies.buf[enemy_index]

	assert(enemy.type == Enemy_Type.Ranger)

	enemy.vel *= 0.8
	enemy.pos += enemy.vel

	return true
}

append_enemy_world_render_tasks :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	enemies: ^Enemies,
) -> bool {
	sprite_src_rects := SPRITE_SRC_RECTS
	enemy_type_infos := ENEMY_TYPE_INFOS

	for i in 0 ..< ENEMY_LIMIT {
		if !enemies.activity[i] {
			continue
		}

		enemy := &enemies.buf[i]

		sprite := enemy_type_infos[enemy.type].sprite

		task := World_Layered_Render_Task {
			pos        = enemy.pos,
			origin     = {0.5, 0.5},
			scale      = {1.0, 1.0},
			rot        = 0.0,
			alpha      = 1.0,
			sprite     = sprite,
			flash_time = enemy.flash_time,
			sort_depth = enemy.pos.y + (f32(sprite_src_rects[sprite].height) / 2.0),
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

		if enemy.hp == type_infos[enemy.type].hp_limit {
			continue
		}

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

spawn_enemy :: proc(type: Enemy_Type, pos: zf4.Vec_2D, world: ^World) -> bool {
	type_infos := ENEMY_TYPE_INFOS

	for i in 0 ..< ENEMY_LIMIT {
		if !world.enemies.activity[i] {
			world.enemies.buf[i] = {
				pos  = pos,
				hp   = type_infos[type].hp_limit,
				type = type,
			}

			world.enemies.activity[i] = true
			world.enemies.versions[i] += 1

			return true
		}
	}

	return false
}

damage_enemy :: proc(enemy_index: int, world: ^World, dmg_info: Damage_Info) {
	assert(world.enemies.activity[enemy_index])
	assert(dmg_info.dmg > 0)

	enemy := &world.enemies.buf[enemy_index]
	enemy.vel += dmg_info.kb
	enemy.hp = max(enemy.hp - dmg_info.dmg, 0)
	enemy.flash_time = ENEMY_DMG_FLASH_TIME
	enemy.attacking = true

	spawn_damage_text(world, dmg_info.dmg, enemy.pos)

	apply_camera_shake(&world.cam, 0.75)
}

gen_enemy_damage_collider :: proc(type: Enemy_Type, pos: zf4.Vec_2D) -> zf4.Rect {
	type_infos := ENEMY_TYPE_INFOS
	return gen_collider_from_sprite(type_infos[type].sprite, pos)
}

