//
//  CustomTableViewCell.swift
//  filmNoise
//
//  Created by Heedon on 2023/02/07.
//

import UIKit

final class CustomTableViewCell: UITableViewCell {

    @IBOutlet weak var filterImageView: UIImageView!
    @IBOutlet weak var filterLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    
    
}
