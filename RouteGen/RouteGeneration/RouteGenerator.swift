//
//  RouteGenerator.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 4/7/2025.
import CoreLocation
import MapKit


class RouteGenerator {
    
   
    func generateDistanceBasedLoopWithInstructions(
        from userLocation: CLLocationCoordinate2D,
        targetDistanceKm: Double,
        preferences: RoutePreferences,
        completion: @escaping (Result<ORSRoute, Error>) -> Void
    ) {
        let meters = targetDistanceKm * 1_000
        
       
        generateWithRetry(
            from: userLocation,
            distance: meters,
            targetDistanceKm: targetDistanceKm,
            preferences: preferences,
            completion: completion
        )
    }
    
   
    
    private func generateWithRetry(
        from userLocation: CLLocationCoordinate2D,
        distance: Double,
        targetDistanceKm: Double,
        preferences: RoutePreferences,
        completion: @escaping (Result<ORSRoute, Error>) -> Void
    ) {
        var attempts = 0
        let maxAttempts = 5
        var currentPoints = 5
        var bestRoute: ORSRoute?
        var bestValidation: ValidationResult?
        
        func attemptGeneration() {
            attempts += 1
            print("🔄 Attempt \(attempts)/\(maxAttempts) with \(currentPoints) points")
            
           
            let seedAttempts = preferences.urbanExplorer ? 3 : 1
            
            generateOptimalRoute(from: userLocation,distance: distance,points: currentPoints,preferences: preferences,attempts: seedAttempts) { [weak self] result in
                switch result {
                case .success(let route):
                    let validation = RouteValidator.shared.validateRoute(
                        route,
                        requestedDistanceKm: targetDistanceKm
                    )
                    
                    print("Distance: requested=\(targetDistanceKm)km, got=\(validation.actualDistance)km, valid=\(validation.isValid)")
                    
                    // Keep track of best route so far
                    if bestRoute == nil ||
                       (bestValidation != nil && validation.percentageOff < bestValidation!.percentageOff) {
                        bestRoute = route
                        bestValidation = validation
                    }
                    
                   
                    if validation.isValid {
                        print("Found valid route!")
                        completion(.success(route))
                        return
                    }
                    
                   
                    if attempts < maxAttempts {
                        let retryParams = RouteValidator.shared.suggestRetryParameters(
                            currentPoints: currentPoints,
                            validationResult: validation
                        )
                        
                        if retryParams.shouldRetry {
                            currentPoints = retryParams.points
                            attemptGeneration()
                        } else {
                            
                            self?.returnBestRoute(
                                bestRoute: bestRoute,
                                bestValidation: bestValidation,
                                completion: completion
                            )
                        }
                    } else {
                      
                        self?.returnBestRoute(
                            bestRoute: bestRoute,
                            bestValidation: bestValidation,
                            completion: completion
                        )
                    }
                    
                case .failure(let error):
                    print("Route generation failed: \(error)")
                    
                  
                    if let best = bestRoute {
                        print("Using best route from previous attempts")
                        completion(.success(best))
                    } else if attempts < maxAttempts {
                        currentPoints = currentPoints == 5 ? 4 : 5
                        attemptGeneration()
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
        
       
        attemptGeneration()
    }
    
    private func returnBestRoute(
        bestRoute: ORSRoute?,
        bestValidation: ValidationResult?,
        completion: @escaping (Result<ORSRoute, Error>) -> Void
    ) {
        if let route = bestRoute {
            if let validation = bestValidation {
                print("Returning best available route: \(validation.actualDistance)km (requested: \(validation.requestedDistance)km)")
            }
            completion(.success(route))
        } else {
            let error = NSError(domain: "RouteGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate any valid route"])
            completion(.failure(error))
        }
    }
    

    private func generateOptimalRoute(
        from userLocation: CLLocationCoordinate2D,
        distance: Double,
        points: Int,
        preferences: RoutePreferences,
        attempts: Int,
        completion: @escaping (Result<ORSRoute, Error>) -> Void
    ) {
        var bestRoute: ORSRoute?
        var bestScore = 0
        let group = DispatchGroup()
        
        for _ in 0..<attempts {
            group.enter()
            
            ORSNetworking.shared.generateRoundTripWithInstructions(
                from: userLocation,
                distance: distance,
                points: points,
                preferences: preferences
            ) { [weak self] result in
                switch result {
                case .success(let route):
                    self?.scoreRoute(route, preferences: preferences) { score in
                        if score > bestScore {
                            bestScore = score
                            bestRoute = route
                        }
                        group.leave()
                    }
                case .failure:
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if let route = bestRoute {
                completion(.success(route))
            } else {
                ORSNetworking.shared.generateRoundTripWithInstructions(
                    from: userLocation,
                    distance: distance,
                    points: points,
                    preferences: preferences,
                    completion: completion
                )
            }
        }
    }
    
    private func scoreRoute(
        _ route: ORSRoute,
        preferences: RoutePreferences,
        completion: @escaping (Int) -> Void
    ) {
        PreferenceEvaluator.shared.scoreRoute(route, preferences: preferences, completion: completion)
    }
}
