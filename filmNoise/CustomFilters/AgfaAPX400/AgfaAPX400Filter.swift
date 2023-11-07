//
//  AgfaAPX400Filter.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/23.
//

import UIKit

class AgfaAPX400Filter: CIFilter {
    
    var gammaCorrection: Float = 2.0
    var exposure: Float = 0.03
    var contrast: Float = 0.75
    
    private let kernel: CIKernel
    
    override init() {
        //need for kernel setting
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
        let data = try! Data(contentsOf: url)
        self.kernel = try! CIColorKernel(functionName: "AgfaAPX400", fromMetalLibraryData: data)
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func outputImage(input: CIImage) -> CIImage? {
        //extent: applying kernel
        //roi: region of interest for sampling (specify which region of input should be processed)
        return self.kernel.apply(extent: input.extent, roiCallback:  { _, r in r }, arguments: [input, gammaCorrection, exposure, contrast])
    }
    
}
