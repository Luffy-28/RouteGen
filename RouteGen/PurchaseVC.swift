import UIKit
import RevenueCat
import RevenueCatUI
import FirebaseAuth
import FirebaseFirestore

class PurchaseVC: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📌 PurchaseVC loaded")
        // Automatically show paywall on load
        showPaywall()
    }
    
    func showPaywall() {
        print("📌 showPaywall triggered")
        Purchases.shared.getOfferings { offerings, error in
            if let error = error {
                print("❌ Failed to fetch offerings: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showAlertMessage(tittle: "Error", message: "Failed to load subscription options: \(error.localizedDescription)")
                    self.dismiss(animated: true) {
                        print("📌 PurchaseVC dismissed due to offerings error")
                    }
                }
                return
            }
            if let offering = offerings?.current {
                print("📌 Presenting PaywallViewController with offering: \(offering.identifier)")
                let paywallVC = PaywallViewController(offering: offering)
                paywallVC.delegate = self
                DispatchQueue.main.async {
                    self.present(paywallVC, animated: true) {
                        print("📌 PaywallViewController presented")
                    }
                }
            } else {
                print("❌ No current offering available")
                DispatchQueue.main.async {
                    self.showAlertMessage(tittle: "Error", message: "No subscription options available.")
                    self.dismiss(animated: true) {
                        print("📌 PurchaseVC dismissed due to no offerings")
                    }
                }
            }
        }
    }
    
    @IBAction func showPaywallTapped(_ sender: UIButton) {
        showPaywall()
    }
    
    @IBAction func restoreTapped(_ sender: UIButton) {
        print("📌 restoreTapped triggered")
        Purchases.shared.restorePurchases { customerInfo, error in
            if let error = error {
                print("❌ Restore error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showAlertMessage(tittle: "Error", message: "Failed to restore purchases: \(error.localizedDescription)")
                }
                return
            }
            let isPremium = customerInfo?.entitlements["Pro"]?.isActive ?? false
            print("📌 Restore result: isPremium = \(isPremium)")
            self.updateIsPremiumInFirestore(isPremium, customerInfo: customerInfo)
            if isPremium {
                DispatchQueue.main.async {
                    self.dismiss(animated: true) {
                        print("📌 PurchaseVC dismissed after restore")
                    }
                }
            }
        }
    }
    
    func updateIsPremiumInFirestore(_ isPremium: Bool, customerInfo: CustomerInfo? = nil, retryCount: Int = 0) {
        UserDefaults.standard.set(isPremium, forKey: "isPremium")
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user ID for Firestore update")
            return
        }
        
        Firestore.firestore().collection("User").document(userId).setData([
            "isPremium": isPremium
        ], merge: true) { error in
            if let error = error {
                print("❌ Failed to update Firestore: \(error.localizedDescription)")
                if retryCount < 2 {
                    print("📌 Retrying Firestore update (\(retryCount + 1)/2)")
                    self.updateIsPremiumInFirestore(isPremium, customerInfo: customerInfo, retryCount: retryCount + 1)
                } else {
                    print("❌ Max retries reached for Firestore update")
                }
            } else {
                print("✅ Firestore synced isPremium = \(isPremium)")
            }
        }
        
        if let entitlement = customerInfo?.entitlements["Pro"] {
            let premiumData = PremiumData(
                productId: entitlement.productIdentifier,
                purchaseDate: entitlement.latestPurchaseDate,
                expirationDate: entitlement.expirationDate,
                store: String(entitlement.store.rawValue),
                isSandbox: entitlement.isSandbox,
                transactionId: customerInfo?.latestTransactionIdentifierSafe ?? "",
                ownershipType: String(entitlement.ownershipType.rawValue)
            )
            
            let docId = premiumData.purchaseDate.isEmpty ? UUID().uuidString : premiumData.purchaseDate
            
            Firestore.firestore()
                .collection("User")
                .document(userId)
                .collection("premiumData")
                .document(docId)
                .setData(premiumData.toDictionary()) { error in
                    if let error = error {
                        print("❌ Failed to save premium data: \(error.localizedDescription)")
                    } else {
                        print("✅ Premium data saved for \(userId)")
                    }
                }
        }
    }
}

extension PurchaseVC: PaywallViewControllerDelegate {
    func paywallViewControllerDidFinish(_ controller: PaywallViewController) {
        print("📌 PaywallViewControllerDidFinish called")
        DispatchQueue.main.async {
            controller.dismiss(animated: true) {
                print("📌 PaywallViewController dismissed")
            }
            Purchases.shared.getCustomerInfo { info, _ in
                let isPremium = info?.entitlements["Pro"]?.isActive ?? false
                print("📌 Purchase result: isPremium = \(isPremium)")
                self.updateIsPremiumInFirestore(isPremium, customerInfo: info)
                if isPremium {
                    self.dismiss(animated: true) {
                        print("📌 PurchaseVC dismissed after purchase")
                    }
                }
            }
        }
    }
}
