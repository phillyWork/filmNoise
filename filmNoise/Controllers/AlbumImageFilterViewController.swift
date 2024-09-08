//
//  AlbumImageFilterViewController.swift
//  filmNoise
//
//  Created by Heedon on 9/8/24.
//

import UIKit
import AVFoundation
import Photos
import PhotosUI
import MetalKit
import Firebase

import NVActivityIndicatorView

final class AlbumImageFilterViewController: UIViewController {
    
    @IBOutlet weak var albumImageView: UIImageView!
    @IBOutlet weak var albumImageFilterCollectionView: UICollectionView!
    
    @IBOutlet weak var selectFromAlbumButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    private var indicator: NVActivityIndicatorView!
    
    //MARK: - Filters
    
    //선택한 필터 담을 var
    private var selectedFilter: (CIImage) -> CIImage? = FilterFunctions.original(ciImage:)
    
    private let filterManager = FilterDataManager()
    
    //core image
    private var originalCIImage: CIImage?
    
    private var currentImageData: Data?
    
    //MARK: - PHPhicker
    
    private var itemProviders: [NSItemProvider] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.topItem?.title = ""
        
        //extension for collectionView
        albumImageFilterCollectionView.delegate = self
        albumImageFilterCollectionView.dataSource = self
        
        configureUI()
        setDataManager()
        setCollectionView()
    }
    
    private func configureUI() {
        
        indicator = NVActivityIndicatorView(frame: CGRect(origin: CGPoint(x: self.view.bounds.width/2-50, y: albumImageView.bounds.height/2-70), size: CGSize(width: 100, height: 100)), type: .circleStrokeSpin, color: .white, padding: 10)
        
        self.view.addSubview(indicator)
        
        albumImageView.image = UIImage(named: "selectImage")
        albumImageView.contentMode = .scaleAspectFit
        
        selectFromAlbumButton.setImage(UIImage(named: "selectFromAlbum"), for: .normal)
        selectFromAlbumButton.contentMode = .scaleAspectFill
        
        saveButton.setImage(UIImage(named: "saveButton"), for: .normal)
        saveButton.contentMode = .scaleAspectFill
    }
    
    private func setDataManager() {
        print(#function)
        if filterManager.checkIsDiscreteArrayEmpty() {
            filterManager.makeDiscreteFilterData()
        }
        filterManager.makeWholeFilterData()
    }
    
    private func setCollectionView() {
        print(#function)
        albumImageFilterCollectionView.showsHorizontalScrollIndicator = false
    }
    
    @IBAction func selectFromAlbumButtonTapped(_ sender: UIButton) {
        checkAlbumPermission()
    }
    
    private func checkAlbumPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            switch status {
            case .authorized, .limited:
                DispatchQueue.main.async {
                    self.presentPicker()
                }
            default:
                DispatchQueue.main.async {
                    self.showAlbumPermissionAlert()
                }
            }
        }
    }
    
    private func showAlbumPermissionAlert() {
        //카메라 허용 요구
        let okayAction = UIAlertAction(title: "확인", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Ask for Reading Photo from Album", message: "사진첩 접근을 허용해야 사진을 불러올 수 있습니다", preferredStyle: .alert)
            alert.addAction(okayAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func presentPicker() {
        var config = PHPickerConfiguration()
        
        if #available(iOS 16.0, *) {
            config.filter = .any(of: [.images, .livePhotos, .screenshots, .bursts, .depthEffectPhotos, .panoramas])
        } else if #available(iOS 15.0, *) {
            config.filter = .any(of: [.images, .livePhotos, .screenshots, .panoramas])
        } else {
            config.filter = .any(of: [.images, .livePhotos])
        }
        config.selectionLimit = 1
        
        let imagePicker = PHPickerViewController(configuration: config)
        imagePicker.delegate = self
        
        self.present(imagePicker, animated: true)
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            
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
        default:
            DispatchQueue.main.async {
                self.showAlbumPermissionAlert()
            }
        }
    }
    
    private func savePhotoToAlbum(album: PHAssetCollection) {
        
        if let imageData = self.currentImageData {
            
            PHPhotoLibrary.shared().performChanges({
                //request to add image into newly created album
                let assetCreationRequest = PHAssetCreationRequest.forAsset()
                assetCreationRequest.addResource(with: .photo, data: imageData, options: nil)
                
                guard let addAssetRequest = PHAssetCollectionChangeRequest(for: album) else {
                    print("Can't create addAssetRequest")
                    return
                }
                addAssetRequest.addAssets([assetCreationRequest.placeholderForCreatedAsset!] as NSArray)
            })
        } else {
            print("Not available to save filter image data")
        }
    }
    
}

