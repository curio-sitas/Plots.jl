

typealias P2 FixedSizeArrays.Vec{2,Float64}
typealias P3 FixedSizeArrays.Vec{3,Float64}

nanpush!(a::AbstractVector{P2}, b) = (push!(a, P2(NaN,NaN)); push!(a, b))
nanappend!(a::AbstractVector{P2}, b) = (push!(a, P2(NaN,NaN)); append!(a, b))
nanpush!(a::AbstractVector{P3}, b) = (push!(a, P3(NaN,NaN,NaN)); push!(a, b))
nanappend!(a::AbstractVector{P3}, b) = (push!(a, P3(NaN,NaN,NaN)); append!(a, b))
compute_angle(v::P2) = (angle = atan2(v[2], v[1]); angle < 0 ? 2π - angle : angle)

# -------------------------------------------------------------

immutable Shape
  # vertices::AVec
  x::AVec
  y::AVec
end

# Shape(x, y) = Shape(collect(zip(x, y)))
Shape(verts::AVec) = Shape(unzip(verts)...)

# get_xs(shape::Shape) = Float64[v[1] for v in shape.vertices]
# get_ys(shape::Shape) = Float64[v[2] for v in shape.vertices]
get_xs(shape::Shape) = shape.x
get_ys(shape::Shape) = shape.y
vertices(shape::Shape) = collect(zip(shape.x, shape.y))


function shape_coords(shape::Shape)
    # unzip(shape.vertices)
    shape.x, shape.y
end

function shape_coords(shapes::AVec{Shape})
    length(shapes) == 0 && return zeros(0), zeros(0)
    xs = map(get_xs, shapes)
    ys = map(get_ys, shapes)
    # x, y = shapes[1].x, shapes[1].y #unzip(shapes[1].vertices)
    x, y = map(copy, shape_coords(shapes[1]))
    for shape in shapes[2:end]
        # tmpx, tmpy = unzip(shape.vertices)
        nanappend!(x, shape.x)
        nanappend!(y, shape.y)
        # x = vcat(x, NaN, tmpx)
        # y = vcat(y, NaN, tmpy)
    end
    x, y
end

"get an array of tuples of points on a circle with radius `r`"
function partialcircle(start_θ, end_θ, n = 20, r=1)
  @compat(Tuple{Float64,Float64})[(r*cos(u),r*sin(u)) for u in linspace(start_θ, end_θ, n)]
end

"interleave 2 vectors into each other (like a zipper's teeth)"
function weave(x,y; ordering = Vector[x,y])
  ret = eltype(x)[]
  done = false
  while !done
    for o in ordering
      try
          push!(ret, shift!(o))
      end
      # try
      #     push!(ret, shift!(y))
      # end
    end
    done = isempty(x) && isempty(y)
  end
  ret
end


"create a star by weaving together points from an outer and inner circle.  `n` is the number of arms"
function makestar(n; offset = -0.5, radius = 1.0)
    z1 = offset * π
    z2 = z1 + π / (n)
    outercircle = partialcircle(z1, z1 + 2π, n+1, radius)
    innercircle = partialcircle(z2, z2 + 2π, n+1, 0.4radius)
    Shape(weave(outercircle, innercircle)[1:end-2])
end

"create a shape by picking points around the unit circle.  `n` is the number of point/sides, `offset` is the starting angle"
function makeshape(n; offset = -0.5, radius = 1.0)
    z = offset * π
    Shape(partialcircle(z, z + 2π, n+1, radius)[1:end-1])
end


function makecross(; offset = -0.5, radius = 1.0)
    z2 = offset * π
    z1 = z2 - π/8
    outercircle = partialcircle(z1, z1 + 2π, 9, radius)
    innercircle = partialcircle(z2, z2 + 2π, 5, 0.5radius)
    Shape(weave(outercircle, innercircle,
                ordering=Vector[outercircle,innercircle,outercircle])[1:end-2])
