#ifndef GC_TILEMAP_H
#define GC_TILEMAP_H

#include <gce_rendering.h>
#include <gce_math.h>
#include <gce_utils.h>

#define TILE_SIZE 16

#define LEVEL_WIDTH 128
#define LEVEL_HEIGHT 128

#define LEVEL_CHUNK_WIDTH 8
#define LEVEL_CHUNK_HEIGHT 8

#define LEVEL_CHUNK_CNT_HOR (LEVEL_WIDTH / LEVEL_CHUNK_WIDTH)
#define LEVEL_CHUNK_CNT_VER (LEVEL_HEIGHT / LEVEL_CHUNK_HEIGHT)

typedef t_byte t_tilemap_chunk[BITS_TO_BYTES(LEVEL_CHUNK_HEIGHT)][BITS_TO_BYTES(LEVEL_CHUNK_WIDTH)];

typedef struct {
    t_tilemap_chunk chunks[LEVEL_HEIGHT / LEVEL_CHUNK_HEIGHT][LEVEL_WIDTH / LEVEL_CHUNK_WIDTH];
} s_tilemap;

bool TilemapCollision(const s_rect collider, const s_tilemap* const tilemap);
s_vec_2d ProcTilemapCollisions(const s_vec_2d vel, const s_rect collider, const s_tilemap* const tilemap);
void RenderTilemap(const s_rendering_context* const rendering_context, const s_tilemap* const tilemap, const s_textures* const textures);

inline bool IsTilePosInBounds(const int x, const int y) {
    return x >= 0 && x < LEVEL_WIDTH && y >= 0 && y < LEVEL_HEIGHT;
}

inline void ActivateTile(const int x, const int y, const s_tilemap* const tilemap) {
    assert(IsTilePosInBounds(x, y));

    const s_vec_2d_i tile_chunk_index = {x / LEVEL_CHUNK_WIDTH, y / LEVEL_CHUNK_HEIGHT};
    const s_vec_2d_i tile_pos_within_chunk = {x % LEVEL_CHUNK_WIDTH, y % LEVEL_CHUNK_HEIGHT};
    const int bit_index = IndexFrom2D(tile_pos_within_chunk.x, tile_pos_within_chunk.y, LEVEL_CHUNK_WIDTH);

    ActivateBit(
        bit_index,
        (t_byte*)tilemap->chunks[tile_chunk_index.y][tile_chunk_index.x],
        LEVEL_CHUNK_WIDTH * LEVEL_CHUNK_HEIGHT
    );
}

inline bool IsTileInChunkActive(const int x, const int y, const t_tilemap_chunk* const chunk) {
    assert(x >= 0 && x < LEVEL_CHUNK_WIDTH && y >= 0 && y < LEVEL_CHUNK_HEIGHT);

    const int bit_index = IndexFrom2D(x, y, LEVEL_CHUNK_WIDTH);

    return IsBitActive(
        bit_index,
        (const t_byte*)chunk,
        LEVEL_CHUNK_WIDTH * LEVEL_CHUNK_HEIGHT
    );
}

inline bool IsTileActive(const int x, const int y, const s_tilemap* const tilemap) {
    assert(IsTilePosInBounds(x, y));

    const s_vec_2d_i tile_chunk_index = {x / LEVEL_CHUNK_WIDTH, y / LEVEL_CHUNK_HEIGHT};
    const s_vec_2d_i tile_pos_within_chunk = {x % LEVEL_CHUNK_WIDTH, y % LEVEL_CHUNK_HEIGHT};
    const int bit_index = IndexFrom2D(tile_pos_within_chunk.x, tile_pos_within_chunk.y, LEVEL_CHUNK_WIDTH);

    return IsBitActive(
        bit_index,
        (t_byte*)tilemap->chunks[tile_chunk_index.y][tile_chunk_index.x],
        LEVEL_CHUNK_WIDTH * LEVEL_CHUNK_HEIGHT
    );
}

#endif
