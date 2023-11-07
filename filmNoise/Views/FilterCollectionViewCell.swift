//
//  FilterCollectionViewCell.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/15.
//

import UIKit

final class FilterCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var filterImageView: UIImageView!
    @IBOutlet weak var filterLabel: UILabel!
    
    fileprivate let titleNormalColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    fileprivate let titleSelectedColor = UIColor(named: "textColor")

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        if isSelected {
            filterLabel.textColor = titleSelectedColor
        } else {
            filterLabel.textColor = titleNormalColor
        }
    }
    
    
    //선택 시, 레이블과 커버사진 하이라이트 효과 주기
    override var isSelected: Bool {
        didSet {
            filterLabel.textColor = isSelected ? titleSelectedColor: titleNormalColor
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut, animations: {
                    self.alpha = 0.96
                    self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                }) { finish in
                    self.alpha = 1.0
                    self.transform = .identity
                }
            }
        }
    }
        
}
