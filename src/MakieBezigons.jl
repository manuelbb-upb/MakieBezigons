module MakieBezigons

import FreeType as FT
import FreeType: FT_Fixed, FT_Vector, FT_Bool, FT_Library, FT_Byte, FT_UInt, FT_Memory, 
    FT_Int, FT_Error, FT_Outline, FT_Curve_Tag_Cubic, FT_Curve_Tag_On
import FreeType: libfreetype
import FixedPointNumbers as FPN

import Makie
import Makie: Point2, Point2f, Point2d
import Makie: BezierPath, MoveTo, LineTo, CurveTo, ClosePath, EllipticalArc, scale, translate, rotate
import Makie: @recipe, automatic, Automatic
import Makie: scatter!, plot!, Scatter
import Makie: ComputeGraph, add_input!, add_constant!
import Makie.ComputePipeline: alias!

import LinearAlgebra: qr

import UnPack: @unpack

const F16_16 = FPN.Fixed{FT_Fixed, 16}
const F26_6 = FPN.Fixed{FT_Fixed, 26}

const Tup2 = Tuple{<:Real, <:Real}
const Tup3 = Tuple{<:Real, <:Real, <:Real}

const NumOrTup2 = Union{Real, Tup2}

include("bezigons/interfaces.jl")
include("bezigons/utils.jl")
include("bezigons/typed_bezigons.jl")

include("bezigons/simple/simple.jl")
include("bezigons/simple/rect.jl")
include("bezigons/simple/bullet.jl")

include("bezigons/arrows_meta/arrows_meta.jl")
include("bezigons/arrows_meta/latex.jl")
include("bezigons/arrows_meta/computermodernright.jl")

include("ft_utils.jl")
include("annotation.jl")
include("sprinkle.jl")
export sprinkle, sprinkle!

function __init__()
    ft_init()
    atexit(ft_done)
    cmove_to[] = @cfunction(move_to, Cint, (Ptr{FT.FT_Vector}, Ptr{Cvoid}))
    cline_to[] = @cfunction(line_to, Cint, (Ptr{FT.FT_Vector}, Ptr{Cvoid}))
    cconic_to[] = @cfunction(conic_to, Cint, (Ptr{FT.FT_Vector}, Ptr{FT.FT_Vector}, Ptr{Cvoid}))
    ccubic_to[] = @cfunction(cubic_to, Cint, (Ptr{FT.FT_Vector}, Ptr{FT.FT_Vector}, Ptr{FT.FT_Vector}, Ptr{Cvoid}))

    outline_funcs[] = FT.FT_Outline_Funcs(
        cmove_to[],
        cline_to[],
        cconic_to[],
        ccubic_to[],
        zero(Cint),
        zero(FT.FT_Pos)
    )
end

end # module MakieBezigons
