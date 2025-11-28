const eps32 = eps(Float32)

abstract type AbstractTypedSpec <: AbstractBezigonSpec end
abstract type AbstractTypedInstance <: AbstractBezigonInstance end

struct BezigonData{
    size_attrs_Type,
    linesize_attrs_Type,
    attrs_Type,
    #defaults_Type,
}
    size_attrs :: size_attrs_Type
    linesize_attrs :: linesize_attrs_Type
    attrs :: attrs_Type
    #defaults :: defaults_Type
end

struct BezigonGeometry{
    target_pos_Type, connector_pos_Type
}
    bpath :: BezierPath
    target_pos :: target_pos_Type
    connector_pos :: connector_pos_Type
end

function rotate(geom::BezigonGeometry, rot)
    bpath = rotate(geom.bpath, rot)
    target_pos = _rotate_2d(geom.target_pos, rot) 
    connector_pos = _rotate_2d(geom.target_pos, connector_pos)
    return BezigonGeometry(bpath, target_pos, connector_pos)
end

function _rotate_2d(v, rotation)
    _x, _y = v
    x = _x * cos(rotation) - _y * sin(rotation)
    y = _y * cos(rotation) + _x * sin(rotation)
    return [x; y]
end

function translate(geom::BezigonGeometry, shift)
    bpath = translate(geom.bpath, shift)
    target_pos = geom.target_pos .+ shift
    connector_pos = geom.connector_pos .+ shift
    return BezigonGeometry(bpath, target_pos, connector_pos)
end

struct TypedBezigon{
    geom_Type <: BezigonGeometry, 
    props_Type
} <: AbstractTypedInstance
    geom :: geom_Type
    props :: props_Type
end

#============================================
AbstractBezigonSpec Interface
============================================#

function bezigon(
    spec::AbstractTypedSpec;
    size, strokewidth
)
    strokewidth = _replace_nan_or_inf(strokewidth, zero(strokewidth))
    
    data = _bezigon_data(spec)
    
    bez_x, bez_y = resolve_relative_sizes(; strokewidth, data.size_attrs...)
    if isnan(bez_x) || isnan(bez_y)
        error("`bezigon`: Could not determine size.")
    end

    size_factor = size * data.attrs.scale
    bez_x *= size_factor
    bez_y *= size_factor

    sw = resolve_bezigon_strokewidth(; strokewidth, bez_x, data.linesize_attrs...)
    if isnan(sw)
        sw = strokewidth
    end
    sw = max(0, sw)

    geom, changed = _bezigon_geometry(spec; bez_x, bez_y, sw, size, strokewidth)

    return TypedBezigon(
        geom, 
        (;
            sw = get(changed, :sw, sw), 
            filled = data.attrs.filled, 
            closed = data.attrs.closed, 
            stroked = data.attrs.stroked, 
            joinstyle = data.attrs.joinstyle,
            linecap = data.attrs.linecap,
            miter_limit = get(changed, :miter_limit, data.attrs.miter_limit),
            color = data.attrs.color,
            fillcolor = data.attrs.fillcolor,
            strokecolor = data.attrs.strokecolor,
            reversed = get(data.attrs, :reversed, false)
        )
    )
end

function transformed_bezigon(
    bezigon::TypedBezigon;
    target!, rotation
)
    geom = bezigon.geom
    if rotation != 0
        geom = rotate(geom, rotation)
    end
    target = geom.target_pos
    if target! != target
        shift = target! .- target
        geom = translate(geom, shift)
    end
    return TypedBezigon(geom, bezigon.props)
end
#===========================================#

#============================================
AbstractBezigonInstance Interface
============================================#

is_bezigon_filled(bez::TypedBezigon) = bez.props.filled :: Bool
is_bezigon_stroked(bez::TypedBezigon) = bez.props.stroked :: Bool
is_bezigon_closed(bez::TypedBezigon) = bez.props.closed :: Bool
bezigon_linecap(bez::TypedBezigon) = bez.props.linecap :: Symbol
bezigon_joinstyle(bez::TypedBezigon) = bez.props.joinstyle :: Symbol
bezigon_strokewidth(bez::TypedBezigon) = bez.props.sw :: Real
bezigon_miter_limit(bez::TypedBezigon) = bez.props.miter_limit :: Real

bezigon_path(bez::TypedBezigon) = bez.geom.bpath :: BezierPath
target_pos(bez::TypedBezigon) = bez.geom.target_pos :: Makie.VecTypes{2}
connector_pos(bez::TypedBezigon) = bez.geom.connector_pos :: Makie.VecTypes{2}

function bezigon_fillcolor(bez::TypedBezigon)
    if !isa(bez.props.fillcolor, Automatic)
        return bez.props.fillcolor
    end
    return bez.props.color
end

function bezigon_strokecolor(bez::TypedBezigon)
    if !isa(bez.props.strokecolor, Automatic)
        return bez.props.strokecolor
    end
    return bez.props.strokecolor
end

#===========================================#

#============================================
AbstractTypedSpec Interface
============================================#

# All subtypes of `AbstractTypedInstance` should have a field `data`
# and a single argument constructor accepting `data::BezigonData`:
_bezigon_data(spec::AbstractTypedSpec) = spec.data :: BezigonData

function _init_typed_spec(T::Type{<:AbstractTypedSpec}, data :: BezigonData)
    return T(data)
end

