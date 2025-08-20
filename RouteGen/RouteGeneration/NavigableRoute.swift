//
//  NavigableRoute.swift
//  RouteGen
//
//  Created by 10167 on 15/7/2025.
//
import MapKit
import CoreLocation


protocol NavigableRoute {
    
    var polyline: MKPolyline { get }

    
    var steps: [NavigationStep] { get }

    
    var expectedTravelTime: TimeInterval? { get }
}


struct NavigationStep {
    let instruction: String
    let distance: CLLocationDistance
    let polyline: MKPolyline
}


extension MKRoute: NavigableRoute {
    var polyline: MKPolyline {
        
        return self.value(forKey: "polyline") as! MKPolyline
    }

    var steps: [NavigationStep] {
        
        let mkSteps = (self.value(forKey: "steps") as? [MKRoute.Step]) ?? []
        return mkSteps.map { mkStep in
            NavigationStep(
                instruction: mkStep.instructions,
                distance: mkStep.distance,
                polyline: mkStep.polyline
            )
        }
    }

    var expectedTravelTime: TimeInterval? {
       
        return self.value(forKey: "expectedTravelTime") as? TimeInterval
    }
}
