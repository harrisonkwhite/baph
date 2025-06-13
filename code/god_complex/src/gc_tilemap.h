#ifndef GC_TILEMAP_H
#define GC_TILEMAP_H

#include <gce_rendering.h>
#include <gce_math.h>
#include <gce_utils.h>

#define TILE_SIZE 16
#define TILEMAP_WIDTH 64
#define TILEMAP_HEIGHT 64

typedef t_byte t_tilemap[BITS_TO_BYTES(TILEMAP_WIDTH * TILEMAP_HEIGHT)];

bool TilemapCollision(const t_tilemap* const tilemap, const s_rect collider);
void ProcTilemapCollisions(s_vec_2d* const vel, const s_rect collider, const t_tilemap* const tilemap);
void RenderTilemap(const s_rendering_context* const rendering_context, const t_tilemap* const tilemap, const s_textures* const textures);

inline bool IsTilePosInBounds(const int x, const int y) {
    return x >= 0 && x < TILEMAP_WIDTH && y >= 0 && y < TILEMAP_HEIGHT;
}

inline void ActivateTile(t_tilemap* const tilemap, const int x, const int y) {
    assert(tilemap);
    assert(IsTilePosInBounds(x, y));

    const int bit_index = IndexFrom2D(x, y, TILEMAP_WIDTH);
    ActivateBit(bit_index, (t_byte*)tilemap, TILEMAP_WIDTH * TILEMAP_HEIGHT);
}

inline bool IsTileActive(const t_tilemap* const tilemap, const int x, const int y) {
    assert(tilemap);
    assert(IsTilePosInBounds(x, y));

    const int bit_index = IndexFrom2D(x, y, TILEMAP_WIDTH);
    return IsBitActive(bit_index, (t_byte*)tilemap, TILEMAP_WIDTH * TILEMAP_HEIGHT);
}

inline s_rect_edges_i RectTilemapSpan(const s_rect rect) {
    assert(rect.width >= 0.0f && rect.height >= 0.0f);

    return RectEdgesIClamped(
        (s_rect_edges_i){
            rect.x / TILE_SIZE,
            rect.y / TILE_SIZE,
            ceilf((rect.x + rect.width) / TILE_SIZE),
            ceilf((rect.y + rect.height) / TILE_SIZE)
        },
        (s_rect_edges_i){0, 0, TILEMAP_WIDTH, TILEMAP_HEIGHT}
    );
}

#endif
