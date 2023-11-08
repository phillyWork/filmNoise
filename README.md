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

------

# Trouble Shooting

A)

-----

B)


------

C)

------

D)


------

# 회고

- 원본 SampleBuffer에서 Metadata까지 얻어와서 같이 저장하도록 설정 필요
- 단순 갤러리에만 저장, 앨범으로 같이 저장하기 (PHCollectionListChangeRequest 활용)

