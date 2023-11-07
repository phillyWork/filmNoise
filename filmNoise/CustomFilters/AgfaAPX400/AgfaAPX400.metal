//
//  AgfaAPX400.metal
//  filmNoise
//
//  Created by Heedon on 2023/02/23.
//

#include <metal_stdlib>
using namespace metal;

#include <CoreImage/CoreImage.h>

extern "C" {
    namespace coreimage {
        float4 AgfaAPX400 (sample_t s,
                           float gammaCorrection,
                           float exposure,
                           float contrast)
        {

            // exposure adjustment
            if (s.r + exposure > 1) {
                s.r = 1;
            } else if (s.r + exposure < 0) {
                s.r = 0;
            } else {
                s.r += exposure;
            }
            
            if (s.b + exposure > 1) {
                s.b = 1;
            } else if (s.b + exposure < 0) {
                s.b = 0;
            } else {
                s.b += exposure;
            }
            
            if (s.g + exposure > 1) {
                s.g = 1;
            } else if (s.g + exposure < 0) {
                s.g = 0;
            } else {
                s.g += exposure;
            }
            
            //convert color to grayscale
            //
            float gray = dot(s.rgb, float3(0.299, 0.587, 0.114));
            s.rgb = float3(gray);

            //adjust contrast
            s.rgb = (s.rgb - 0.5) * contrast + 0.5;

            //gamma correction
            s.rgb = pow(s.rgb, gammaCorrection);
            
            return s;
        }
    }
}

