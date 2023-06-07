#######
# All calculations come from:
# - https://www.color.org/sRGB.pdf doc
# - https://www.wikiwand.com/en/CIELAB_color_space page
#######

using Printf

abstract type ClinearCalculator end

struct ICCv2 <: ClinearCalculator end
struct ICCv2_precise <: ClinearCalculator end
struct ICCv4 <: ClinearCalculator end


function calc_Clinear(CsRGB::Float64, calculator::ICCv2)
    if CsRGB <= 0.04045
        return CsRGB / 12.92
    else
        return ((CsRGB + 0.055) / 1.055) ^ 2.4
    end
end

function calc_Clinear(CsRGB::Float64, calculator::ICCv2_precise)
    if CsRGB <= 0.0392857
        return CsRGB / 12.9232102
    else
        return ((CsRGB + 0.055) / 1.055) ^ 2.4
    end
end

function calc_Clinear(CsRGB::Float64, calculator::ICCv4)
    if CsRGB <= 0.04045
        return 0.0772059 * CsRGB + 0.0025
    else
        return (0.946879 * CsRGB + 0.0520784) ^ 2.4 + 0.0025
    end
end

# Convert linearRGB to XYZ
const R709_TO_XYZ_D65 = [
    0.4124564 0.3575761 0.1804375;
    0.2126729 0.7151522 0.0721750;
    0.0193339 0.1191920 0.9503041
]

### ONLY for calculating monochrome!!!
function calc_L✩_for_monochrome(Clinear::Float64)
    
    # Multiply R709_TO_XYZ_D65 matrix by vector with the same Clinear for R, G and B (monochrome)
    XYZ_D65 = R709_TO_XYZ_D65 * fill(Clinear, 3)
    
    # Calculate L* for D65
    Yn = 1.0  # Reference white point
    Y = XYZ_D65[2]  # Y coordinate
    Y÷Yn = Y / Yn

    if Y÷Yn > 0.008856
        return 116 * Y÷Yn ^ (1/3) - 16
    else
        return 903.3 * Y÷Yn
    end
end


const ICCv2_CALC = ICCv2()
const ICCv2_precise_CALC = ICCv2_precise()
const ICCv4_CALC = ICCv4()
const ALL_CALCS = [ICCv2_CALC, ICCv2_precise_CALC, ICCv4_CALC]

@enum BitDepth::UInt8 _8=8 _9=9 _10=10 _11=11 _12=12 _13=13 _14=14 _15=15 _16=16

function stat(CsRGB_number__ICCv2::Union{UInt8, UInt16}, CsRGB_number__ICCv4::Union{UInt8, UInt16}, bit_depth::BitDepth)
    
    CsRGB_numbers = Dict(
        ICCv2_CALC => CsRGB_number__ICCv2,
        ICCv2_precise_CALC => CsRGB_number__ICCv2,
        ICCv4_CALC => CsRGB_number__ICCv4
    )

    CsRGBs = Dict{ClinearCalculator, Float64}()
    Clinears = Dict{ClinearCalculator, Float64}()
    L✩s = Dict{ClinearCalculator, Float64}()
    
    for calc in ALL_CALCS

        CsRGBs[calc] = CsRGB_numbers[calc] / (2^UInt8(bit_depth) - 1)
        
        Clinears[calc] = calc_Clinear(CsRGBs[calc], calc)

        L✩s[calc] = calc_L✩_for_monochrome(Clinears[calc])
    end    

    for calc in ALL_CALCS

        @printf "CsRGB number %5d /%2d CsRGB in range [0.0..1.0]: %0.5f (%s)\n" CsRGB_numbers[calc] UInt8(bit_depth) CsRGBs[calc] nameof(typeof(calc))
    end

    for calc in ALL_CALCS

        @printf "CsRGB number %5d /%2d Clinear in range [0.0..1.0]: %0.5f (%s)\n" CsRGB_numbers[calc] UInt8(bit_depth) Clinears[calc] nameof(typeof(calc))
    end

    for calc in ALL_CALCS

        @printf "CsRGB number %5d /%2d L* in range [0..100]: %0.2f (%s)\n" CsRGB_numbers[calc] UInt8(bit_depth) L✩s[calc] nameof(typeof(calc))
    end
    
    println()
end


stat(UInt8(0), UInt8(0), _8)  # BLACK - 8-bit
stat(UInt16(0), UInt16(0), _16)  # BLACK - 16-bit
stat(UInt8(1), UInt8(1), _8)  # very dark color (ICC v2) - 8-bit
stat(UInt16(1), UInt16(1), _16)  # very dark color (ICC v2) - 16-bit
stat(UInt8(2^8 - 2), UInt8(2^8 - 2), _8)  # brightness color (ICC v2) - 8-bit
stat(UInt16(2^16 - 2), UInt16(2^16 - 2), _16)  # brightness color (ICC v2) - 16-bit
stat(UInt8(124), UInt8(123), _8)  # 20% Image surround reflectance (ICC v2) - 8-bit
stat(UInt8(118), UInt8(117), _8)  # 18% gray card (ICC v2) - 8-bit
stat(UInt16(15117), UInt16(15037), _15)  # 18% gray card (ICC v2) - 15-bit
stat(UInt16(30235), UInt16(30074), _16)  # 18% gray card (ICC v2) - 16-bit