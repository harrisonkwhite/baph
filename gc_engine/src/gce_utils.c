#include <stdlib.h>
#include <stdio.h>
#include <gce_utils.h>

bool IsZero(const void* const mem, const int size) {
    assert(mem);
    assert(size > 0);

    const t_byte* const mem_bytes = mem;

    for (int i = 0; i < size; i++) {
        if (mem_bytes[i]) {
            return false;
        }
    }

    return true;
}

bool InitMemArena(s_mem_arena* const arena, const int size) {
    assert(arena);
    assert(IsZero(arena, sizeof(*arena)));
    assert(size > 0);

    arena->buf = malloc(size);

    if (!arena->buf) {
        return false;
    }

    ZeroOut(arena->buf, size);

    arena->size = size;

    return true;
}

void CleanMemArena(s_mem_arena* const arena) {
    assert(arena);
    AssertMemArenaValidity(arena);

    if (arena->buf) {
        free(arena->buf);
    }

    ZeroOut(arena, sizeof(*arena));
}

void* PushToMemArena(s_mem_arena* const arena, const int size, const int alignment) {
    assert(arena);
    AssertMemArenaValidity(arena);
    assert(IsMemArenaActive(arena));
    assert(size > 0);
    assert(IsValidAlignment(alignment));

    const int offs_aligned = AlignForward(arena->offs, alignment);
    const int offs_next = offs_aligned + size;

    if (offs_next > arena->size) {
        fprintf(stderr, "Failed to push to memory arena!");
        return NULL;
    }

    arena->offs = offs_next;

    return arena->buf + offs_aligned;
}

void ResetMemArena(s_mem_arena* const arena) {
    assert(arena);
    AssertMemArenaValidity(arena);
    assert(!IsZero(arena, sizeof(*arena)));

    if (arena->offs > 0) {
        ZeroOut(arena->buf, arena->offs);
        arena->offs = 0;
    }
}

void AssertMemArenaValidity(const s_mem_arena* const arena) {
    assert(arena);

    if (!IsZero(arena, sizeof(*arena))) {
        assert(arena->buf);
        assert(arena->size > 0);
        assert(arena->offs >= 0 && arena->offs <= arena->size);
    }
}
