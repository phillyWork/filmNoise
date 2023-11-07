//
//  FilterDataManager.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/11.
//

import UIKit

final class FilterDataManager {
    
    fileprivate struct FilterDescription {
        //Agfa APX 400
        static let agfaName = "minimal life"
        static let agfaImage = "agfa"
        static let agfaDescription = "inspired by APX 400"
        static let agfaTip = "낮은 대비와 그레인으로 여러 상황에 활용할 수 있습니다. \n정적인 느낌의 사진을 시도해보세요."
        //Evangelion
        static let evaName = "tumble down"
        static let evaImage = "eva"
        static let evaDescription = "전하지 못한 진심을, 너에게"
        static let evaTip = "실내에서 활용할 시, 암부의 푸른 보라색이 잘 나타납니다. \n차분한 가운데 오묘한 분위기를 기록해보세요."
    }
    
    //old film과 theme filter 구분하기
    private let sections = ["Old Films", "Theme Filters"]
    
    private var oldFilmDataArray = [FilterData]()
    private var themeFilterDataArray = [FilterData]()
    private var filterArray = [FilterData]()

    //실제 필터 데이터들 instance로 배열에 추가하기
    func makeDiscreteFilterData() {
        oldFilmDataArray = [
            FilterData(coverImage: UIImage(named: FilterDescription.agfaImage), nameLabel: FilterDescription.agfaName, descriptionLabel: FilterDescription.agfaDescription, tipLabel: FilterDescription.agfaTip),
        ]
        
        themeFilterDataArray = [
            FilterData(coverImage: UIImage(named: FilterDescription.evaImage), nameLabel: FilterDescription.evaName, descriptionLabel: FilterDescription.evaDescription, tipLabel: FilterDescription.evaTip),
        ]
    }
    
    func makeWholeFilterData() {
        filterArray.append(FilterData(nameLabel: "original", descriptionLabel: "", tipLabel: ""))
        filterArray += oldFilmDataArray
        filterArray += themeFilterDataArray
    }
    
    func checkIsDiscreteArrayEmpty() -> Bool {
        return oldFilmDataArray.isEmpty
    }
    
    func getSections() -> [String] {
        return sections
    }

    func getOldFilmData() -> [FilterData] {
        return oldFilmDataArray
    }
    
    func getThemeFilterData() -> [FilterData] {
        return themeFilterDataArray
    }
    
    func getWholeFilterData() -> [FilterData] {
        return filterArray
    }
    
}
