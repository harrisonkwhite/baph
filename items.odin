package baph

import "core:fmt"
import "core:math"
import "core:mem"
import "zf4"

INVENTORY_WIDTH :: 4
INVENTORY_HEIGHT :: 4

INVENTORY_SLOT_QUANTITY_LIMIT :: 99

ITEM_DROP_LIMIT :: 64
ITEM_DROP_COLLECTION_DIST :: 56.0
ITEM_DROP_MOVE_SPD :: 5.0
ITEM_DROP_VEL_LERP_FACTOR :: 0.2

Item_Type :: enum {
	Rock,
}

Inventory :: struct {
	slots: [INVENTORY_HEIGHT][INVENTORY_WIDTH]Inventory_Slot,
}

Inventory_Slot :: struct {
	item_type: Item_Type,
	quantity:  int,
}

is_inventory_slot_valid :: proc(slot: ^Inventory_Slot) -> bool {
	if mem.check_zero_ptr(slot, size_of(slot^)) {
		return true
	}

	return slot.quantity > 0 && slot.quantity <= INVENTORY_SLOT_QUANTITY_LIMIT
}

Item_Drop :: struct {
	item_type:     Item_Type,
	item_quantity: int,
	pos:           zf4.Vec_2D,
	vel:           zf4.Vec_2D,
}

add_item_to_inventory :: proc(item_type: Item_Type, quantity: int, inventory: ^Inventory) -> int {
	quantity := quantity

	assert(quantity >= 1)

	// Add to existing stacks of the same item type.
	for y in 0 ..< INVENTORY_HEIGHT {
		for x in 0 ..< INVENTORY_WIDTH {
			slot := &inventory.slots[y][x]

			if slot.quantity == 0 {
				continue
			}

			if slot.item_type == item_type && slot.quantity < INVENTORY_SLOT_QUANTITY_LIMIT {
				add_quantity := min(quantity, INVENTORY_SLOT_QUANTITY_LIMIT - slot.quantity)
				slot.quantity += add_quantity
				quantity -= add_quantity

				if quantity == 0 {
					return 0
				}
			}
		}
	}

	// Add to empty slots.
	for y in 0 ..< INVENTORY_HEIGHT {
		for x in 0 ..< INVENTORY_WIDTH {
			slot := &inventory.slots[y][x]

			if slot.quantity > 0 {
				continue
			}

			add_quantity := min(quantity, INVENTORY_SLOT_QUANTITY_LIMIT)
			slot.quantity = add_quantity
			quantity -= add_quantity

			if quantity == 0 {
				return 0
			}
		}
	}

	return quantity
}

drop_item_from_inventory :: proc(
	item_type: Item_Type,
	quantity: int,
	inventory: ^Inventory,
) -> int {
	quantity := quantity

	assert(quantity > 0)

	for y in 0 ..< INVENTORY_HEIGHT {
		for x in 0 ..< INVENTORY_WIDTH {
			slot := &inventory.slots[y][x]

			if slot.quantity > 0 {
				if slot.item_type == item_type {
					if slot.quantity >= quantity {
						slot.quantity -= quantity
						return 0
					} else {
						quantity -= slot.quantity
						slot.quantity = 0
					}
				}
			}
		}
	}

	return quantity
}

