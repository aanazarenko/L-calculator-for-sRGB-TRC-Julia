#######
# All calculations come from:
# - https://www.color.org/sRGB.pdf doc
# - https://www.wikiwand.com/en/CIELAB_color_space page
#######

using Printf
import Pkg; Pkg.add("StringBuilders")
using StringBuilders

# 'Clinear' stands from:
# - 'C' - color component
# - 'linear' - linear or 'gamma expanded' float number in range [0.0..1.0]
abstract type ClinearCalculator end

struct ICCv2 <: ClinearCalculator end
struct ICCv2_precise <: ClinearCalculator end
struct ICCv4 <: ClinearCalculator end


function calc_Clinear(Csrgb::Float64, ::ICCv2)
    if Csrgb <=0.04045
        Csrgb / 2.92
    else
        ((Csrgb + .055) / 1.055) ^ 2.4
    end
end

function calc_Clinear(Csrgb::Float64, ::ICCv2_precise)
    if Csrgb <=0.0392857
        Csrgb / 2.9232102
    else
        ((Csrgb + .055) / 1.055) ^ 2.4
    end
end

### ICCv4 specification allows to use parametric curves for TRC, so Type 4 curve from the spec
##   should be supported. This type of curve uses four parameters: 
##   - g - gamma
##   - d - slope, where a linear part (near black) ends, and an exponential part starts
##   - c - coefficient for a linear part near black
##   - a and b - coefficients for an exponential part
## The parameters should be supplied by v4 matrix ICC profile.
## I've extracted them from `sRGB-elle-V4-srgbtrc.icc` profile using IccXMLTools by executing:
## > IccToXml.exe sRGB-elle-V4-srgbtrc.icc sRGB-elle-V4-srgbtrc.xml
## The main part from `sRGB-elle-V4-srgbtrc.xml` file is that one:
##
##      <ParametricCurve FunctionType="3">
##        2.39999390 0.94786072 0.05213928 0.07739258 0.04045105
##      </ParametricCurve>
## `FunctionType` attribute value="3" means Type 4 curve, because `FunctionType` values start from 0
function calc_Clinear(Csrgb::Float64, ::ICCv4)

    g = 2.39999390
    a = 0.94786072
    b = 0.05213928
    c = 0.07739258
    d = 0.04045105

    if Csrgb < d
        c * Csrgb
    else
        (a * Csrgb + b)^g 
    end
end

# Convert linearRGB to XYZ
const R709_TO_XYZ_D65 = [
    0.4124564 0.3575761 0.1804375
    0.2126729 0.7151522 0.0721750
    0.0193339 0.1191920 0.9503041
]

### ONLY for calculating monochrome!!!
function calc_L✩_for_monochrome(Clinear::Float64)

    # Multiply R709_TO_XYZ_D65 matrix by vector with the same Clinear for R, G and B (monochrome)
    XYZ_D65 = R709_TO_XYZ_D65 * [Clinear; Clinear; Clinear]
    
    # Calculate L* for D65
    Yn = 1.0  # Reference white point
    Y = XYZ_D65[2]  # Y coordinate
    Y_div_Yn = Y / Yn

    if Y_div_Yn > 0.008856
        116 * Y_div_Yn ^ (1/3) - 16
    else
        903.3 * Y_div_Yn
    end
end


const ICCv2_CALC = ICCv2()
const ICCv2_precise_CALC = ICCv2_precise()
const ICCv4_CALC = ICCv4()
const ALL_CALCS = [ICCv2_CALC, ICCv2_precise_CALC, ICCv4_CALC]

# To calculate Clinear (in range [0.0..1.0]) and L* values (in range [0.0..100.0]) we need:
#   - two Csrgb input numbers for ICCv2 and ICCv4 calculations
#   - color bit depth in from 8..16 bits
# P.S. UNICODE '⨉' character in the name means 'pair'
struct CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits{V}
    forICCv2::V
    forICCv4::V
    bit_depth::UInt8
end

