struct LatexArrow{is_tip, data_Type} <: AbstractArrowSpec
    data :: data_Type
end
const LatexTip = LatexArrow{true}
const LatexTail = LatexArrow{false}
function LatexArrow{T}(data) where T
    return LatexArrow{T, typeof(data)}(data)
end

function _fallback_attrs(
    ::Type{<:LatexArrow{is_tip}};
    linecap = :butt,
    joinstyle = :miter, 
    kwargs...
) where {is_tip}
    length = (3f0, 4.8f0)
    width_ = (0f0, 0.75f0)
    line_width = (0, 1)
    return (; length, width_, line_width, linecap, joinstyle, reversed = !is_tip, closed = true)
end

const LATEX_ARROW_BEZIER_CONSTANTS = (;
    cx1 = .877192f0, cy1 = .077922f0,
    cx2 = .337381f0, cy2 = .519480f0,
)

function __bezigon_arrow_data(
    spec::LatexArrow;
    bez_x, bez_y, sw, sw_par,
    align, reversed, swapped, linecap, joinstyle, miter_limit
)
    global LATEX_ARROW_BEZIER_CONSTANTS
    arr_length = bez_x
    arr_width = bez_y
 
    ## cap actual strokewidth to be at most fifth of arrow length    
    sw = min(sw, arr_length/5)
        
    cx1, cy1, cx2, cy2 = LATEX_ARROW_BEZIER_CONSTANTS
   
    arr_halfwidth = arr_width / 2
    if sw > 0   ## if there is no stroke, we don't need these computations
        ## compute miter length
        ## formula: `miter_len = sw / sin(ψ)`
        ##          `ψ` is the angle between bottom leg and hypotenuse of right-angled triangle
        ##          assume bottom leg has length `λ` and other leg has length `ω`
        ##          Then `1 / sin(ψ) = sqrt( λ^2 / ω^2 + 1)`.
        ##          Looking at the drawing code the tangents at the tip form a suitable triangle
        ##          with `λ = (1 - cx1) * arr_length` (or rather `inner_length`) and `ω = cy1 * arr_width / 2`
        cot_psi_tip = ((1-cx1) * arr_length) / (cy1 * arr_halfwidth)
        csc_psi_tip = sqrt( 1 + cot_psi_tip^2 )
        sin_psi_tip = 1 / csc_psi_tip      # 1/sqrt(9 * L^2 / H^2 + 1) in LaTeX
        miter_half_len = (csc_psi_tip * sw) / 2

        ## for inner length, substract miter_half_len (front), and half strokewidth (back)
        back_end = -sw / 2
        inner_length = arr_length + back_end - miter_half_len
        if inner_length < eps32
            ## shrink strokewidth even further to compensate large miter
            ### arr_length - sw/2 * ( 1 + csc_psi_tip) >= eps32
            _sw = 2 * (arr_length - eps32) / (1 + csc_psi_tip)
            sw = max(0f0, min(sw, _sw))
            
            miter_half_len = (csc_psi_tip * sw) / 2
            back_end = -sw / 2
            inner_length = arr_length + back_end - miter_half_len
        end

        harpoon_extra_len = (sw * cot_psi_tip / 2) 

        ## (vertical) back miter
        ## φ = 2 * ψ, where ψ is the half angle of the miter join
        cot_phi_tail =  ((1 - cy2) * arr_halfwidth) / (arr_length * cx2)
        csc_phi_tail = sqrt(1 + cot_phi_tail^2 )
        cot_psi_tail = cot_phi_tail + csc_phi_tail 
        csc_psi_tail = sqrt(1 + cot_psi_tail^2 )
        bmiter_half_len = (csc_psi_tail * sw) / 2
        inner_halfwidth = arr_halfwidth - sqrt(bmiter_half_len^2 - (sw/2)^2)
        if inner_halfwidth < eps32
            ## shrink strokewidth even further to compensate large miter
            ### arr_halfwidth - sqrt(bmiter_half_len^2 - (sw/2)^2) >= eps32
            ### (arr_halfwidth - eps32)^2 >= bmiter_half_len^2 - (sw/2)^2
            ### (arr_halfwidth - eps32)^2 >= sw^2 * csc_phi_tail^2 / 4  - sw^2/4
            _sw = sqrt(4 * (arr_halfwidth - eps32)^2 / (csc_phi_tail^2 - 1))
            sw = max(0f0, min(sw, _sw))

            bmiter_half_len = (csc_psi_tail * sw) / 2
            inner_halfwidth = arr_halfwidth - sqrt(bmiter_half_len^2 - (sw/2)^2)
        end

        line_end = reversed ? inner_length - sw_par / 2 : 0f0 |> f32
        max_miter_halflen = Makie.miter_angle_to_distance(miter_limit) * sw
        tip_end = if joinstyle == :round
            inner_length + sw / 2
        elseif joinstyle == :miter && miter_half_len <= max_miter_halflen
            inner_length + miter_half_len
        else# join == :bevel
            inner_length + sin_psi_tip * sw
        end
        
        ## modify control points to match scaled geometry
        bezier_points = _latex_bezier_points(arr_length, arr_halfwidth, inner_length, inner_halfwidth)
    else
        line_end = reversed ? arr_length - sw_par / 2 : 0f0
        tip_end = arr_length
        back_end = 0f0
        bezier_points = _latex_default_bezier_points(arr_length, arr_halfwidth)
    end
    
    swap(p) = Point2d(p[1], -p[2])
    bpath = let (P0, P1, P2, P3) = bezier_points;
        _P3 = swap(P3)
        _P2 = swap(P2)
        _P1 = swap(P1)
        BezierPath([
            MoveTo(P0),             # tip
            CurveTo(P1,P2,P3),      # top left
            LineTo(_P3),            # bottom left
            CurveTo(_P2,_P1,P0),    # tip
            ClosePath()
        ])
    end
    
    return (; bpath, tip_end, line_end, back_end, sw)
end

function _latex_default_bezier_points(arrow_length, arrow_halfwidth)
    global LATEX_ARROW_BEZIER_CONSTANTS
    cx1, cy1, cx2, cy2 = LATEX_ARROW_BEZIER_CONSTANTS
    l = arrow_length
    h = arrow_halfwidth
    p0 = [l, 0f0]
    p1 = [cx1 * l, cy1 * h]
    p2 = [cx2 * l, cy2 * h]
    p3 = [0, h]
    return [Point2(p0), Point2(p1), Point2(p2), Point2(p3)]
 end

function _latex_bezier_points(
    arrow_length, arrow_halfwidth,
    inner_length, inner_halfwidth;
    kwargs...,
)
    p0, p1, p2, p3 = _latex_default_bezier_points(arrow_length, arrow_halfwidth)   
    
    L = inner_length
    H = inner_halfwidth
    P0 = [L; 0f0]
    P3 = [0f0; H]
    return _match_bezier_curveto_tangents(
        p0, p1, p2, p3, P0, P3; kwargs...
    )
end