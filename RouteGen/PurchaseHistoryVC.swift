import UIKit
import RevenueCat
import RevenueCat_CustomEntitlementComputation
import FirebaseFirestore
import FirebaseAuth
import StoreKit

struct PurchaseHistory: Codable {
    let purchaseDate: String
    let productName: String
    let price: String
    let expireDate: String
}

class PurchaseHistoryVC: UITableViewController {
    
    // MARK: - Data
    var purchasesList: [PurchaseHistory] = []
    let db = Firestore.firestore()
    var userId: String { Auth.auth().currentUser?.uid ?? "unknown_user" }
    
    // MARK: - UI (Footer)
    private let footerContainer = UIView()
    private let footerStack = UIStackView()
    private let cancelButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Basic table appearance
        tableView.tableFooterView = buildFooter()
        tableView.separatorStyle = .singleLine
        tableView.contentInset.bottom = 16
        
        guard Auth.auth().currentUser != nil else {
            print("⚠️ No Firebase user logged in.")
            return
        }
        
        loadFromCache()
        fetchPurchaseHistoryFromRevenueCat()
    }
    
    // MARK: - Footer Builder
    private func buildFooter() -> UIView {
        let footerView = UIView()
        footerView.backgroundColor = .clear
        
        footerStack.axis = .vertical
        footerStack.spacing = 12
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        
        configureButton(cancelButton,
                        title: "Cancel Subscription",
                        bg: UIColor.systemRed,
                        action: #selector(cancelTapped))
        
        configureButton(restoreButton,
                        title: "Restore Purchases",
                        bg: UIColor.systemBlue,
                        action: #selector(restoreTapped))
        
        footerStack.addArrangedSubview(cancelButton)
        footerStack.addArrangedSubview(restoreButton)
        
        footerView.addSubview(footerStack)
        NSLayoutConstraint.activate([
            footerStack.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 16),
            footerStack.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 16),
            footerStack.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -16),
            footerStack.bottomAnchor.constraint(equalTo: footerView.bottomAnchor, constant: -16)
        ])
        
        // Force layout so we can calculate height
        footerView.layoutIfNeeded()
        let height = footerStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height + 32
        footerView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: height)
        
        return footerView
    }
    
    private func configureButton(_ button: UIButton, title: String, bg: UIColor, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = bg
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }
    
    private func setFooterBusy(_ busy: Bool) {
        cancelButton.isEnabled = !busy
        restoreButton.isEnabled = !busy
        busy ? spinner.startAnimating() : spinner.stopAnimating()
    }
    
    // MARK: - Button Actions
    @objc private func cancelTapped() {
        RevenueCat.Purchases.shared.showManageSubscriptions { error in
            if let error = error {
                print("showManageSubscriptions error: \(error.localizedDescription)")
                self.openManageSubscriptionsURLFallback()
            }
        }
    }
    
    private func openManageSubscriptionsURLFallback() {
        let urls = [
            "itms-apps://apps.apple.com/account/subscriptions",
            "https://apps.apple.com/account/subscriptions"
        ]
        for raw in urls {
            if let url = URL(string: raw), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }
        }
    }
    
    @objc private func restoreTapped() {
        setFooterBusy(true)
        RevenueCat.Purchases.shared.restorePurchases { customerInfo, error in
            self.setFooterBusy(false)
            if let error = error {
                self.presentAlert(title: "Restore Failed", message: error.localizedDescription)
                return
            }
            self.presentAlert(title: "Restored", message: "Your purchases were restored.")
            self.fetchPurchaseHistoryFromRevenueCat()
        }
    }
    
    // MARK: - Load from Firestore Cache
    func loadFromCache() {
        db.collection("purchaseHistory").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error loading cached purchase history: \(error)")
                return
            }
            
            if let data = snapshot?.data(),
               let items = data["items"] as? [[String: Any]] {
                
                let cachedPurchases = items.compactMap { dict -> PurchaseHistory? in
                    guard let purchaseDate = dict["purchaseDate"] as? String,
                          let productName = dict["productName"] as? String,
                          let price = dict["price"] as? String,
                          let expireDate = dict["expireDate"] as? String else { return nil }
                    return PurchaseHistory(purchaseDate: purchaseDate,
                                           productName: productName,
                                           price: price,
                                           expireDate: expireDate)
                }
                
                self.purchasesList = cachedPurchases
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Fetch from RevenueCat & Update Firestore
    func fetchPurchaseHistoryFromRevenueCat() {
        Purchases.shared.getCustomerInfo { customerInfo, error in
            if let error = error {
                print("Error fetching purchase history: \(error.localizedDescription)")
                return
            }
            
            guard let customerInfo = customerInfo else { return }
            var history: [PurchaseHistory] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for (_, entitlement) in customerInfo.entitlements.all {
                if let latestPurchaseDate = entitlement.latestPurchaseDate {
                    let purchaseDateString = dateFormatter.string(from: latestPurchaseDate)
                    let expireDateString = entitlement.expirationDate != nil ?
                        dateFormatter.string(from: entitlement.expirationDate!) : "No Expiry"
                    
                    let productId = entitlement.productIdentifier
                    
                    RevenueCat.Purchases.shared.getProducts([productId]) { products in
                        let priceString = products.first?.localizedPriceString ?? "N/A"
                        
                        let purchase = PurchaseHistory(
                            purchaseDate: purchaseDateString,
                            productName: productId,
                            price: priceString,
                            expireDate: expireDateString
                        )
                        
                        history.append(purchase)
                        history.sort { $0.purchaseDate > $1.purchaseDate }
                        self.updateCacheAndUI(with: history)
                    }
                }
            }
            
            for transaction in customerInfo.nonSubscriptionTransactions {
                let purchaseDateString = dateFormatter.string(from: transaction.purchaseDate)
                let productId = transaction.productIdentifier
                
                RevenueCat.Purchases.shared.getProducts([productId]) { products in
                    let priceString = products.first?.localizedPriceString ?? "N/A"
                    
                    let purchase = PurchaseHistory(
                        purchaseDate: purchaseDateString,
                        productName: productId,
                        price: priceString,
                        expireDate: "N/A"
                    )
                    
                    history.append(purchase)
                    history.sort { $0.purchaseDate > $1.purchaseDate }
                    self.updateCacheAndUI(with: history)
                }
            }
        }
    }
    
    // MARK: - Update Firestore + UI
    func updateCacheAndUI(with history: [PurchaseHistory]) {
        self.purchasesList = history
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        
        let dataToSave: [[String: Any]] = history.map {
            [
                "purchaseDate": $0.purchaseDate,
                "productName": $0.productName,
                "price": $0.price,
                "expireDate": $0.expireDate
            ]
        }
        
        db.collection("purchaseHistory").document(userId).setData(["items": dataToSave]) { error in
            if let error = error {
                print("Error saving to Firestore: \(error)")
            } else {
                print("Purchase history cached in Firestore")
            }
        }
    }
    
    // MARK: - TableView Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        purchasesList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PurchaseCell", for: indexPath) as! PurchaseCell
        let purchase = purchasesList[indexPath.row]
        cell.purchaseDateLabel.text = purchase.purchaseDate
        cell.productNameLabel.text = purchase.productName
        cell.priceLabel.text = purchase.price
        cell.expireDateLabel.text = purchase.expireDate
        return cell
    }
    
    // MARK: - Helpers
    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
