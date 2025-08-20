//
//  ProfileStats.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 28/6/2025.
//

import Foundation
import FirebaseFirestore

class ProfileStats {
    var id: String!
    var distanceCovered: Double
    var friendsCount: Int
    var routeGenerated: Int
    var runCounts: Int
    var totalTimeTaken: Int
    
    //default initializer
    init(distanceCovered: Double, friendsCount: Int, routeGenerated: Int, runCounts: Int, totalTimeTaken: Int) {
        self.distanceCovered = distanceCovered
        self.friendsCount = friendsCount
        self.routeGenerated = routeGenerated
        self.runCounts = runCounts
        self.totalTimeTaken = totalTimeTaken
    }
    
    convenience init(id: String, distanceCovered: Double, friendsCount: Int, routeGenerated: Int, runCounts: Int, totalTimeTaken: Int)
    {
        self.init(
            distanceCovered: distanceCovered,
            friendsCount: friendsCount,
            routeGenerated: routeGenerated,
            runCounts: runCounts,
            totalTimeTaken: totalTimeTaken)
        self.id = id
    }
    //This initializer will be used to fetch achievements from the database.
     convenience init(id: String)
    {
        self.init(distanceCovered: 0.0,
                  friendsCount: 0,
                  routeGenerated: 0,
                  runCounts: 0,
                  totalTimeTaken: 0)
    }
    convenience init(id: String, dictionary : [String:Any]){
        self.init(id: id,
                  distanceCovered: dictionary["distanceCovered"] as! Double,
                  friendsCount: dictionary["friendsCount"] as! Int,
                  routeGenerated: dictionary["routeGenerated"] as! Int,
                  runCounts: dictionary["runCounts"] as! Int,
                  totalTimeTaken: dictionary["totalTimeTaken"] as! Int
        )
    }
    
}