extension AlbumImageFilterViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filterManager.getWholeFilterData().count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = albumImageFilterCollectionView.dequeueReusableCell(withReuseIdentifier: "ImageFilterCollectionCell", for: indexPath) as! AlbumFilterCollectionCell
        
        let filter = filterManager.getWholeFilterData()[indexPath.row]
        cell.albumFilterLabel.text = filter.nameLabel
        cell.albumFilterImageView.image = filter.coverImage
        
        return cell
    }
    
}

extension AlbumImageFilterViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let nameLable = filterManager.getWholeFilterData()[indexPath.row].nameLabel
        
        switch nameLable {
        case "minimal life":
            selectedFilter = FilterFunctions.agfaAPX400(ciImage:)
        case "tumble down":
            selectedFilter = FilterFunctions.evangelion(ciImage:)
        default:
            selectedFilter = FilterFunctions.original(ciImage:)
        }
        
        self.applyFilter()
        
        let event = "filterCell"
        let parameters = [
            "file": #file,
            "function": #function,
            "filterName": nameLable
        ]
        
        Analytics.setUserID("userID = \(1234)")
        Analytics.setUserProperty("ko", forName: "country")
        Analytics.logEvent(AnalyticsEventSelectItem, parameters: nil) // select_item으로 로깅
        Analytics.logEvent(event, parameters: parameters)
        
    }
    
    private func applyFilter() {
        guard let uiImage = albumImageView.image else {
            print("No UIImage for albumImageView")
            return
        }
        
        let imageOrientation = uiImage.imageOrientation
        let imageScale = uiImage.scale
        
        if let original = originalCIImage {
            guard let resultImage = selectedFilter(original) else {
                print("No Filter to be applied for various filters!!!")
                return
            }
            
            let finalImage = UIImage(ciImage: resultImage, scale: imageScale, orientation: imageOrientation)
            
            self.currentImageData = finalImage.jpegData(compressionQuality: 0.7)
            
            DispatchQueue.main.async {
                self.albumImageView.image = finalImage

            }
        } else {
            guard let cgIImage = uiImage.cgImage else {
                print("No CGIImage for UIImage")
                return
            }
            
            let ciImage = CIImage(cgImage: cgIImage)
            
            guard let resultImage = selectedFilter(ciImage) else {
                print("No Filter to be applied")
                return
            }
            
            self.originalCIImage = ciImage
            
            let finalImage = UIImage(ciImage: resultImage, scale: imageScale, orientation: imageOrientation)
            
            self.currentImageData = finalImage.jpegData(compressionQuality: 0.7)
            
            DispatchQueue.main.async {
                self.albumImageView.image = finalImage
            }
        }
    }
    
}

extension AlbumImageFilterViewController: UICollectionViewDelegateFlowLayout {
    //셀 크기
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        print(#function)
        return CGSize(width: 100, height: albumImageFilterCollectionView.frame.height)
    }
    
    //위아래 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        print(#function)
        return 0
    }
    
    //좌우 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        print(#function)
        return 0
    }
}




extension AlbumImageFilterViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        itemProviders = results.map(\.itemProvider)
        
        if !itemProviders.isEmpty {
            displayImage()
        }
    }
    
    private func displayImage() {
        guard let itemProvider = itemProviders.first else { return }
        
        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                guard let self = self, let image = image as? UIImage else { return }
                
                //Check for Multiple Image Selection
                if originalCIImage != nil {
                    self.originalCIImage = nil
                    self.currentImageData = nil
                }
                
                DispatchQueue.main.async {
                    self.albumImageView.image = image
                }
            }
        }
    }
    
}

