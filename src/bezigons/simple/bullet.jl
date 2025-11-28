
struct Bullet{data_Type} <: AbstractSimpleSpec
    data :: data_Type
end

function _fallback_attrs(::Type{<:Bullet};
    diameter = nothing, radius = nothing, kwargs...
)

    length = nothing
    if isa(diameter, NumOrTup2)
        length = diameter
    elseif isa(radius, NumOrTup2)
        length = 2 .* radius
    end
    if !isnothing(length)
        return (;
            length, width_ = (0, 1), 
            width = nothing, angle = nothing, angle_ = nothing
        )
    else
        return __fallback_attrs_simple(; kwargs...)
    end
end

function _bezigon_geometry_simple(
    spec::Bullet; 
    bez_x, bez_y, sw, target_anchor, connector_anchor
)
    L = bez_x - sw
    H = bez_y - sw

    r_x = L/2
    r_y = H/2

    bpath = BezierPath(
        [
            MoveTo(Point2(r_x, 0.0)),
            EllipticalArc(Point2(0.0, 0), r_x, r_y, 0.0, 0.0, 2pi),
            ClosePath(),
        ]
    )
    target_pos = _anchored_point_bullet(r_x, r_y, target_anchor)
    connector_pos = _anchored_point_bullet(r_x, r_y, connector_anchor)
    return BezigonGeometry(bpath, target_pos, connector_pos)
end

function _anchored_point_bullet(
    r_x, r_y, anchor
)
    θ = if anchor isa Real
        anchor
    else
        _anchor_rel_coords_bullet(_anchor_tuple(anchor))
    end
    if isnan(θ) || isinf(θ)
        return Point2f(0, 0)
    else
        x = r_x * cos(θ)
        y = r_y * sin(θ)
        return Point2f(x, y)
    end        
end

function _anchor_rel_coords_bullet(tup::Tup2)
    return atan(tup[2], tup[1])
end

function _anchor_rel_coords_bullet(anc::NTuple{2, Symbol})
    θ = if anc == (:right, :center)
        0f0
    elseif anc == (:right, :top)
        pi32 / 4
    elseif anc == (:center, :top)
        pi32 / 2
    elseif anc == (:left, :top)
        3 * pi32 / 4
    elseif anc == (:left, :center)
        pi32
    elseif anc == (:left, :bottom)
        5 * pi32 / 4
    elseif anc == (:center, :bottom)
        3 * pi32 / 2
    elseif anc == (:right, :bottom)
        7 * pi32 / 4
    else
        NaN32
    end
    return θ
end