end


from_polar(angle, dist) = P2(dist*cos(angle), dist*sin(angle))

function makearrowhead(angle; h = 2.0, w = 0.4)
    tip = from_polar(angle, h)
    Shape(P2[(0,0), from_polar(angle - 0.5π, w) - tip,
        from_polar(angle + 0.5π, w) - tip, (0,0)])
end

const _shapes = KW(
    :ellipse    => makeshape(20),
    :rect       => makeshape(4, offset=-0.25),
    :diamond    => makeshape(4),
    :utriangle  => makeshape(3),
    :dtriangle  => makeshape(3, offset=0.5),
    :pentagon   => makeshape(5),
    :hexagon    => makeshape(6),
    :heptagon   => makeshape(7),
    :octagon    => makeshape(8),
    :cross      => makecross(offset=-0.25),
    :xcross     => makecross(),
    :vline      => Shape([(0,1),(0,-1)]),
    :hline      => Shape([(1,0),(-1,0)]),
  )

for n in [4,5,6,7,8]
  _shapes[symbol("star$n")] = makestar(n)
end

# -----------------------------------------------------------------------

# center(shape::Shape) = (mean(shape.x), mean(shape.y))

# uses the centroid calculation from https://en.wikipedia.org/wiki/Centroid#Centroid_of_polygon
function center(shape::Shape)
    x, y = shape_coords(shape)
    n = length(x)
    A, Cx, Cy = 0.0, 0.0, 0.0
    for i=1:n
        ip1 = i==n ? 1 : i+1
        A += x[i] * y[ip1] - x[ip1] * y[i]
    end
    A *= 0.5
    for i=1:n
        ip1 = i==n ? 1 : i+1
        m = (x[i] * y[ip1] - x[ip1] * y[i])
        Cx += (x[i] + x[ip1]) * m
        Cy += (y[i] + y[ip1]) * m
    end
    Cx / 6A, Cy / 6A
end

function Base.scale!(shape::Shape, x::Real, y::Real = x, c = center(shape))
    sx, sy = shape_coords(shape)
    cx, cy = c
    for i=1:length(sx)
        sx[i] = (sx[i] - cx) * x + cx
        sy[i] = (sy[i] - cy) * y + cy
    end
    shape
end

function Base.scale(shape::Shape, x::Real, y::Real = x, c = center(shape))
    shapecopy = deepcopy(shape)
    scale!(shape, x, y, c)
end

function translate!(shape::Shape, x::Real, y::Real = x)
    sx, sy = shape_coords(shape)
    for i=1:length(sx)
        sx[i] += x
        sy[i] += y
    end
    shape
end

function translate(shape::Shape, x::Real, y::Real = x)
    shapecopy = deepcopy(shape)
    translate!(shape, x, y)
end

function rotate_x(x::Real, y::Real, Θ::Real, centerx::Real, centery::Real)
    (x - centerx) * cos(Θ) - (y - centery) * sin(Θ) + centerx
end

function rotate_y(x::Real, y::Real, Θ::Real, centerx::Real, centery::Real)
    (y - centery) * cos(Θ) + (x - centerx) * sin(Θ) + centery
end

function rotate(x::Real, y::Real, θ::Real, c = center(shape))
    cx, cy = c
    rotate_x(x, y, Θ, cx, cy), rotate_y(x, y, Θ, cx, cy)
end

function rotate!(shape::Shape, Θ::Real, c = center(shape))
    x, y = shape_coords(shape)
    cx, cy = c
    for i=1:length(x)
        x[i] = rotate_x(x[i], y[i], Θ, cx, cy)
        y[i] = rotate_y(x[i], y[i], Θ, cx, cy)
    end
    shape
end

function rotate(shape::Shape, Θ::Real, c = center(shape))
    shapecopy = deepcopy(shape)
    rotate!(shapecopy, Θ, c)
end

# -----------------------------------------------------------------------

