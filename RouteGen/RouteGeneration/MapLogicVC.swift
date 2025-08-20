import UIKit
import MapKit
import CoreLocation
import RevenueCat
import RevenueCatUI
import FirebaseAuth
import FirebaseFirestore

class MapLogicVC: UIViewController,
    MKLocalSearchCompleterDelegate,
    UISearchBarDelegate,
    UITableViewDataSource,
    UITableViewDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var distanceTF: UITextField!
    @IBOutlet weak var routePlannerView: UIView!
    @IBOutlet weak var routeDetailsView: UIView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var suggestionTableView: UITableView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var urbanExplorerSwitch: UISwitch!
    @IBOutlet weak var quietSwitch: UISwitch!
    @IBOutlet weak var avoidStairsSwitch: UISwitch!
    @IBOutlet weak var preferenceFailedView: UIView!
    @IBOutlet weak var preferenceFailedLabel: UILabel!
    @IBOutlet weak var distanceRouteDetails: UILabel!
    @IBOutlet weak var durationRouteDetails: UILabel!
    @IBOutlet weak var elevationRouteDetails: UILabel!
    @IBOutlet weak var caloriesRouteDetails: UILabel!

    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private let routeGenerator = RouteGenerator()
    private var navigableRoute: NavigableRoute?
    private let displayManager = RouteDisplayManager.shared
    private let preferenceEvaluator = PreferenceEvaluator.shared
    private let routeValidator = RouteValidator.shared

    // Autocomplete
    private let searchCompleter = MKLocalSearchCompleter()
    private var searchResults: [MKLocalSearchCompletion] = []

    // Distance picker
    private let distancePicker = UIPickerView()
    private let distanceOptions = (1...10).map { "\($0) km" }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        guard mapView != nil else {
            print("ERROR: mapView outlet is not connected!")
            return
        }

        setupMap()
        setupLocation()
        setupDistancePicker()
        setupSearchAutocomplete()
        setupSuggestionTable()

        routeDetailsView.isHidden = true
        preferenceFailedView.isHidden = true

        // Check and reset route count on view load
        RouteManager.shared.checkAndResetIfNewMonth { success in
            if !success {
                print("Error checking/resetting route count")
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetRouteDisplay()
    }
    
    // MARK: - Reset Route Display
    private func resetRouteDisplay() {
        displayManager.clearRoute(from: mapView)
        navigableRoute = nil
        routeDetailsView.isHidden = true
        routePlannerView.isHidden = false
        distanceTF.text = ""
        avoidStairsSwitch.isOn = false
        urbanExplorerSwitch.isOn = false
        quietSwitch.isOn = false
        preferenceFailedView.isHidden = true
        searchBar.text = ""
        suggestionTableView.isHidden = true
        
        if let userLocation = mapView.userLocation.location {
            let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapView.setRegion(region, animated: true)
        }
    }

    private func setupMap() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
    }

    private func setupLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func setupDistancePicker() {
        distancePicker.delegate = self
        distancePicker.dataSource = self
        distanceTF.inputView = distancePicker

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain,
                                         target: self, action: #selector(dismissPicker))
        toolbar.setItems([doneButton], animated: false)
        distanceTF.inputAccessoryView = toolbar
    }

    @objc private func dismissPicker() {
        view.endEditing(true)
    }

    private func setupSearchAutocomplete() {
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
        searchCompleter.region = mapView.region
        searchBar.delegate = self
    }

    private func setupSuggestionTable() {
        suggestionTableView.dataSource = self
        suggestionTableView.delegate = self
        suggestionTableView.isHidden = true
    }

    // MARK: - Button Actions
    @IBAction func generateRouteButtonTapped(_ sender: UIButton) {
        // Ensure user is signed in
        guard Auth.auth().currentUser != nil else {
            showLoginAlert()
            return
        }

        guard let text = distanceTF.text,
              let kmString = text.split(separator: " ").first,
              let km = Double(kmString) else {
            showErrorAlert(message: "Please select a valid distance.")
            return
        }

        let prefs = RoutePreferences(
            quiet: quietSwitch.isOn,
            urbanExplorer: urbanExplorerSwitch.isOn,
            avoidStairs: avoidStairsSwitch.isOn
        )

        // Check subscription and route limit
        RouteManager.shared.checkAndResetIfNewMonth { success in
            if !success {
                self.showErrorAlert(message: "Error checking route limit. Please try again.")
                return
            }

            self.isPremiumUser { isPremium in
                if isPremium {
                    // Premium users can generate unlimited routes
                    self.generateRoute(targetDistanceKm: km, preferences: prefs)
                } else {
                    // Non-premium users are limited to 5 routes
                    RouteManager.shared.getRouteData { (routeCount, _) in
                        if routeCount < 5 {
                            RouteManager.shared.incrementRouteCount { success in
                                if success {
                                    self.generateRoute(targetDistanceKm: km, preferences: prefs)
                                } else {
                                    self.showErrorAlert(message: "Error updating route count. Please try again.")
                                }
                            }
                        } else {
                            self.showUpgradeAlert()
                        }
                    }
                }
            }
        }
    }

    @IBAction func newRouteButtonTapped(_ sender: Any) {
        routePlannerView.isHidden = false
        routeDetailsView.isHidden = true
        distanceTF.text = ""
        displayManager.clearRoute(from: mapView)
        navigableRoute = nil
        preferenceFailedView.isHidden = true
    }

    @IBAction func startNavigationTapped(_ sender: UIButton) {
        guard let route = navigableRoute else {
            print("No route available to navigate!")
            return
        }
        
        guard let window = UIApplication.shared.windows.first,
              let tabBarController = window.rootViewController as? UITabBarController else {
            print("Could not find tab bar controller")
            return
        }
        
        guard let runNavController = tabBarController.viewControllers?[2] as? UINavigationController else {
            print("Tab 2 is not a navigation controller")
            return
        }
        
        guard let startRouteVC = runNavController.viewControllers.first as? StartRouteVC else {
            print("First VC in Run tab is not StartRouteVC, it's: \(type(of: runNavController.viewControllers.first))")
            return
        }
        
        startRouteVC.loadViewIfNeeded()
        startRouteVC.startButtonTapped(startRouteVC.startButton!)
        
        let navVC = storyboard!.instantiateViewController(withIdentifier: "NavigationVC") as! NavigationVC
        navVC.route = route
        navVC.trackingViewController = startRouteVC
        navVC.modalPresentationStyle = .fullScreen
        navVC.isModalInPresentation = true
        
        present(navVC, animated: true)
    }
    
    private func generateRoute(
        targetDistanceKm: Double,
        preferences: RoutePreferences
    ) {
        guard let userLoc = mapView.userLocation.location?.coordinate else {
            showErrorAlert(message: "User location not available.")
            return
        }

        routeGenerator.generateDistanceBasedLoopWithInstructions(
            from: userLoc,
            targetDistanceKm: targetDistanceKm,
            preferences: preferences
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let orsRoute):
                    let validation = self.routeValidator.validateRoute(
                        orsRoute,
                        requestedDistanceKm: targetDistanceKm
                    )
                    
                    print("🎯 Distance validation: \(validation.isValid ? "PASS" : "FAIL")")
                    if let message = validation.message {
                        print("📏 \(message)")
                    }
                    
                    self.navigableRoute = orsRoute
                    self.displayManager.displayRoute(orsRoute, on: self.mapView)
                    
                    if !validation.isValid {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.showDistanceWarning(validation: validation)
                        }
                    }
                    
                    self.preferenceEvaluator.evalulateRoute(orsRoute, preferences: preferences) { [weak self] missingFeatures in
                        if !missingFeatures.isEmpty {
                            let message = self?.preferenceEvaluator.generateFeedbackMessage(for: missingFeatures) ?? ""
                            self?.showPreferenceBanner(message)
                        }
                    }
                    
                    self.displayManager.updateRouteDetailsUI(
                        with: orsRoute,
                        distanceLabel: self.distanceRouteDetails,
                        durationLabel: self.durationRouteDetails,
                        elevationLabel: self.elevationRouteDetails,
                        caloriesLabel: self.caloriesRouteDetails
                    )
                    
                    self.routePlannerView.isHidden = true
                    self.routeDetailsView.isHidden = false

                case .failure(let error):
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Oops!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showDistanceWarning(validation: ValidationResult) {
        let message = String(
            format: "Route is %.1fkm (requested %.1fkm)",
            validation.actualDistance,
            validation.requestedDistance
        )
        
        let alert = UIAlertController(
            title: "Distance Notice",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showUpgradeAlert() {
        let alert = UIAlertController(
            title: "Route Limit Reached",
            message: "You’ve created 5 routes this month. Upgrade to Premium for unlimited routes!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Upgrade", style: .default) { _ in
            self.showPurchaseVC()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showLoginAlert() {
        let alert = UIAlertController(
            title: "Please Log In",
            message: "You need to be logged in to create routes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showPurchaseVC() {
        guard let purchaseVC = storyboard?.instantiateViewController(withIdentifier: "PurchaseVC") as? PurchaseVC else {
            print("❌ Failed to instantiate PurchaseVC")
            showErrorAlert(message: "Unable to load subscription options. Please try again.")
            return
        }
        let navController = UINavigationController(rootViewController: purchaseVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true) {
            print("📌 PurchaseVC presented")
        }
    }

    private func isPremiumUser(completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        // Check Firestore for isPremium
        Firestore.firestore().collection("User").document(userId).getDocument { (document, error) in
            if let document = document, document.exists, let isPremium = document.get("isPremium") as? Bool, isPremium {
                completion(true)
            } else {
                // Fallback to RevenueCat if Firestore check fails
                Purchases.shared.getCustomerInfo { (customerInfo, error) in
                    if let customerInfo = customerInfo, error == nil {
                        let isPremium = customerInfo.entitlements["Pro"]?.isActive ?? false
                        completion(isPremium)
                    } else {
                        completion(false)
                    }
                }
            }
        }
    }

    private func showPreferenceBanner(_ message: String) {
        preferenceFailedLabel.text = message
        preferenceFailedView.alpha = 0
        preferenceFailedView.isHidden = false
        view.bringSubviewToFront(preferenceFailedView)
        UIView.animate(withDuration: 0.3, animations: {
            self.preferenceFailedView.alpha = 1
        }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                UIView.animate(withDuration: 0.3, animations: {
                    self.preferenceFailedView.alpha = 0
                }) { _ in
                    self.preferenceFailedView.isHidden = true
                }
            }
        }
    }
    
    // MARK: - Autocomplete & TableView
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            suggestionTableView.isHidden = true
            searchResults.removeAll()
            suggestionTableView.reloadData()
        } else {
            searchCompleter.queryFragment = searchText
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        suggestionTableView.reloadData()
        suggestionTableView.isHidden = searchResults.isEmpty
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        suggestionTableView.isHidden = true
        guard let query = searchBar.text, !query.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.region = mapView.region
        MKLocalSearch(request: req).start { [weak self] resp, _ in
            guard let coord = resp?.mapItems.first?.placemark.coordinate else { return }
            self?.drawRoute(to: coord)
        }
    }

    private func getRouteToDestination(completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { [weak self] resp, _ in
            guard let coord = resp?.mapItems.first?.placemark.coordinate else { return }
            self?.drawRoute(to: coord)
        }
    }

    // MARK: - Table View Data Source
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let result = searchResults[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "SuggestionCell")
        cell.textLabel?.text = result.title
        cell.detailTextLabel?.text = result.subtitle
        return cell
    }

    // MARK: - Table View Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = searchResults[indexPath.row]
        searchBar.text = selected.title
        suggestionTableView.isHidden = true
        getRouteToDestination(completion: selected)
    }

    // MARK: - Drawing Helpers
    private func drawRoute(to destination: CLLocationCoordinate2D) {
        let src = MKPlacemark(coordinate: mapView.userLocation.coordinate)
        let dst = MKPlacemark(coordinate: destination)
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: src)
        req.destination = MKMapItem(placemark: dst)
        req.transportType = .walking
        
        MKDirections(request: req).calculate { [weak self] resp, _ in
            guard let route = resp?.routes.first, let self = self else { return }
            
            self.navigableRoute = route
            self.displayManager.displayRoute(route, on: self.mapView)
            self.displayManager.updateRouteDetailsUI(
                with: route,
                distanceLabel: self.distanceRouteDetails,
                durationLabel: self.durationRouteDetails,
                elevationLabel: self.elevationRouteDetails,
                caloriesLabel: self.caloriesRouteDetails
            )
            
            self.routePlannerView.isHidden = true
            self.routeDetailsView.isHidden = false
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension MapLogicVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - MKMapViewDelegate
extension MapLogicVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return displayManager.rendererForOverlay(overlay)
    }
}

// MARK: - UIPickerViewDelegate & DataSource
extension MapLogicVC: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return distanceOptions.count
    }
    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int, forComponent component: Int) -> String? {
        return distanceOptions[row]
    }
    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int, inComponent component: Int) {
        distanceTF.text = distanceOptions[row]
    }
}
