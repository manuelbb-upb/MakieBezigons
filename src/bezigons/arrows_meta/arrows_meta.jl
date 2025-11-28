abstract type AbstractArrowSpec <: AbstractTypedSpec end

function _bezigon_geometry(
    spec::AbstractArrowSpec; bez_x, bez_y, sw, size, strokewidth
)
    sw_par = strokewidth
    data = _bezigon_data(spec)
    @unpack align, reversed, swapped, linecap, joinstyle, miter_limit = data.attrs
    return _bezigon_geometry_arrow(
        spec; 
        bez_x, bez_y, sw, sw_par, 
        align, reversed, swapped, linecap, joinstyle, miter_limit
    )
end

function _bezigon_geometry_arrow(
    spec::AbstractArrowSpec; 
    kwargs...
)
    data = __bezigon_arrow_data(spec; kwargs...)
    return _arrow_data_to_geometry(data; kwargs...)
end

function __bezigon_arrow_data(spec::AbstractArrowSpec; kwargs...)
    return nothing::NamedTuple
end

function _arrow_data_to_geometry(data; reversed, swapped, align, sw, kwargs...)
    @unpack bpath, tip_end, line_end = data
    sw = get(data, :sw, sw)
    path_transform = (
        reversed ? -1 : 1,
        swapped ? -1 : 1
    )
    if align != 0
        connector_end = (1-align) * line_end + align * tip_end
        shift_end = connector_end - line_end
    else
        shift_end = 0
    end
    target_pos = Point2f(tip_end + shift_end, 0)
    connector_pos = Point2f(line_end + shift_end, 0)
 
    if path_transform != (1, 1)
        bpath = scale(bpath, path_transform)
        target_pos = target_pos .* path_transform
        connector_pos = connector_pos .* path_transform
    end
    return BezigonGeometry(bpath, target_pos, connector_pos), (; sw,)
end

function _common_attrs(
    ::Type{<:AbstractArrowSpec};
    kwargs...
)
    return __common_attrs_arrow(; kwargs...)
end

function __common_attrs_arrow(;
    align :: Real = 0,
    reversed :: Bool = false,
    swapped :: Bool = false,
    miter_limit :: Real = eps32,
    kwargs...
)
    align = min(1, max(0, align))
    base_attrs = __common_attrs_typed(; kwargs...)
    return merge(base_attrs, (; align, reversed, swapped, miter_limit))
end

function _match_bezier_curveto_tangents(
    # target curve from p0 to p3 with controls p1 and p2
    p0, p1, p2, p3,
    # new endpoints
    P0, P3;
    # curve parameter values where tangents should match
    eq = [0f0, 1f0], ls = Float32[1/6, 2/6, 3/6, 4/6, 5/6]
)
    dt_b(t) = (1 - t)^2 .* (p1 .- p0) .+ 2 * (1-t) * t .* (p2 .- p1) .+ t^2 .* (p3 .- p2)   # * 3

    # (1 - t)^2 * (x1 - P0[1]) + 2 * (1-t) * t * (x2 - x1) +  t^2 * (P3[1] - x2)
    # (1-t)^2*x1 - (1-t)^2*P0[1] + 2*(1-t)*t*x2 - 2*(1-t)*t*x1 + t^2*P3[1] - t^2*x2
    # ((1-t)^2 - 2*(1-t)*t)*x1 + (2*(1-t)*t - t^2)*x2 + (t^2*P3[1] - (1-t)^2*P0[1])
    # (similar for y1 & y2)
    dt_B1(t) = (1-t)^2 - 2*(1-t)*t
    dt_B2(t) = 2*(1-t)*t - t^2
    dt_Bx(t) = t^2*P3[1] - (1-t)^2*P0[1]
    dt_By(t) = t^2*P3[2] - (1-t)^2*P0[2]
    at = vcat(eq, ls)
    N = length(at)
    A = zeros(Float32, N, 2)
    b = zeros(Float32, N, 2)
    for (i, t) in enumerate(at)
        A[i, 1] = dt_B1(t) 
        A[i, 2] = dt_B2(t) 
        b[i, :] .= dt_b(t)
        b[i, 1] -= dt_Bx(t)
        b[i, 2] -= dt_By(t)
    end
    if length(eq) < 2
        β = A \ b
    else
        # https://en.wikipedia.org/wiki/Ordinary_least_squares#Constrained_estimation
        Qt = A[1:length(eq), :]
        Q = transpose(Qt)
        c = b[1:2, :]
        X = A
        y = b
        XtX = qr(X'X)
        Xy = X'y
        α = XtX \ Xy
        tmp0 = Qt * α - c
        tmp1 = Qt * (XtX \ Q)
        tmp2 = Q * (tmp1 \ tmp0)
        tmp3 = XtX \ tmp2
        β = α - tmp3
    end 
    P1 = β[1, :]
    P2 = β[2, :]
    return [Point2(P0), Point2(P1), Point2(P2), Point2(P3)]
end
