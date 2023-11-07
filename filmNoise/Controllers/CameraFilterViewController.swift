//
//  CameraFilterViewController.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/07.
//

import UIKit
import GoogleMobileAds

final class CameraFilterViewController: UIViewController {

    @IBOutlet weak var filterImageView: UIImageView!
    @IBOutlet weak var filterDescription: UILabel!
    @IBOutlet weak var filterTip: UITextView!

    private var bannerView: GADBannerView!
    
    var filterData: FilterData?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureUI()
        addBannerAd()
    }
    
    private func configureUI() {
        filterImageView.image = filterData?.coverImage
        filterDescription.text = filterData?.descriptionLabel
        filterTip.text = filterData?.tipLabel
        filterTip.textContainer.lineBreakMode = .byWordWrapping
    }

    private func addBannerAd() {
        //배너 사이즈 설정
        bannerView = GADBannerView(adSize: GADAdSizeBanner)
        
        //배너의 아이디 설정
        bannerView.adUnitID = APIKey.key
        bannerView.rootViewController = self
     
        //광고 로드
        bannerView.load(GADRequest())
        
        //delegate 설정
        bannerView.delegate = self
    }
    
    deinit {
        print("FilterVC released from memory")
    }
    
}

//MARK: - Delegate for bannerView

extension CameraFilterViewController: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        
        //default auto-layout 해제하기
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        //rootView에 배너 추가
        view.addSubview(bannerView)
        //앵커 설정, constraint 설정
        NSLayoutConstraint.activate([
            bannerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            bannerView.widthAnchor.constraint(equalToConstant: 320),
            bannerView.heightAnchor.constraint(equalToConstant: 50),
            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        print("bannerViewDidReceiveAd")
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
      print("bannerView:didFailToReceiveAdWithError: \(error.localizedDescription)")
    }

    func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
      print("bannerViewDidRecordImpression")
    }

    func bannerViewWillPresentScreen(_ bannerView: GADBannerView) {
      print("bannerViewWillPresentScreen")
    }

    func bannerViewWillDismissScreen(_ bannerView: GADBannerView) {
      print("bannerViewWillDIsmissScreen")
    }

    func bannerViewDidDismissScreen(_ bannerView: GADBannerView) {
      print("bannerViewDidDismissScreen")
    }
}
