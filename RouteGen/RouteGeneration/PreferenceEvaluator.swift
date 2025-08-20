//
//  PreferenceEvaluator.swift
//  RouteGen
//
//  Created by 10167 on 5/8/2025.
//

import Foundation
import MapKit
import CoreLocation

final class PreferenceEvaluator {
    static let shared = PreferenceEvaluator()
    
    init(){}
    
    func evalulateRoute(_ route: NavigableRoute, preferences: RoutePreferences, completion: @escaping ([String]) -> Void){
        let mapRect = route.polyline.boundingMapRect
        let region = MKCoordinateRegion(mapRect)
        let group = DispatchGroup()
        
        var urbanPOICount = 0
        var quietScore = 0
        
        if preferences.urbanExplorer{
            group.enter()
            checkUrbanPOIs(in: region){
                count in urbanPOICount = count
                group.leave()
            }
        }
        
        if preferences.quiet {
            group.enter()
            checkQuietAreas(in: region){
                count in quietScore = count
                group.leave()
            }
        }
        
        group.notify(queue: .main){
            var missing: [String] = []
            
            if preferences.urbanExplorer && urbanPOICount < 3 {
                missing.append("Urban Landmarks")
            }
            
            if preferences.quiet && quietScore == 0 {
                missing.append("Quiet Streets")
            }
            
            completion(missing)
        }
    }
    
    func scoreRoute(_ route: NavigableRoute, preferences: RoutePreferences, completion: @escaping (Int) -> Void){
        let mapRect = route.polyline.boundingMapRect
        let region = MKCoordinateRegion(mapRect)
        var score = 100
        let group = DispatchGroup()
        
        if preferences.urbanExplorer{
            group.enter()
            checkUrbanPOIs(in: region){
                count in score += count * 15
                group.leave()
            }
        }
        
        if preferences.quiet{
            group.enter()
            checkCommercialDensity(in: region){
                commercialCount in
                if commercialCount < 3 {
                    score += 30
                } else if commercialCount > 6 {
                    score -= 20
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
                completion(score)
            }
    }
    
   private func checkUrbanPOIs(in region: MKCoordinateRegion, completion: @escaping (Int) -> Void){
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
           .museum, .landmark, .cafe, .restaurant, .theater, .nationalPark
        ])
        
        MKLocalSearch(request: request).start{response, _ in let count = response?.mapItems.count ?? 0
        completion(count)
        }
    }
    
    private func checkQuietAreas(in region: MKCoordinateRegion, completion: @escaping (Int) -> Void){
        checkCommercialDensity(in: region) { commercialCount in
            let quietScore = commercialCount < 3 ? 1 : 0
            completion(quietScore)
        }
    }
    
    private func checkCommercialDensity(in region: MKCoordinateRegion, completion: @escaping (Int) -> Void){
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .gasStation, .store, .amusementPark
        ])
        
        MKLocalSearch(request: request).start{response, _ in let count = response?.mapItems.count ?? 0
            completion(count)
        }
    }
    
    func generateFeedbackMessage(for missingFeatures: [String]) -> String {
        guard !missingFeatures.isEmpty else {return ""}
        
        let list = missingFeatures.joined(separator: "and")
        return "Couldnt find a truly \(list) route nearby, here is the best we can offer!"
    }
}