# abstract AbstractAxisTicks
# immutable DefaultAxisTicks end
#
# type CustomAxisTicks
#     # TODO
# end

# simple wrapper around a KW so we can hold all attributes pertaining to the axis in one place
type Axis
    d::KW
    # name::AbstractString      # "x" or "y"
    # label::AbstractString
    # lims::NTuple{2}
    # ticks::AbstractAxisTicks
    # scale::Symbol
    # flip::Bool
    # rotation::Number
    # guidefont::Font
    # tickfont::Font
    # use_minor::Bool
    # _plotDefaults[:foreground_color_axis]       = :match            # axis border/tick colors
    # _plotDefaults[:foreground_color_border]     = :match            # plot area border/spines
    # _plotDefaults[:foreground_color_text]       = :match            # tick text color
    # _plotDefaults[:foreground_color_guide]      = :match            # guide text color
end


# function processAxisArg(d::KW, letter::AbstractString, arg)
function axis(letter, args...; kw...)
    # TODO: this should initialize with values from _plotDefaults
    d = KW(
        :letter => letter,
        :label => "",
        :lims => :auto,
        :ticks => :auto,
        :scale => :identity,
        :flip => false,
        :rotation => 0,
        :guidefont => font(11),
        :tickfont => font(8),
        :use_minor => false,
        :foreground_color_axis   => :match,
        :foreground_color_border => :match,
        :foreground_color_text   => :match,
        :foreground_color_guide  => :match,
    )

    # first process args
    for arg in args
        T = typeof(arg)
        arg = get(_scaleAliases, arg, arg)
        # scale, flip, label, lim, tick = axis_symbols(letter, "scale", "flip", "label", "lims", "ticks")

        if typeof(arg) <: Font
            d[:tickfont] = arg
            d[:guidefont] = arg

        elseif arg in _allScales
            d[:scale] = arg

        elseif arg in (:flip, :invert, :inverted)
            d[:flip] = true

        elseif T <: @compat(AbstractString)
            d[:label] = arg

        # xlims/ylims
        elseif (T <: Tuple || T <: AVec) && length(arg) == 2
            sym = typeof(arg[1]) <: Number ? :lims : :ticks
            d[sym] = arg

        # xticks/yticks
        elseif T <: AVec
            d[:ticks] = arg

        elseif arg == nothing
            d[:ticks] = []

        elseif typeof(arg) <: Number
            d[:rotation] = arg

        else
            warn("Skipped $(letter)axis arg $arg")

        end
    end

    # then override for any keywords
    for (k,v) in kw
        d[k] = v
    end

    Axis(d)
end


xaxis(args...) = axis("x", args...)
yaxis(args...) = axis("y", args...)
zaxis(args...) = axis("z", args...)

# -----------------------------------------------------------------------


immutable Font
  family::AbstractString
  pointsize::Int
  halign::Symbol
  valign::Symbol
  rotation::Float64
  color::Colorant
end

"Create a Font from a list of unordered features"
function font(args...)

  # defaults
  family = "Helvetica"
  pointsize = 14
  halign = :hcenter
  valign = :vcenter
  rotation = 0.0
  color = colorant"black"

  for arg in args
    T = typeof(arg)

    if arg == :center
      halign = :hcenter
      valign = :vcenter
    elseif arg in (:hcenter, :left, :right)
      halign = arg
    elseif arg in (:vcenter, :top, :bottom)
      valign = arg
    elseif T <: Colorant
      color = arg
    elseif T <: @compat Union{Symbol,AbstractString}
      try
        color = parse(Colorant, string(arg))
      catch
        family = string(arg)
      end
    elseif typeof(arg) <: Integer
      pointsize = arg
    elseif typeof(arg) <: Real
      rotation = convert(Float64, arg)
    else
      warn("Unused font arg: $arg ($(typeof(arg)))")
    end
  end

  Font(family, pointsize, halign, valign, rotation, color)
