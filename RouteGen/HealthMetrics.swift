//
//  HealthMetrics.swift
//  RouteGen
//
//  Created by Shankar Singh on 6/7/2025.
//


//
//  HealthMetrics.swift
//  fbAuth
//
//  Created by shankar singh on 21/05/2025.
//

import Foundation
import FirebaseFirestore

class HealthMetrics {
    var id: String!
    var timestamp: Date
    var steps: Int
    var calories: Int
    var distanceKm: Double
    var heartRate: Int

    init(id: String,
         timestamp: Date,
         steps: Int,
         calories: Int,
         distanceKm: Double,
         heartRate: Int) {
        self.id = id
        self.timestamp = timestamp
        self.steps = steps
        self.calories = calories
        self.distanceKm = distanceKm
        self.heartRate = heartRate
    }

    convenience init(id: String, dictionary: [String: Any]) {
        let ts = (dictionary["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let steps = dictionary["steps"] as? Int ?? 0
        let calories = dictionary["calories"] as? Int ?? 0
        let distance = dictionary["distanceKm"] as? Double ?? 0.0
        let hr = dictionary["heartRate"] as? Int ?? 0
        self.init(id: id,
                  timestamp: ts,
                  steps: steps,
                  calories: calories,
                  distanceKm: distance,
                  heartRate: hr)
    }

    func toDictionary() -> [String: Any] {
        return [
            "timestamp": Timestamp(date: timestamp),
            "steps": steps,
            "calories": calories,
            "distanceKm": distanceKm,
            "heartRate": heartRate
        ]
    }

    func toString() -> String {
        return "timestamp: \(timestamp)\n" +
               "steps: \(steps)\n" +
               "calories: \(calories)\n" +
               "distanceKm: \(distanceKm)\n" +
               "heartRate: \(heartRate)"
    }
}
