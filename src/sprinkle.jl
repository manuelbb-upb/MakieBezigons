@recipe Sprinkle (positions,) begin
    "Sets the color of the outline around a marker."
    strokecolor = automatic
    markersize = 1f0
    strokewidth = @inherit linewidth

    (Makie.filtered_attributes(Scatter; exclude = (:strokecolor, :markersize, :strokewidth)))...
end

Makie.conversion_trait(::Type{<:Sprinkle}) = Makie.PointBased()

function Makie.plot!(plt::Sprinkle)
    map!(
        plt, 
        [:marker, :strokewidth, :markersize, :color, :strokecolor],
        [:inner_marker, :outer_marker, :outer_visible, :fillcolor, :outlinecolor, :strokewidth0] 
    ) do marker, strokewidth, size, color, strokecolor
        fillcolor = color
        outlinecolor = strokecolor
        strokewidth0 = strokewidth
        outer_marker = marker
        outer_visible = false
        if marker isa AbstractBezigonSpec
            _bez = bezigon(marker; size, strokewidth)
            bez = transformed_bezigon(_bez; target! = (0, 0), rotation = 0)
            marker = bezigon_path(bez)
            
            strokewidth0 = 0f0
            if !is_bezigon_filled(bez)
                fillcolor = :transparent
            else
                fcolor_override = bezigon_fillcolor(bez)
                if !isa(fcolor_override, Automatic)
                    fillcolor = fcolor_override
                end
            end
            if is_bezigon_stroked(bez)
                outer_marker = bezigon_outline_path(bez)
                outer_visible = true
                if isa(strokecolor, Automatic)
                    outlinecolor = color
                end
                scolor_override = bezigon_strokecolor(bez)
                if !isa(scolor_override, Automatic)
                    outlinecolor = scolor_override
                end
            else
                outer_marker = marker
                outlinecolor = :transparent 
            end
        else
            if isa(strokecolor, Automatic)
                outlinecolor = get(Makie.theme(plt), :markerstrokecolor, color)
            end
        end
        return (marker, outer_marker, outer_visible, fillcolor, outlinecolor, strokewidth0)
    end

    scatter!(
        plt, plt.attributes, plt.positions; 
        marker = plt.inner_marker, 
        color = plt.fillcolor, 
        strokewidth = plt.strokewidth0,
        strokecolor = plt.outlinecolor,
        markersize = 1f0,
        glowwidth = 0,
        glowcolor = :transparent
    )
    
    scatter!(
        plt, plt.attributes, plt.positions; 
        visible = plt.outer_visible,
        marker = plt.outer_marker, 
        color = plt.outlinecolor,
        strokewidth = 0f0,
        strokecolor = :transparent, 
        markersize = 1f0
    )
end