//
//  RouteDisplayManager.swift
//  RouteGen
//
//  Created by 10167 on 5/8/2025.
//

import Foundation
import MapKit
import CoreLocation

final class RouteDisplayManager{
    static let shared = RouteDisplayManager()
    
    private init() {}

    func displayRoute(_ route: NavigableRoute, on mapView: MKMapView){
        
        clearRoute(from: mapView)
        
        mapView.addOverlay(route.polyline)
        
        fitMapToRoute(route, on: mapView)
        
    }
    
    func clearRoute(from mapView: MKMapView){
        mapView.removeOverlays(mapView.overlays)
    }

    func fitMapToRoute(_ route: NavigableRoute, on mapView: MKMapView){
        let rect = route.polyline.boundingMapRect
        
        if let _ = route as? ORSRoute{
            let inset = rect.size.width * 0.1
            mapView.setVisibleMapRect(rect.insetBy(dx: -inset, dy: -inset), animated: true)
        } else {
            let padding = UIEdgeInsets(top: 80, left: 40, bottom: 160, right: 40)
            mapView.setVisibleMapRect(rect, edgePadding: padding, animated: true)
        }
    }

    func updateRouteDetailsUI(with route: NavigableRoute?, distanceLabel: UILabel, durationLabel: UILabel, elevationLabel: UILabel, caloriesLabel: UILabel){
        guard let route = route else {
            distanceLabel.text = "- km"
            durationLabel.text = "- min"
            elevationLabel.text = "- m"
            caloriesLabel.text = "- cal"
            
            return
        }
        
        if let orsRoute = route as? ORSRoute {
            if let distance = orsRoute.distance{
                let km = distance / 1000.0
                distanceLabel.text = String(format: "%.1f km", km)
                
            } else {
                distanceLabel.text = "- km"
            }
            
            if let duration = orsRoute.expectedTravelTime {
                let minutes = Int (duration/60)
                durationLabel.text = "\(minutes) min"
                
            }else {
                durationLabel.text = "- min"
            }
            
            if let elevation = orsRoute.elevationGain{
                elevationLabel.text = String(format: "%.0f m", elevation)
                
            } else {
                elevationLabel.text = "- m"
            }
            
            let calories = calculateCalories(distanceMeters: orsRoute.distance, elevationGainMeters: orsRoute.elevationGain)
            caloriesLabel.text = "\(calories) cal"
            
        } else if let mkRoute = route as? MKRoute {
            
            let km = mkRoute.distance / 1000.0
            distanceLabel.text = String(format: "%.1f km", km)
            
            if let travelTime = mkRoute.expectedTravelTime {
                let minutes = Int(travelTime / 60)
                durationLabel.text = "\(minutes) min"
            } else {
                durationLabel.text = "— min"
            }
            
            
            elevationLabel.text = "-m"
            
            let calories = calculateCalories(distanceMeters: mkRoute.distance, elevationGainMeters: nil)
            caloriesLabel.text = "\(calories), cal"
        }
    }

    private func calculateCalories( distanceMeters: Double?, elevationGainMeters: Double?) -> Int{
        guard let distance = distanceMeters else {return 0}
        
        let km = distance / 1000.0
        var calories = km * 65.0
        
        if let elevation = elevationGainMeters{
            
            calories += (elevation / 10) * 10.0
        }
        
        return Int(calories)
    }

    func rendererForOverlay(_ overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemOrange
            renderer.lineWidth = 4
            renderer.lineCap = .round
            
            return renderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }

}


