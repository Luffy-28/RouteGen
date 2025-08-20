//
//  CarouselCell.swift
//  RouteGen
//
//  Created by 10167 on 31/7/2025.
//

import Foundation
import UIKit

class CarouselCell: UICollectionViewCell {
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func prepareForReuse() {
            super.prepareForReuse()
            
            imageView.kf.cancelDownloadTask()
            titleLabel.text = ""
        }
    
}
