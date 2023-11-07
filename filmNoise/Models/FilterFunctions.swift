//
//  FilterFunctions.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/19.
//

import UIKit

//각 필터 대응용 적용 함수 모음
struct FilterFunctions {
    
    //MARK: - Setting for CIFilters' input

    private struct VectorSetting {
        let grayscaleVector = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        let AlphaVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        let zeroVector = CIVector(x: 0, y: 0, z: 0, w: 0)
    }
    
    private struct NoiseSetting {
        // Adjust noise image using CIColorControls
        let noiseBrightness: Float
        let noiseContrast: Float
        let noiseSaturation: Float
        
        init(brightness noiseBrightness: Float, contrast noiseContrast: Float, saturation noiseSaturation: Float) {
            self.noiseBrightness = noiseBrightness
            self.noiseContrast = noiseContrast
            self.noiseSaturation = noiseSaturation
        }
    }
        
    static func original(ciImage image: CIImage) -> CIImage? {
        return image
    }
    
    static func agfaAPX400(ciImage image: CIImage) -> CIImage? {
        let agfaFilter = AgfaAPX400Filter()
        let agfaResult = agfaFilter.outputImage(input: image)
        
        let vectorSetting = VectorSetting()
        //create B&W image of original for masking's background
        guard
            let grayscaleFilter = CIFilter(name: "CIColorMatrix", parameters:
                                           [
                                            kCIInputImageKey: image,
                                            "inputRVector": vectorSetting.grayscaleVector,
                                            "inputGVector": vectorSetting.grayscaleVector,
                                            "inputBVector": vectorSetting.grayscaleVector,
                                            "inputAVector": vectorSetting.AlphaVector,
                                            "inputBiasVector": vectorSetting.zeroVector
                                           ]),
            let bwImage = grayscaleFilter.outputImage
        else {
            print("Can't produce grayscaleFilter and bwImage")
            return nil
        }
        
        //create randomly varying speckle
        guard
            let colorNoise = CIFilter(name: "CIRandomGenerator"),
            let noiseImage = colorNoise.outputImage
        else {
            print("Can't produce grainImage")
            return nil
        }
        
        let noiseSettingForAgfa = NoiseSetting(brightness: 0.6, contrast: 0.9, saturation: 1.8)
        guard
            let noiseControlsFilter = CIFilter(name: "CIColorControls", parameters:
                                                [
                                                    kCIInputImageKey: noiseImage,
                                                    kCIInputBrightnessKey: noiseSettingForAgfa.noiseBrightness,
                                                    kCIInputContrastKey: noiseSettingForAgfa.noiseContrast,
                                                    kCIInputSaturationKey: noiseSettingForAgfa.noiseSaturation
                                                ]),
            let adjustedNoiseImage = noiseControlsFilter.outputImage
        else {
            print("Can't produce noiseControlsFilter and adjustedNoiseImage")
            return nil
        }
        
        //blend agfaResult, bw original image with mask of noiseFilter
        guard
            let blendFilter = CIFilter(name: "CIBlendWithMask", parameters:
                                        [
                                            kCIInputImageKey: agfaResult!,
                                            kCIInputBackgroundImageKey: bwImage,
                                            kCIInputMaskImageKey: adjustedNoiseImage
                                        ]),
            let blendImage = blendFilter.outputImage
        else {
            print("Can't produce blendFilter and blendImage")
            return nil
        }
        
        return blendImage.cropped(to: image.extent)
    }
    
    static func evangelion(ciImage image: CIImage) -> CIImage? {
        let evaFilter = EvangelionFilter()
        let evaResult = evaFilter.outputImage(input: image)
        
        let vectorSetting = VectorSetting()
        guard
            let grayscaleFilter = CIFilter(name: "CIColorMatrix", parameters:
                                           [
                                            kCIInputImageKey: image,
                                            "inputRVector": vectorSetting.grayscaleVector,
                                            "inputGVector": vectorSetting.grayscaleVector,
                                            "inputBVector": vectorSetting.grayscaleVector,
                                            "inputAVector": vectorSetting.AlphaVector,
                                            "inputBiasVector": vectorSetting.zeroVector
                                           ]),
            let bwImage = grayscaleFilter.outputImage
        else {
            print("Can't produce grayscaleFilter and bwImage")
            return nil
        }
        
        guard
            let colorNoise = CIFilter(name: "CIRandomGenerator"),
            let noiseImage = colorNoise.outputImage
        else {
            print("Can't produce grainImage")
            return nil
        }
        
        let noiseSettingForEva = NoiseSetting(brightness: 0.65, contrast: 1.13, saturation: 1.27)
        guard
            let noiseControlsFilter = CIFilter(name: "CIColorControls", parameters:
                                                [
                                                    kCIInputImageKey: noiseImage,
                                                    kCIInputBrightnessKey: noiseSettingForEva.noiseBrightness,
                                                    kCIInputContrastKey: noiseSettingForEva.noiseContrast,
                                                    kCIInputSaturationKey: noiseSettingForEva.noiseSaturation
                                                ]),
            let adjustedNoiseImage = noiseControlsFilter.outputImage
        else {
            print("Can't produce noiseControlsFilter and adjustedNoiseImage")
            return nil
        }
        
        guard
            let blendFilter = CIFilter(name: "CIBlendWithMask", parameters:
                                        [
                                            kCIInputImageKey: evaResult!,
                                            kCIInputBackgroundImageKey: bwImage,
                                            kCIInputMaskImageKey: adjustedNoiseImage
                                        ]),
            let blendImage = blendFilter.outputImage
        else {
            print("Can't produce blendFilter and blendImage")
            return nil
        }
        
        return blendImage.cropped(to: image.extent)
    }

    
}
