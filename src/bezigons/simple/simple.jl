
abstract type AbstractSimpleSpec <: AbstractTypedSpec end

function _bezigon_geometry(
    spec::AbstractSimpleSpec; bez_x, bez_y, sw, size, strokewidth
)
    data = _bezigon_data(spec)
    target_anchor = data.attrs.target_anchor
    connector_anchor = data.attrs.connector_anchor
    geom = _bezigon_geometry_simple(spec; bez_x, bez_y, sw, target_anchor, connector_anchor)
    return geom, (;)
end

function _bezigon_geometry_simple(spec; kwargs...)
    return nothing::BezigonGeometry
end

function _common_attrs(
    ::Type{<:AbstractSimpleSpec};
   kwargs...
)
    return __common_attrs_simple(; kwargs...)
end

function __common_attrs_simple(; 
    target_anchor = :center,
    connector_anchor = :center,
    kwargs...
)
    base = __common_attrs_typed(; kwargs...)
    return merge(base, (; target_anchor, connector_anchor))
end
__fallback_attrs_simple(; kwargs...) = __fallback_attrs_typed(; kwargs...)

const valid_anchor_tups = (
    (:center, :top),
    (:center, :bottom),
    (:center, :center),
    (:left, :top),
    (:left, :bottom),
    (:left, :center),
    (:right, :top),
    (:right, :bottom),
    (:right, :center),
)

function _anchor_tuple(num::Real)
    return (num, num)
end

function _anchor_tuple(tup::Tup2)
    return tup
end

function _anchor_tuple(symb::Symbol)
    if symb === :north || symb === :top
        return (:center, :top)
    elseif symb === :south || symb === :bottom
        return (:center, :bottom)
    elseif symb === :west || symb === :left
        return (:left, :center)
    elseif symb === :east || symb === :right
        return (:right, :center)
    elseif symb === :northeast || symb === :topright
        return (:right, :top)
    elseif symb === :southeast || symb === :bottomright
        return (:right, :bottom)
    elseif symb === :southwest || symb === :bottomleft
        return (:left, :bottom)
    elseif symb === :northwest || symb === :topleft
        return (:left, :top)
    else
        return (:center, :center)
    end
end

function _anchor_tuple(_tup::NTuple{2, Symbol})
    tup = _normalize_anchor_symb.(_tup)
    if !(tup in valid_anchor_tups)
        tup = reverse(tup)
    end
    if !(tup in valid_anchor_tups)
        tup = (:center, :center)
    end
    return tup
end

function _normalize_anchor_symb(symb::Symbol)
    symb === :north && return :top
    symb === :south && return :bottom
    symb === :west && return :left
    symb === :east && return :right
    return symb
end