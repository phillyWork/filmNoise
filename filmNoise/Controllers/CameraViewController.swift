//
//  CameraViewController.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/05.
//

import UIKit
import AVFoundation
import Photos
import MetalKit
import Firebase

import NVActivityIndicatorView

import AppTrackingTransparency

//실시간 필터 처리에 Metal, Metal Kit을 사용하는 이유
//AVCaptureVideoPreviewLayer에서는 프레임들을 직접 AVCaptureSession에서 직접 받아오기 때문에 만드려고 하는 앱에 효과를 적용할 수 없음
//MTKView를 상속함으로, AVCamFilter는 매 프레임을 렌더링 하기 전에 필터를 적용할 수 있음

final class CameraViewController: UIViewController {
    
    //MTKView로 렌더링, 필터 적용 화면 보이기
    //MTKView: subclass of UIView
    @IBOutlet weak var mtkView: MTKView!
    @IBOutlet weak var takePhotoButton: UIButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var timeStampButton: UIButton!
    @IBOutlet weak var cameraLensButton: UIButton!
    @IBOutlet weak var filterCollectionView: UICollectionView!
    
    
    //MARK: - Filters
    
    //선택한 필터 담을 var
    private var selectedFilter: (CIImage) -> CIImage? = FilterFunctions.original(ciImage:)
    
    private var selectedFilterLabel: String = "original"
    
    private var filterManager = FilterDataManager()
    
    
    //MARK: - Variable for Camera Sessions
    
    //device(카메라, 마이크)로부터 입력 데이터를 받아들인 후에 입력 데이터가 결과적으로 적절한 형태의 결과물(비디오나 사진)으로 나올 수 있도록 하는 역할
    private var captureSession: AVCaptureSession!
    
    //cameras and inputs
    private var backCamera: AVCaptureDevice!
    private var frontCamera: AVCaptureDevice!
    private var backInput: AVCaptureInput!
    private var frontInput: AVCaptureInput!
        
    //check for single/dual/triple camera set
    private var cameraType = 0.0
    
    //output of video frame
    private var videoOutput: AVCaptureVideoDataOutput!
    
    //output of photo
    private var photoOutput: AVCapturePhotoOutput!
    //setting of photo
    private var photoSettings: AVCapturePhotoSettings!
    
    private var isFlashOn = false
        
    private var cameraPosition = AVCaptureDevice.Position.back
    
    private var modelName: String?
    
    private var isTimeStampOn = false
    
    private var data: Data?
    
    private var isZoomIn = false
    
    private var indicator: NVActivityIndicatorView!

    //MARK: - Variable for Metal Rendering
    
    //A GPU in the MetalKit framework is represented by a MTLDevice
    //similar to how a camera or a microphone is represented by an AVCaptureDevice in the AVFoundation framework.
    private var metalDevice: MTLDevice!
    
    //To send instructions to the GPU for processing, we need a pipeline to send instructions down
    private var metalCommandQueue: MTLCommandQueue!
    
    //core image for filter
    private var ciContext: CIContext!
    
    //core image
    private var currentCIImage: CIImage?
    
    
    //MARK: - ViewController lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.topItem?.title = ""
        
        filterCollectionView.delegate = self
        filterCollectionView.dataSource = self
            
