#include "gc_tilemap.h"

#include "gc_game.h"

static s_rect_i FindTilemapChunkSpan(const s_rect collider) {
    assert(collider.width > 0 && collider.height > 0);

    // Map the collider to tilemap space.
    const s_vec_2d_i collider_tile_pos = {
        collider.x / TILE_SIZE,
        collider.y / TILE_SIZE
    };

    const s_vec_2d_i collider_tile_size = {
        collider.width / TILE_SIZE,
        collider.height / TILE_SIZE
    };

    // Now map to chunk space.
    const s_rect_i span_without_clamp = {
        collider_tile_pos.x / LEVEL_CHUNK_WIDTH,
        collider_tile_pos.y / LEVEL_CHUNK_HEIGHT,
        ceilf((float)collider_tile_size.x / LEVEL_CHUNK_WIDTH),
        ceilf((float)collider_tile_size.y / LEVEL_CHUNK_HEIGHT)
    };

    return RectIClamped(span_without_clamp, (s_vec_2d_i){LEVEL_CHUNK_CNT_HOR, LEVEL_CHUNK_CNT_VER});
}

static bool TilemapChunkCollision(const s_rect collider, const t_tilemap_chunk* const chunk, const s_vec_2d chunk_level_pos) {
    assert(chunk);

    for (int ty = 0; ty < LEVEL_CHUNK_HEIGHT; ty++) {
        for (int tx = 0; tx < LEVEL_CHUNK_WIDTH; tx++) {
            if (!IsTileInChunkActive(tx, ty, chunk)) {
                continue;
            }

            const s_rect tile_collider = {
                chunk_level_pos.x + (TILE_SIZE * tx),
                chunk_level_pos.y + (TILE_SIZE * ty)
            };

            if (DoRectsInters(collider, tile_collider)) {
                return true;
            }
        }
    }

    return false;
}

bool TilemapCollision(const s_rect collider, const s_tilemap* const tilemap) {
    assert(tilemap);

    // Find area of chunks the collider spans over.
    const s_rect_i collider_chunk_span = FindTilemapChunkSpan(collider);

    // Check for collisions within any of the spanned-over chunks.
    for (int cy = collider_chunk_span.y; cy < RectIBottom(collider_chunk_span); cy++) {
        for (int cx = collider_chunk_span.x; cx < RectIRight(collider_chunk_span); cx++) {
            const s_vec_2d chunk_level_pos = {
                cx * LEVEL_CHUNK_WIDTH * TILE_SIZE,
                cy * LEVEL_CHUNK_HEIGHT * TILE_SIZE
            };

            if (TilemapChunkCollision(collider, &tilemap->chunks[cy][cx], chunk_level_pos)) {
                return true;
            }
        }
    }

    return false;
}

static void RenderTilemapChunk(const s_rendering_context* const rendering_context, const t_tilemap_chunk* const chunk, const s_vec_2d pos, const s_textures* const textures) {
    for (int y = 0; y < LEVEL_CHUNK_HEIGHT; y++) {
        for (int x = 0; x < LEVEL_CHUNK_WIDTH; x++) {
            if (!IsTileInChunkActive(x, y, chunk)) {
                continue;
            }

            const s_vec_2d tile_pos = {
                pos.x + (x * TILE_SIZE),
                pos.y + (y * TILE_SIZE)
            };

            RenderSprite(rendering_context, ek_sprite_tile, textures, tile_pos, (s_vec_2d){0}, (s_vec_2d){1.0f, 1.0f}, 0.0f, WHITE);
        }
    }
}

void RenderTilemap(const s_rendering_context* const rendering_context, const s_tilemap* const tilemap, const s_textures* const textures) {
    for (int y = 0; y < LEVEL_CHUNK_CNT_VER; y++) {
        for (int x = 0; x < LEVEL_CHUNK_CNT_HOR; x++) {
            // NOTE: Could omit this check?
            if (IsZero(tilemap->chunks, sizeof(tilemap->chunks))) {
                continue;
            }

            const s_vec_2d pos = {
                TILE_SIZE * LEVEL_CHUNK_WIDTH * x,
                TILE_SIZE * LEVEL_CHUNK_HEIGHT * y
            };

            RenderTilemapChunk(rendering_context, &tilemap->chunks[y][x], pos, textures);
        }
    }
}