render_inventory :: proc(
	rendering_context: ^zf4.Rendering_Context,
	inventory: ^Inventory,
	pos: zf4.Vec_2D,
	textures: ^zf4.Textures,
	fonts: ^zf4.Fonts,
) {
	SLOT_SIZE :: zf4.Vec_2D{64.0, 64.0}
	SLOT_GAP :: zf4.Vec_2D{80.0, 80.0}
	SLOT_BG_ALPHA :: 0.4
	SLOT_OUTLINE_THICKNESS :: 1
	SLOT_QUANTITY_OFFS :: zf4.Vec_2D{12.0, 2.0}

	sprite_src_rects := SPRITE_SRC_RECTS

	for y in 0 ..< len(inventory.slots) {
		for x in 0 ..< len(inventory.slots[y]) {
			slot := &inventory.slots[y][x]

			slot_rect := zf4.Rect {
				pos.x + (f32(x) * SLOT_GAP.x),
				pos.y + (f32(y) * SLOT_GAP.y),
				SLOT_SIZE.x,
				SLOT_SIZE.y,
			}

			zf4.render_rect(rendering_context, slot_rect, {0.0, 0.0, 0.0, SLOT_BG_ALPHA})
			zf4.render_rect_outline(rendering_context, slot_rect, zf4.WHITE, 1.0)

			if slot.quantity > 0 {
				// Render item.
				zf4.render_texture(
					rendering_context,
					int(Texture.All),
					textures,
					sprite_src_rects[Sprite.Stone_Item],
					zf4.calc_rect_center(slot_rect),
					scale = CAMERA_SCALE,
				)

				// Render quantity.
				quantity_pos := zf4.calc_rect_bottom_right(slot_rect) - SLOT_QUANTITY_OFFS

				quantity_str_buf: [4]byte
				quantity_str := fmt.bprintf(quantity_str_buf[:], "%d", slot.quantity)

				zf4.render_str(
					rendering_context,
					quantity_str,
					int(Font.EB_Garamond_32),
					fonts,
					quantity_pos,
					zf4.Str_Hor_Align.Right,
					zf4.Str_Ver_Align.Bottom,
				)
			}
		}
	}
}

spawn_item_drop :: proc(
	item_type: Item_Type,
	quantity: int,
	pos: zf4.Vec_2D,
	game: ^Game,
	vel := zf4.Vec_2D{},
) -> bool {
	if game.item_drop_cnt == ITEM_DROP_LIMIT {
		fmt.eprintln("Failed to spawn item drop due to insufficient space!")
		return false
	}

	game.item_drops[game.item_drop_cnt] = {
		item_type     = item_type,
		item_quantity = quantity,
		pos           = pos,
		vel           = vel,
	}

	game.item_drop_cnt += 1

	return true
}

proc_item_drop_movement_and_collection :: proc(game: ^Game) {
	// TODO: Account for solid colliders as well... or don't?

	player := &game.player
	player_collider := gen_player_movement_collider(player.pos)
	player_collider_center := zf4.calc_rect_center(player_collider)

	for i := 0; i < game.item_drop_cnt; i += 1 {
		drop := &game.item_drops[i]

		vel_targ: zf4.Vec_2D

		// TODO: We need to evaluate first whether the player actually has room for the item.
		//       Don't move to play if not the case.

		if !player.killed &&
		   zf4.calc_dist(drop.pos, player_collider_center) <= ITEM_DROP_COLLECTION_DIST {
			player_dir := zf4.calc_normal_or_zero(player_collider_center - drop.pos)
			vel_targ = player_dir * ITEM_DROP_MOVE_SPD

			drop_collider := gen_item_drop_collider(drop.item_type, drop.pos)

			if zf4.do_rects_inters(player_collider, drop_collider) {
				add_item_to_inventory(Item_Type.Rock, drop.item_quantity, &game.inventory)

				game.item_drop_cnt -= 1
				game.item_drops[i] = game.item_drops[game.item_drop_cnt]
				i -= 1
			}
		}

		drop.vel = math.lerp(drop.vel, vel_targ, f32(ITEM_DROP_VEL_LERP_FACTOR))
		drop.pos += drop.vel
	}
}

gen_item_drop_collider :: proc(drop_item_type: Item_Type, drop_pos: zf4.Vec_2D) -> zf4.Rect {
	// TODO: The collider should ideally only be the bottom of the drop?
	return gen_collider_rect_from_sprite(Sprite.Stone_Item, drop_pos)
}

append_item_drop_render_tasks :: proc(
	tasks: ^[dynamic]Render_Task,
	item_drops: []Item_Drop,
) -> bool {
	sprite_src_rects := SPRITE_SRC_RECTS

	for &drop in item_drops {
		sprite := Sprite.Stone_Item

		task := Render_Task {
			pos        = drop.pos,
			origin     = {0.5, 0.5},
			scale      = {1.0, 1.0},
			alpha      = 1.0,
			sprite     = sprite,
			sort_depth = drop.pos.y + (f32(sprite_src_rects[sprite].height) / 2.0),
		}

		n, err := append(tasks, task)

		if err != nil {
			return false
		}
	}

	return true
}

