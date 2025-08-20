//
//  FollowFriends.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 16/7/2025.
//

import Foundation
import FirebaseFirestore

class Follow {
    var id: String!
    var followerUid: String = ""
    var followingUid: String = ""
    var followedAt: Timestamp!
    
    init(id: String!, followerUid: String, followingUid: String, followedAt: Timestamp? = nil) {
        self.id = id
        self.followerUid = followerUid
        self.followingUid = followingUid
        self.followedAt = followedAt
    }
    
    convenience init?(document: DocumentSnapshot) {
        let data = document.data() ?? [:]

        guard let followerUid = data["followedById"] as? String,
              let followingUid = data["followingId"] as? String,
              let followedAt = data["followedAt"] as? Timestamp else {
            print("❌ Follow data missing or invalid")
            return nil
        }

        self.init(id: document.documentID, followerUid: followerUid, followingUid: followingUid, followedAt: followedAt)
    }

    func toDictionary() -> [String: Any] {
        return [
            "followedById": followerUid,
            "followingId": followingUid,
            "followedAt": followedAt ?? Timestamp(date: Date())
        ]
    }
}
