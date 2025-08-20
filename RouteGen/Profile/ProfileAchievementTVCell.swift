import UIKit
import GameKit

class ProfileAchievementTVCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var progressviewSlider: UIProgressView!
    @IBOutlet weak var detailsLabel: UILabel!
    @IBOutlet weak var progressPointsLabel: UILabel!

    func configure(with achievement: GKAchievement, description: GKAchievementDescription?) {
        // Title
        titleLabel.text = description?.title ?? achievement.identifier ?? "Unknown"

        // Details: achieved vs unachieved description
        if achievement.isCompleted {
            detailsLabel.text = description?.achievedDescription ?? "Completed!"
        } else {
            detailsLabel.text = description?.unachievedDescription ?? "Not completed yet"
        }

        // Percent complete
        let percent = Int(achievement.percentComplete)
        progressPointsLabel.text = "\(percent)%"

        // Progress bar
        progressviewSlider.progress = Float(achievement.percentComplete / 100.0)
    }
}
