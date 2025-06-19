#include <metal_stdlib>
using namespace metal;

struct alignas(16) HSVPositionParams {
    uint xComponent;      // HSV component for X axis (0=H, 1=S, 2=V)
    uint yComponent;      // HSV component for Y axis (0=H, 1=S, 2=V)
    uint outputWidth;     // Output texture width
    uint outputHeight;    // Output texture height
    uint reverseX;        // 1 to reverse X axis direction, 0 for normal
    uint reverseY;        // 1 to reverse Y axis direction, 0 for normal
    float noiseAmount;    // Amount of random noise to add (in pixels)
    uint pixelSize;       // Size of each plotted pixel (width and height)
    uint forceFullValue;  // 1 to force value to full (1.0), 0 for normal
    uint forceFullSaturation; // 1 to force saturation to full (1.0), 0 for normal
};

// Convert RGB to HSV with NaN prevention
float3 rgbToHsv(float3 rgb) {
    float maxVal = max(max(rgb.r, rgb.g), rgb.b);
    float minVal = min(min(rgb.r, rgb.g), rgb.b);
    float delta = maxVal - minVal;
    
    float3 hsv;
    
    // Calculate Hue with NaN protection
    if (delta < 1e-6 || maxVal < 1e-6) {
        hsv.x = 0.0; // Undefined, set to 0
    } else if (maxVal == rgb.r) {
        hsv.x = fmod((rgb.g - rgb.b) / delta, 6.0);
    } else if (maxVal == rgb.g) {
        hsv.x = (rgb.b - rgb.r) / delta + 2.0;
    } else {
        hsv.x = (rgb.r - rgb.g) / delta + 4.0;
    }
    
    // Normalize hue to [0, 1] with safety checks
    hsv.x = hsv.x / 6.0;
    if (hsv.x < 0.0) hsv.x += 1.0;
    if (!isfinite(hsv.x)) hsv.x = 0.0; // NaN/Inf protection
    
    // Calculate Saturation with NaN protection
    hsv.y = (maxVal < 1e-6) ? 0.0 : delta / maxVal;
    if (!isfinite(hsv.y)) hsv.y = 0.0; // NaN/Inf protection
    
    // Calculate Value
    hsv.z = maxVal;
    if (!isfinite(hsv.z)) hsv.z = 0.0; // NaN/Inf protection
    
    // Final clamp to valid ranges
    hsv.x = clamp(hsv.x, 0.0, 1.0);
    hsv.y = clamp(hsv.y, 0.0, 1.0);
    hsv.z = clamp(hsv.z, 0.0, 1.0);
    
    return hsv;
}

// Convert HSV back to RGB for output
float3 hsvToRgb(float3 hsv) {
    float h = hsv.x * 6.0;
    float s = hsv.y;
    float v = hsv.z;
    
    float c = v * s;
    float x = c * (1.0 - abs(fmod(h, 2.0) - 1.0));
    float m = v - c;
    
    float3 rgb;
    if (h < 1.0) {
        rgb = float3(c, x, 0.0);
    } else if (h < 2.0) {
        rgb = float3(x, c, 0.0);
    } else if (h < 3.0) {
        rgb = float3(0.0, c, x);
    } else if (h < 4.0) {
        rgb = float3(0.0, x, c);
    } else if (h < 5.0) {
        rgb = float3(x, 0.0, c);
    } else {
        rgb = float3(c, 0.0, x);
    }
    
    return rgb + float3(m);
}

kernel void hsvPosition(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant HSVPositionParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Clear the output texture first - ensure we cover the entire output area
    if (gid.x < params.outputWidth && gid.y < params.outputHeight) {
        outputTexture.write(uint4(0, 0, 0, 0), gid);
    }
    
    // Process only input pixels - early exit if we're outside input bounds
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Read input pixel
    uint4 inputColor = inputTexture.read(gid);
    
    // Convert to normalized RGB [0, 1]
    float3 rgb = float3(inputColor.rgb) / 255.0;
    
    // Convert RGB to HSV
    float3 hsv = rgbToHsv(rgb);
    
    // Apply force overrides if enabled
    if (params.forceFullValue) {
        hsv.z = 1.0; // Force value to full
    }
    if (params.forceFullSaturation) {
        hsv.y = 1.0; // Force saturation to full
    }
    
    // Get the HSV components for positioning
    float xValue, yValue;
    
    switch (params.xComponent) {
        case 0: xValue = hsv.x; break; // Hue
        case 1: xValue = hsv.y; break; // Saturation
        case 2: xValue = hsv.z; break; // Value
        default: xValue = 0.0; break;
    }
    
    switch (params.yComponent) {
        case 0: yValue = hsv.x; break; // Hue
        case 1: yValue = hsv.y; break; // Saturation
        case 2: yValue = hsv.z; break; // Value
        default: yValue = 0.0; break;
    }
    
    // Calculate output position based on HSV values with optional reversal
    uint2 outputPos;
    
    // Apply reversal if requested with NaN protection
    float finalXValue = params.reverseX ? (1.0 - xValue) : xValue;
    float finalYValue = params.reverseY ? (1.0 - yValue) : yValue;
    
    // Protect against NaN values before casting to uint
    if (!isfinite(finalXValue)) finalXValue = 0.0;
    if (!isfinite(finalYValue)) finalYValue = 0.0;
    
    // Clamp values to valid ranges before casting
    finalXValue = clamp(finalXValue, 0.0, 1.0);
    finalYValue = clamp(finalYValue, 0.0, 1.0);
    
    outputPos.x = uint(finalXValue * float(params.outputWidth - 1));
    outputPos.y = uint(finalYValue * float(params.outputHeight - 1));
    
    // Final bounds check (should be redundant now, but keeping for safety)
    outputPos.x = min(outputPos.x, params.outputWidth - 1);
    outputPos.y = min(outputPos.y, params.outputHeight - 1);
    
    // Convert modified HSV back to RGB for output color
    float3 outputRgb = hsvToRgb(hsv);
    uint4 outputColor = uint4(uint3(outputRgb * 255.0), inputColor.a);
    
    // Draw a pixel block of the specified size
    uint halfSize = params.pixelSize / 2;
    for (uint dy = 0; dy < params.pixelSize; dy++) {
        for (uint dx = 0; dx < params.pixelSize; dx++) {
            uint2 writePos = uint2(
                outputPos.x + dx - halfSize,
                outputPos.y + dy - halfSize
            );
            
            // Bounds check for the pixel block
            if (writePos.x < params.outputWidth && writePos.y < params.outputHeight) {
                outputTexture.write(outputColor, writePos);
            }
        }
    }
}
