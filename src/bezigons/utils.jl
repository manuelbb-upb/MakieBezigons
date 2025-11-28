function resolve_relative_sizes(;
    strokewidth, 
    length = nothing, 
    angle = nothing, 
    angle_ = nothing, 
    width = nothing, 
    width_ = nothing, 
    kwargs... 
)
    sw = strokewidth
    bez_x = bez_y = NaN32
    if isa(angle, Tup3)
        θ, L, l = angle
        bez_x = (L + l * sw) * cos(θ)
        bez_y = (2 * sin(θ/2)) * bez_x
    end
    isnan(bez_x) && (bez_x = _relative_length(length, sw))
   
    isnan(bez_y) && (bez_y = _relative_length(width, sw))
    isnan(bez_y) && (bez_y = _relative_length(width_, bez_x))
    if isnan(bez_y) && isa(angle_, Real)
        bez_y = tan(ang_ / 2) * bez_x
    end

    return bez_x, bez_y
end

function resolve_bezigon_strokewidth(;
    strokewidth, bez_x,
    line_width = nothing, line_width_ = nothing,
    kwargs...
)
    sw = strokewidth
    outlinewidth = _relative_length(line_width, sw)
    isnan(outlinewidth) && (outline_width = _relative_length(line_width_, bez_x))
    return outlinewidth
end

_relative_length(len::Real, sw) = len
_relative_length(len::Tup2, sw) = len[1] + len[2] * sw
_relative_length(len, sw) = NaN32

f32(t) = convert(Float32, t)
f32(k::Symbol, t) = f32(t)
v32(t) = convert(Vector{Float32}, t)
v32(k::Symbol, t) = v32(t)
boolean(k::Symbol, t) = boolean(t)
boolean(t) = convert(Bool, t)
makeref(k::Symbol, t) = _makeref(t, Any)
_makeref(t, T::Type)=Ref{T}(t)

_num_attr(x, fback = nothing) = __num_attr(x, fback)
__num_attr(x::Real, fback) = x
__num_attr(x, fback) = fback

_tup2_attr(x, fback = nothing) = __tup2_attr(x, fback)
__tup2_attr(x::Real, fback) = (x, 0)
__tup2_attr(x::Tup2, fback) = x
__tup2_attr(x, fback) = fback

_tup3_attr(x, fback = nothing) = __tup3_attr(x, fback)
__tup3_attr(x::Real, fback) = (x, 0, 0)
__tup3_attr(x::Tup2, fback) = (x..., 0)
__tup3_attr(x::Tup3, fback) = x
__tup3_attr(x, fback) = fback

_make_spec1(k::Symbol, v) = _make_spec1(v)
_make_spec1(v) = f32(_num_attr(v, NaN32))

_make_spec2(k::Symbol, v) = _make_spec2(v)
_make_spec2(v) = convert(NTuple{2, Float32}, _tup2_attr(v, (NaN32, NaN32)))

_make_spec3(k::Symbol, v) = _make_spec3(v)
_make_spec3(v) = convert(NTuple{3, Float32}, _tup3_attr(v, (NaN32, NaN32, NaN32)))

_replace_nan_or_inf(v, fback::Real=0) = _replace_nan(_replace_inf(v, fback), fback)

function _replace_nan(v, fback::Real=0)
    _replace_bad(isnan, v, fback)
end
function _replace_inf(v, fback::Real=0)
    _replace_bad(isinf, v, fback)
end

function _replace_bad(@nospecialize(isbad), v::Real, fback::Real=0)
    isbad(v) && return fback
    return v
end
function _replace_bad(@nospecialize(isbad), v, fback::Real=0)
    return _replace_bad.(isbad, v, fback)
end