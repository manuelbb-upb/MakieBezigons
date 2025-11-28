Base.@kwdef struct PathArrow
    tip :: Any = nothing
    tail :: Any = nothing
end

_init_path_decoration(obj; linewidth) = obj
function _init_path_decoration(spec::AbstractBezigonSpec; linewidth)
    return bezigon(spec; size=1, strokewidth = linewidth)
end

_endpoint(cmd) = Makie.endpoint(cmd)
_startpoint(c::MoveTo) = c.p
_shrinksize(obj) = Makie.shrinksize(obj)
function _shrinksize(bez::AbstractBezigonInstance)
    tp = target_pos(bez)
    cp = connector_pos(bez)
    return sqrt(sum(abs2, tp .- cp))
end

function Makie.plotspecs(_bez::AbstractBezigonInstance, pos; rotation, color, linewidth)
    pspecs = Makie.PlotSpec[]
    if !(is_bezigon_filled(_bez) || is_bezigon_stroked(_bez))
        return pspecs
    end
    bez = transformed_bezigon(_bez; target! = (0, 0), rotation = 0)
    rotation += rotation_offset(bez)
    if is_bezigon_filled(bez)
        marker = bezigon_path(bez)
        fcolor = bezigon_fillcolor(bez)
        if isa(fcolor, Automatic)
            fcolor = color
        end
        inner = Makie.PlotSpec(:Scatter, pos; space = :pixel, rotation, color = fcolor, marker, markersize = 1)
        push!(pspecs, inner)
    end
    if is_bezigon_stroked(bez)
        marker = bezigon_outline_path(bez)
        scolor = bezigon_strokecolor(bez)
        if isa(scolor, Automatic)
            scolor = color
        end
        outer = Makie.PlotSpec(:Scatter, pos; space = :pixel, rotation, color = scolor, marker, markersize = 1)
        push!(pspecs, outer)
    end
    return pspecs
end

function Makie.annotation_style_plotspecs(l::PathArrow, path::BezierPath, p1, p2; color, linewidth)
    length(path.commands) < 2 && return PlotSpec[]
    p_tip = _endpoint(path.commands[end])
    p_tail = _startpoint(path.commands[1])

    tip = _init_path_decoration(l.tip; linewidth)
    tail = _init_path_decoration(l.tail; linewidth)
    
    shrink_for_tip = _shrinksize(tip)
    shrink_for_tail = _shrinksize(tail)

    shortened_path = Makie.shrink_path(path, (shrink_for_tail, shrink_for_tip))
    length(shortened_path.commands) < 2 && return PlotSpec[]

    _p2 = _endpoint(shortened_path.commands[end])
    if p2 != _p2
        tip_dir = p2 .- _p2     # normalized in `Makie`, but I don't think it has to be
    else
        p2_prev = _endpoint(shortened_path.commands[end-1])
        tip_dir = _tangent_at_endpoint(shortened_path.commands[end], p2_prev)
    end
    tip_rotation = atan(tip_dir[2], tip_dir[1])

    _p1 = _startpoint(shortened_path.commands[1])
    if p1 != _p1
        tail_dir = p1 - _p1
    else
        p1_succ = _startpoint(shortened_path.commands[2])
        tail_dir = _tangent_at_startpoint(shortened_path.commands[1], p1_succ)
    end
    tail_rotation = atan(tail_dir[2], tail_dir[1])

    specs = [
        Makie.PlotSpec(:Lines, shortened_path; color, space = :pixel, linewidth);
    ]
    if tip !== nothing
        append!(specs, Makie.plotspecs(tip, p_tip; rotation = tip_rotation, color, linewidth))
    end
    if tail !== nothing
        append!(specs, Makie.plotspecs(tail, p_tail; rotation = tail_rotation, color, linewidth))
    end
    return specs
end

function _tangent_at_startpoint(c::Union{MoveTo, LineTo}, p_succ)
    return p_succ - c.p
end
function _tangent_at_endpoint(c::Union{MoveTo, LineTo}, p_prev)
    return c.p - p_prev
end
function _tangent_at_startpoint(c::CurveTo, p_succ)
    return c.c1 - c.p
end
function _tangent_at_endpoint(c::CurveTo, p_prev)
    return c.p - c.c2
end