        configureUI()
        setDataManager()
        setCollectionView()
    }
    
    private func configureUI() {
    
        indicator = NVActivityIndicatorView(frame: CGRect(origin: CGPoint(x: self.view.bounds.width/2-50, y: mtkView.bounds.height/2-70), size: CGSize(width: 100, height: 100)), type: .circleStrokeSpin, color: .white, padding: 10)
        
        self.view.addSubview(indicator)
        
        let nonFlashIpadModels = ["iPad 5", "iPad 6", "iPad 7", "iPad 8", "iPad 9", "iPad 10", "iPad Air 2", "iPad Air 3", "iPad Air 4", "iPad Air 5", "iPad Mini 4", "iPad Mini 5", "iPad Mini 6", "iPad Pro 12.9-inch"]
        
        modelName = getModelName()
        
        if nonFlashIpadModels.contains(modelName!) {
            flashButton.setValue(true, forKey: "hidden")
        } else {
            flashButton.setImage(UIImage(named: "flashOff"), for: .normal)
            flashButton.contentMode = .scaleAspectFill
        }
        takePhotoButton.setImage(UIImage(named: "captureButton"), for: .normal)
        takePhotoButton.contentMode = .scaleAspectFill
        switchCameraButton.setImage(UIImage(named: "cameraChange"), for: .normal)
        switchCameraButton.contentMode = .scaleAspectFill
        
        timeStampButton.setImage(UIImage(named: "stampOff"), for: .normal)
        timeStampButton.contentMode = .scaleAspectFill
        
        cameraLensButton.setImage(UIImage(named: "wideAngle"), for: .normal)
        cameraLensButton.contentMode = .scaleAspectFill
    }
    
    private func setDataManager() {
        if filterManager.checkIsDiscreteArrayEmpty() {
            filterManager.makeDiscreteFilterData()
        }
        filterManager.makeWholeFilterData()
    }

    private func setCollectionView() {
        filterCollectionView.showsHorizontalScrollIndicator = false
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestAdPermission()
        checkCameraPermissions()
        setUpMetal()
        setUpCoreImage()
        setUpAndStartCaptureSession()
    }
    
    private func requestAdPermission() {
        //광고 추적 허용 여부 표시
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:
                return
            case .denied:
                print("status = denied")
            case .notDetermined:
                print("status = notDetermined")
            case .restricted:
                print("status = restricted")
            @unknown default:
                print("status = default")
            }
        }
    }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
    
    // Dispose of any resources that can be recreated.
    override func didReceiveMemoryWarning() {
        print(#function)
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - Camera Setup
    
    //show camera permission alert
    private func showCameraPermissionAlert() {
        //카메라 허용 요구
        let okayAction = UIAlertAction(title: "확인", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Ask for Camera Permission", message: "카메라 접근을 허용해야 촬영을 할 수 있습니다", preferredStyle: .alert)
            alert.addAction(okayAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    //check user permission
    private func checkCameraPermissions() {
        print(#function)
        let cameraAuthStatus =  AVCaptureDevice.authorizationStatus(for: .video)     //AVMediaType.video
        switch cameraAuthStatus {
        case .authorized:
            return
        case .denied:
            showCameraPermissionAlert()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { authorized in
                if !authorized {
                    self.showCameraPermissionAlert()
                }
            }
        case .restricted:
            showCameraPermissionAlert()
        @unknown default:
            print("Something wrong with authorization")
        }
    }
    
    //Setting up Capture Session
    private func setUpAndStartCaptureSession() {
        //startRunning: blocking call
        //execution of app stops at line until capture session actually starts, or until it fails
        DispatchQueue.global(qos: .userInitiated).async {
            //init session
            self.captureSession = AVCaptureSession()
            //start configuration
            //call before changing sessions' inputs or outputs
            self.captureSession.beginConfiguration()
            
            //session specific configuration
            //before setting a session presets, we should check if the session supports it
            //.photo: highest quality
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
            
            //setup inputs
            self.setUpInputs()
            
            //setup output
            self.setUpOutput()
            
            //commit configuration
            //call after making changes
            self.captureSession.commitConfiguration()
            //start running it
            self.captureSession.startRunning()
        }
    }
    
    
    private func getModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let model = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        //dual, triple 각 모델 구분 목적
        //매년 새모델 업데이트 필요
        switch model {
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6":                return "iPhone X"
        case "iPhone11,2":                              return "iPhone XS"
        case "iPhone11,4", "iPhone11,6":                return "iPhone XS Max"
        case "iPhone12,1":                              return "iPhone 11"
        case "iPhone12,3":                              return "iPhone 11 Pro"
        case "iPhone12,5":                              return "iPhone 11 Pro Max"
        case "iPhone13,1":                              return "iPhone 12 Mini"
        case "iPhone13,2":                              return "iPhone 12"
        case "iPhone13,3":                              return "iPhone 12 Pro"
        case "iPhone13,4":                              return "iPhone 12 Pro Max"
        case "iPhone14,4":                              return "iPhone 13 mini"
        case "iPhone14,5":                              return "iPhone 13"
        case "iPhone14,2":                              return "iPhone 13 Pro"
        case "iPhone14,3":                              return "iPhone 13 Pro Max"
        case "iPhone14,7":                              return "iPhone 14"
        case "iPhone14,8":                              return "iPhone 14 Plus"
        case "iPhone15,2":                              return "iPhone 14 Pro"
        case "iPhone15,3":                              return "iPhone 14 Pro Max"
        case "iPhone15,4":                              return "iPhone 15"
        case "iPhone15,5":                              return "iPhone 15 Plus"
        case "iPhone16,1":                              return "iPhone 15 Pro"
        case "iPhone16,2":                              return "iPhone 15 Pro Max"
            
        //iPad for non-flash model
        case "iPad6,11", "iPad6,12":                    return "iPad 5"
        case "iPad7,5", "iPad7,6":                      return "iPad 6"
        case "iPad7,11", "iPad7,12":                    return "iPad 7"
        case "iPad11,6", "iPad11,7":                    return "iPad 8"
        case "iPad12,1", "iPad12,2":                    return "iPad 9"
        case "iPad13,18", "iPad13,19":                  return "iPad 10"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad11,3", "iPad11,4":                    return "iPad Air 3"
        case "iPad13,1", "iPad13,2":                    return "iPad Air 4"
        case "iPad13,16", "iPad13,17":                  return "iPad Air 5"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad11,1", "iPad11,2":                    return "iPad Mini 5"
        case "iPad14,1", "iPad14,2":                    return "iPad Mini 6"
        case "iPad6,7", "iPad6,8":                      return "iPad Pro 12.9-inch"
        default:                                        return model
        }
        
    }
    
    
    private func checkCameraTypes() {
        if let _ = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            cameraType = 3.0;     //pro-models
        } else if let _ = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            cameraType = 2.2;     //wide + telephoto: 7 plus, 8 plus, X, XS
        } else if let _ = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            cameraType = 2.1;     //wide + ultrawide: 11, 12, 13, 14
        } else {
            cameraType = 1.0;     //single: 6S, 6S plus, XR, SE, etc...
        }
    }

    private func setUpInputs() {
        checkCameraTypes()

        //get back camera
        //메인 wide 카메라가 가장 고화소이며 센서 크기가 큼 ~ 보정 관용도가 높으므로 메인 카메라로 확정하기
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) { //single camera
            backCamera = device
        } else {
            //handle this appropriately for production purposes
            fatalError("no back camera")
        }
        
        //get front camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
        } else {
            fatalError("no front camera")
        }
        
        //now we need to create an input objects from our devices
        guard let bInput = try? AVCaptureDeviceInput(device: backCamera) else {
            showCameraPermissionAlert()
            print("could not create input device from back camera")
            return
        }
        backInput = bInput
        if !captureSession.canAddInput(backInput) {
            showCameraPermissionAlert()
            fatalError("could not add back camera input to capture session")
        }
        
        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera) else {
            showCameraPermissionAlert()
            print("could not create input device from front camera")
            return
        }
        frontInput = fInput
        if !captureSession.canAddInput(frontInput) {
            showCameraPermissionAlert()
            fatalError("could not add front camera input to capture session")
        }
        
        //connect camera input to session
        cameraPosition == .back ? captureSession.addInput(backInput) : captureSession.addInput(frontInput)
    }
    
    private func setUpOutput(){
        //set photoOutput
        photoOutput = AVCapturePhotoOutput()
        //photoOutput.availablePhotoCodecTypes = []
        photoOutput.isHighResolutionCaptureEnabled = true
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        } else {
            fatalError("could not add photo output")
        }
        
        photoOutput.connections.first?.videoOrientation = .portrait
  
        //set videoOutput
        videoOutput = AVCaptureVideoDataOutput()
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            fatalError("could not add video output")
        }
        
        videoOutput.connections.first?.videoOrientation = .portrait
    }
    
    //MARK: - Metal
    
    private func setUpMetal() {
        //fetch the default gpu of the device (only one on iOS devices)
        metalDevice = MTLCreateSystemDefaultDevice()
        
        //tell our MTKView which gpu to use
        mtkView.device = metalDevice
        
        //update the MTKView every time there’s a new frame to display
        //tell our MTKView to use explicit drawing meaning we have to call .draw() on it
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = false
        
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        //create a command queue to be able to send down instructions to the GPU
        metalCommandQueue = metalDevice.makeCommandQueue()
        
        //extension for mtkView
        //send commands to GPU
        //MTKViewDelegate for responding view's drawing events
        //conform to our MTKView's delegate
        mtkView.delegate = self
        
        //let its drawable texture be writen to
        mtkView.framebufferOnly = false
        
    }
    
    //MARK: - Core Image
    
    private func setUpCoreImage() {
        //initialize a CIContext instance using Metal
        //what GPU device to use for its built-in processing and evaluation functions
        ciContext = CIContext(mtlDevice: metalDevice)
    }
    
    //MARK: - Actions
    
    //using PhotoOutput: take a picture from camera
    //using VideoDataOutput: capture one frame from video data
    @IBAction func takePhotoButtonTapped(_ sender: UIButton) {
        takePhotoButton.isUserInteractionEnabled = false
        photoSettings = getSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        DispatchQueue.main.async {
            self.indicator.startAnimating()
        }
        
        takePhotoButton.isUserInteractionEnabled = true
        
        let event = "takePhotoButton"
        let parameters = [
            "file": #file,
            "function": #function
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
        
    }
    
    private func getSettings() -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.isHighResolutionPhotoEnabled = true
        settings.flashMode = isFlashOn ? .on : .off
        return settings
    }
    
    @IBAction func switchCameraButtonTapped(_ sender: UIButton) {
        switchFrontBackCameraInput()
        
        let event = "switchCameraButton"
        let parameters = [
            "file": #file,
            "function": #function
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
    }
    
    private func switchFrontBackCameraInput() {
        //deactivate switch button
        switchCameraButton.isUserInteractionEnabled = false
        
        //reconfigure input
        captureSession.beginConfiguration()
        
        if cameraPosition != .front {               //후면카메라에서 누른 경우: 전면카메라로 전환하기
            captureSession.removeInput(backInput)
            captureSession.addInput(frontInput)
            
            //mirror video if front camera
            videoOutput.connections.first?.isVideoMirrored = true
            photoOutput.connections.first?.isVideoMirrored = true
            
            cameraPosition = .front

            //전면카메라 전환 시 렌즈 선택 숨기기
            cameraLensButton.setValue(true, forKey: "hidden")
            
        } else {                                    //전면카메라에서 누른 경우: 후면카메라로 전환하기
            captureSession.removeInput(frontInput)
            captureSession.addInput(backInput)
            
            videoOutput.connections.first?.isVideoMirrored = false
            photoOutput.connections.first?.isVideoMirrored = false
            
            cameraPosition = .back
            
            //후면카메라 전환 시 렌즈 선택 다시 보이기
            //.isHidden은 iOS 16부터
            cameraLensButton.setValue(false, forKey: "hidden")
        }
        
        //icon change
        DispatchQueue.main.async {
            self.cameraPosition == .front ? self.switchCameraButton.setImage(UIImage(named: "cameraChangeSelected"), for: .normal) : self.switchCameraButton.setImage(UIImage(named: "cameraChange"), for: .normal)
        }
        
        //deal with the connection again for portrait mode
        videoOutput.connections.first?.videoOrientation = .portrait
        photoOutput.connections.first?.videoOrientation = .portrait
        
        photoOutput.isHighResolutionCaptureEnabled = true
        
        //animation for flipping
        UIView.transition(with: self.mtkView, duration: 0.5, options: [.transitionFlipFromLeft]) {
            self.mtkView.alpha = 0.0
        } completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseInOut) {
                //commit config
                self.captureSession.commitConfiguration()
                self.mtkView.alpha = 1.0
            }
        }
        
        //activate switch button again
        switchCameraButton.isUserInteractionEnabled = true
    }
    
    @IBAction func flashButtonTapped(_ sender: UIButton) {
        self.isFlashOn.toggle()
        
        DispatchQueue.main.async {
            self.isFlashOn ? self.flashButton.setImage(UIImage(named: "flash"), for: .normal) : self.flashButton.setImage(UIImage(named: "flashOff"), for: .normal)
        }
        
        let event = "flashButton"
        let parameters = [
            "file": #file,
            "function": #function
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
    }
    

    @IBAction func cameraLensButtonPressed(_ sender: UIButton) {
        cameraLensButton.isUserInteractionEnabled = false

        switch cameraType {
        case 3.0:
            tripleCameraSwitch()
        case 2.2:
            dualCameraSwitch()
        case 2.1:
            dualWideCameraSwitch()
        case 1.0:
            break
        default:
            break
        }
        
        //reconfigure input
        captureSession.beginConfiguration()
        
        // Create a new input and add it to the session
        captureSession.removeInput(self.backInput)

        guard let newBackInput = try? AVCaptureDeviceInput(device: backCamera) else {
            showCameraPermissionAlert()
            print("could not create new input device from changing camera lens")
            return
        }
        backInput = newBackInput
        
        captureSession.addInput(self.backInput)
        
        //deal with the connection again for portrait mode
        videoOutput.connections.first?.videoOrientation = .portrait
        photoOutput.connections.first?.videoOrientation = .portrait
        
        photoOutput.isHighResolutionCaptureEnabled = true
        
        //zoom in, zoom out animation when changing lens
        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut) {
            if self.isZoomIn {
                // Set the transform to zoom in
                self.mtkView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            } else {
                // Set the transform to zoom out
                self.mtkView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }
            self.mtkView.alpha = 0.0
            
        } completion: { _ in
            //animation for loading new lens' view
            UIView.animate(withDuration: 0.3) {
                //commit config
                self.captureSession.commitConfiguration()
                
                // Set the transform to original
                self.mtkView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                self.mtkView.alpha = 1.0
            }
        }
        
        cameraLensButton.isUserInteractionEnabled = true
        
        let event = "cameraLensButton"
        let parameters = [
            "file": #file,
            "function": #function
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
    }
    
    private func tripleCameraSwitch() {
        //wide --> telephoto --> ultrawide --> wide 순서로 반복
        
        //망원 배율 구분 목적
        //11 Pro, 11 Pro Max, 12 Pro : 초광각 x0.5 / 광각 / 망원 x2
        //12 Pro Max: 초광각 x0.5 / 광각 / 망원 x2.5
        //13 Pro, 13 Pro Max, 14 Pro, 14 Pro Max, 15 Pro : 초광각 x0.5 / 광각 / 망원 x3
        //15 Pro Max: 초광각 x0.5 / 광각 / 망원 x5
        
        if backCamera == AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            isZoomIn = true
            
            DispatchQueue.main.async {
                switch self.modelName {
                case "iPhone 12 Pro Max":
                    self.cameraLensButton.setImage(UIImage(named: "telephotoAngle2.5"), for: .normal)
                case "iPhone 11 Pro", "iPhone 11 Pro Max", "iPhone 12 Pro":
                    self.cameraLensButton.setImage(UIImage(named: "telephotoAngle2"), for: .normal)
                case "iPhone 15 Pro Max":
                    self.cameraLensButton.setImage(UIImage(named: "telephotoAngle5"), for: .normal)
                default:
                    self.cameraLensButton.setImage(UIImage(named: "telephotoAngle3"), for: .normal)
                }
            }
            
        } else if backCamera == AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
            backCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            isZoomIn = false
            
            DispatchQueue.main.async {
                self.cameraLensButton.setImage(UIImage(named: "ultraWideAngle"), for: .normal)
            }
        } else if backCamera == AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back){
            backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            isZoomIn = true
            
            DispatchQueue.main.async {
                self.cameraLensButton.setImage(UIImage(named: "wideAngle"), for: .normal)
            }
        }
    }
    
    private func dualCameraSwitch() {
        //wide + telephoto
        //7 plus, 8 plus, X, Xs, Xs Max : 광각 / 망원 x2
        if backCamera == AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
            isZoomIn = true
            
            DispatchQueue.main.async {
                self.cameraLensButton.setImage(UIImage(named: "telephotoAngle2"), for: .normal)
            }
        } else if backCamera == AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
            backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            isZoomIn = false
            
            DispatchQueue.main.async {
                self.cameraLensButton.setImage(UIImage(named: "wideAngle"), for: .normal)
            }
        }
    }
    
    private func dualWideCameraSwitch() {
        //wide + ultrawide
        //11, 12, 13, 14, 15: 광각 / 초광각 x0.5 (with Mini and Plus)
        if backCamera == AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            isZoomIn = false
            
            DispatchQueue.main.async {
                self.cameraLensButton.setImage(UIImage(named: "ultraWideAngle"), for: .normal)
           }
        } else if backCamera == AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            isZoomIn = true
            
            DispatchQueue.main.async {
                self.cameraLensButton.setImage(UIImage(named: "wideAngle"), for: .normal)
            }
        }
    }
    
    //time stamp 버튼 클릭: 날짜 새기기
    @IBAction func timeStampButtonTapped(_ sender: UIButton) {
        isTimeStampOn.toggle()
        
        DispatchQueue.main.async {
            self.isTimeStampOn ? self.timeStampButton.setImage(UIImage(named: "stampOn"), for: .normal) : self.timeStampButton.setImage(UIImage(named: "stampOff"), for: .normal)
        }
        
        let event = "timeStampButton"
        let parameters = [
            "file": #file,
            "function": #function
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
    }
    
    //화면 tap --> focus 잡기
    @IBAction func TapScreenToFocus(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            let thisFocusPoint = sender.location(in: mtkView)
            focusAnimation(thisFocusPoint)
            
            guard let device = cameraPosition == .back ? backCamera : frontCamera else { return }
            
            doCaptureDeviceSetting(device: device, focusPoint: thisFocusPoint)
        }
        
        let event = "screenFocus"
        let parameters = [
            "file": #file,
            "function": #function
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
    }
    
    //do CaptureDevice works
    private func doCaptureDeviceSetting(device: AVCaptureDevice, focusPoint: CGPoint) {
        if (device.isFocusModeSupported(.autoFocus) && device.isFocusPointOfInterestSupported) {
            do {
                try device.lockForConfiguration()
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                
                if (device.isExposureModeSupported(.autoExpose) && device.isFocusPointOfInterestSupported) {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    //focus 받는 부분 애니메이션 처리
    private func focusAnimation(_ point: CGPoint) {
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        focusView.center = point
        focusView.layer.borderWidth = 1
        focusView.layer.borderColor = UIColor(named: "selectedOrange")?.cgColor
        mtkView.addSubview(focusView)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.autoreverse], animations: {
            focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        }, completion: { _ in
            focusView.removeFromSuperview()
        })
    }
    
    deinit {
        print("CameraVC released from memory")
    }

}

//MARK: - Delegate for AVCaptureVideoDataOutputSampleBuffer

//사진 찍기는 AVCapturePhotoOutput의 capturePhoto(with:delegate)를 이용
//찍은 사진을 저장하기 위해서는 AVCapturePhotoCaptureDelegate 프로토콜 채택
//AVCapturePhotoCaptureDelegate: photo capture output 결과를 받아오는 메소드 제공

//get sampleBuffer from videoOutput
//methods for checking status of videoOutput
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    //실시간 필터 적용되는 preview를 구현하기 위해 필요한 메서드
    
    //output: AVCapturVideoDataOutput이 들어올 것
    //AVCaptureOutput은 최상위 클래스
    //AVCaptureSession의 addOutput에 인자가 될 수 있는 클래스들의 부모 클래스(AVCaptureVideoDataOutput, AVCapturePhotoOutput 등)입니다.
    
    //CMSampleBuffer는 변경할 수 없는 CMSampleBufferRef 객체에 대한 참조
    //CMSampleBuffer 는 압축되어 있거나 압축되어 있지 않은 특정 미디어 타입(audio, video 등)의 samples 를 가지고 있습니다.
    
    //CMSampleBuffer contains different data type, want image buffer
    //CMSampleBuffetGetImageBuffer() --> CVImageBuffer, can get CIImage
    //CIImage 클래스는 Core Image filter 들을 거칠 또는 생산된 image를 말합니다
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //displyaing preview: CPU(frame) --> GPU(CIIMage) --> CPU(UIIMage) is bad
        //metalkit is way better
        
        //try and get a CVImageBuffer out of the sample buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sampleBuffer")
            return
        }
        
        //Process Image here
        print("did receive image frame")
        
        //get a CIImage out of the CVImageBuffer
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        
        guard let resultImage = selectedFilter(ciImage) else { return }
        
        self.currentCIImage = resultImage
        
        print("currentCIImage: ", currentCIImage ?? "There is nothing in currentCIImage in captureOutput")
        
        //remove setupPreviewLayer(), adding an instance to store metal view
        //draw on MTKView
        mtkView.draw()
    }
    
}

