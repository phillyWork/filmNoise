# filmNoise

![imagesForApp](./readMeImage/appImage.jpg)

#### 일상에서 누구나 감성을 더할 수 있는 사진 필터 앱입니다.

# Link

[filmNoise 앱스토어 링크](https://apps.apple.com/app/filmnoise/id6445938664)

[첫 배포 이후 블로그 회고 링크](https://velog.io/@simonyain/series/filmNoise-개발-과정)

# 개발 기간 및 인원
- 2023.02.05 ~ 2023.03.08
- 배포 이후 지속적 업데이트 중 (현재 version 2.3.1)
- 최소 버전: iOS 14.1
- 1인 개발

# 사용 기술
- **UIKit, AVFoundation, MetalKit, Photos, AppTrackingTransparency, SPM**
- **FirebaseAnalyticsWithoutAdidSupport, FirebaseCrashlytics, GoogleMobileAds, NVActivityIndicatorView**
- **MVC, Storyboard, Delegate, GCD**
- **AVCaptureSession & MTKView, custom CIFilter & CIKernel, PHPhotoLibrary**

------

# 기능 구현
- `Metal` 파일 및 커스텀 `CIFilter` 활용하여 필터 제작
  - `CIKernel` 커스텀하게 등록 후, Metal 파일 내 설정값 적용하여 CIImage 반환
- `AVCaptureSession`의 output을 `CIImage`화, `MTKView`에 실시간으로 필터 적용 화면 그려내기
  - `AVCaptureVideoDataOutputSampleBufferDelegate`의 `captureOutput` 메서드 활용, `CMSampleBuffer`에서 CIImage 추출
  - 추출한 CIImage를 `MTKViewDelegate`의 `draw` 메서드에 적용, MTKView에 `render`
- `DateFormatter`와 custom Font 활용해 촬영 날짜 그려내기
- `utsname`과 `machine` property를 활용하여 디바이스 모델명 구분, `AVCaptureDevice`의 각 모델에 맞는 듀얼/트리플 렌즈시스템 및 플래시 유무 여부 UI 구성
- AVCaptureDevice의 `authorizationStatus`, `cameraPosition`, `flashMode`, `focusMode` property 활용하여 카메라 권한 요청, 셀피, 플래시, 오토포커스 기능 구현
- `PHPhotoLibrary` 활용, 사진 저장 권한 요청 및 갤러리 앨범에 사진 저장
- `AnalyticsWithoutAdidSupport`와 `Crashlytics`를 활용, UUID 정보 없이도 UI component 활용 통계 및 크래시 정보 수집
- `ATTrackingManager` 활용하여 광고 권한 얻고 `Admob` 활용해 배너 광고 게재

### 전체 촬영 Flow
![totalFlow](./readMeImage/totalFlow.jpg)

------

# Trouble Shooting

### A. CIImage 적용된 데이터를 실시간 스크린으로 보여주기 위해선 AVCaptureVideoPreviewLayer를 활용할 수 없음

실시간 Preview 화면으로 `AVCaptureVideoPreviewLayer`를 `UIView`의 layer로 설정할 수 있지만, 추가 데이터를 적용할 수 없는 특징이 존재한다.
UIView 대신 MTKView를 활용하면 매 frame을 렌더링하여 화면에 그려내기 전, 필터 데이터를 적용할 수 있다. MTKView는 UIView를 상속하므로 Preview 화면으로의 역할도 가능하다.

MTKView에 최종 결과물을 그려내기 위해선 Metal Rendering Process를 통해 render해야 한다.

- _Metal Rendering Process 준비 과정_
```swift
@IBOutlet weak var mtkView: MTKView!

//A GPU in the MetalKit framework, represented as a MTLDevice
var metalDevice: MTLDevice!
    
//a pipeline to send instructions down to MTLDevice
var metalCommandQueue: MTLCommandQueue!
    
//core image for filter
var ciContext: CIContext!
    
//core image with filter data
var currentCIImage: CIImage?

func setUpMetal() {
    //fetch the default gpu of the device (only one on iOS devices)
    metalDevice = MTLCreateSystemDefaultDevice()
        
    //setup MTKView's MTLDevice
    mtkView.device = metalDevice
        
    //update MTKView every time there’s a new frame to display
    //explicit drawing, have to call .draw()
    mtkView.isPaused = true
    
    //command queue to send down instructions to the GPU
    metalCommandQueue = metalDevice.makeCommandQueue()
        
	//send commands to GPU
    //MTKViewDelegate for responding view's drawing events
    mtkView.delegate = self

    //sample or perform read/write operations on the textures
    mtkView.framebufferOnly = false
}

func setUpCoreImage() {
	//initialize CIContext instance using Metal device
    ciContext = CIContext(mtlDevice: metalDevice)
}
```
- _AVCaptureVideoDataOutputSampleBufferDelegate의 captureOutput 메서드에서 원본 image buffer에서 CIImage 추출, MTKViewDelegate의 draw 메서드 호출_
```swift
//유저가 특정 필터를 선택할 시, 해당 필터를 담고 있을 변수
var currentCIImage: CIImage?

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {		

		//get CVImageBuffer out of the sample buffer
		guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
			debugPrint("unable to get image from sampleBuffer")
			return
		}
		
		//get CIImage out of the CVImageBuffer
		let ciImage = CIImage(cvImageBuffer: cvBuffer)

		//save it in variable to draw in mtkView
		self.currentCIImage = ciImage

		//draw on MTKView
		mtkView.draw()
	}
}
```

- _MTKViewDelegate의 draw 메서드 수행_
```swift
extension ViewController: MTKViewDelegate {
	//render on screen
	func draw(in view: MTKView) {
    	//store a reference to each frame
    	guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        
	    //ciImage with filter data to work with
    	guard let ciImage = currentCIImage else { return }

		//make sure currentDrawable object is available
    	//should not be in use by previous draw cycle
    	guard let currentDrawable = view.currentDrawable else { return }

    	let widthOfDrawable = view.drawableSize.width
    	let heightOfDrawable = view.drawableSize.height
        
    	//frame is centered on screen
    	let widthOfciImage = ciImage.extent.width
    	let xOffsetFromBottom = (widthOfDrawable - widthOfciImage)/2
        
    	let heightOfciImage = ciImage.extent.height
    	let yOffsetFromBottom = (heightOfDrawable - heightOfciImage)/2
            
    	//render a CIImage into our metal texture
        
    	//image: CIImage for each frame
    	//texture: rendering it to the screen through mtkView
    	//commandBuffer: instructions sent through commandQueue to GPU
    	//bounds: GCRect to draw the image on the texture
    	//colorSpace: tells CIContext how to interpret color info from CIImage
    	self.ciContext.render(ciImage, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: CGRect(origin: CGPoint(x: -xOffsetFromBottom, y: -yOffsetFromBottom), size: view.drawableSize), colorSpace: CGColorSpaceCreateDeviceRGB())
        
    	//register to draw the instructions in the command buffer once it executes
    	commandBuffer.present(currentDrawable)
        
    	//commit the command to the queue ~ execute
    	commandBuffer.commit()
	}
}
```

-----

### B. Custom CIFilter 제작

기본 제공되는 CIFilter만 활용하기엔 수치 조정을 직접 할 수 없어서 원하는 색감 표현에 한계가 존재했다. Metal로 직접 CIFilter를 만들어 활용했다.

#### 1. WWDC의 Session을 보면서 전체 흐름을 익힌다.

[WWDC14: Working with Metal: Overview](https://developer.apple.com/videos/play/wwdc2014/603/)

[WWDC20: Build Metal-based Core Image kernels with Xcode](https://developer.apple.com/videos/play/wwdc2020/10021/)

[WWDC21: Explore Core Image kernel improvements](https://developer.apple.com/videos/play/wwdc2021/10159/)

Xcode Build Settings에서 Metal Linker - Build Options에 `-fcikernel`을 추가해서 CIKernel 인식을 할 수 있도록 해준다.



#### 2. 이미지 프로세싱을 위한 도메인 지식을 활용해 Metal 파일에서 수치를 조정했다.




------

### C. 

------

### D.


------

# 회고

- 원본 SampleBuffer에서 Metadata까지 얻어와서 같이 저장하도록 설정 필요
- 단순 갤러리에만 저장, 앨범으로 같이 저장하기 (PHCollectionListChangeRequest 활용)

