//
//  RunDataManager.swift
//  RouteGen
//
//  Created by 10167 on 29/7/2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class RunDataManager {
    
    static let shared = RunDataManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Save Run
    func saveRun(_ run: Run, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(RunDataError.noUserLoggedIn))
            return
        }
        
        print("DEBUG - Saving run for userId: \(userId)")
          print("DEBUG - Run data: \(run.asDictionary)")
        
        let runRef = db.collection("User").document(userId).collection("runs").document(run.id)
        
        runRef.setData(run.asDictionary) { error in
            if let error = error {
                print("DEBUG - Firebase save error: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("DEBUG - Run saved successfully with ID: \(run.id)")
                completion(.success(run.id))
            }
        }
    }
    
    // MARK: - Fetch All Runs for User
    func fetchRuns(completion: @escaping (Result<[Run], Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("fetchRuns - no user logged in")
            completion(.failure(RunDataError.noUserLoggedIn))
            return
        }
        print("fetchRuns - querying for userId: \(userId)")
        
        let runsRef = db
          .collection("User")
          .document(userId)
          .collection("runs")
          .order(by: "startTime", descending: true)
        
        runsRef.getDocuments { snapshot, error in
            if let error = error {
                print("fetchRuns - Firestore error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            let docs = snapshot?.documents ?? []
            print(" fetchRuns - document count: \(docs.count)")
            for doc in docs {
                print("fetchRuns - docID: \(doc.documentID), data: \(doc.data())")
            }
            
            let runs = docs.compactMap { document -> Run? in
                let data = document.data()
                
                guard let startTimestamp   = data["startTime"]   as? Timestamp,
                      let endTimestamp     = data["endTime"]     as? Timestamp,
                      let duration         = data["duration"]    as? TimeInterval,
                      let distance         = data["distance"]    as? Double,
                      let avgPace          = data["avgpace"]     as? String,
                      let createdTimestamp = data["createdAt"]   as? Timestamp else {
                    print("⚠️ fetchRuns - skipping doc \(document.documentID) due to missing fields")
                    return nil
                }
                
                return Run(
                    id: document.documentID,
                    userId: userId,
                    startTime: startTimestamp.dateValue(),
                    endTime: endTimestamp.dateValue(),
                    duration: duration,
                    distance: distance,
                    avgpace: avgPace,
                    createdAt: createdTimestamp.dateValue()
                )
            }
            
            print("fetchRuns - parsed runs count: \(runs.count)")
            completion(.success(runs))
        }
    }

    
    
    func deleteRun(runId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(RunDataError.noUserLoggedIn))
            return
        }
        
        db.collection("User").document(userId).collection("runs").document(runId).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}


enum RunDataError: LocalizedError {
    case noUserLoggedIn
    
    var errorDescription: String? {
        switch self {
        case .noUserLoggedIn:
            return "No user is currently logged in"
        }
    }
}
