//
//  ProfileAchievementTVCell.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 24/6/2025.
//

import UIKit


class ProfileAchievementTVCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var progressviewSlider: UIProgressView!
    
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var progressPointsLabel: UILabel!
    
    var service = Repository()
    


    func configure(with achievement: Achievement) {
        titleLabel.text = achievement.achievementTitle
        detailsLabel.text = achievement.description
        progressPointsLabel.text = "\(achievement.currentPoints)/\(achievement.totalPoints)"
        //progressviewSlider.progress = Float(achievement.currentPoints) / Float(achievement.totalPoints)
    
    }
   }
