#include <metal_stdlib>
using namespace metal;

struct alignas(16) DonutParams {
    uint2 center;        // Center of the donut
    uint innerRadius;    // Inner radius of the donut
    float featherPixels; // Edge feather width in pixels. 0 = hard edge (default).
};

kernel void donutMask(
    texture2d<uint, access::read> inputTexture [[texture(0)]],
    texture2d<uint, access::write> outputTexture [[texture(1)]],
    constant DonutParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early exit if we're outside the output bounds
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    // Calculate distance from center
    float dx = float(gid.x) - float(params.center.x);
    float dy = float(gid.y) - float(params.center.y);
    float distanceSquared = dx * dx + dy * dy;

    // Read input pixel
    uint4 inputColor = inputTexture.read(gid);

    // Calculate outer radius (half the image width since it's square)
    float outerRadius = float(outputTexture.get_width()) / 2.0;
    float outerRadiusSquared = outerRadius * outerRadius;
    float innerRadiusSquared = float(params.innerRadius) * float(params.innerRadius);

    if (params.featherPixels <= 0.0) {
        // Hard edge (default): keep original color only for pixels between
        // inner and outer radius, otherwise fully transparent. Preserved
        // exactly as-is so existing callers (e.g. the detection pipeline,
        // which consumes this mask as a binary input) see no behavior change.
        if (distanceSquared <= outerRadiusSquared && distanceSquared >= innerRadiusSquared) {
            outputTexture.write(uint4(inputColor[0], inputColor[1], inputColor[2], 255), gid);
        } else {
            outputTexture.write(uint4(0, 0, 0, 0), gid);
        }
        return;
    }

    // Feathered edge: ramp alpha across `featherPixels` on both the inner
    // and outer boundary instead of a hard cut, to anti-alias the ring for
    // display purposes.
    float distance = sqrt(distanceSquared);
    float outerAlpha = 1.0 - smoothstep(outerRadius - params.featherPixels, outerRadius + params.featherPixels, distance);
    float innerAlpha = smoothstep(float(params.innerRadius) - params.featherPixels, float(params.innerRadius) + params.featherPixels, distance);
    float alpha = saturate(outerAlpha * innerAlpha);

    uint8_t a = uint8_t(round(alpha * 255.0));
    outputTexture.write(uint4(inputColor[0], inputColor[1], inputColor[2], a), gid);
}
