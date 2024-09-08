//
//  AlbumFilterCollectionCell.swift
//  filmNoise
//
//  Created by Heedon on 9/8/24.
//

import UIKit

final class AlbumFilterCollectionCell: UICollectionViewCell {
    
    @IBOutlet weak var albumFilterImageView: UIImageView!
    @IBOutlet weak var albumFilterLabel: UILabel!

    fileprivate let titleNormalColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    fileprivate let titleSelectedColor = UIColor(named: "textColor")

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        if isSelected {
            albumFilterLabel.textColor = titleSelectedColor
        } else {
            albumFilterLabel.textColor = titleNormalColor
        }
    }

    override var isSelected: Bool {
        didSet {
            albumFilterLabel.textColor = isSelected ? titleSelectedColor: titleNormalColor
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
