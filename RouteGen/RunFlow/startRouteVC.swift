//
//  startRouteVC.swift
//  RouteGen
//
//  Created by 10167 on 14/7/2025.
//

// StartRouteVC.swift

import UIKit
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import PhoneNumberKit

class StartRouteVC: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var timeElapsedLabel: UILabel!
    @IBOutlet weak var milesLabel: UILabel!
    @IBOutlet weak var avgPaceLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var emergencyButton: UIButton!
    @IBOutlet weak var endButton: UIButton!
    
    
    let locationManager = CLLocationManager()
    let service = Repository()
    private var user: User?
    private let phoneNumberKit = PhoneNumberUtility()
    
    var timer: Timer?
    private var startTime: Date?
    private var totalDistance: CLLocationDistance = 0
    private var lastLocation: CLLocation?
    private var routeLocations: [CLLocation] = []
    private var pausedTime: TimeInterval = 0
    private var pauseStartTime: Date?
    private var isTracking = false
    private var isPaused = false
    
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        endButton.isEnabled = false
        startButton.isEnabled = true
        timeElapsedLabel.text = "00:00"
        milesLabel.text = "0.00"
        avgPaceLabel.text = "0:00"
        
       
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        
        let states: [UIControl.State] = [.normal, .highlighted, .selected, .disabled]
        for state in states {
            startButton.setTitle(nil, for: state)
        }
        startButton.contentHorizontalAlignment = .center
        startButton.imageView?.contentMode = .center
        if let mainColour = UIColor(named: "mainColour"),
           let playIcon = UIImage(systemName: "play.fill")?
                .withTintColor(mainColour, renderingMode: .alwaysOriginal) {
            startButton.setImage(playIcon, for: .normal)
        }
        
       
        if let uid = Auth.auth().currentUser?.uid {
            service.findUserInfo(for: uid) { [weak self] fetched in
                self?.user = fetched
            }
        }
    }
    
    
    @IBAction func startButtonTapped(_ sender: Any) {
        if isTracking && !isPaused {
            
            pauseTracking()
            setPlayIcon()
            isPaused = true
        } else if isTracking && isPaused {
           
            resumeTracking()
            setPauseIcon()
            isPaused = false
        } else {
            
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            startTime = Date()
            timer = Timer.scheduledTimer(timeInterval: 1,
                                         target: self,
                                         selector: #selector(updateTimer),
                                         userInfo: nil,
                                         repeats: true)
            resetRunData()
            setPauseIcon()
            endButton.isEnabled = true
        }
    }
    
    @IBAction func emergencyButtonTapped(_ sender: Any) {
        let currentEC = user?.emergencyContact ?? ""
        if currentEC.isEmpty {
            let alert = UIAlertController(
                title: "Add Emergency Contact",
                message: "Please enter a phone number with country code (e.g., +1 555-123-4567)",
                preferredStyle: .alert)
            alert.addTextField { tf in
                tf.placeholder = "+1 555-123-4567"
                tf.keyboardType = .phonePad
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Save & Send", style: .default) { [weak self] _ in
                guard let self = self,
                      let input = alert.textFields?.first?.text, !input.isEmpty else { return }
                
                do {
                    let parsed = try self.phoneNumberKit.parse(input)
                    let e164 = self.phoneNumberKit.format(parsed, toType: .e164)
                    
                    if var u = self.user {
                        u.emergencyContact = e164
                        // Persist to Firestore
                        self.service.updateUser(withData: u) { success in
                            if success {
                                self.user?.emergencyContact = e164
                                // TODO: Send emergency message with location
                                self.showAlert(title: "Success", message: "Emergency contact saved. Emergency feature coming soon!")
                            } else {
                                self.showAlert(title: "Error", message: "Could not save number. Try again.")
                            }
                        }
                    }
                } catch {
                    self.showAlert(title: "Invalid Number", message: "Please enter a valid phone number with country code.")
                }
            })
            present(alert, animated: true)
        } else {
    
            showAlert(title: "Emergency", message: "Emergency feature coming soon! Contact: \(currentEC)")
        }
    }
    
    @IBAction func endButtonTapped(_ sender: Any) {
        timer?.invalidate()
        locationManager.stopUpdatingLocation()
        guard let start = startTime else { return }
        updateTimer(); updateDistance(); updatePace()
        let endTime = Date()
        let duration = endTime.timeIntervalSince(start) - pausedTime
        let distanceMiles = totalDistance / 1609.34
        let paceSec = duration / (distanceMiles > 0 ? distanceMiles : 1)
        let formattedPace = format(seconds: paceSec)
        let run = Run(id: UUID().uuidString,
                      userId: Auth.auth().currentUser?.uid ?? "",
                      startTime: start,
                      endTime: endTime,
                      duration: duration,
                      distance: distanceMiles,
                      avgpace: formattedPace,
                      createdAt: Date())
        saveRun(run)
    }

    
     func pauseTracking() {
        timer?.invalidate()
        locationManager.stopUpdatingLocation()
        pauseStartTime = Date()
    }
     func resumeTracking() {
        if let pauseStart = pauseStartTime {
            pausedTime += Date().timeIntervalSince(pauseStart)
        }
        locationManager.startUpdatingLocation()
        timer = Timer.scheduledTimer(timeInterval: 1,
                                     target: self,
                                     selector: #selector(updateTimer),
                                     userInfo: nil,
                                     repeats: true)
        pauseStartTime = nil
    }

    
    private func saveRun(_ run: Run) {
        let loading = UIAlertController(title: nil, message: "Saving run...", preferredStyle: .alert)
        present(loading, animated: true)
        RunDataManager.shared.saveRun(run) { [weak self] result in
            loading.dismiss(animated: true) {
                switch result {
                    case .success:
                        let a = UIAlertController(title: "Run Completed!", message: "Your run has been saved successfully.", preferredStyle: .alert)
                        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in self?.resetUI() })
                        self?.present(a, animated: true)
                    case .failure(let error):
                        self?.showAlert(title: "Error", message: "Failed to save run: \(error.localizedDescription)")
                }
            }
        }
    }

    
    private func resetRunData() {
        totalDistance = 0; lastLocation = nil; routeLocations.removeAll()
        pausedTime = 0; isTracking = true; isPaused = false
    }
    private func resetUI() {
        timeElapsedLabel.text = "00:00"; milesLabel.text = "0.00"; avgPaceLabel.text = "0:00"
        isTracking = false; isPaused = false; endButton.isEnabled = false; startButton.isEnabled = true
        setupInitialIcons()
    }
    private func setPlayIcon() {
        if let c = UIColor(named: "mainColour"), let img = UIImage(systemName: "play.fill")?.withTintColor(c, renderingMode: .alwaysOriginal) {
            startButton.setImage(img, for: .normal)
        }
    }
    private func setPauseIcon() {
        if let c = UIColor(named: "mainColour"), let img = UIImage(systemName: "pause.fill")?.withTintColor(c, renderingMode: .alwaysOriginal) {
            startButton.setImage(img, for: .normal)
        }
    }
    private func setupInitialIcons() {
        setPlayIcon(); startButton.contentHorizontalAlignment = .center; startButton.imageView?.contentMode = .center
    }

   
    @objc private func updateTimer() {
        guard let start = startTime else { return }
        let elapsed = Date().timeIntervalSince(start) - pausedTime
        timeElapsedLabel.text = format(seconds: elapsed)
        updateDistance(); updatePace()
    }
    private func updateDistance() {
        milesLabel.text = String(format: "%.2f", totalDistance / 1609.34)
    }
    private func updatePace() {
        guard totalDistance > 0, let start = startTime else {
            avgPaceLabel.text = "00:00"
            return
        }
        
        let elapsed = Date().timeIntervalSince(start) - pausedTime
        let distanceInMiles = totalDistance / 1609.34
        
        // Ensure we don't divide by zero
        guard distanceInMiles > 0 else {
            avgPaceLabel.text = "00:00"
            return
        }
        
        avgPaceLabel.text = format(seconds: elapsed / distanceInMiles)
    }
    private func format(seconds: TimeInterval) -> String {
        // Check for invalid values
        guard seconds.isFinite && !seconds.isNaN && seconds >= 0 else {
            return "00:00"
        }
        
        let ti = Int(seconds)
        return String(format: "%02d:%02d", ti/60, ti%60)
    }

   
    private func showAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}


extension StartRouteVC {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for newLoc in locations {
            guard newLoc.horizontalAccuracy >= 0 else { continue }
            routeLocations.append(newLoc)
            if let last = lastLocation {
                totalDistance += newLoc.distance(from: last)
            }
            lastLocation = newLoc
        }
        updateDistance()
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted { print("Location denied") }
    }
}