end

"Wrap a string with font info"
immutable PlotText
  str::@compat(AbstractString)
  font::Font
end
PlotText(str) = PlotText(string(str), font())

function text(str, args...)
  PlotText(string(str), font(args...))
end
# -----------------------------------------------------------------------

# simple wrapper around a KW so we can hold all attributes pertaining to the axis in one place
type Axis
    d::KW
end

function expand_extrema!(a::Axis, v::Number)
    emin, emax = a[:extrema]
    a[:extrema] = (min(v, emin), max(v, emax))
end
function expand_extrema!{MIN<:Number,MAX<:Number}(a::Axis, v::Tuple{MIN,MAX})
    emin, emax = a[:extrema]
    a[:extrema] = (min(v[1], emin), max(v[2], emax))
end
function expand_extrema!{N<:Number}(a::Axis, v::AVec{N})
    if !isempty(v)
        emin, emax = a[:extrema]
        a[:extrema] = (min(minimum(v), emin), max(maximum(v), emax))
    end
    a[:extrema]
end

# these methods track the discrete values which correspond to axis continuous values (cv)
# whenever we have discrete values, we automatically set the ticks to match.
# we return the plot value
function discrete_value!(a::Axis, v)
    cv = get(a[:discrete_map], v, NaN)
    if isnan(cv)
        emin, emax = a[:extrema]
        cv = max(0.5, emax + 1.0)
        expand_extrema!(a, cv)
        a[:discrete_map][v] = cv
        push!(a[:discrete_values], (cv, v))
    end
    cv
end

# add the discrete value for each item
function discrete_value!(a::Axis, v::AVec)
    Float64[discrete_value!(a, vi) for vi=v]
end

Base.getindex(a::Axis, k::Symbol) = getindex(a.d, k)
Base.setindex!(a::Axis, v, ks::Symbol...) = setindex!(a.d, v, ks...)
Base.extrema(a::Axis) = a[:extrema]

# get discrete ticks, or not
function get_ticks(a::Axis)
    ticks = a[:ticks]
    dvals = a[:discrete_values]
    if !isempty(dvals) && ticks == :auto
        vals, labels = unzip(dvals)
    else
        ticks
    end
end

const _axis_symbols = (:label, :lims, :ticks, :scale, :flip, :rotation)
const _axis_symbols_fonts_colors = (
    :guidefont, :tickfont,
    :foreground_color_axis,
    :foreground_color_border,
    :foreground_color_text,
    :foreground_color_guide
    )

# function processAxisArg(d::KW, letter::AbstractString, arg)
function Axis(letter::AbstractString, args...; kw...)
    # init with defaults
    d = KW(
        :letter => letter,
        # :label => "",
        # :lims => :auto,
        # :ticks => :auto,
        # :scale => :identity,
        # :flip => false,
        # :rotation => 0,
        # :guidefont => font(11),
        # :tickfont => font(8),
        # :foreground_color_axis   => :match,
        # :foreground_color_border => :match,
        # :foreground_color_text   => :match,
        # :foreground_color_guide  => :match,
        :extrema => (Inf, -Inf),
        :discrete_map => Dict(),   # map discrete values to continuous plot values
        :discrete_values => [],
        :use_minor => false,
        :show => true,  # show or hide the axis? (useful for linked subplots)
    )
    for sym in _axis_symbols
        k = symbol(letter * string(sym))
        d[k] = _plotDefaults[k]
    end
    for k in _axis_symbols_fonts_colors
        d[k] = _plotDefaults[k]
    end

    # first process args
    for arg in args
        T = typeof(arg)
        arg = get(_scaleAliases, arg, arg)
        # scale, flip, label, lim, tick = axis_symbols(letter, "scale", "flip", "label", "lims", "ticks")

        if typeof(arg) <: Font
            d[:tickfont] = arg
            d[:guidefont] = arg

        elseif arg in _allScales
            d[:scale] = arg

        elseif arg in (:flip, :invert, :inverted)
            d[:flip] = true

        elseif T <: @compat(AbstractString)
            d[:label] = arg

        # xlims/ylims
        elseif (T <: Tuple || T <: AVec) && length(arg) == 2
            sym = typeof(arg[1]) <: Number ? :lims : :ticks
            d[sym] = arg

        # xticks/yticks
        elseif T <: AVec
            d[:ticks] = arg

        elseif arg == nothing
            d[:ticks] = []

        elseif typeof(arg) <: Number
            d[:rotation] = arg

        else
            warn("Skipped $(letter)axis arg $arg")

        end
    end

    # then override for any keywords... only those keywords that already exists in d
    for (k,v) in kw
        sym = symbol(string(k)[2:end])
        if haskey(d, sym)
            d[sym] = v
        end
    end

    Axis(d)
