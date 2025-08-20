//
//  Goal.swift
//  fbAuth
//
//  Created by shankar singh on 21/05/2025.
//

import Foundation
import FirebaseFirestore

class Goal {
    var id: String!
    var dailySteps: Int
    var dailyCalories: Int
    var dailyDistanceKm: Double

    init(id: String,
         dailySteps: Int,
         dailyCalories: Int,
         dailyDistanceKm: Double) {
        self.id = id
        self.dailySteps = dailySteps
        self.dailyCalories = dailyCalories
        self.dailyDistanceKm = dailyDistanceKm
    }

    convenience init(id: String, dictionary: [String: Any]) {
        let steps = dictionary["dailySteps"] as? Int ?? 0
        let calories = dictionary["dailyCalories"] as? Int ?? 0
        let distance = dictionary["dailyDistanceKm"] as? Double ?? 0.0
        self.init(id: id,
                  dailySteps: steps,
                  dailyCalories: calories,
                  dailyDistanceKm: distance)
    }

    func toDictionary() -> [String: Any] {
        return [
            "dailySteps": dailySteps,
            "dailyCalories": dailyCalories,
            "dailyDistanceKm": dailyDistanceKm
        ]
    }

    func toString() -> String {
        return "dailySteps: \(dailySteps)\n" +
               "dailyCalories: \(dailyCalories)\n" +
               "dailyDistanceKm: \(dailyDistanceKm)"
    }
}

