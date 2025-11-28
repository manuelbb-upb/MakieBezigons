struct ComputerModernRightarrow{data_Type} <: AbstractArrowSpec
    data :: data_Type
end

function ComputerModernRightTip(; kwargs...)
    return ComputerModernRightarrow(; reversed = false, kwargs...)
end
function ComputerModernRightTail(; kwargs...)
    return ComputerModernRightarrow(; reversed = true, kwargs...)
end

function _fallback_attrs(
    ::Type{<:ComputerModernRightarrow};
    length = (1.9f0, 2.2f0),
    width_ = (0f0, 2.096744f0),
    line_width = (0, 1),
    linecap = :round,
    joinstyle = :round,
    filled = false,
    kwargs...
)
    return (; length, width_, line_width, linecap, joinstyle, filled, closed = false)
end


function __bezigon_arrow_data(
    spec::ComputerModernRightarrow;
    bez_x, bez_y, sw, sw_par,
    align, reversed, swapped, linecap, joinstyle, miter_limit
)
    cx1 = -.81731f0; cy1 = .2f0
    cx2 = -.41019f0; cy2 = .05833333f0

    arr_length = bez_x
    arr_width = bez_y

    inner_length = arr_length - sw
    if inner_length < eps32
        _sw = arr_length - eps32
        sw = min(sw, _sw)
    end

    inner_width = arr_width - sw
    if inner_width < eps32
        _sw = arr_width - eps32
        sw = min(sw, _sw)
    end

    back_end = - inner_length - sw / 2
    line_end = - sw / 2
    visual_back_end = sw / 2

     if sw > 0
        cot_psi_tip = ((1-cx2) * inner_length) / (cy2 * inner_width)
        csc_psi_tip = sqrt(cot_psi_tip^2 + 1)
        sin_psi_tip = 1 / csc_psi_tip

        miter_half_len = csc_psi_tip * sw / 2
        miter_half_len_max = Makie.miter_angle_to_distance(miter_limit) * sw
        tip_end = if join == :round
            sw / 2
        elseif join == :miter && miter_half_len <= miter_half_len_max
            miter_half_len
        else# if join == :bevel
            sin_psi_tip * sw
        end
    else
        tip_end = 0f0
    end

    bezier_points_inner = let L = inner_length, W = inner_width;
        p0 = Point2d(-L, W/2)
        p1 = Point2d(cx1 * L, cy1 * W)
        p2 = Point2d(cx2 * L, cy2 * W)
        p3 = Point2d(0, 0)
        (p0, p1, p2, p3)
    end

    if sw > 0
        bezier_points = let L = arr_length, W = arr_width;
            p0 = Point2d(-L, W/2)
            p1 = Point2d(cx1 * L, cy1 * W)
            p2 = Point2d(cx2 * L, cy2 * W)
            p3 = Point2d(0, 0)
            P0 = bezier_points_inner[1]
            P3 = bezier_points_inner[4]
            _match_bezier_curveto_tangents(p0, p1, p2, p3, P0, P3)
        end
    else
        bezier_points = bezier_points_inner
    end
   
    swap(p) = Point2d(p[1], -p[2])

    bpath = let (P0, P1, P2, P3) = bezier_points;
        _P2 = swap(P2)
        _P1 = swap(P1)
        _P0 = swap(P0)
        BezierPath([
            MoveTo(P0),             # top left
            CurveTo(P1,P2,P3),      # tip
            CurveTo(_P2,_P1,_P0)    # bottom left
        ])
    end
    return (; visual_back_end, bpath, tip_end, line_end, back_end, sw)
end