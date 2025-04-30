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
    float min;
    float max;
} s_range_f;

typedef struct {
    s_vec_2d* pts;
    int cnt;
} s_poly;

typedef struct {
    const s_vec_2d* pts;
    int cnt;
} s_poly_view;

s_rect GenSpanningRect(const s_rect* const rects, const int cnt);
void InitIdenMatrix4x4(t_matrix_4x4* const mat);
void InitOrthoMatrix4x4(t_matrix_4x4* const mat, const float left, const float right, const float bottom, const float top, const float near, const float far);

bool PushQuadPoly(s_poly* const poly, s_mem_arena* const mem_arena, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin);
bool PushQuadPolyRotated(s_poly* const poly, s_mem_arena* const mem_arena, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin, const float rot);
bool DoPolysInters(const s_poly_view* const a, const s_poly_view* const b);
bool DoesPolyIntersWithRect(const s_poly_view* const poly, const s_rect rect);

inline float Lerp(const float a, const float b, const float t) {
    assert(t >= 0.0f && t <= 1.0f);
    return a + ((b - a) * t);
}

inline s_vec_2d LerpVec2D(const s_vec_2d a, const s_vec_2d b, const float t) {
    assert(t >= 0.0f && t <= 1.0f);
    return (s_vec_2d) { Lerp(a.x, b.x, t), Lerp(a.y, b.y, t) };
}

inline s_vec_2d Vec2DSum(const s_vec_2d a, const s_vec_2d b) {
    return (s_vec_2d) { a.x + b.x, a.y + b.y };
}

inline s_vec_2d_i Vec2DISum(const s_vec_2d_i a, const s_vec_2d_i b) {
    return (s_vec_2d_i) { a.x + b.x, a.y + b.y };
}

inline s_vec_2d Vec2DDiff(const s_vec_2d a, const s_vec_2d b) {
    return (s_vec_2d) { a.x - b.x, a.y - b.y };
}

inline s_vec_2d_i Vec2DIDiff(const s_vec_2d_i a, const s_vec_2d_i b) {
    return (s_vec_2d_i) { a.x - b.x, a.y - b.y };
}

inline s_vec_2d Vec2DScale(const s_vec_2d a, const float scalar) {
    return (s_vec_2d) { a.x* scalar, a.y* scalar };
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
        return (s_vec_2d) { 0 };
    }

    return (s_vec_2d) { vec.x / mag, vec.y / mag };
}

inline float Dist(const s_vec_2d a, const s_vec_2d b) {
    s_vec_2d d = {a.x - b.x, a.y - b.y};
    return Mag(d);
}

inline float Dir(const s_vec_2d vec) {
    return atan2f(-vec.y, vec.x);
}

inline s_vec_2d LenDir(float len, float dir) {
    return (s_vec_2d) { cosf(dir)* len, -sinf(dir) * len };
}

inline s_vec_2d RectPos(const s_rect* const rect) {
    return (s_vec_2d) { rect->x, rect->y };
}

inline s_vec_2d_i RectIPos(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x, rect->y };
}

inline s_vec_2d RectSize(const s_rect* const rect) {
    return (s_vec_2d) { rect->width, rect->height };
}

inline s_vec_2d_i RectISize(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->width, rect->height };
}

inline float RectRight(const s_rect* const rect) {
    return rect->x + rect->width;
}

inline int RectIRight(const s_rect_i* const rect) {
    return rect->x + rect->width;
}

inline float RectBottom(const s_rect* const rect) {
    return rect->y + rect->height;
}

inline int RectIBottom(const s_rect_i* const rect) {
    return rect->y + rect->height;
}

inline s_vec_2d RectTopCenter(const s_rect* const rect) {
    return (s_vec_2d) { rect->x + rect->width * 0.5f, rect->y };
}

inline s_vec_2d_i RectITopCenter(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x + rect->width / 2, rect->y };
}

inline s_vec_2d RectTopRight(const s_rect* const rect) {
    return (s_vec_2d) { rect->x + rect->width, rect->y };
}

inline s_vec_2d_i RectITopRight(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x + rect->width, rect->y };
}

inline s_vec_2d RectCenterLeft(const s_rect* const rect) {
    return (s_vec_2d) { rect->x, rect->y + rect->height * 0.5f };
}

inline s_vec_2d_i RectICenterLeft(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x, rect->y + rect->height / 2 };
}

inline s_vec_2d RectCenter(const s_rect* const rect) {
    return (s_vec_2d) { rect->x + rect->width * 0.5f, rect->y + rect->height * 0.5f };
}

inline s_vec_2d_i RectICenter(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x + rect->width / 2, rect->y + rect->height / 2 };
}

inline s_vec_2d RectCenterRight(const s_rect* const rect) {
    return (s_vec_2d) { rect->x + rect->width, rect->y + rect->height * 0.5f };
}

inline s_vec_2d_i RectICenterRight(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x + rect->width, rect->y + rect->height / 2 };
}

inline s_vec_2d RectBottomLeft(const s_rect* const rect) {
    return (s_vec_2d) { rect->x, rect->y + rect->height };
}

inline s_vec_2d_i RectIBottomLeft(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x, rect->y + rect->height };
}

