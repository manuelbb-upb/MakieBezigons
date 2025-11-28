# copied from FreeTypeAbstraction
const LIBRARY_LOCK = ReentrantLock()
const FREE_FONT_LIBRARY = FT_Library[C_NULL]

function ft_init()
    @lock LIBRARY_LOCK begin
        if FREE_FONT_LIBRARY[1] != C_NULL
            error("Freetype already initalized. init() called two times?")
        end
        return FT.FT_Init_FreeType(FREE_FONT_LIBRARY) == 0
    end
end

function ft_done()
    @lock LIBRARY_LOCK begin
        if FREE_FONT_LIBRARY[1] == C_NULL
            error("Library == CNULL. FreeTypeAbstraction.done() called before init(), or done called two times?")
        end
        err = FT.FT_Done_FreeType(FREE_FONT_LIBRARY[1])
        FREE_FONT_LIBRARY[1] = C_NULL
        return err == 0
    end
end
##############################

const FT_Angle = FT_Fixed

const cmove_to = Ref{Ptr{Cvoid}}(0) 
const cline_to = Ref{Ptr{Cvoid}}(0) 
const cconic_to = Ref{Ptr{Cvoid}}(0) 
const ccubic_to = Ref{Ptr{Cvoid}}(0)
const outline_funcs = Ref{FT.FT_Outline_Funcs}()

const BEZIER_CMD = Union{MoveTo, LineTo, CurveTo, ClosePath}

### inspired by Makie/src/bezier_path.jl
const PositionFormat = Union{FT_Fixed, F16_16, F26_6}

function make_outline(bpath, P::Type{<:PositionFormat})
    n_contours::FT_Int = 0
    n_points::FT_UInt = 0
    points = FT_Vector[]
    tags = Int8[]
    contours = Int16[]
    for command in bpath.commands
        new_contour, n_newpoints, newpoints, newtags = convert_command(command, P)
        if new_contour
            n_contours += 1
            if n_contours > 1
                push!(contours, n_points - 1) # -1 because of C zero-based indexing
            end
        end
        n_points += n_newpoints
        append!(points, newpoints)
        append!(tags, newtags)
    end
    push!(contours, n_points - 1)
    @assert n_points == length(points) == length(tags)
    @assert n_contours == length(contours)
    push!(contours, n_points)
    # Manually create outline, since FT_Outline_New seems to be problematic on windows somehow
    outline = FT_Outline(
        n_contours,
        n_points,
        pointer(points),
        pointer(tags),
        pointer(contours),
        0
    )
    # Return Ref + arrays that went into outline, so the GC doesn't abandon them
    return (Ref(outline), points, tags, contours)
end

make_FT_Fixed(num) = round(FT_Fixed, num)
make_FT_Fixed(num::Integer) = convert(FT_Fixed, num)
make_FT_Fixed(num::F16_16) = reinterpret(num)
make_FT_Fixed(num::F26_6) = reinterpret(num)
convert_position(::Type{<:FT_Fixed}, num) = make_FT_Fixed(num)
convert_position(::Type{<:F16_16}, num) = make_FT_Fixed(F16_16(num))
convert_position(::Type{<:F26_6}, num) = make_FT_Fixed(F26_6(num))

function ftvec(P::Type{<:PositionFormat}, p)
    return FT_Vector(
        convert_position(P, p[1]), 
        convert_position(P, p[2])
    )
end

function convert_command(m::MoveTo, P)
    return true, 1, ftvec.(P, [m.p]), [FT_Curve_Tag_On]
end

function convert_command(l::LineTo, P)
    return false, 1, ftvec.(P, [l.p]), [FT_Curve_Tag_On]
end

function convert_command(c::CurveTo, P)
    return false, 3, ftvec.(P, [c.c1, c.c2, c.p]), [FT_Curve_Tag_Cubic, FT_Curve_Tag_Cubic, FT_Curve_Tag_On]
end

@enum FT_Stroker_LineJoin_ :: Cuint begin
    FT_STROKER_LINEJOIN_ROUND          = 0
    FT_STROKER_LINEJOIN_BEVEL          = 1
    FT_STROKER_LINEJOIN_MITER          = 2 
    FT_STROKER_LINEJOIN_MITER_FIXED    = 3
end
const FT_STROKER_LINEJOIN_MITER_VARIABLE = FT_STROKER_LINEJOIN_MITER
const FT_Stroker_LineJoin = FT_Stroker_LineJoin_

@enum FT_Stroker_LineCap_ :: Cuint begin
    FT_STROKER_LINECAP_BUTT = 0
    FT_STROKER_LINECAP_ROUND
    FT_STROKER_LINECAP_SQUARE
