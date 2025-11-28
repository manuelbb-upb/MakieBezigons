const pi32 = Float32(π)

"Specification describing a marker like bezigon or bezier path aligned with the x-axis."
abstract type AbstractBezigonSpec end
abstract type AbstractBezigonInstance end

function bezigon(
    ::AbstractBezigonSpec;
    size, strokewidth
)
    return nothing :: AbstractBezigonInstance
end

function transformed_bezigon(
    ::AbstractBezigonInstance;
    target!, rotation
)
    return nothing :: AbstractBezigonInstance
end

"Return `true` if the bezigon should be filled."
is_bezigon_filled(::AbstractBezigonInstance) = true

"Return `true` if the bezigon should be stroked."
is_bezigon_stroked(::AbstractBezigonInstance) = true

"Return `true` if the bezigon is actually a closed bezigon, return `false` if it's a bezier path."
is_bezigon_closed(::AbstractBezigonInstance) = true

bezigon_strokewidth(::AbstractBezigonInstance) = nothing :: Real

bezigon_path(::AbstractBezigonInstance) = nothing :: BezierPath
target_pos(::AbstractBezigonInstance) = nothing :: Point2
connector_pos(::AbstractBezigonInstance) = nothing :: Point2

bezigon_joinstyle(::AbstractBezigonInstance) = :miter
bezigon_linecap(::AbstractBezigonInstance) = :butt
bezigon_miter_limit(::AbstractBezigonInstance) = pi32 / 3

rotation_offset(::AbstractBezigonInstance) = 0

function bezigon_outline_path(bez::AbstractBezigonInstance)
    return stroke_bezier_path(
        bezigon_path(bez), F16_16;
        joinstyle = bezigon_joinstyle(bez),
        linecap = bezigon_linecap(bez),
        miter_limit = bezigon_miter_limit(bez),
        opened = !is_bezigon_closed(bez),
        radius = bezigon_strokewidth(bez) / 2
    )
end

bezigon_fillcolor(::AbstractBezigonInstance) = automatic
bezigon_strokecolor(::AbstractBezigonInstance) = automatic