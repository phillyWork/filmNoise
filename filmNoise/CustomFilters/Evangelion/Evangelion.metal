//
//  Evangelion.metal
//  filmNoise
//
//  Created by Heedon on 2023/02/27.
//

#include <metal_stdlib>
using namespace metal;

#include <CoreImage/CoreImage.h>

extern "C" {
    namespace coreimage {
        float4 Evangelion (sample_t s,
                           float gammaCorrection,
                           float exposure,
                           float contrast)
        {
            
            //exposure
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
            
            //contrast
            s.rgb = (s.rgb - 0.5) * contrast + 0.5;
            
            //gamma correction
            s.rgb = pow(s.rgb, gammaCorrection);
         
            //check luminance of color
            //float3(0.2126, 0.7152, 0.0722): y(luminance) of monitor
            float luma = dot(s.rgb, float3(0.2126, 0.7152, 0.0722));
            if (luma < 0.3) {
                s.rgb += float3(0.0077, 0.00268, 0.03215);
            }
        
            return s;
        }
    }
}