end
const FT_Stroker_LineCap = FT_Stroker_LineCap_

@enum FT_StrokerBorder_ :: Cuint begin
    FT_STROKER_BORDER_LEFT = 0
    FT_STROKER_BORDER_RIGHT
end
const FT_StrokerBorder = FT_StrokerBorder_

mutable struct FT_StrokerRec_ end
const FT_StrokerRec = FT_StrokerRec_
const FT_Stroker = Ptr{FT_StrokerRec_}

function FT_Stroker_New(library, astroker)
    ccall(
        (:FT_Stroker_New, libfreetype), 
        FT_Error, 
        (FT_Library, Ptr{FT_Stroker}), 
        library, astroker
    )
end

function FT_Stroker_Set(stroker, radius, line_cap, line_join, miter_limit)
    ccall(
        (:FT_Stroker_Set, libfreetype), 
        Cvoid, 
        (FT_Stroker, FT_Fixed, FT_Stroker_LineCap, FT_Stroker_LineJoin, FT_Fixed),
        stroker, radius, line_cap, line_join, miter_limit
    )
end

function FT_Stroker_Done(stroker)
    ccall(
        (:FT_Stroker_Done, libfreetype),
        Cvoid,
        (FT_Stroker,),
        stroker
    )
end

function FT_Stroker_ParseOutline(stroker, outline_ref, opened=false)
    ccall(
        (:FT_Stroker_ParseOutline, libfreetype),
        FT_Error,
        (FT_Stroker, Ptr{FT_Outline}, FT_Bool),
        stroker, outline_ref, opened
    )
end

function FT_Stroker_GetCounts(stroker, anum_points, anum_contours)
    ccall(
        (:FT_Stroker_GetCounts, libfreetype),
        FT_Error,
        (FT_Stroker, Ref{FT_UInt}, Ref{FT_UInt}),
        stroker, anum_points, anum_contours
    )
end

function FT_Stroker_Export(stroker, outline_ref)
    ccall(
        (:FT_Stroker_Export, libfreetype),
        Cvoid,
        (FT_Stroker, Ptr{FT_Outline}),
        stroker, outline_ref
    )
end

function new_stroker(
    ftlib = FREE_FONT_LIBRARY
)
    astroker = Ref{FT_Stroker}(Base.C_NULL)
    err = @lock LIBRARY_LOCK FT_Stroker_New(ftlib[1], astroker)
    if err != 0
        error("`FT_Stroker_New` errored with code $(err).")
    end
    stroker = astroker[] 
    return stroker
end

function stroke_bezier_path(bpath, P::Type{<:PositionFormat}; kwargs...)
    outlinedata = bezier_path_to_outlinedata(bpath, P;)
    return outlinedata_to_stroked_bezier_path(outlinedata, P; kwargs...)
end

function outlinedata_to_stroked_bezier_path(
    outlinedata, P::Type{<:PositionFormat};
    linecap = :butt, joinstyle = :miter, miter_limit = π/3,
    radius = 1, opened = false
)
    stroker = new_stroker()

    bpath = GC.@preserve outlinedata begin
        @lock LIBRARY_LOCK FT_Stroker_Set(
            stroker, 
            reinterpret(F16_16(radius)), 
            to_ft_linecap(linecap), 
            to_ft_joinstyle(joinstyle),
            to_ft_miter_limit(miter_limit)
        )
        err = @lock LIBRARY_LOCK FT_Stroker_ParseOutline(stroker, outlinedata[1], opened)
        err != 0 && error("`FT_Stroker_ParseOutline` errored with code `$(err)`.")

        num_points_ref = Ref{FT_UInt}(0)
        num_contours_ref = Ref{FT_UInt}(0)
        @lock LIBRARY_LOCK FT_Stroker_GetCounts(stroker, num_points_ref, num_contours_ref)
        
        n_points = num_points_ref[]
        n_contours = num_contours_ref[]
 
        points = Vector{FT_Vector}(undef, n_points)
        tags = Vector{Int8}(undef, n_points)
        contours = Vector{Int16}(undef, n_contours)
        
        strokeline = FT_Outline(
            0, #n_contours,             # FT_Stroker_Export **appends**, so we fully allocate our arrays but lie about the number of points and contours
            0, #n_points,
            pointer(points),
            pointer(tags),
            pointer(contours),
            0
        )
        GC.@preserve points tags contours strokeline begin
            strokeline_ref = Ref(strokeline)
            @lock LIBRARY_LOCK FT_Stroker_Export(stroker, strokeline_ref)
            outline_to_bezier_path(strokeline_ref, P)
        end
    end
    @lock LIBRARY_LOCK FT_Stroker_Done(stroker)
    #stroker = nothing
    return bpath
