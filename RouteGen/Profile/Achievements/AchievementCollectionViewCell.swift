//
//  AchievementCollectionViewCell.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 3/8/2025.
//

import UIKit
import FirebaseFirestore

class AchievementCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var badgeImageView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
           super.awakeFromNib()
           
           // Style the cell
           contentView.layer.cornerRadius = 12
           contentView.layer.borderWidth = 1
           contentView.layer.borderColor = UIColor.systemGray4.cgColor
           contentView.clipsToBounds = true
       }
    
    func configure(with achievements: Achievements, unlocked: Bool) {
        print("badgeImageView: \(badgeImageView != nil), titleLabel: \(titleLabel != nil), descriptionLabel: \(descriptionLabel != nil)")
           // Debug check
           if badgeImageView == nil || titleLabel == nil || descriptionLabel == nil {
               print("❌ Outlets not connected in storyboard")
               return
           }

           titleLabel.text = achievements.name
           descriptionLabel.text = achievements.description
           
        // Use trophy icons
            let symbolName = unlocked ? "trophy.fill" : "trophy"
            badgeImageView.image = UIImage(systemName: symbolName)
            badgeImageView.tintColor = unlocked ? .systemYellow : .systemGray3
       }

   }
