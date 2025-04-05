package apocalypse

import "core:math"
import "zf4"

MINION_CNT :: 5
MINION_ORBIT_DIST :: 80.0
MINION_ATTACK_DMG :: 6
MINION_ATTACK_KNOCKBACK :: 4.0
MINION_ATTACK_INTERVAL :: 60
MINION_ATTACK_HITBOX_SIZE :: 32.0
MINION_ATTACK_HITBOX_OFFS_DIST :: 40.0

Minion :: struct {
	pos:         zf4.Vec_2D,
	vel:         zf4.Vec_2D,
	targ:        Enemy_ID,
	attack_time: int,
}

update_minions :: proc(world: ^World, solid_colliders: []zf4.Rect) -> bool {
	//
	// Assigning Minions to Enemies
	//

	// For every untargeted enemy within the combat radius, assign the nearest minion with no current target to it.
	for i in 0 ..< ENEMY_LIMIT {
		if !world.enemies.activity[i] {
			continue
		}

		enemy := &world.enemies.buf[i]
		enemy_id := gen_enemy_id(i, &world.enemies)

		player_dist := zf4.calc_dist(enemy.pos, world.player.pos)

		if player_dist <= PLAYER_COMBAT_RADIUS {
			enemy_already_targeted := false

			for &minion in world.minions {
				if minion.targ == enemy_id {
					enemy_already_targeted = true
				}
			}

			if enemy_already_targeted {
				continue
			}

			nearest_minion: ^Minion = nil
			nearest_minion_dist: f32

			for &minion in world.minions {
				if does_enemy_exist(minion.targ, &world.enemies) {
					continue
				}

				enemy_to_minion_dist := zf4.calc_dist(enemy.pos, minion.pos)

				if nearest_minion == nil || enemy_to_minion_dist < nearest_minion_dist {
					nearest_minion = &minion
					nearest_minion_dist = enemy_to_minion_dist
				}
			}

			if nearest_minion != nil {
				nearest_minion.targ = gen_enemy_id(i, &world.enemies)
			}
		}
	}

	//
	// Minion AI
	//
	for &minion, i in world.minions {
		player_orbit_dir := (f32(i) / MINION_CNT) * math.TAU

		targ := get_enemy(minion.targ, &world.enemies)

		dest: zf4.Vec_2D

		if targ == nil {
			dest = world.player.pos + zf4.calc_len_dir(MINION_ORBIT_DIST, player_orbit_dir)
		} else {
			targ_to_player_dir := zf4.calc_normal_or_zero(world.player.pos - targ.pos)
			dest = targ.pos + (targ_to_player_dir * 40.0)
		}

		dest_dist := zf4.calc_dist(minion.pos, dest)
		dest_dir := zf4.calc_normal_or_zero(dest - minion.pos)
		vel_targ := dest_dist > 8.0 ? dest_dir * 2.5 : {}

		minion.vel += (vel_targ - minion.vel) * 0.2

		proc_solid_collisions(
			&minion.vel,
			gen_minion_movement_collider(minion.pos),
			solid_colliders,
		)

		minion.pos += minion.vel

		if targ != nil {
			if minion.attack_time < MINION_ATTACK_INTERVAL {
				minion.attack_time += 1
			} else {
				attack_dir := zf4.calc_normal_or_zero(targ.pos - minion.pos)

				if !spawn_hitmask_quad(
					minion.pos + (attack_dir * MINION_ATTACK_HITBOX_OFFS_DIST),
					{MINION_ATTACK_HITBOX_SIZE, MINION_ATTACK_HITBOX_SIZE},
					{dmg = MINION_ATTACK_DMG, kb = attack_dir * MINION_ATTACK_KNOCKBACK},
					{Damage_Flag.Damage_Enemy},
					world,
				) {
					return false
				}

				minion.attack_time = 0
			}
		} else {
			minion.attack_time = 0
		}
	}

	return true
}

append_minion_world_render_tasks :: proc(
	tasks: ^[dynamic]World_Layered_Render_Task,
	minions: []Minion,
) -> bool {
	sprite_src_rects := SPRITE_SRC_RECTS

	for &minion in minions {
		sort_depth := minion.pos.y + (f32(sprite_src_rects[Sprite.Minion].height) / 2.0)

		if !append_world_render_task(tasks, minion.pos, Sprite.Minion, sort_depth) {
			return false
		}
	}

	return true
}

gen_minion_movement_collider :: proc(minion_pos: zf4.Vec_2D) -> zf4.Rect {
	spr_collider := gen_collider_from_sprite(Sprite.Minion, minion_pos)

	mv_collider := spr_collider
	mv_collider.height = spr_collider.height / 4.0
	mv_collider.y = zf4.calc_rect_bottom(spr_collider) - mv_collider.height
	return mv_collider
}

