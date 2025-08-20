//
//  ORSRoute.swift
//  RouteGen
//
//  Created by 10167 on 15/7/2025.
//
import MapKit
import CoreLocation



struct ORSRoute: NavigableRoute {
    let polyline: MKPolyline
    let steps: [NavigationStep]
    let expectedTravelTime: TimeInterval?
    let elevationGain: Double?
    let distance: Double?

    
    init(geoJSON: ORSGeoJSONExtended) {
        
        let rawCoordinates = geoJSON.features[0].geometry.coordinates

       
        let coords = rawCoordinates.map { arr in
            CLLocationCoordinate2D(latitude: arr[1], longitude: arr[0])
        }
        polyline = MKPolyline(coordinates: coords, count: coords.count)

       
        expectedTravelTime = geoJSON.features[0].properties.summary?.duration
        distance = geoJSON.features[0].properties.summary?.distance

       
       
        var totalGain: Double = 0.0
        if rawCoordinates.count > 1 && rawCoordinates[0].count > 2 {
            for i in 1..<rawCoordinates.count {
                if rawCoordinates[i].count > 2 && rawCoordinates[i-1].count > 2 {
                    let elevDiff = rawCoordinates[i][2] - rawCoordinates[i-1][2]
                    if elevDiff > 0 {
                        totalGain += elevDiff
                    }
                }
            }
            elevationGain = totalGain
        } else {
            elevationGain = nil
        }

       
        var navSteps: [NavigationStep] = []
        for segment in geoJSON.features[0].properties.segments {
            for step in segment.steps {
                let wp = step.wayPoints
                let sliceCoords = Array(coords[wp[0]...wp[1]])
                let stepPolyline = MKPolyline(coordinates: sliceCoords,
                                              count: sliceCoords.count)
                navSteps.append(
                    NavigationStep(
                        instruction: step.instruction,
                        distance: step.distance,
                        polyline: stepPolyline
                    )
                )
            }
        }
        steps = navSteps
    }
}
