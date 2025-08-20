//
//  HomePageVC.swift
//  RouteGen
//
//  Created by 10167 on 13/8/2025
//

import Foundation
import WeatherKit
import UIKit
import CoreLocation
import SafariServices
import FirebaseFirestore
import Kingfisher
import RevenueCat
import Network

class HomePageVC: UIViewController, CLLocationManagerDelegate {
    // MARK: - Outlets
    @IBOutlet weak var imageWeather: UIImageView!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var labelStreak: UILabel!
    @IBOutlet weak var carouselCollectionView: UICollectionView!

    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private let carouselRepository = CarouselRepository()
    private var carouselItems: [CaroselItem] = []
    private var carouselListener: ListenerRegistration?
    private var lastWeatherFetch: Date?
    private var cachedWeather: (temperature: Int, iconName: String, description: String)?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🚀 HomePageVC.viewDidLoad fired")

        setupLocationManager()
        requestLocationIfAuthorized()
        loadStreak()
        setupCarousel()
        
        // Accessibility for weather UI elements
        imageWeather.isAccessibilityElement = true
        imageWeather.accessibilityLabel = "Weather icon"
        tempLabel.accessibilityLabel = "Current temperature"
        descriptionLabel.accessibilityLabel = "Weather description"
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        carouselListener?.remove()
    }
    
    // MARK: - Carousel Setup
    private func setupCarousel() {
        carouselCollectionView.delegate = self
        carouselCollectionView.dataSource = self
        loadCarouselItems()
    }
    
    private func loadCarouselItems() {
        print("Starting to load carousel items...")
        
        carouselRepository.fetchCarouselItems { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    print("One-time fetch successful: \(items.count) items")
                    self?.carouselItems = items
                    self?.carouselCollectionView.reloadData()
                case .failure(let error):
                    print("One-time fetch failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Then set up real-time listener
        carouselListener = carouselRepository.observeCarouselItems { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    print("Real-time listener update: \(items.count) items")
                    self?.carouselItems = items
                    self?.carouselCollectionView.reloadData()
                    
                    if items.isEmpty {
                        print("Warning: Received empty array from Firebase")
                    }
                case .failure(let error):
                    print("Real-time listener error: \(error.localizedDescription)")
                    print("Error details: \(error)")
                }
            }
        }
    }

    // MARK: - Location Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    private func requestLocationIfAuthorized() {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            print("Location access denied or restricted")
            showLocationErrorAlert()
        @unknown default:
            print("Unknown authorization status: \(status)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            print("Location access denied.")
            showLocationErrorAlert()
        @unknown default:
            print("Unknown authorization status: \(status)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else {
            print("didUpdateLocations: no locations in array")
            return
        }
        print("didUpdateLocations fired – got location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        locationManager.stopUpdatingLocation()
        checkNetworkAndFetchWeather(at: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError:", error.localizedDescription)
        showLocationErrorAlert()
    }
    
    // MARK: - Weather Fetching
    private func showLocationErrorAlert() {
        let alert = UIAlertController(
            title: "Location Access Needed",
            message: "Please enable location services in Settings to view weather data.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func checkNetworkAndFetchWeather(at location: CLLocation) {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("Network is available, fetching weather...")
                self.fetchWeather(at: location)
            } else {
                print("Network is unavailable")
                DispatchQueue.main.async {
                    self.imageWeather.image = UIImage(systemName: "questionmark.circle")
                    self.tempLabel.text = "--°"
                    self.descriptionLabel.text = "N/A"
                    
                    let alert = UIAlertController(
                        title: "No Network",
                        message: "Please connect to the internet to fetch weather data.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    private func fetchWeather(at location: CLLocation) {
        // Check cache (5-minute cache)
        if let lastFetch = lastWeatherFetch, Date().timeIntervalSince(lastFetch) < 300,
           let cached = cachedWeather {
            DispatchQueue.main.async {
                self.imageWeather.image = UIImage(systemName: cached.iconName)
                self.tempLabel.text = "\(cached.temperature)°"
                self.descriptionLabel.text = cached.description
            }
            return
        }
        
        Task {
            do {
                let weather = try await WeatherService.shared.weather(for: location)
                let current = weather.currentWeather
                let tempValue = Int(current.temperature.value)
                let iconName = current.symbolName
                let descriptionText = current.condition.description
                
                await MainActor.run {
                    self.imageWeather.image = UIImage(systemName: iconName)
                    self.tempLabel.text = "\(tempValue)°"
                    self.descriptionLabel.text = descriptionText
                    
                    // Cache the results
                    self.cachedWeather = (tempValue, iconName, descriptionText)
                    self.lastWeatherFetch = Date()
                }
            } catch {
                await MainActor.run {
                    let nsError = error as NSError
                    print("WeatherKit fetch failed: \(error.localizedDescription), Code: \(nsError.code), Domain: \(nsError.domain), UserInfo: \(nsError.userInfo)")
                    
                    self.imageWeather.image = UIImage(systemName: "questionmark.circle")
                    self.tempLabel.text = "--°"
                    self.descriptionLabel.text = "N/A"
                    
                    let alert = UIAlertController(
                        title: "Weather Update Failed",
                        message: "Unable to fetch weather data. Please check your network connection or try again later.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                        self.checkNetworkAndFetchWeather(at: location)
                    })
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    // MARK: - Streak Loading
    private func loadStreak() {
        CalculateStreaks.shared.computeStreak { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let days):
                    self.labelStreak.text = "\(days) Day Streak, Keep it up!"
                case .failure:
                    self.labelStreak.text = "—-Day Streak"
                }
            }
        }
    }
}

// MARK: - Carousel Data Source & Delegate
extension HomePageVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("Collection view asking for number of items. Current count: \(carouselItems.count)")
        return carouselItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("Creating cell for item at index \(indexPath.item)")
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CarouselCell", for: indexPath) as! CarouselCell
        
        guard indexPath.item < carouselItems.count else {
            print("Index out of bounds: \(indexPath.item) >= \(carouselItems.count)")
            return cell
        }
        
        let item = carouselItems[indexPath.item]
        print("Setting up cell with title: '\(item.title)'")
        cell.titleLabel.text = item.title
        
        cell.imageView.kf.setImage(
            with: item.imageURL,
            placeholder: UIImage(systemName: "photo"),
            options: [
                .transition(.fade(0.3)),
                .cacheOriginalImage,
                .backgroundDecode
            ]
        )
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 140, height: collectionView.bounds.height)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = carouselItems[indexPath.item]
        let safariVC = SFSafariViewController(url: item.linkURL)
        present(safariVC, animated: true)
    }
}
