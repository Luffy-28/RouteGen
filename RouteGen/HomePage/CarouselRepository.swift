//
//  CarouselRepository.swift
//  RouteGen
//
//  Created by 10167 on 1/8/2025.
//

import Foundation
import FirebaseFirestore

class CarouselRepository {
    private let db = Firestore.firestore()
    private let collectionName = "carouselItems"
    
    
    func fetchCarouselItems(completion: @escaping (Result<[CaroselItem], Error>) -> Void) {
        print("🔄 Starting to fetch carousel items from collection: \(collectionName)")
        
        db.collection(collectionName)
            .whereField("enabled", isEqualTo: true)
            .order(by: "order")
            .getDocuments() { snapshot, error in
                
                if let error = error {
                    print("Firebase error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents found in snapshot")
                    completion(.success([]))
                    return
                }
                
                print("Found \(documents.count) documents in Firestore")
                
                let items = documents.compactMap { document -> CaroselItem? in
                    let data = document.data()
                    print("Processing document \(document.documentID): \(data)")
                    
                    
                    guard let title = data["title"] as? String else {
                        print(" Missing or invalid 'title' field in document \(document.documentID)")
                        return nil
                    }
                    
                    guard let imageURLString = data["imageURL"] as? String else {
                        print("Missing or invalid 'imageURL' field in document \(document.documentID)")
                        return nil
                    }
                    
                    guard let linkURLString = data["linkURL"] as? String else {
                        print("Missing or invalid 'linkURL' field in document \(document.documentID)")
                        return nil
                    }
                    
                    guard let imageURL = URL(string: imageURLString) else {
                        print("Invalid imageURL format: '\(imageURLString)' in document \(document.documentID)")
                        return nil
                    }
                    
                    guard let linkURL = URL(string: linkURLString) else {
                        print("Invalid linkURL format: '\(linkURLString)' in document \(document.documentID)")
                        return nil
                    }
                    
                    print("Successfully parsed document \(document.documentID): title='\(title)'")
                    return CaroselItem(title: title, imageURL: imageURL, linkURL: linkURL)
                }
                
                print("Successfully created \(items.count) CaroselItem objects")
                completion(.success(items))
            }
    }
    
   
    func observeCarouselItems(completion: @escaping (Result<[CaroselItem], Error>) -> Void) -> ListenerRegistration {
        print("Setting up real-time listener for collection: \(collectionName)")
        
        return db.collection(collectionName)
            .whereField("enabled", isEqualTo: true)
            .order(by: "order")
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    print(" Real-time listener error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents found in real-time snapshot")
                    completion(.success([]))
                    return
                }
                
                print("Real-time listener found \(documents.count) documents")
                
                let items = documents.compactMap { document -> CaroselItem? in
                    let data = document.data()
                    print("Real-time processing document \(document.documentID): \(data)")
                    
                    // Check each field individually
                    guard let title = data["title"] as? String else {
                        print("Missing or invalid 'title' field in document \(document.documentID)")
                        return nil
                    }
                    
                    guard let imageURLString = data["imageURL"] as? String else {
                        print("Missing or invalid 'imageURL' field in document \(document.documentID)")
                        return nil
                    }
                    
                    guard let linkURLString = data["linkURL"] as? String else {
                        print("Missing or invalid 'linkURL' field in document \(document.documentID)")
                        return nil
                    }
                    
                    guard let imageURL = URL(string: imageURLString) else {
                        print("Invalid imageURL format: '\(imageURLString)' in document \(document.documentID)")
                        return nil
                    }
                    
                    guard let linkURL = URL(string: linkURLString) else {
                        print("Invalid linkURL format: '\(linkURLString)' in document \(document.documentID)")
                        return nil
                    }
                    
                    print("Successfully parsed document \(document.documentID): title='\(title)'")
                    return CaroselItem(title: title, imageURL: imageURL, linkURL: linkURL)
                }
                
                print("Real-time listener created \(items.count) CaroselItem objects")
                completion(.success(items))
            }
    }
    
    func addCarouselItem(title: String, imageURL: String, linkURL: String, order: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let data: [String: Any] = [
            "title": title,
            "imageURL": imageURL,
            "linkURL": linkURL,
            "order": order,
            "enabled": true
        ]
        
        db.collection(collectionName).addDocument(data: data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func updateCarouselItem(documentID: String, title: String? = nil, imageURL: String? = nil, linkURL: String? = nil, order: Int? = nil, enabled: Bool? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        var data: [String: Any] = [:]
        
        if let title = title { data["title"] = title }
        if let imageURL = imageURL { data["imageURL"] = imageURL }
        if let linkURL = linkURL { data["linkURL"] = linkURL }
        if let order = order { data["order"] = order }
        if let enabled = enabled { data["enabled"] = enabled }
        
        db.collection(collectionName).document(documentID).updateData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func deleteCarouselItem(documentID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(collectionName).document(documentID).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
