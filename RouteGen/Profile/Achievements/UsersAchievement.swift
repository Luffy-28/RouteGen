//
//  UsersAchievement.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 4/8/2025.
//

import Foundation
import FirebaseFirestore

class UsersAchievement {
    var userId: String
    var unlockedAchievementIds: [String]
    
    // Initializer
    init(userId: String, unlockedAchievementIds: [String]) {
        self.userId = userId
        self.unlockedAchievementIds = unlockedAchievementIds
    }
    
    // Init from Firestore dictionary
    convenience init(userId: String, dictionary: [String: Any]) {
        let unlockedAchievementIds = dictionary["achievementIds"] as? [String] ?? []
        self.init(userId: userId, unlockedAchievementIds: unlockedAchievementIds)
    }
    
    // Convert to dictionary (if saving)
    func toDictionary() -> [String: Any] {
        return [
            "achievementIds": unlockedAchievementIds
        ]
    }
}