end


xaxis(args...) = Axis("x", args...)
yaxis(args...) = Axis("y", args...)
zaxis(args...) = Axis("z", args...)

# -----------------------------------------------------------------------

immutable Stroke
  width
  color
  alpha
  style
end

function stroke(args...; alpha = nothing)
  # defaults
  # width = 1
  # color = colorant"black"
  # style = :solid
  width = nothing
  color = nothing
  style = nothing

  for arg in args
    T = typeof(arg)

    # if arg in _allStyles
    if allStyles(arg)
      style = arg
    elseif T <: Colorant
      color = arg
    elseif T <: @compat Union{Symbol,AbstractString}
      try
        color = parse(Colorant, string(arg))
      end
    # elseif trueOrAllTrue(a -> typeof(a) <: Real && a > 0 && a < 1, arg)
    elseif allAlphas(arg)
      alpha = arg
    # elseif typeof(arg) <: Real
    elseif allReals(arg)
      width = arg
    else
      warn("Unused stroke arg: $arg ($(typeof(arg)))")
    end
  end

  Stroke(width, color, alpha, style)
end


immutable Brush
  size  # fillrange, markersize, or any other sizey attribute
  color
  alpha
end

function brush(args...; alpha = nothing)
  # defaults
  # sz = 1
  # color = colorant"black"
  size = nothing
  color = nothing

  for arg in args
    T = typeof(arg)

    if T <: Colorant
      color = arg
    elseif T <: @compat Union{Symbol,AbstractString}
      try
        color = parse(Colorant, string(arg))
      end
    # elseif trueOrAllTrue(a -> typeof(a) <: Real && a > 0 && a < 1, arg)
    elseif allAlphas(arg)
      alpha = arg
    # elseif typeof(arg) <: Real
    elseif allReals(arg)
      size = arg
    else
      warn("Unused brush arg: $arg ($(typeof(arg)))")
    end
  end

  Brush(size, color, alpha)
end

# -----------------------------------------------------------------------

"type which represents z-values for colors and sizes (and anything else that might come up)"
immutable ZValues
  values::Vector{Float64}
  zrange::Tuple{Float64,Float64}
end

function zvalues{T<:Real}(values::AVec{T}, zrange::Tuple{T,T} = (minimum(values), maximum(values)))
  ZValues(collect(float(values)), map(Float64, zrange))
end

# -----------------------------------------------------------------------

abstract AbstractSurface

"represents a contour or surface mesh"
immutable Surface{M<:AMat} <: AbstractSurface
  # x::AVec
  # y::AVec
  surf::M
end

Surface(f::Function, x, y) = Surface(Float64[f(xi,yi) for xi in x, yi in y])

Base.Array(surf::Surface) = surf.surf

for f in (:length, :size)
  @eval Base.$f(surf::Surface, args...) = $f(surf.surf, args...)
end
Base.copy(surf::Surface) = Surface(copy(surf.surf))


