#ifndef GCE_UTILS_H
#define GCE_UTILS_H

#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdalign.h>
#include <assert.h>

typedef uint8_t t_byte;

bool IsZero(const void* const mem, const int size);

inline void ZeroOut(void* const mem, const int size) {
    assert(mem);
    assert(size > 0);

    memset(mem, 0, size);
}

inline bool IsPowerOfTwo(const int n) {
    return n > 0 && (n & (n - 1)) == 0;
}

inline bool IsValidAlignment(const int n) {
    return n > 0 && IsPowerOfTwo(n);
}

inline int AlignForward(const int n, const int alignment) {
    assert(n >= 0);
    assert(IsValidAlignment(alignment));
    return (n + alignment - 1) & ~(alignment - 1);
}

typedef struct {
    t_byte* buf;
    int size;
    int offs;
} s_mem_arena;

bool InitMemArena(s_mem_arena* const arena, const int size);
void CleanMemArena(s_mem_arena* const arena);
void* PushToMemArena(s_mem_arena* const arena, const int size, const int alignment);
void ResetMemArena(s_mem_arena* const arena);
void AssertMemArenaValidity(const s_mem_arena* const arena);

inline bool IsMemArenaActive(const s_mem_arena* const arena) {
    assert(arena);
    AssertMemArenaValidity(arena);
    return arena->buf;
}

#define MEM_ARENA_PUSH_TYPE(arena, type) (type*)PushToMemArena(arena, sizeof(type), alignof(type))
#define MEM_ARENA_PUSH_TYPE_MANY(arena, type, cnt) (type*)PushToMemArena(arena, sizeof(type) * cnt, alignof(type))

#endif