# We can then have a keyword constructor taking care of resetting defaults:
function (T::Type{<:AbstractTypedSpec})(;
    kwargs...
)
    ## get a tuple of fallback attributes for relative sizes
    ## (`fbacks` can also be used to override kwargs in call to `_common_attrs`)
    fbacks = _fallback_attrs(T; kwargs...)  

    ## try to parse `kwargs...` for size information
    szx_valid, szy_valid, size_attrs = _size_attrs_tuple(T; kwargs...)
    ## if unsuccessful, use fallback attributes
    if !(szx_valid && szy_valid)
        length = get(fbacks, :length, nothing)
        angle = get(fbacks, :angle, nothing)
        width = get(fbacks, :width, nothing)
        width_ = get(fbacks, :width_, nothing)
        angle_ = get(fbacks, :angle_, nothing)
        if !szx_valid && !szy_valid
            sz_fbacks = (; length, angle, width, width_, angle_)
        elseif !szx_valid
            sz_fbacks = (; length, angle)
        else
            sz_fbacks = (; width, width_, angle_)
        end
        szx_valid, szy_valid, size_attrs = _size_attrs_tuple(T; kwargs..., sz_fbacks...)
    end
    !(szx_valid && szy_valid) && error("Incomplete size specification for bezigon of type `$(T)`.")
    
    ## try to parse `kwargs...` for line width information
    lsz_valid, linesize_attrs = _linesize_attrs_tuple(T; kwargs...)
    ## if unsuccessful, use fallback attributes
    if !lsz_valid
        line_width = get(fbacks, :line_width, nothing)
        line_width_ = get(fbacks, :line_width_, nothing)
        lsz_valid, linesize_attrs = _linesize_attrs_tuple(T; kwargs..., line_width, line_width_)
    end
    !lsz_valid && error("Incomplete line width specification for bezigon of type `$T`.")

    attrs = _common_attrs(T; kwargs..., fbacks...)
    data = BezigonData(size_attrs, linesize_attrs, attrs)
    return _init_typed_spec(T, data)
end

function _bezigon_geometry(
    ::AbstractTypedSpec; bez_x, bez_y, sw, size, strokewidth
)
    return (nothing::BezigonGeometry, (;))
end

function _fallback_attrs(
    T::Type{<:AbstractTypedSpec};
    kwargs...
)
    return __fallback_attrs_typed(; kwargs...)
end

function __fallback_attrs_typed(; kwargs...)
    return (;
        length = 1,
        width_ = (0, 1),
        line_width = (0, 1)
    )
end

function _common_attrs(
    T::Type{<:AbstractTypedSpec};
    kwargs...
)
    return _common_attrs_typed(; kwargs...)
end

function __common_attrs_typed(;
    scale :: Real = 1,
    linecap :: Symbol = :butt,
    joinstyle :: Symbol = :miter,
    miter_limit :: Real = π/3,
    color = automatic,
    fillcolor = automatic,
    strokecolor = automatic,
    closed :: Bool = true,
    stroked :: Bool = true,
    filled :: Bool = true,
    kwargs...
)
    @assert linecap === :butt || linecap === :rect || linecap === :round "`linecap` should be `:round`, `:butt` or `:rect`."
    @assert joinstyle === :round || joinstyle === :bevel || joinstyle === :miter "`joinstyle` should be `:round`, `:bevel` or `:miter`."
    miter_limit = max(eps32, min(pi32 - eps32, miter_limit))

    return (; 
        linecap, joinstyle, miter_limit, closed, stroked, filled, scale,
        color, fillcolor, strokecolor
    )
end

function _size_attrs_tuple(
    ::Type{<:AbstractTypedSpec};
    kwargs...
)
    return __size_attrs_tuple(; kwargs...)
end

function __size_attrs_tuple(; 
    length = nothing, 
    angle = nothing, 
    angle_ = nothing, 
    width = nothing, 
    width_ = nothing, 
    kwargs... 
)
    x_valid = y_valid = false
    if isa(angle, Tup3)
        x_valid = y_valid = true
        angle = _replace_nan_or_inf(angle, 0)
    end
    if isa(length, NumOrTup2)
        x_valid && error("Ambiguous length specification for bezigon.")
        x_valid = true
        length = _replace_nan_or_inf(length, 0)
    end
    if isa(width, NumOrTup2)
        y_valid && error("Ambiguous width specification for bezigon.")
        y_valid = true
        width = _replace_nan_or_inf(width, 0)
    end
    if isa(width_, NumOrTup2)
        y_valid && error("Ambiguous width specification for bezigon.")
        y_valid = true
        width_ = _replace_nan_or_inf(width_, 0)
    end
    if isa(angle_, Real)
        y_valid && error("Ambiguous width specification for bezigon.")
        y_valid = true
        angle_ = _replace_nan_or_inf(angle_, 0)
    end
    return x_valid, y_valid, (; length, angle, angle_, width, width_)
end

function _linesize_attrs_tuple(
    ::Type{<:AbstractTypedSpec}; 
    kwargs...
)
    return __linesize_attrs_tuple(; kwargs...)
end

function __linesize_attrs_tuple(; 
    line_width = nothing,
    line_width_ = nothing,
    kwargs... 
)
    valid = false
    if isa(line_width, NumOrTup2)
        valid = true
        line_width = _replace_nan_or_inf(line_width, 0)
    end
    if isa(line_width_, NumOrTup2)
        valid && error("Ambiguous line width specifications for bezigon.")
        valid = true
        line_width_ = _replace_nan_or_inf(line_width_, 0)
    end

    return valid, (; line_width, line_width_)
end
#===========================================#