"For the case of representing a surface as a function of x/y... can possibly avoid allocations."
immutable SurfaceFunction <: AbstractSurface
    f::Function
end

# -----------------------------------------------------------------------

type OHLC{T<:Real}
  open::T
  high::T
  low::T
  close::T
end

# -----------------------------------------------------------------------

# style is :open or :closed (for now)
immutable Arrow
    style::Symbol
    headlength::Float64
    headwidth::Float64
end

function arrow(args...)
    style = :simple
    headlength = 0.3
    headwidth = 0.3
    setlength = false
    for arg in args
        T = typeof(arg)
        if T == Symbol
            style = arg
        elseif T <: Number
            # first we apply to both, but if there's more, then only change width after the first number
            headwidth = Float64(arg)
            if !setlength
                headlength = headwidth
            end
            setlength = true
        elseif T <: Tuple && length(arg) == 2
            headlength, headwidth = Float64(arg[1]), Float64(arg[2])
        else
            warn("Skipped arrow arg $arg")
        end
    end
    Arrow(style, headlength, headwidth)
end


# allow for do-block notation which gets called on every valid start/end pair which
# we need to draw an arrow
function add_arrows(func::Function, x::AVec, y::AVec)
    for i=2:length(x)
        xyprev = (x[i-1], y[i-1])
        xy = (x[i], y[i])
        if ok(xyprev) && ok(xy)
            if i==length(x) || !ok(x[i+1], y[i+1])
                # add the arrow from xyprev to xy
                func(xyprev, xy)
            end
        end
    end
end


# -----------------------------------------------------------------------

# @require FixedSizeArrays begin

  type BezierCurve{T <: FixedSizeArrays.Vec}
      control_points::Vector{T}
  end

  function Base.call(bc::BezierCurve, t::Real)
      p = zero(P2)
      n = length(bc.control_points)-1
      for i in 0:n
          p += bc.control_points[i+1] * binomial(n, i) * (1-t)^(n-i) * t^i
      end
      p
  end

  Base.mean(x::Real, y::Real) = 0.5*(x+y)
  Base.mean{N,T<:Real}(ps::FixedSizeArrays.Vec{N,T}...) = sum(ps) / length(ps)

  curve_points(curve::BezierCurve, n::Integer = 30; range = [0,1]) = map(curve, linspace(range..., n))

  # build a BezierCurve which leaves point p vertically upwards and arrives point q vertically upwards.
  # may create a loop if necessary.  Assumes the view is [0,1]
  function directed_curve(p::P2, q::P2; xview = 0:1, yview = 0:1)
    mn = mean(p, q)
    diff = q - p

    minx, maxx = minimum(xview), maximum(xview)
    miny, maxy = minimum(yview), maximum(yview)
    diffpct = P2(diff[1] / (maxx - minx),
                 diff[2] / (maxy - miny))

    # these points give the initial/final "rise"
    # vertical_offset = P2(0, (maxy - miny) * max(0.03, min(abs(0.5diffpct[2]), 1.0)))
    vertical_offset = P2(0, max(0.15, 0.5norm(diff)))
    upper_control = p + vertical_offset
    lower_control = q - vertical_offset

    # try to figure out when to loop around vs just connecting straight
    # TODO: choose loop direction based on sign of p[1]??
    # x_close_together = abs(diffpct[1]) <= 0.05
    p_is_higher = diff[2] <= 0
    inside_control_points = if p_is_higher
      # add curve points which will create a loop
      sgn = mn[1] < 0.5 * (maxx + minx) ? -1 : 1
      inside_offset = P2(0.3 * (maxx - minx), 0)
      additional_offset = P2(sgn * diff[1], 0)  # make it even loopier
      [upper_control + sgn * (inside_offset + max(0,  additional_offset)),
       lower_control + sgn * (inside_offset + max(0, -additional_offset))]
    else
      []
    end

    BezierCurve([p, upper_control, inside_control_points..., lower_control, q])
  end

# end