inline s_vec_2d RectBottomCenter(const s_rect* const rect) {
    return (s_vec_2d) { rect->x + rect->width * 0.5f, rect->y + rect->height };
}

inline s_vec_2d_i RectIBottomCenter(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x + rect->width / 2, rect->y + rect->height };
}

inline s_vec_2d RectBottomRight(const s_rect* const rect) {
    return (s_vec_2d) { rect->x + rect->width, rect->y + rect->height };
}

inline s_vec_2d_i RectIBottomRight(const s_rect_i* const rect) {
    return (s_vec_2d_i) { rect->x + rect->width, rect->y + rect->height };
}

inline bool IsPointInRect(const s_vec_2d pt, const s_rect* const rect) {
    return pt.x >= rect->x && pt.y >= rect->y && pt.x < RectRight(rect) && pt.y < RectBottom(rect);
}

inline bool DoRectsInters(const s_rect* const a, const s_rect* const b) {
    return a->x < b->x + b->width && a->y < b->y + b->height && a->x + a->width > b->x && a->y + a->height > b->y;
}

#endif

/*#ifndef GCE_MATH_H
#define GCE_MATH_H

#include <stdbool.h>
#include <stdint.h>

#define PI 3.14159265358979323846f

typedef float vec_3d[3];
typedef float vec_4d[4];
typedef float mat4x4[4][4];

typedef struct {
    float x;
    float y;
} s_vec_2d;

typedef struct {
    int x;
    int y;
} s_vec_2d_i;

typedef struct s_rect {
    float x;
    float y;
    float width;
    float height;
} s_rect;

typedef struct s_rect_i {
    int x;
    int y;
    int width;
    int height;
} s_rect_i;

typedef struct s_rect_edges {
    float left;
    float top;
    float right;
    float bottom;
} s_rect_edges;

typedef struct s_poly {
    s_vec_2d* pts;
    int count;
} s_poly;

s_vec_2d ToVec2D(const s_vec_2d_i vec);
bool IsSize(const s_vec_2d vec);
bool IsSizeI(const s_vec_2d_i vec);
s_vec_2d CalcRectPos(const s_rect* rect);
s_vec_2d_i CalcRectIPos(const s_rect_i* rect);
s_vec_2d CalcRectSize(const s_rect* rect);
s_vec_2d_i CalcRectISize(const s_rect_i* rect);
float CalcRectRight(const s_rect* rect);
int CalcRectIRight(const s_rect_i* rect);
float CalcRectBottom(const s_rect* rect);
int CalcRectIBottom(const s_rect_i* rect);
s_vec_2d CalcRectTopCenter(const s_rect* rect);
s_vec_2d_i CalcRectITopCenter(const s_rect_i* rect);
s_vec_2d CalcRectTopRight(const s_rect* rect);
s_vec_2d_i CalcRectITopRight(const s_rect_i* rect);
s_vec_2d CalcRectCenterLeft(const s_rect* rect);
s_vec_2d_i CalcRectICenterLeft(const s_rect_i* rect);
s_vec_2d CalcRectCenter(const s_rect* rect);
s_vec_2d_i CalcRectICenter(const s_rect_i* rect);
s_vec_2d CalcRectCenterRight(const s_rect* rect);
s_vec_2d_i CalcRectICenterRight(const s_rect_i* rect);
s_vec_2d CalcRectBottomLeft(const s_rect* rect);
s_vec_2d_i CalcRectIBottomLeft(const s_rect_i* rect);
s_vec_2d CalcRectBottomCenter(const s_rect* rect);
s_vec_2d_i CalcRectIBottomCenter(const s_rect_i* rect);
s_vec_2d CalcRectBottomRight(const s_rect* rect);
s_vec_2d_i CalcRectIBottomRight(const s_rect_i* rect);
void TranslateRect(s_rect* rect, const s_vec_2d trans);
void TranslateRectI(s_rect_i* rect, const s_vec_2d_i trans);
bool IsPointInRect(const s_vec_2d pt, const s_rect* rect);
bool DoRectsInters(const s_rect* a, const s_rect* b);
s_rect GenSpanningRect(const s_rect* rects, int count);
float CalcMag(const s_vec_2d vec);
float CalcDot(const s_vec_2d a, const s_vec_2d b);
s_vec_2d CalcNormalOrZero(const s_vec_2d vec);
float CalcDist(const s_vec_2d a, const s_vec_2d b);
float CalcDir(const s_vec_2d vec);
s_vec_2d CalcLenDir(float len, float dir);
void GenIdenMatrix4x4(mat4x4 mat);
void GenOrthoMatrix4x4(mat4x4 mat, float left, float right, float bottom, float top, float near, float far);
bool AllocQuadPoly(s_poly* poly, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin);
bool AllocQuadPolyRotated(s_poly* poly, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin, float rot);
bool DoPolysInters(const s_poly* a, const s_poly* b);
bool DoesPolyIntersWithRect(const s_poly* poly, const s_rect* rect);
bool CheckPolySep(const s_poly* poly, const s_poly* other);
void ProjectPts(const s_vec_2d* pts, int count, const s_vec_2d edge, float* out_min, float* out_max);

#endif*/