end

to_ft_linecap(lc::FT_Stroker_LineCap) = lc
to_ft_linecap(lc::Symbol) = if lc === :round
    FT_STROKER_LINECAP_ROUND
elseif lc === :square
    FT_STROKER_LINECAP_SQUARE
else
    FT_STROKER_LINECAP_BUTT
end

to_ft_joinstyle(js::FT_Stroker_LineJoin) = js
to_ft_joinstyle(js::Symbol) = if js === :round
    FT_STROKER_LINEJOIN_ROUND
elseif js === :bevel
    FT_STROKER_LINEJOIN_BEVEL
else
    FT_STROKER_LINEJOIN_MITER_FIXED
end

to_ft_miter_limit(ang) = reinterpret(F16_16(_safeguard_fixed_16_16(2 * Makie.miter_angle_to_distance(ang))))
_safeguard_fixed_16_16(num) = min(typemax(Int16), max(typemin(Int16), num))


function bezier_path_to_outlinedata(
    bpath, P::Type{<:PositionFormat}
)
    return make_outline(
        Makie.replace_nonfreetype_commands(bpath), P
    )
end

function outline_to_bezier_path(
    outline, P::Type{<:PositionFormat}
)
    global outline_funcs
    user = Dict(:commands => BEZIER_CMD[], :lastp => zeros(2), :pos_format => P)
    bpath = GC.@preserve user begin 
        @lock LIBRARY_LOCK FT.FT_Outline_Decompose(outline, outline_funcs, Base.pointer_from_objref(user))
        #BezierPath(deepcopy(user[:commands]))
        BezierPath(user[:commands])
    end
    return bpath
end

function move_to(to::Ptr{FT.FT_Vector}, user::Ptr{Cvoid})::Cint
    _p = Base.unsafe_load(to)
    trgt = Base.unsafe_pointer_to_objref(user)
    p = floatify_position(_p, trgt[:pos_format])
    push!(trgt[:commands], MoveTo(p))
    update_last_point!(trgt, p)
    return zero(Cint)
end

function line_to(to::Ptr{FT.FT_Vector}, user::Ptr{Cvoid})::Cint
    _p = Base.unsafe_load(to)
    trgt = Base.unsafe_pointer_to_objref(user)
    p = floatify_position(_p, trgt[:pos_format])
    push!(trgt[:commands], LineTo(p))
    update_last_point!(trgt, p)
    return zero(Cint)
end

function conic_to(control::Ptr{FT.FT_Vector}, to::Ptr{FT.FT_Vector}, user::Ptr{Cvoid})::Cint
    _c = Base.unsafe_load(control)
    _p = Base.unsafe_load(to)
    trgt = Base.unsafe_pointer_to_objref(user)
    c = floatify_position(_c, trgt[:pos_format])
    p = floatify_position(_p, trgt[:pos_format])
    l = if isempty(trgt[:commands])
        zeros(2)        # TODO do need this conditional ?
    else
        trgt[:lastp]
    end
    push!(trgt[:commands], Makie.quadratic_curve_to(l[1], l[2], c[1], c[2], p[1], p[2]))
    update_last_point!(trgt, p)
    return zero(Cint)
end

function cubic_to(control::Ptr{FT.FT_Vector}, control2::Ptr{FT.FT_Vector}, to::Ptr{FT.FT_Vector}, user::Ptr{Cvoid})::Cint
    _c = Base.unsafe_load(control)
    _c2 = Base.unsafe_load(control2)
    _p = Base.unsafe_load(to)
    trgt = Base.unsafe_pointer_to_objref(user)
    p = floatify_position(_p, trgt[:pos_format])
    c = floatify_position(_c, trgt[:pos_format])
    c2 = floatify_position(_c2, trgt[:pos_format])
    push!(trgt[:commands], Makie.CurveTo(c, c2, p))
    update_last_point!(trgt, p)
    return zero(Cint)
end

function update_last_point!(trgt, p)
    lastp = trgt[:lastp]
    lastp[1] = p[1]
    lastp[2] = p[2]
    return trgt
end

function floatify_position(p::FT_Vector, P::Type{<:PositionFormat})
    return Point2(
        floatify_position(p.x, P),
        floatify_position(p.y, P)
    )
end
floatify_position(num::FT_Fixed, ::Type{<:FT_Fixed}) = float(num) |> copy
floatify_position(num::FT_Fixed, ::Type{<:F16_16}) = float(reinterpret(F16_16, num))
floatify_position(num::FT_Fixed, ::Type{<:F26_6}) = float(reinterpret(F26_6, num))
