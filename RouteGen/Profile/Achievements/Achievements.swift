//
//  Achievements.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 3/8/2025.
//
import Foundation

//for global achievement
class Achievements {
    
    var id: String!
    var name: String
    var description: String
    var points: Int
    var badgeImageURL: String
    var requirementType: String
    var requirementCount: Int
    
    // Default initializer
    init(name: String,
         description: String,
         points: Int,
         badgeImageURL: String,
         requirementType: String,
         requirementCount: Int) {
        
        self.name = name
        self.description = description
        self.points = points
        self.badgeImageURL = badgeImageURL
        self.requirementType = requirementType
        self.requirementCount = requirementCount
    }
    
    // Convenience initializer with ID
    convenience init(id: String,
                     name: String,
                     description: String,
                     points: Int,
                     badgeImageURL: String,
                     requirementType: String,
                     requirementCount: Int) {
        
        self.init(
            name: name,
            description: description,
            points: points,
            badgeImageURL: badgeImageURL,
            requirementType: requirementType,
            requirementCount: requirementCount
        )
        self.id = id
    }
    
    // Init with only ID (placeholder)
    convenience init(id: String) {
        self.init(
            name: "",
            description: "",
            points: 0,
            badgeImageURL: "",
            requirementType: "",
            requirementCount: 0
        )
        self.id = id
    }
    
    // Init from Firestore dictionary
    convenience init(id: String, dictionary: [String: Any]) {
        let name = dictionary["name"] as? String ?? ""
        let description = dictionary["description"] as? String ?? ""
        let points = dictionary["points"] as? Int ?? 0
        let badgeImageURL = dictionary["badgeImageURL"] as? String ?? ""
        
        // Requirements is a map
        let requirements = dictionary["requirements"] as? [String: Any] ?? [:]
        let requirementType = requirements["type"] as? String ?? ""
        let requirementCount = requirements["count"] as? Int ?? 0
        
        self.init(
            id: id,
            name: name,
            description: description,
            points: points,
            badgeImageURL: badgeImageURL,
            requirementType: requirementType,
            requirementCount: requirementCount
        )
    }
    
    func toString() -> String {
        return "\(name) - \(description)"
    }
}

