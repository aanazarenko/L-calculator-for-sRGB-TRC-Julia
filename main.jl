#######
# All calculations come from:
# - https://www.color.org/sRGB.pdf doc
# - https://www.wikiwand.com/en/CIELAB_color_space page
#######

using Printf

function calculate_linear_value_ICCv2(normalized_level::Float64)
    if normalized_level <= 0.04045
        linear_value = normalized_level / 12.92
    else
        linear_value = ((normalized_level + 0.055) / 1.055) ^ 2.4
    end
    return linear_value
end

function calculate_linear_value_ICCv2_precise(normalized_level::Float64)
    if normalized_level <= 0.0392857
        linear_value = normalized_level / 12.9232102
    else
        linear_value = ((normalized_level + 0.055) / 1.055) ^ 2.4
    end
    return linear_value
end

function calculate_linear_value_ICCv4(normalized_level::Float64)
    if normalized_level <= 0.04045
        linear_value = 0.0772059 * normalized_level + 0.0025
    else
        linear_value = (0.946879 * normalized_level + 0.0520784) ^ 2.4 + 0.0025
    end
    return linear_value
end

# Convert linearRGB to XYZ
const R709_TO_XYZ_D65 = [
    0.4124564 0.3575761 0.1804375;
    0.2126729 0.7151522 0.0721750;
    0.0193339 0.1191920 0.9503041
]

### ONLY for calculating monochrome!!!
function calculate_Lstar_value_for_monochrome(linear_value::Float64)
    # Define the matrix and vector
    matrix = R709_TO_XYZ_D65
    vector = [linear_value, linear_value, linear_value]
    
    # Multiply R709_TO_XYZ_D65 matrix by vector with linear_value
    XYZ_D65 = matrix * vector
    
    # Calculate L* value for D65
    Yn = 1.0  # Reference white point
    Y = XYZ_D65[2]  # Y coordinate
    Y_div_Yn = Y / Yn

    if Y_div_Yn > 0.008856
        L_star = 116 * Y_div_Yn ^ (1/3) - 16
    else
        L_star = 903.3 * Y_div_Yn
    end

    return L_star
end

function stat(int_level__ICCv2::Int, int_level__ICCv4::Int, bit_depth::Int)
    
    normalized_level__ICCv2 = int_level__ICCv2 / (2^bit_depth - 1)
    @printf "level %5d /%2d normalized level in range [0..1]: %0.5f (ICC v2)\n" int_level__ICCv2 bit_depth normalized_level__ICCv2
    
    normalized_level__ICCv4 = int_level__ICCv4 / (2^bit_depth - 1)
    @printf "level %5d /%2d normalized level in range [0..1]: %0.5f (ICC v4)\n" int_level__ICCv4 bit_depth normalized_level__ICCv4
    
    linear_value__ICCv2 = calculate_linear_value_ICCv2(normalized_level__ICCv2)
    @printf "level %5d /%2d linear value in range [0..1]: %0.5f (ICC v2)\n" int_level__ICCv2 bit_depth linear_value__ICCv2
    
    linear_value__ICCv2_precise = calculate_linear_value_ICCv2_precise(normalized_level__ICCv2)
    @printf "level %5d /%2d linear value in range [0..1]: %0.5f (ICC v2 precise)\n" int_level__ICCv2 bit_depth linear_value__ICCv2_precise
    
    linear_value__ICCv4 = calculate_linear_value_ICCv4(normalized_level__ICCv4)
    @printf "level %5d /%2d linear value in range [0..1]: %0.5f (ICC v4)\n" int_level__ICCv4 bit_depth linear_value__ICCv4
    
    Lstar_value__ICCv2 = calculate_Lstar_value_for_monochrome(linear_value__ICCv2)
    @printf "level %5d /%2d L* value in range [0..100]: %0.2f (ICC v2)\n" int_level__ICCv2 bit_depth Lstar_value__ICCv2
    
    Lstar_value__ICCv4 = calculate_Lstar_value_for_monochrome(linear_value__ICCv4)
    @printf "level %5d /%2d L* value in range [0..100]: %0.2f (ICC v4)\n" int_level__ICCv4 bit_depth Lstar_value__ICCv4
    
    println()
end

stat(1, 1, 8)  # very dark color (ICC v2) - 8-bit
stat(1, 1, 16)  # very dark color (ICC v2) - 16-bit
stat(2^8 - 2, 2^8 - 2, 8)  # brightness color (ICC v2) - 8-bit
stat(2^16 - 2, 2^16 - 2, 16)  # brightness color (ICC v2) - 16-bit
stat(124, 123, 8)  # 20% Image surround reflectance (ICC v2) - 8-bit
stat(118, 117, 8)  # 18% gray card (ICC v2) - 8-bit
stat(15117, 15037, 15)  # 18% gray card (ICC v2) - 15-bit
stat(30235, 30074, 16)  # 18% gray card (ICC v2) - 16-bit