# Let's state explicitly that we should use *only* unsigned integer numbers to represent Csrgb input numbers.
# Also we need to select appropriate unsigned integer data type for input color bit depth:
# - UInt8 for 8 bits input sRGB color
# - UInt16 for >8 bits input sRGB color
# P.S. There are three known useful bit depth for sRGB input numbers: 8, 10, 15 (Photoshop), 16
function toCsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(bit_depth, CsrgbnumICCv2, CsrgbnumICCv4)
    
    @assert isinteger(bit_depth) && isinteger(CsrgbnumICCv2) && isinteger(CsrgbnumICCv4) "All arguments must be integers"

    @assert bit_depth in 8:16  "bit_depth must be in range $(bit_depth)"

    bit_depth     = UInt8(bit_depth)
    CsrgbnumICCv2 = UInt(CsrgbnumICCv2)
    CsrgbnumICCv4 = UInt(CsrgbnumICCv4)

    Csrgbnum_range = 0:(2 ^ bit_depth - 1)
    
    @assert CsrgbnumICCv2 in Csrgbnum_range "CsrgbnumICCv2 must be in range $(Csrgbnum_range)"

    @assert CsrgbnumICCv4 in Csrgbnum_range "CsrgbnumICCv4 must be in range $(Csrgbnum_range)"
    
    if bit_depth == 8
        return CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits{UInt8}(UInt8(CsrgbnumICCv2), UInt8(CsrgbnumICCv4), bit_depth)
    else
        return CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits{UInt16}(UInt16(CsrgbnumICCv2), UInt16(CsrgbnumICCv4), bit_depth)
    end
end


function stat(triple::CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits)

    result = StringBuilder()
    
    Csrgb_numbers = Dict(
        ICCv2_CALC         => triple.forICCv2,
        ICCv2_precise_CALC => triple.forICCv2, #use the same ICCv2 number for ICCv2_precise calculator
        ICCv4_CALC         => triple.forICCv4
    )

    # output calculated values grouped by method of Clinear calculations
    
    Csrgbs   = Dict{ClinearCalculator, Float64}() #range of values [0.0..1.0]
    Clinears = Dict{ClinearCalculator, Float64}() #range of values [0.0..1.0]
    L✩s      = Dict{ClinearCalculator, Float64}() #range of values [0.0..100.0]
    
    for calc in ALL_CALCS

        Csrgbs[calc]   = Csrgb_numbers[calc] / (2^UInt8(triple.bit_depth) - 1)
        
        Clinears[calc] = calc_Clinear(Csrgbs[calc], calc)

        L✩s[calc]      = calc_L✩_for_monochrome(Clinears[calc])
    end    

    for calc in ALL_CALCS

        append!(result, @sprintf "Csrgb number %5d /%2d Csrgb in range [0.0..1.0]: %0.5f (%s)\n" Csrgb_numbers[calc] triple.bit_depth Csrgbs[calc] nameof(typeof(calc)))
    end

    for calc in ALL_CALCS

        append!(result, @sprintf "Csrgb number %5d /%2d Clinear in range [0.0..1.0]: %0.5f (%s)\n" Csrgb_numbers[calc] triple.bit_depth Clinears[calc] nameof(typeof(calc)))
    end

    for calc in ALL_CALCS

        append!(result, @sprintf "Csrgb number %5d /%2d L* in range [0..100]: %0.2f (%s)\n" Csrgb_numbers[calc] triple.bit_depth L✩s[calc] nameof(typeof(calc)))
    end
    
    String(result)
end


function stat()
    
    foreach(
        triple -> println(stat(toCsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(triple...))), 
        [ 
            (  8,     0,     0 ),  # BLACK - 8-bit
            (  8,     1,     1 ),  # very dark color - 8-bit
            (  8,     2,     2 ),  # very dark color - 8-bit
            (  8,     3,     3 ),  # very dark color - 8-bit
            (  8,     4,     4 ),  # very dark color - 8-bit
            (  8,     5,     5 ),  # very dark color - 8-bit
            (  8,     6,     6 ),  # very dark color - 8-bit
            (  8,     7,     7 ),  # very dark color - 8-bit
            (  8,     8,     8 ),  # very dark color - 8-bit
            (  8,     9,     9 ),  # very dark color - 8-bit
            (  8,    10,    10 ),  # very dark color - 8-bit
            (  8,    11,    11 ),  # very dark color - 8-bit
            (  8,    12,    12 ),  # very dark color - 8-bit
            (  8,    13,    13 ),  # very dark color - 8-bit
            (  8,   118,   118 ),  # gamma 2.2 18% gray card - 8-bit
            (  8,   119,   119 ),  # 18% gray card - 8-bit
            (  8,   124,   124 ),  # 20% Image surround reflectance - 8-bit
            (  8,   254,   254 ),  # brightness color - 8-bit
            (  8,   255,   255 ),  # WHITE color - 8-bit
            ( 16,     0,     0 ),  # BLACK - 16-bit
            ( 16,     1,     1 ),  # very dark color - 16-bit
            ( 16, 65534, 65534 ),  # brightness color - 16-bit
            ( 15, 15280, 15280 ),  # 18% gray card - 15-bit
            ( 16, 30560, 30560 )   # 18% gray card - 16-bit
        ]
    )
end

stat()