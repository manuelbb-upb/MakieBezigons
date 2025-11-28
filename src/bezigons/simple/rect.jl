struct Rect{data_Type} <: AbstractSimpleSpec
    data :: data_Type
end

function _bezigon_geometry_simple(
    spec::Rect; 
    bez_x, bez_y, sw, target_anchor, connector_anchor
)
    L = bez_x - sw
    H = bez_y - sw
    
    xmin = -L/2
    xmax = L/2
    ymin = -H/2
    ymax = H/2
    bl = Point2(xmin, ymin)
    br = Point2(xmax, ymin)
    tr = Point2(xmax, ymax)
    tl = Point2(xmin, ymax)
    bpath = BezierPath([
        MoveTo(bl),
        LineTo(br),
        LineTo(tr),
        LineTo(tl),
        ClosePath()
    ])
    target_pos = _anchored_point_rect(xmin, xmax, ymin, ymax, target_anchor)
    connector_pos = _anchored_point_rect(xmin, xmax, ymin, ymax, connector_anchor)
    return BezigonGeometry(bpath, target_pos, connector_pos)
end

function _anchored_point_rect(
    xmin, xmax, ymin, ymax, anchor
)
    t1, t2 = _anchor_rel_coords_rect(_anchor_tuple(anchor))
    x = (1 - t1) * xmin + t1 * xmax
    y = (1 - t2) * ymin + t2 * ymax
    return Point2(x, y)
end

function _anchor_rel_coords_rect(tup::Tup2)
    return tup
end

function _anchor_rel_coords_rect(tup::NTuple{2, Symbol})
    t1 = if tup[1] === :left
        0
    elseif tup[1] === :right
        1
    else
        1 // 2
    end
    t2 = if tup[2] === :bottom
        0
    elseif tup[2] === :top
        1
    else
        1 // 2
    end
    return (t1, t2)
end