//MARK: - Delegate for saving captured photos from AVCapturePhotoOutput into photo library

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        //error 체크
        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }
        
        //captureOutput에서 필터 적용된 CIImage 활용하기
        guard let ciImage = currentCIImage else {
            print("There is nothing in currentCIImage in photoOutput")
            return
        }
    
        let filteredImage = UIImage(ciImage: ciImage)
        
        if isTimeStampOn {
            //adding time-stamp on image
            let timeStamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
            let canvasSize = CGSize(width: filteredImage.size.width, height: filteredImage.size.height)
            let renderer = UIGraphicsImageRenderer(size: canvasSize)
            
            guard let customFont = UIFont(name: "SFDigitalReadout-HeavyOblique", size: 65) else {
                fatalError("""
                            Failed to load the "SFDigitalReadout" font.
                            Make sure the font file is included in the project and the font name is spelled correctly.
                            """)
            }
            
            let timestampAttributes = [
                NSAttributedString.Key.font: UIFontMetrics.default.scaledFont(for: customFont),
                NSAttributedString.Key.foregroundColor: UIColor(red: 0.957, green: 0.777, blue: 0.102, alpha: 0.6)
            ]
            
            let timestampRect = CGRect(x: filteredImage.size.width - 325, y: filteredImage.size.height - 100, width: canvasSize.width - 100, height: 100)
        
            let result = renderer.image { context in
                // Draw the original image
                filteredImage.draw(at: CGPoint(x: 0, y: 0))
                // Draw the timestamp
                timeStamp.draw(in: timestampRect, withAttributes: timestampAttributes)
            }
            data = result.jpegData(compressionQuality: 0.99)
        } else {
            data = filteredImage.jpegData(compressionQuality: 0.99)
        }
        
        //Photo Library 접근 허용 확인
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                self.showPhotoSavePermissionAlert()
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                var existingAlbum: PHAssetCollection?
                
                //check album existance
                let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
                albums.enumerateObjects { album, index, stop in
                    if album.localizedTitle == "filmNoise" {
                        existingAlbum = album as? PHAssetCollection
                    }
                }
                    
                if let album = existingAlbum {
                    //album exists
                    print("Album Exists")
                    self.savePhotoToAlbum(album: album)
                } else {
                    print("No Album")
                    //create new album
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "filmNoise")
                    }, completionHandler: { didSucceed, error in
                        if didSucceed {
                            let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
                            albums.enumerateObjects { album, index, stop in
                                if album.localizedTitle == "filmNoise" {
                                    existingAlbum = album as? PHAssetCollection
                                }
                            }
                            if let album = existingAlbum {
                                print("Album created and found")
                                self.savePhotoToAlbum(album: album)
                            }
                        } else {
                            print("Can't create new album!")
                            return
                        }
                    })
                }
            }) { (success, error) in
                if success {
                    //저장 완료 알림 주기
                    DispatchQueue.main.async {
                        self.indicator.stopAnimating()
                        let alert = UIAlertController(title: nil, message: "저장 완료!", preferredStyle: .alert)
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                            self.dismiss(animated: true, completion: nil)
                        })
                        self.present(alert, animated: true, completion: nil)
                    }
                } else {
                    //실패 알림 주기
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: nil, message: "저장에 실패했습니다!", preferredStyle: .alert)
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                            self.dismiss(animated: true, completion: nil)
                        })
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
        
    }
    
    func savePhotoToAlbum(album: PHAssetCollection) {
        PHPhotoLibrary.shared().performChanges {
            //request to add image into newly created album
            let assetCreationRequest = PHAssetChangeRequest.creationRequestForAsset(from: UIImage(data: self.data!)!)
            
            guard let addAssetRequest = PHAssetCollectionChangeRequest(for: album) else {
                print("Can't create addAssetRequest")
                return
            }
            addAssetRequest.addAssets([assetCreationRequest.placeholderForCreatedAsset!] as NSArray)
        }
    }

    //show photo saving permission alert
    private func showPhotoSavePermissionAlert() {
        //카메라 허용 요구
        let okayAction = UIAlertAction(title: "확인", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Ask for Photo Savings", message: "사진첩 접근을 허용해야 사진 저장이 가능합니다", preferredStyle: .alert)
            alert.addAction(okayAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
}

//MARK: - Delegate for MTKView

extension CameraViewController: MTKViewDelegate {
    
    //drawable's size has changed
    //MTLDrawable: use drawable objects when you want to render images using Metal and present them onscreen
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    //render to the screen
    func draw(in view: MTKView) {
       
        //store a reference to each frame in our class so that when we call draw on the metal view, it knows what frame it needs to use
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        
        //make sure we actually have a ciImage to work with
        guard let ciImage = currentCIImage else { return }
        
        //make sure the current drawable object for this metal view is available
        //it's not in use by the previous draw cycle
        guard let currentDrawable = view.currentDrawable else { return }

        let widthOfDrawable = view.drawableSize.width
        let heightOfDrawable = view.drawableSize.height
        
        //make sure frame is centered on screen
        let widthOfciImage = ciImage.extent.width
        let xOffsetFromBottom = (widthOfDrawable - widthOfciImage)/2
        
        let heightOfciImage = ciImage.extent.height
        let yOffsetFromBottom = (heightOfDrawable - heightOfciImage)/2
            
        //render a CIImage into our metal texture
        
        //image: CIImage we create for each frame
        
        //texture: rendering it to the screen through metal view ~ texture of drawable that the metal view is housing
        //an image that's used to map onto an object
        
        //commandBuffer: instructions sent through commandQueue to GPU
        
        //bounds: GCRect to draw the image on the texture
        
        //colorSpace: tells CIContext how to interpret color info from CIImage
        
        self.ciContext.render(ciImage, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: CGRect(origin: CGPoint(x: -xOffsetFromBottom, y: -yOffsetFromBottom), size: view.drawableSize), colorSpace: CGColorSpaceCreateDeviceRGB())
        
        //register where to draw the instructions in the command buffer once it executes
        commandBuffer.present(currentDrawable)
        //commit the command to the queue so it executes
        commandBuffer.commit()
    }

}


//a CIImage (that thing we create out of the video frame) is just a recipe for an image
//whenever we transform to CGImage and UIImage we’ve run into the CPU
//we want to do that only if necessary ~ if user actually takes image

//We’ll be storing a reference to the CIImage we’ve already created and call draw on our metal view to take over and render the image inside the metal view.

//CIImage ~ recipe for an image --> can apply CIFilters
//CIContext: we can render directly to a metal texture

//step to get the frame from camera to screen: CMSampleBuffer (from VideoCaptureDataOutput) --> CIImage --> MTLTexture

//apply filters before we use the CIImage to render onto the screen and/or before saving it when the user takes a picture.

//MARK: - Delegate for CollectionView

extension CameraViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filterManager.getWholeFilterData().count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = filterCollectionView.dequeueReusableCell(withReuseIdentifier: "FilterCollectionViewCell", for: indexPath) as! FilterCollectionViewCell

        let filter = filterManager.getWholeFilterData()[indexPath.row]
        cell.filterLabel.text = filter.nameLabel
        cell.filterImageView.image = filter.coverImage
    
        return cell
    }
    
}

extension CameraViewController: UICollectionViewDelegate {
   
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let nameLabel = filterManager.getWholeFilterData()[indexPath.row].nameLabel
        
        switch nameLabel {
        case "minimal life":
            selectedFilter = FilterFunctions.agfaAPX400(ciImage:)
        case "tumble down":
            selectedFilter = FilterFunctions.evangelion(ciImage:)
        default:
            selectedFilter = FilterFunctions.original(ciImage:)
        }
        self.selectedFilterLabel = nameLabel
        
        let event = "filterCell"
        let parameters = [
            "file": #file,
            "function": #function,
            "filterName": nameLabel
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
    }
    
}

extension CameraViewController: UICollectionViewDelegateFlowLayout {
    //셀 크기
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        //cell의 height값을 크게하여 cell이 밑이 아닌 오른쪽으로 뻗어지도록 설정
        //height값을 collectionView의 height만큼 설정
        return CGSize(width: 100, height: filterCollectionView.frame.height)
    }
    
    //위아래 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    //좌우 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}
