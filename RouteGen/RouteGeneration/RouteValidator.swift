//
//  RouteValidator.swift
//  RouteGen
//
//  Created by 10167 on 5/8/2025.
//

import Foundation
import CoreLocation
import MapKit


struct ValidationResult {
    let isValid: Bool
    let actualDistance: Double
    let requestedDistance: Double
    let percentageOff: Double
    let message: String?
}

final class RouteValidator {
    static let shared = RouteValidator()
    
    private init() {}
    
    
    
   
    func validateRoute(_ route: NavigableRoute, requestedDistanceKm: Double) -> ValidationResult {
        let actualDistanceKm: Double
        if let orsRoute = route as? ORSRoute {
            actualDistanceKm = (orsRoute.distance ?? 0) / 1000.0
        } else if let mkRoute = route as? MKRoute {
            actualDistanceKm = mkRoute.distance / 1000.0
        } else {
            actualDistanceKm = 0
        }
        
      
        let percentageOff = abs(actualDistanceKm - requestedDistanceKm) / requestedDistanceKm * 100
        
        
        let tolerance = calculateDistanceTolerance(for: requestedDistanceKm)
        let isValid = percentageOff <= tolerance
        
        let message = generateValidationMessage(requested: requestedDistanceKm,actual: actualDistanceKm,percentageOff: percentageOff,isValid: isValid)
        
        return ValidationResult(isValid: isValid,actualDistance: actualDistanceKm,requestedDistance: requestedDistanceKm,percentageOff: percentageOff,message: message)
    }
    
    
    private func calculateDistanceTolerance(for requestedKm: Double) -> Double {
        switch requestedKm {
        case 0..<2:
            return 20.0
        case 2..<5:
            return 15.0
        case 5..<10:
            return 12.0
        default:
            return 10.0
        }
    }
    
   
    func isDistanceAcceptable(requested: Double,actual: Double) -> Bool {
        let percentageOff = abs(actual - requested) / requested * 100
        let tolerance = calculateDistanceTolerance(for: requested)
        return percentageOff <= tolerance
    }
    
   
    func validateLoopClosure(_ route: NavigableRoute,startPoint: CLLocationCoordinate2D) -> Bool {
            let polyline = route.polyline
            guard polyline.pointCount > 0 else {
                return false
            }
        
       
        let lastPoint = polyline.points()[polyline.pointCount - 1]
        let endCoordinate = lastPoint.coordinate
        
        
        let startLocation = CLLocation(latitude: startPoint.latitude,longitude: startPoint.longitude)
        
        let endLocation = CLLocation(latitude: endCoordinate.latitude,longitude: endCoordinate.longitude)
        
        let distance = startLocation.distance(from: endLocation)
        
        return distance < 100
    }
    
    
    private func generateValidationMessage(requested: Double,actual: Double,percentageOff: Double,isValid: Bool) -> String? {
        if isValid {
            return nil
        }
        let difference = actual - requested
        let verb = difference > 0 ? "longer" : "shorter"
        
        return String(format: "Route is %.1fkm (%.0f%% %@) than requested. Requested: %.1fkm, Got: %.1fkm",abs(difference),percentageOff,verb,requested,actual)
    }
    
   
    
   
    func suggestRetryParameters(
            currentPoints: Int,
            validationResult: ValidationResult
        ) -> (points: Int, shouldRetry: Bool) {
           
            guard !validationResult.isValid else {
                return (currentPoints, false)
            }
            
            let ratio = validationResult.actualDistance / validationResult.requestedDistance
            
            if ratio > 2.0 {
                return (3, currentPoints != 3)
            } else if ratio > 1.5 {
                
                let newPoints = max(3, currentPoints - 2)
                return (newPoints, newPoints != currentPoints)
            } else if ratio > 1.2 {
                
                let newPoints = max(3, currentPoints - 1)
                return (newPoints, newPoints != currentPoints)
            } else if ratio < 0.5 {
               
                return (10, currentPoints != 10)
            } else if ratio < 0.7 {
                
                let newPoints = min(10, currentPoints + 2)
                return (newPoints, newPoints != currentPoints)
            } else if ratio < 0.8 {
               
                let newPoints = min(10, currentPoints + 1)
                return (newPoints, newPoints != currentPoints)
            }
            
           
            return (currentPoints, false)
        }
    
    
    
    
    func selectBestRoute(from routes: [NavigableRoute],requestedDistanceKm: Double) -> (route: NavigableRoute, validation: ValidationResult)? {
        guard !routes.isEmpty else { return nil }
        
        let validatedRoutes = routes.map { route in
            (route: route, validation: validateRoute(route, requestedDistanceKm: requestedDistanceKm))
        }
        
        let sorted = validatedRoutes.sorted { first, second in
            first.validation.percentageOff < second.validation.percentageOff
        }
        
        return sorted.first
    }
}
