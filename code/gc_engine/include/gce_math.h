#ifndef GCE_MATH_H
#define GCE_MATH_H

#include <stdbool.h>
#include <stdint.h>
#include <assert.h>
#include <math.h>
#include "gce_utils.h"

#define PI 3.14159265358979323846f

#define MIN(x, y) ((x) <= (y) ? (x) : (y))
#define MAX(x, y) ((x) >= (y) ? (x) : (y))

#define CLAMP(x, min, max) (((x) < (min)) ? (min) : ((x) > (max) ? (max) : (x)))

#define VEC_2D_ZERO (s_vec_2d) {0}
#define VEC_2D_I_ZERO (s_vec_2d_i) {0}

typedef float t_matrix_4x4[4][4];

typedef struct {
    float x;
    float y;
} s_vec_2d;

typedef struct {
    int x;
    int y;
} s_vec_2d_i;

typedef struct {
    float x;
    float y;
    float z;
} s_vec_3d;

typedef struct {
    float x;
    float y;
    float z;
    float w;
} s_vec_4d;

typedef struct {
    float x;
    float y;
    float width;
    float height;
} s_rect;

typedef struct {
    int x;
    int y;
    int width;
    int height;
} s_rect_i;

typedef struct {
    float left;
    float top;
    float right;
    float bottom;
} s_rect_edges;

typedef struct {
    int left;
    int top;
    int right;
    int bottom;
} s_rect_edges_i;

typedef struct {
    float min;
    float max;
} s_range_f;

typedef struct {
    s_vec_2d* pts;
    int cnt;
} s_poly;

s_rect GenSpanningRect(const s_rect* const rects, const int cnt);
void InitIdenMatrix4x4(t_matrix_4x4* const mat);
void InitOrthoMatrix4x4(t_matrix_4x4* const mat, const float left, const float right, const float bottom, const float top, const float near, const float far);

bool PushQuadPoly(s_poly* const poly, s_mem_arena* const mem_arena, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin);
bool PushQuadPolyRotated(s_poly* const poly, s_mem_arena* const mem_arena, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin, const float rot);
bool DoPolysInters(const s_poly* const a, const s_poly* const b);
bool DoesPolyIntersWithRect(const s_poly* const poly, const s_rect rect);

inline int IndexFrom2D(const int x, const int y, const int width) {
    assert(x >= 0 && x < width && y >= 0);
    return (width * y) + x;
}

inline float Lerp(const float a, const float b, const float t) {
    assert(t >= 0.0f && t <= 1.0f);
    return a + ((b - a) * t);
}

inline s_vec_2d LerpVec2D(const s_vec_2d a, const s_vec_2d b, const float t) {
    assert(t >= 0.0f && t <= 1.0f);
    return (s_vec_2d){Lerp(a.x, b.x, t), Lerp(a.y, b.y, t)};
}

inline s_vec_2d Vec2DSum(const s_vec_2d a, const s_vec_2d b) {
    return (s_vec_2d){a.x + b.x, a.y + b.y};
}

inline s_vec_2d_i Vec2DISum(const s_vec_2d_i a, const s_vec_2d_i b) {
    return (s_vec_2d_i){a.x + b.x, a.y + b.y};
}

inline s_vec_2d Vec2DDiff(const s_vec_2d a, const s_vec_2d b) {
    return (s_vec_2d){a.x - b.x, a.y - b.y};
}

inline s_vec_2d_i Vec2DIDiff(const s_vec_2d_i a, const s_vec_2d_i b) {
    return (s_vec_2d_i){a.x - b.x, a.y - b.y};
}

inline s_vec_2d Vec2DScale(const s_vec_2d a, const float scalar) {
    return (s_vec_2d){a.x* scalar, a.y* scalar};
}

inline bool Vec2DsEqual(const s_vec_2d a, const s_vec_2d b) {
    return a.x == b.x && a.y == b.y;
}

inline bool Vec2DIsEqual(const s_vec_2d_i a, const s_vec_2d_i b) {
    return a.x == b.x && a.y == b.y;
}

inline float Mag(const s_vec_2d vec) {
    return sqrtf(vec.x * vec.x + vec.y * vec.y);
}

inline float Dot(const s_vec_2d a, const s_vec_2d b) {
    return a.x * b.x + a.y * b.y;
}

inline s_vec_2d NormalOrZero(const s_vec_2d vec) {
    const float mag = Mag(vec);

    if (mag == 0.0f) {
        return (s_vec_2d){0};
    }

    return (s_vec_2d){vec.x / mag, vec.y / mag};
}

inline float Dist(const s_vec_2d a, const s_vec_2d b) {
    s_vec_2d d = {a.x - b.x, a.y - b.y};
    return Mag(d);
}

inline float Dir(const s_vec_2d vec) {
    return atan2f(-vec.y, vec.x);
}

inline float DirFrom(const s_vec_2d src, const s_vec_2d dest) {
    return Dir(Vec2DDiff(dest, src));
}

inline s_vec_2d LenDir(float len, float dir) {
    return (s_vec_2d){cosf(dir)* len, -sinf(dir) * len};
}

