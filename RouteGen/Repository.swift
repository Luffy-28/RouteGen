import Foundation
import FirebaseFirestore
import FirebaseAuth
import HealthKit

class Repository {
    
    let db = Firestore.firestore()
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    
    // MARK: - USER CRUD
    
    func addUser(withData user: User, completion: @escaping (Bool) -> Void) {
        let dictionary: [String: Any] = [
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "address": user.address,
            "photo": user.photo
        ]
        
        db.collection("User").document(user.id).setData(dictionary) { error in
            if let error = error {
                print("Error adding user: \(error.localizedDescription)")
                completion(false)
            } else {
                print("User added: \(user.email)")
                completion(true)
            }
        }
    }
    
    func updateUser(withData user: User, completion: @escaping (Bool) -> Void) {
        var dictionary: [String: Any] = [
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "address": user.address,
            "photo": user.photo
        ]
        
        // Only add emergencyContact if it has a value
        if let emergencyContact = user.emergencyContact, !emergencyContact.isEmpty {
            dictionary["emergencyContact"] = emergencyContact
        }
        
        db.collection("User").document(user.id).updateData(dictionary) { error in
            if let error = error {
                print("Error updating user: \(error.localizedDescription)")
                completion(false)
            } else {
                print("User updated successfully")
                completion(true)
            }
        }
    }
    
    func findUserInfo(for userId: String, completion: @escaping (User?) -> ()) {
        let userRef = db.collection("User").document(userId)
        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error getting user info: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                print("User document does not exist")
                completion(nil)
                return
            }

            let user = User(id: document.documentID, dictionary: data)
            completion(user)
        }
    }
    //MARK: - fetch suggested user
    
    func fetchSuggestedUsers(completion: @escaping ([User]) -> Void) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            print("❌ No logged in user")
            completion([])
            return
        }

        let followsRef = db.collection("Follow")  // singular, per your collection
        let usersRef = db.collection("User")

        // Step 1: Fetch UIDs of already followed users
        followsRef.whereField("followedById", isEqualTo: currentUID).getDocuments { followSnapshot, error in
            if let error = error {
                print("❌ Error fetching follows: \(error.localizedDescription)")
                completion([])
                return
            }

            let followedUIDs = followSnapshot?.documents.compactMap {
                $0.data()["followingId"] as? String
            } ?? []

            // Step 2: Fetch all users
            usersRef.getDocuments { userSnapshot, error in
                if let error = error {
                    print("❌ Error fetching users: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let docs = userSnapshot?.documents else {
                    completion([])
                    return
                }

                // Step 3: Filter out current user and followed users
                let suggestedUsers: [User] = docs.compactMap { doc in
                    let uid = doc.documentID
                    if uid == currentUID || followedUIDs.contains(uid) {
                        return nil
                    }

                    let data = doc.data()
                    return User(
                        id: uid,
                        name: data["name"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        phone: data["phone"] as? String ?? "",
                        address: data["address"] as? String ?? "",
                        photo: data["photo"] as? String ?? ""
                    )
                }

                print("✅ Fetched suggested users count: \(suggestedUsers.count)")
                completion(suggestedUsers)
            }
        }
    }


    
    
    //MARK: -achievements
    func fetchAllAchievements(fromCollection name: String, completion: @escaping ([Achievement]) -> ()){
        var achievements = [Achievement]()
        _ = db.collection(name).addSnapshotListener { snapshot, error in
            if let document = snapshot?.documents {
                achievements = document.compactMap({ doc -> Achievement? in
                let data = doc.data()
                    return Achievement(id: doc.documentID, dictionary: data)
                })
//                for achievement in achievements {
//                    print(achievement.toString())
//                }
                completion(achievements)
            }else {
                print("error fetching documents \(error!.localizedDescription)")
                return
            }
        }
        
        
        
    }


    func saveOrUpdateGoal(withData goal: Goal, completion: @escaping (Bool) -> Void) {
            let goalRef = db.collection("User").document(goal.id)
                .collection("metrics").document("goals")

            goalRef.getDocument { (document, error) in
                if let error = error {
                    print("Failed to fetch document: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                let data: [String: Any] = [
                    "dailySteps": goal.dailySteps,
                    "dailyCalories": goal.dailyCalories,
                    "dailyDistance": goal.dailyDistanceKm
                ]

                if document?.exists == true {
                    // Update existing document
                    goalRef.updateData(data) { error in
                        if let error = error {
                            print("Error updating goal: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            print("Goal successfully updated.")
                            completion(true)
                        }
                    }
                } else {
                    // Set new document
                    goalRef.setData(data) { error in
                        if let error = error {
                            print("Error adding goal: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            print("Goal successfully added.")
                            completion(true)
                        }
                    }
                }
            }
        }

       
    func fetchGoal(forUserId userId: String, completion: @escaping (Goal?) -> Void) {
        let ref = db.collection("User").document(userId)
            .collection("metrics").document("goals")

        ref.getDocument { (document, error) in
            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
            }

            guard let document = document, document.exists, let data = document.data() else {
                print("Document not found or empty at path: User/\(userId)/metrics/goals")
                completion(nil)
                return
            }

            print("Goal data: \(data)")
            let goals = Goal(id: userId, dictionary: data)
            completion(goals)
        }
    }




    func fetchhealthData(forUserId userId: String, completion: @escaping (HealthMetrics?) -> Void) {
        let ref = db.collection("User").document(userId)
            .collection("metrics").document("healthMetrics")

        ref.getDocument { (document, error) in
            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
            }

            guard let document = document, document.exists, let data = document.data() else {
                print("Document not found or empty at path: User/\(userId)/metrics/healthMetrics")
                completion(nil)
                return
            }

            print("HealthMetrics data: \(data)")
            let healthmetrics = HealthMetrics(id: userId, dictionary: data)
            completion(healthmetrics)
        }
    }
    
    //MARK: - followUser
    
    func followUser(followerUid: String, followingUid: String, completion: @escaping (Bool) -> Void) {
        
        let followData: [String: Any] = [
            "followerUid": followerUid,
            "followingUid": followingUid,
            "followedAt": Timestamp(date: Date())
        ]
        
        db.collection("Follow").addDocument(data: followData) { error in
            if let error = error {
                print("❌ Error following user: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Followed user successfully")
                completion(true)
            }
        }
    }
    
    //
    //MARK: -achievements for global.
    func fetchAllGlobalAchievements(fromCollection name: String, completion: @escaping ([Achievements]) -> Void) {
        db.collection(name).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching achievements: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No achievements found.")
                completion([])
                return
            }
            
            let achievements = documents.map { doc -> Achievements in
                let data = doc.data()
                return Achievements(id: doc.documentID, dictionary: data)
            }
            
            // Debug log
            achievements.forEach { print($0.toString()) }
            
            completion(achievements)
        }
    }

    ////MARK: -achievements for comparing with users achievements.
    func fetchUnlockedAchievements(forUser userId: String, completion: @escaping ([String]) -> Void) {
        db.collection("User")
            .document(userId)
            .collection("achievements")
            .document("unlocked")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching unlocked achievements: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let data = snapshot?.data() else {
                    print("No unlocked achievements found")
                    completion([])
                    return
                }

                print("Unlocked data: \(data)")

                if let achievementIds = data["achievementIds"] as? [String] {
                    completion(achievementIds)
                } else {
                    print("achievementIds not found or wrong type")
                    completion([])
                }
            }
    }
    
}


