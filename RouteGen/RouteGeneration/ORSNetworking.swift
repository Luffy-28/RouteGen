//
//  ORSNetworking.swift
//  RouteGen
//
//  Created by 10167 on 15/7/2025.
//

import Foundation
import CoreLocation


struct ORSGeoJSONExtended: Codable {
    let features: [ORSFeatureExtended]
}

struct ORSFeatureExtended: Codable {
    let geometry: ORSGeometry
    let properties: ORSPropertiesExtended
}

struct ORSGeometry: Codable {
    let coordinates: [[Double]]
}

struct ORSPropertiesExtended: Codable {
    let summary: ORSSummary?
    let segments: [ORSSegmentExtended]
}

struct ORSSummary: Codable {
    let distance: Double
    let duration: Double
}

struct ORSSegmentExtended: Codable {
    let steps: [ORSInstructionStep]
}

struct ORSInstructionStep: Codable {
    let instruction: String
    let distance: Double
    let wayPoints: [Int]

    enum CodingKeys: String, CodingKey {
        case instruction, distance
        case wayPoints = "way_points"
    }
}


final class ORSNetworking {
    static let shared = ORSNetworking()

    private let apiKey: String
    private let endpoint = URL(string: "https://api.openrouteservice.org/v2/directions/foot-walking/geojson")!

    private init() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ORS_API_KEY") as? String,
              !key.isEmpty else {
            fatalError("Missing ORS_API_KEY in Info.plist")
        }
        apiKey = key
    }

   
    func generateRoundTripWithInstructions(
        from start: CLLocationCoordinate2D,
        distance: Double,
        points: Int = 5,
        preferences: RoutePreferences,
        completion: @escaping (Result<ORSRoute, Error>) -> Void
    ) {
        let detail: [String: Any] = [
            "length": distance,
            "points": points,
            "seed": Int.random(in: 1...1_000_000)
        ]

        
        var options: [String: Any] = ["round_trip": detail]
        
        
        var avoidFeatures: [String] = ["ferries"]
        
       
        if preferences.avoidStairs {
            avoidFeatures.append("steps")
        }
        
        options["avoid_features"] = avoidFeatures

      
        var body: [String: Any] = [
            "coordinates": [[start.longitude, start.latitude]],
            "options": options,
            "instructions": true
        ]
        
       
        body["elevation"] = true

        
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("ORS Request Body:\n\(jsonString)")
            }
            req.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }

       
        URLSession.shared.dataTask(with: req) { data, response, error in
            
            if let error = error {
                return completion(.failure(error))
            }
            
            guard let http = response as? HTTPURLResponse,
                  let data = data else {
                let err = NSError(
                    domain: "ORS",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No response or data from ORS"]
                )
                return completion(.failure(err))
            }
            
            let rawBody = String(data: data, encoding: .utf8) ?? "<empty>"
            print("🔄 ORS responded [\(http.statusCode)]: \n\(rawBody)")

            
            guard http.statusCode == 200 else {
                let err = NSError(
                    domain: "ORS",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "ORS HTTP \(http.statusCode)"]
                )
                return completion(.failure(err))
            }

           
            do {
                let geo = try JSONDecoder().decode(ORSGeoJSONExtended.self, from: data)
                let route = ORSRoute(geoJSON: geo)
                completion(.success(route))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
