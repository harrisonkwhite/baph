#include "gc_tilemap.h"
#include "gc_game.h"

bool TilemapCollision(const t_tilemap* const tilemap, const s_rect collider) {
    assert(tilemap);
    assert(collider.width > 0.0f && collider.height > 0.0f);

    const s_rect_edges_i collider_tilemap_span = RectTilemapSpan(collider);

    for (int ty = collider_tilemap_span.top; ty < collider_tilemap_span.bottom; ty++) {
        for (int tx = collider_tilemap_span.left; tx < collider_tilemap_span.right; tx++) {
            if (!IsTileActive(tilemap, tx, ty)) {
                continue;
            }

            const s_rect tile_collider = {
                TILE_SIZE * tx,
                TILE_SIZE * ty,
                TILE_SIZE,
                TILE_SIZE
            };

            if (DoRectsInters(collider, tile_collider)) {
                return true;
            }
        }
    }

    return false;
}

// NOTE: This is likely a placeholder approach. Once gameplay is more defined, this can be reviewed and updated. Could generate solid colliders per frame, for instance (generalised approach).
void ProcTilemapCollisions(s_vec_2d* const vel, const s_rect collider, const t_tilemap* const tilemap) {
    assert(vel);
    assert(collider.width > 0 && collider.height > 0);
    assert(tilemap);

    const s_rect hor_rect = RectTranslated(collider, (s_vec_2d){vel->x, 0.0f});

    if (TilemapCollision(tilemap, hor_rect)) {
        vel->x = 0.0f;
    }

    const s_rect ver_rect = RectTranslated(collider, (s_vec_2d){0.0f, vel->y});

    if (TilemapCollision(tilemap, ver_rect)) {
        vel->y = 0.0f;
    }

    if (vel->x != 0.0f && vel->y != 0.0f) {
        const s_rect diag_rect = RectTranslated(collider, *vel);

        if (TilemapCollision(tilemap, diag_rect)) {
            vel->x = 0.0f;
        }
    }
}

void RenderTilemap(const s_rendering_context* const rendering_context, const t_tilemap* const tilemap, const s_textures* const textures) {
    for (int ty = 0; ty < TILEMAP_HEIGHT; ty++) {
        for (int tx = 0; tx < TILEMAP_WIDTH; tx++) {
            if (!IsTileActive(tilemap, tx, ty)) {
                continue;
            }

            const s_vec_2d tpos = {
                TILE_SIZE * tx,
                TILE_SIZE * ty
            };

            RenderSprite(rendering_context, ek_sprite_tile, textures, tpos, (s_vec_2d){0}, (s_vec_2d){1.0f, 1.0f}, 0.0f, WHITE);
        }
    }
}
