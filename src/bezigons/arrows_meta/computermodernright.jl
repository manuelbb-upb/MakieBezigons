# TODO
struct ComputerModernRightarrowSpecification{attrs_Type} <: AbstractBezigonDecoSpecification
    attrs :: attrs_Type
end

function ComputerModernRightarrowSpecification(;
    length = (1.9f0, 2.2f0),
    width_ = (0f0, 2.096744f0),
    line_width = (0f0, 1f0),
    linecap = :round,
    joinstyle = :round,
    is_filled = false,
    kwargs...
    )
    attrs = _setup_base_bezigon_attributes(;
        length, width_, line_width, linecap, joinstyle, is_filled, kwargs...)
    return ComputerModernRightarrowSpecification(attrs)
end

function ComputerModernRightarrowTip(; kwargs...)
    ComputerModernRightarrowSpecification(; reversed=false, kwargs...)
end
function ComputerModernRightarrowTail(; kwargs...)
    ComputerModernRightarrowSpecification(; reversed=true, kwargs...)
end

function _register_path_computations!(graph, ::Type{<:ComputerModernRightarrowSpecification})
    graph = _register_appearance_attributes!(graph)
    cx1 = -.81731f0; cy1 = .2f0
    cx2 = -.41019f0; cy2 = .05833333f0
    map!(
        graph, 
        [:arrow_length, :arrow_width, :strokewidth_fin, :stroke_bgon, :reversed, :joinstyle, :miter_limit], 
        [:inner_length, :inner_width, :line_end, :back_end, :tip_end, :miter_limit_fin]
    ) do arr_length, arr_width, _sw, stroke_bgon, rev, join, mlimit
        sw = stroke_bgon ? _sw : 0f0
        inner_length = arr_length - sw
        inner_width = arr_width - sw

        tan_psi_tip = cy2 * inner_width / ((1-cx2) * inner_length)
        sin_psi_tip_inv = sqrt( 1/tan_psi_tip^2 + 1)
        miter_half_len = sin_psi_tip_inv * sw / 2
        tip_end = if join == :round
            sw / 2
        elseif join == :miter
            miter_half_len
        else# if join == :bevel
            1 / sin_psi_tip_inv * sw
        end
        miter_limit = if join == :miter
            _mlimit = miter_distance_to_angle(miter_half_len / sw) / 2
            max(mlimit, _mlimit)
        else
            mlimit
        end
        back_end = inner_length - sw / 2
        line_end = - sw / 2
        return (inner_length, inner_width, line_end, back_end, tip_end, miter_limit)
    end
    
    map!(graph, [:inner_length, :inner_width], :bezier_points) do L, W
        p0 = Point2(-L, W/2)
        p1 = Point2(cx1 * L, cy1 * W)
        p2 = Point2(cx2 * L, cy2 * W)
        p3 = Point2(0, 0)
        return (p0, p1, p2, p3)
    end
    
    map!(
        graph, :bezier_points, :path0
    ) do (P0, P1, P2, P3) 
        swap(p) = Point2d(p[1], -p[2])
        _P2 = swap(P2)
        _P1 = swap(P1)
        _P0 = swap(P0)
        BezierPath([
            MoveTo(P0),             # top left
            CurveTo(P1,P2,P3),      # tip
            CurveTo(_P2,_P1,_P0)    # bottom left
        ])
    end
    
    graph = _register_bezigon_drawing_cmds!(graph)

    return graph
end