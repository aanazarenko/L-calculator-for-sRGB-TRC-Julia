#######
# All calculations come from:
# - https://www.color.org/sRGB.pdf doc
# - https://www.wikiwand.com/en/CIELAB_color_space page
#######

using Printf

# 'Clinear' stands from:
# - 'C' - color component
# - 'linear' - linear or 'gamma expanded' float number in range [0.0..1.0]
abstract type ClinearCalculator end

struct ICCv2 <: ClinearCalculator end
struct ICCv2_precise <: ClinearCalculator end
struct ICCv4 <: ClinearCalculator end


function calc_Clinear(Csrgb::Float64, ::ICCv2)
    if Csrgb <=0.04045
        return Csrgb / 2.92
    else
        return ((Csrgb + .055) / 1.055) ^ 2.4
    end
end

function calc_Clinear(Csrgb::Float64, ::ICCv2_precise)
    if Csrgb <=0.0392857
        return Csrgb / 2.9232102
    else
        return ((Csrgb + .055) / 1.055) ^ 2.4
    end
end

function calc_Clinear(Csrgb::Float64, ::ICCv4)
    if Csrgb <=0.04045
        return 0.0772059 * Csrgb + .0025
    else
        return (0.946879 * Csrgb + .0520784) ^ 2.4 + 0.0025
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
        return 116 * Y_div_Yn ^ (1/3) - 16
    else
        return 903.3 * Y_div_Yn
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
CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(aICCv2::UInt8, aICCv4::UInt8) = CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits{UInt8}(aICCv2, aICCv4, 8)
CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(aICCv2::UInt16, aICCv4::UInt16) = CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits{UInt16}(aICCv2, aICCv4, UInt8(16))
CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(aICCv2::UInt16, aICCv4::UInt16, bit_depth::Val{10}) = CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits{UInt16}(aICCv2, aICCv4, UInt8(10))
CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(aICCv2::UInt16, aICCv4::UInt16, bit_depth::Val{15}) = CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits{UInt16}(aICCv2, aICCv4, UInt8(15))


function stat(triple::CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits)
    
    Csrgb_nubers = Dict(
        ICCv2_CALC         => triple.forICCv2,
        ICCv2_precise_CALC => triple.forICCv2, #use the same ICCv2 number for ICCv2_precise calculator
        ICCv4_CALC         => triple.forICCv4
    )

    # output calculated values grouped by method of Clinear calculations
    
    Csrgbs   = Dict{ClinearCalculator, Float64}() #range of values [0.0..1.0]
    Clinears = Dict{ClinearCalculator, Float64}() #range of values [0.0..1.0]
    L✩s      = Dict{ClinearCalculator, Float64}() #range of values [0.0..100.0]
    
    for calc in ALL_CALCS

        Csrgbs[calc]   = Csrgb_nubers[calc] / (2^UInt8(triple.bit_depth) - 1)
        
        Clinears[calc] = calc_Clinear(Csrgbs[calc], calc)

        L✩s[calc]      = calc_L✩_for_monochrome(Clinears[calc])
    end    

    for calc in ALL_CALCS

        @printf "Csrgb number %5d /%2d Csrgb inrange [0.0..1.0]: %0.5f (%s)\n" Csrgb_nubers[calc] triple.bit_depth Csrgbs[calc] nameof(typeof(calc))
    end

    for calc in ALL_CALCS

        @printf "Csrgb number %5d /%2d Clinear in range [0.0..1.0]: %0.5f (%s)\n" Csrgb_nubers[calc] triple.bit_depth Clinears[calc] nameof(typeof(calc))
    end

    for calc in ALL_CALCS

        @printf "Csrgb number %5d /%2d L* in range [0..100]: %0.2f (%s)\n" Csrgb_nubers[calc] triple.bit_depth L✩s[calc] nameof(typeof(calc))
    end
    
    println()
end


stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt8(0), UInt8(0)))  # BLACK - 8-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt16(0), UInt16(0)))  # BLACK - 16-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt8(1), UInt8(1)))  # very dark color - 8-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt8(10), UInt8(10)))  # very dark color - 8-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt16(1), UInt16(1)))  # very dark color - 16-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt8(2^8 - 2), UInt8(2^8 - 2)))  # brightness color - 8-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt16(2^16 - 2), UInt16(2^16 - 2)))  # brightness color - 16-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt8(124), UInt8(123)))  # 20% Image surround reflectance - 8-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt8(118), UInt8(117)))  # 18% gray card - 8-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt16(15117), UInt16(15037), Val(15)))  # 18% gray card - 15-bit
stat(CsrgbnumICCv2⨉CsrgbnumICCv4⨉bits(UInt16(30235), UInt16(30074)))  # 18% gray card - 16-bit