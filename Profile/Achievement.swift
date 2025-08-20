//
//  Achievements.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 28/6/2025.
//

import Foundation

class Achievement {
    
    var id: String!
    var achievementTitle: String
    var description: String
    var currentPoints: Int
    var totalPoints: Int
    var imageURL: String
    
    //default initializer
    init(achievementTitle: String, description: String, currentPoints: Int, totalPoints: Int, imageURL: String) {
        self.achievementTitle = achievementTitle
        self.description = description
        self.currentPoints = currentPoints
        self.totalPoints = totalPoints
        self.imageURL = imageURL
    }
    convenience init(id: String, achievementTitle: String, description: String, currentPoints: Int, totalPoints: Int, imageURL: String) {
        self.init(
            achievementTitle: achievementTitle,
            description: description,
            currentPoints: currentPoints,
            totalPoints: totalPoints,
            imageURL: imageURL)
        self.id = id
    }
    
    convenience init( id: String){
        self.init(achievementTitle: "",
                  description: "",
                  currentPoints: 0,
                  totalPoints: 0,
                  imageURL: "")
    }
    convenience init(id: String, dictionary : [String:Any]) {
        self.init(id: id,
                  achievementTitle: dictionary["achievementTitle"] as! String,
                  description: dictionary["description"] as? String ?? "",
                  currentPoints: dictionary["currentPoints"] as? Int ?? 0,
                  totalPoints: dictionary["totalPoints"] as? Int ?? 0,
                  imageURL: dictionary["imageURL"] as? String ?? ""
                  
        )
        
    }
    func toString() -> String {
        return "\(achievementTitle)"
    }
    
}
