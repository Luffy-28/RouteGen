//
//  NavigationVC.swift
//  RouteGen
//
//  Created by 10167 on 11/7/2025.
//

// NavigationVC.swift


import UIKit
import CoreLocation
import MapKit
import AVFoundation

class NavigationVC: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var directionsLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pauseButton: UIButton!
    
    
    var route: NavigableRoute!
    
   
    var trackingViewController: StartRouteVC?

    private let speechSynth = AVSpeechSynthesizer()
    private let locationManager = CLLocationManager()

    private var steps: [NavigationStep] = []
    private var currentStepIndex = 0

    
    private var startCoordinate: CLLocationCoordinate2D?
    private var hasStarted = false

    override func viewDidLoad() {
        super.viewDidLoad()

        
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.addOverlay(route.polyline)
        let padding = UIEdgeInsets(top: 100, left: 40, bottom: 160, right: 40)
        mapView.setVisibleMapRect(route.polyline.boundingMapRect,
                                  edgePadding: padding,
                                  animated: false)

        
        steps = route.steps
        currentStepIndex = 0

       
        showStep(at: currentStepIndex)
        
        
        updateTrackingStats()

        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
       
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTrackingStats()
        }
    }
    
    
    private func updateTrackingStats() {
        guard let trackingVC = trackingViewController else { return }
        
        // Update distance and time labels with current values from tracking
       // distanceLabel.text = "Distance: \(trackingVC.milesLabel.text ?? "0.00") mi"
       // timeLabel.text = "Time: \(trackingVC.timeElapsedLabel.text ?? "00:00")"
    }
    
    // MARK: - Button Actions
    @IBAction func pauseButtonTapped(_ sender: UIButton) {
        guard let trackingVC = trackingViewController else { return }
        
        if sender.title(for: .normal) == "Pause" {
            
            trackingVC.pauseTracking()
            
            
            sender.setTitle("Resume", for: .normal)
            
           
            speechSynth.pauseSpeaking(at: .immediate)
        } else {
            
            trackingVC.resumeTracking()
            
           
            sender.setTitle("Pause", for: .normal)
            
            
            speechSynth.continueSpeaking()
        }
    }
    
    @IBAction func endButtonTapped(_ sender: UIButton) {
        
        locationManager.stopUpdatingLocation()
        
        
        speechSynth.stopSpeaking(at: .immediate)
        
        
        guard let trackingVC = trackingViewController else { return }
        trackingVC.timer?.invalidate()
        trackingVC.locationManager.stopUpdatingLocation()
        
        
        guard let window = UIApplication.shared.windows.first,
              let tabBarController = window.rootViewController as? UITabBarController else {
            print("Could not find tab bar controller")
            return
        }
        
        
        tabBarController.selectedIndex = 2
        
        self.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Display & Speak

    private func showStep(at index: Int) {
        let step = steps[index]
        let coords = step.polyline.coordinates()
        guard let first = coords.first else {
            directionsLabel.text = step.instruction
            speak(text: step.instruction)
            return
        }
        let loc = CLLocation(latitude: first.latitude, longitude: first.longitude)
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let self = self else { return }
            let street = placemarks?.first?.thoroughfare ?? ""
            let distm = Int(round(step.distance))
            var text: String
            if !street.isEmpty {
                text = "Continue on \(street) for \(distm)m"
            } else {
                text = "Walk for \(distm)m"
            }
            if index + 1 < self.steps.count {
                let nextInstr = self.steps[index + 1].instruction.lowercased()
                if !nextInstr.contains("straight") && !nextInstr.contains("head") {
                    text += ", then \(nextInstr)"
                }
            }
            self.directionsLabel.text = text
            self.speak(text: text)
        }
    }

    private func speak(text: String) {
        let utt = AVSpeechUtterance(string: text)
        utt.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynth.speak(utt)
    }


    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLoc = locations.last else { return }
        mapView.setCenter(userLoc.coordinate, animated: true)

        
        if startCoordinate == nil {
            startCoordinate = userLoc.coordinate
            return
        }
        
        if !hasStarted {
            let d = userLoc.distance(
                from: CLLocation(latitude: startCoordinate!.latitude,
                                 longitude: startCoordinate!.longitude))
            if d > 20 { hasStarted = true }
            else { return }
        }

        
        if currentStepIndex >= steps.count {
            let done = "You've arrived!"
            directionsLabel.text = done
            speak(text: done)
            manager.stopUpdatingLocation()
            return
        }

        let step = steps[currentStepIndex]
        let pts = step.polyline.points()
        let lastPt = pts[step.polyline.pointCount - 1].coordinate
        let distToEnd = userLoc.distance(from: CLLocation(latitude: lastPt.latitude,
                                                          longitude: lastPt.longitude))
        if distToEnd < 20 {
            currentStepIndex += 1
            if currentStepIndex < steps.count {
                showStep(at: currentStepIndex)
            } else {
                let done = "You've arrived!"
                directionsLabel.text = done
                speak(text: done)
                manager.stopUpdatingLocation()
            }
        }
    }

   

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let pl = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let r = MKPolylineRenderer(polyline: pl)
        r.strokeColor = .systemBlue
        r.lineWidth = 5
        return r
    }
}


private extension MKPolyline {
    func coordinates() -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid,
                                              count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
