//
//  Run.swift
//  RouteGen
//
//  Created by 10167 on 29/7/2025.
//

import Foundation
import FirebaseFirestore

struct Run {
    let id: String
    let userId: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let distance: Double
    let avgpace: String
    let createdAt: Date
    
    var asDictionary: [String: Any] {
        return [
            "userId": userId,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "duration": duration,
            "distance": distance,
            "avgpace": avgpace,
            "createdAt": Timestamp(date: createdAt)
            ]
            }
    }