inline s_vec_2d RectPos(const s_rect rect) {
    return (s_vec_2d){rect.x, rect.y};
}

inline s_vec_2d_i RectIPos(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x, rect.y};
}

inline s_vec_2d RectSize(const s_rect rect) {
    return (s_vec_2d){rect.width, rect.height};
}

inline s_vec_2d_i RectISize(const s_rect_i rect) {
    return (s_vec_2d_i){rect.width, rect.height};
}

inline float RectRight(const s_rect rect) {
    return rect.x + rect.width;
}

inline int RectIRight(const s_rect_i rect) {
    return rect.x + rect.width;
}

inline float RectBottom(const s_rect rect) {
    return rect.y + rect.height;
}

inline int RectIBottom(const s_rect_i rect) {
    return rect.y + rect.height;
}

inline s_vec_2d RectTopCenter(const s_rect rect) {
    return (s_vec_2d){rect.x + rect.width * 0.5f, rect.y};
}

inline s_vec_2d_i RectITopCenter(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x + rect.width / 2, rect.y};
}

inline s_vec_2d RectTopRight(const s_rect rect) {
    return (s_vec_2d){rect.x + rect.width, rect.y};
}

inline s_vec_2d_i RectITopRight(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x + rect.width, rect.y};
}

inline s_vec_2d RectCenterLeft(const s_rect rect) {
    return (s_vec_2d){rect.x, rect.y + rect.height * 0.5f};
}

inline s_vec_2d_i RectICenterLeft(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x, rect.y + rect.height / 2};
}

inline s_vec_2d RectCenter(const s_rect rect) {
    return (s_vec_2d){rect.x + rect.width * 0.5f, rect.y + rect.height * 0.5f};
}

inline s_vec_2d_i RectICenter(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x + rect.width / 2, rect.y + rect.height / 2};
}

inline s_vec_2d RectCenterRight(const s_rect rect) {
    return (s_vec_2d){rect.x + rect.width, rect.y + rect.height * 0.5f};
}

inline s_vec_2d_i RectICenterRight(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x + rect.width, rect.y + rect.height / 2};
}

inline s_vec_2d RectBottomLeft(const s_rect rect) {
    return (s_vec_2d){rect.x, rect.y + rect.height};
}

inline s_vec_2d_i RectIBottomLeft(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x, rect.y + rect.height};
}

inline s_vec_2d RectBottomCenter(const s_rect rect) {
    return (s_vec_2d){rect.x + rect.width * 0.5f, rect.y + rect.height};
}

inline s_vec_2d_i RectIBottomCenter(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x + rect.width / 2, rect.y + rect.height};
}

inline s_vec_2d RectBottomRight(const s_rect rect) {
    return (s_vec_2d){rect.x + rect.width, rect.y + rect.height};
}

inline s_vec_2d_i RectIBottomRight(const s_rect_i rect) {
    return (s_vec_2d_i){rect.x + rect.width, rect.y + rect.height};
}

inline s_rect RectTranslated(const s_rect rect, const s_vec_2d trans) {
    return (s_rect){rect.x + trans.x, rect.y + trans.y, rect.width, rect.height};
}

inline s_rect_edges RectEdgesClamped(const s_rect_edges edges, const s_rect_edges clamp_edges) {
    return (s_rect_edges){
        MAX(edges.left, clamp_edges.left),
        MAX(edges.top, clamp_edges.top),
        MIN(edges.right, clamp_edges.right),
        MIN(edges.bottom, clamp_edges.bottom)
    };
}

inline s_rect_edges_i RectEdgesIClamped(const s_rect_edges_i edges, const s_rect_edges_i clamp_edges) {
    return (s_rect_edges_i){
        MAX(edges.left, clamp_edges.left),
        MAX(edges.top, clamp_edges.top),
        MIN(edges.right, clamp_edges.right),
        MIN(edges.bottom, clamp_edges.bottom)
    };
}

inline s_rect_i RectIClamped(const s_rect_i rect, const s_vec_2d_i span) {
    assert(span.x >= 0 && span.y >= 0);

    const s_vec_2d_i rect_clamped_tl = {MAX(rect.x, 0), MAX(rect.y, 0)};

    const s_vec_2d_i rect_clamped_br = {
        MIN(rect_clamped_tl.x + rect.width, span.x),
        MIN(rect_clamped_tl.y + rect.height, span.y)
    };

    return (s_rect_i){
        rect_clamped_tl.x,
        rect_clamped_tl.y,
        rect_clamped_br.x - rect_clamped_tl.x,
        rect_clamped_br.y - rect_clamped_tl.y
    };
}

inline bool IsPointInRect(const s_vec_2d pt, const s_rect rect) {
    return pt.x >= rect.x && pt.y >= rect.y && pt.x < RectRight(rect) && pt.y < RectBottom(rect);
}

inline bool DoRectsInters(const s_rect a, const s_rect b) {
    return a.x < b.x + b.width && a.y < b.y + b.height && a.x + a.width > b.x && a.y + a.height > b.y;
}

#endif
