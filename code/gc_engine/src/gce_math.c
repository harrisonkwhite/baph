#include <assert.h>
#include <float.h>
#include <gce_math.h>
#include <gce_utils.h>

s_rect GenSpanningRect(const s_rect* const rects, const int cnt) {
    assert(rects && cnt > 0);

    s_rect_edges span = {
        rects[0].x,
        rects[0].y,
        rects[0].x + rects[0].width,
        rects[0].y + rects[0].height
    };

    for (int i = 1; i < cnt; ++i) {
        const s_rect* const r = &rects[i];

        if (r->x < span.left) {
            span.left = r->x;
        }
        
        if (r->y < span.top) {
            span.top = r->y;
        }
        
        if (r->x + r->width > span.right) {
            span.right = r->x + r->width;
        }
        
        if (r->y + r->height > span.bottom) {
            span.bottom = r->y + r->height;
        }
    }

    return (s_rect) { span.left, span.top, span.right - span.left, span.bottom - span.top };
}

void InitIdenMatrix4x4(t_matrix_4x4* const mat) {
    assert(mat);
    assert(IsZero(mat, sizeof(*mat)));

    (*mat)[0][0] = 1.0f;
    (*mat)[1][1] = 1.0f;
    (*mat)[2][2] = 1.0f;
    (*mat)[3][3] = 1.0f;
}

void InitOrthoMatrix4x4(t_matrix_4x4* const mat, const float left, const float right, const float bottom, const float top, const float near, const float far) {
    assert(mat);
    assert(IsZero(mat, sizeof(*mat)));
    assert(right > left);
    assert(top < bottom);
    assert(far > near);
    assert(near < far);

    (*mat)[0][0] = 2.0f / (right - left);
    (*mat)[1][1] = 2.0f / (top - bottom);
    (*mat)[2][2] = -2.0f / (far - near);
    (*mat)[3][0] = -(right + left) / (right - left);
    (*mat)[3][1] = -(top + bottom) / (top - bottom);
    (*mat)[3][2] = -(far + near) / (far - near);
    (*mat)[3][3] = 1.0f;
}

static s_range_f ProjectPts(const s_vec_2d* const pts, const int cnt, const s_vec_2d edge) {
    s_range_f range = {
        .min = FLT_MAX,
        .max = -FLT_MAX
    };
    
    for (int i = 0; i < cnt; ++i) {
        const float dot = Dot(pts[i], edge);
        
        if (dot < range.min) {
            range.min = dot;
        }
        
        if (dot > range.max) {
            range.max = dot;
        }
    }
    
    return range;
}

static bool CheckPolySep(const s_poly_view* const poly, const s_poly_view* const other) {
    for (int i = 0; i < poly->cnt; ++i) {
        const s_vec_2d a = poly->pts[i];
        const s_vec_2d b = poly->pts[(i + 1) % poly->cnt];

        s_vec_2d normal = { b.y - a.y, -(b.x - a.x) };

        const s_range_f a_range = ProjectPts(poly->pts, poly->cnt, normal);
        const s_range_f b_range = ProjectPts(other->pts, other->cnt, normal);

        if (a_range.max <= b_range.min || b_range.max <= a_range.min) {
            return false;
        }
    }
    
    return true;
}

bool PushQuadPoly(s_poly* const poly, s_mem_arena* const mem_arena, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin) {
    assert(poly);
    assert(IsZero(poly, sizeof(*poly)));
    assert(size.x > 0.0f && size.y > 0.0f);
    assert(origin.x >= 0.0f && origin.y >= 0.0f && origin.x <= 1.0f && origin.y <= 1.0f);
    
    poly->pts = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, s_vec_2d, 4);

    if (!poly->pts) {
        return false;
    }

    poly->cnt = 4;

    const s_vec_2d pos_base = {pos.x - size.x * origin.x, pos.y - size.y * origin.y};
    poly->pts[0] = pos_base;
    poly->pts[1] = (s_vec_2d){pos_base.x + size.x, pos_base.y};
    poly->pts[2] = (s_vec_2d){pos_base.x + size.x, pos_base.y + size.y};
    poly->pts[3] = (s_vec_2d){pos_base.x, pos_base.y + size.y};

    return true;
}

bool PushQuadPolyRotated(s_poly* const poly, s_mem_arena* const mem_arena, const s_vec_2d pos, const s_vec_2d size, const s_vec_2d origin, const float rot) {
    assert(poly);
    assert(IsZero(poly, sizeof(*poly)));
    assert(size.x > 0.0f && size.y > 0.0f);
    assert(origin.x >= 0.0f && origin.y >= 0.0f && origin.x <= 1.0f && origin.y <= 1.0f);
    
    poly->pts = MEM_ARENA_PUSH_TYPE_MANY(mem_arena, s_vec_2d, 4);

    if (!poly->pts) {
        return false;
    }

    poly->cnt = 4;

    const s_vec_2d left_offs  = LenDir(size.x * origin.x, rot + PI);
    const s_vec_2d up_offs = LenDir(size.y * origin.y, rot + PI * 0.5f);
    const s_vec_2d right_offs = LenDir(size.x * (1.0f - origin.x), rot);
    const s_vec_2d down_offs = LenDir(size.y * (1.0f - origin.y), rot - PI * 0.5f);

    poly->pts[0] = (s_vec_2d){pos.x + left_offs.x + up_offs.x, pos.y + left_offs.y + up_offs.y};
    poly->pts[1] = (s_vec_2d){pos.x + right_offs.x + up_offs.x, pos.y + right_offs.y + up_offs.y};
    poly->pts[2] = (s_vec_2d){pos.x + right_offs.x + down_offs.x, pos.y + right_offs.y + down_offs.y};
    poly->pts[3] = (s_vec_2d){pos.x + left_offs.x + down_offs.x, pos.y + left_offs.y + down_offs.y};

    return true;
}

bool DoPolysInters(const s_poly_view* const a, const s_poly_view* const b) {
    return CheckPolySep(a, b) && CheckPolySep(b, a);
}

bool DoesPolyIntersWithRect(const s_poly_view* const poly, const s_rect rect) {
    const s_vec_2d pts[4] = {
        {rect.x, rect.y},
        {rect.x + rect.width, rect.y},
        {rect.x + rect.width, rect.y + rect.height},
        {rect.x, rect.y + rect.height}
    };

    const s_poly rect_poly = {
        .pts = (s_vec_2d*)pts,
        .cnt = 4
    };
    
    return DoPolysInters(poly, (const s_poly_view*)&rect_poly);
}
