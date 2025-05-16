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
    assert(IsMemArenaValid(arena));
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

int FirstActiveBitIndex(const t_byte* const bytes, const int byte_cnt) {
    assert(bytes);
    assert(byte_cnt > 0);

    for (int i = 0; i < byte_cnt; i++) {
        if (bytes[i] == 0xFF) {
            continue;
        }
        
        for (int j = 0; j < 8; j++) {
            if (bytes[i] & (1 << j)) {
                return (i * 8) + j;
            }
        }
    }
    
    return -1;
}

int FirstInactiveBitIndex(const t_byte* const bytes, const int byte_cnt) {
    assert(bytes);
    assert(byte_cnt > 0);

    for (int i = 0; i < byte_cnt; i++) {
        if (bytes[i] == 0xFF) {
            continue;
        }
        
        for (int j = 0; j < 8; j++) {
            if (!(bytes[i] & (1 << j))) {
                return (i * 8) + j;
            }
        }
    }
    
    return -1;
}

t_byte* PushEntireFileContents(const char* const file_path, s_mem_arena* const mem_arena, const bool incl_term_byte) {
    assert(file_path);
    assert(mem_arena);
    assert(IsMemArenaValid(mem_arena));

    FILE* const fs = fopen(file_path, "rb");

    if (!fs) {
        fprintf(stderr, "Failed to open \"%s\"!\n", file_path);
        return NULL;
    }

    fseek(fs, 0, SEEK_END);
    const int file_size = ftell(fs);
    fseek(fs, 0, SEEK_SET);

    t_byte* const contents = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, t_byte, incl_term_byte ? (file_size + 1) : file_size);

    if (!contents) {
        return NULL;
    }

    const int read_cnt = fread(contents, 1, file_size, fs);
    
    if (read_cnt != file_size) {
        fprintf(stderr, "Failed to read the contents of \"%s\"!\n", file_path);
        return NULL;
    }

    return contents;
}
