//
//  EvangelionFilter.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/27.
//

import UIKit

class EvangelionFilter: CIFilter {
    
    var gammaCorrection: Float = 1.5
    var exposure: Float = 0.05
    var contrast: Float = 1.17
    
    private let kernel: CIKernel
    
    override init() {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        self.kernel = try! CIColorKernel(functionName: "Evangelion", fromMetalLibraryData: data)
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func outputImage(input: CIImage) -> CIImage? {
        return self.kernel.apply(extent: input.extent, roiCallback:  { _, r in r }, arguments: [input, gammaCorrection, exposure, contrast])
    }
    
}
