import UIKit
import FirebaseAuth
import FirebaseFirestore
import RevenueCat

class ProfileSettingVC: UIViewController {
    
    var user: User?
    var service = Repository()
    var userAuthId: String?
    
    @IBOutlet weak var firstnameLabel: UILabel!
    @IBOutlet weak var lastnameLabel: UILabel!
    @IBOutlet weak var profileImageLabel: UIImageView!
    @IBOutlet var ProfileSettingUIView: UIView!
    @IBOutlet weak var goPremium: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📌 ProfileSettingVC viewDidLoad")
        userAuthId = Auth.auth().currentUser?.uid
        if userAuthId == nil {
            print("❌ No user logged in, redirecting to login")
            navigateToLogin()
            return
        }
        loadUserData()
    }

    func loadUserData() {
        guard let currentUserId = userAuthId else {
            print("❌ No user ID available")
            navigateToLogin()
            return
        }
        service.findUserInfo(for: currentUserId) { [weak self] fetchedUser in
            guard let self = self else { return }
            guard let fetchedUser = fetchedUser else {
                print("❌ User not found in Database")
                DispatchQueue.main.async {
                    self.showAlertMessage(tittle: "Error", message: "User data not found. Please log in again.")
                    self.navigateToLogin()
                }
                return
            }

            self.user = fetchedUser
            DispatchQueue.main.async {
                self.updateUI()
            }
        }
    }

    func updateUI() {
        guard let user = user else {
            print("❌ user is nil inside updateUI")
            return
        }

        // Update name labels
        let nameParts = user.name.split(separator: " ")
        firstnameLabel.text = String(nameParts.first ?? "")
        lastnameLabel.text = String(nameParts.dropFirst().joined(separator: " "))

        // Load image from URL if available
        if user.photo.starts(with: "http") {
            if let url = URL(string: user.photo) {
                URLSession.shared.dataTask(with: url) { data, _, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.profileImageLabel.image = image
                        }
                    }
                }.resume()
            }
        } else {
            profileImageLabel.image = UIImage(systemName: "person.circle.fill")
        }

        // Check premium status and update goPremium button
        checkPremiumStatus()
    }
    
    func checkPremiumStatus() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user ID found in checkPremiumStatus")
            updateGoPremiumButton(isPremium: false)
            return
        }
        
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ RevenueCat error: \(error.localizedDescription)")
                // Fallback to non-premium
                DispatchQueue.main.async {
                    self.updateGoPremiumButton(isPremium: false)
                }
                return
            }
            
            let isPremium = info?.entitlements["Pro"]?.isActive ?? false
            print("📌 RevenueCat isPremium: \(isPremium)")
            
            // Update Firestore and UserDefaults for consistency
            self.updateFirestoreIsPremium(isPremium)
            UserDefaults.standard.set(isPremium, forKey: "isPremium")
            
            DispatchQueue.main.async {
                self.updateGoPremiumButton(isPremium: isPremium)
            }
        }
    }
    
    func updateGoPremiumButton(isPremium: Bool) {
        if isPremium {
            goPremium.setTitle("Premium", for: .normal)
            goPremium.backgroundColor = .systemGreen
            goPremium.layer.borderColor = UIColor.systemYellow.cgColor // Golden border
            goPremium.layer.borderWidth = 2.0
            goPremium.layer.cornerRadius = 8.0 // Optional: for rounded corners
        } else {
            goPremium.setTitle("Go Premium", for: .normal)
            goPremium.backgroundColor = .systemBlue // Default background for non-premium
            goPremium.layer.borderColor = nil
            goPremium.layer.borderWidth = 0.0
            goPremium.layer.cornerRadius = 8.0 // Optional: for rounded corners
        }
    }
    
    func updateFirestoreIsPremium(_ isPremium: Bool, retryCount: Int = 0) {
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
                    self.updateFirestoreIsPremium(isPremium, retryCount: retryCount + 1)
                } else {
                    print("❌ Max retries reached for Firestore update")
                }
            } else {
                print("✅ Firestore synced isPremium = \(isPremium)")
            }
        }
    }
    
    func navigateToLogin() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        do {
            let loginVC = try storyboard.instantiateViewController(withIdentifier: "ViewController")
            DispatchQueue.main.async {
                self.view.window?.rootViewController = loginVC
                self.view.window?.makeKeyAndVisible()
                print("📌 Navigated to ViewController due to no user")
            }
        } catch {
            print("❌ Failed to instantiate ViewController — check storyboard identifier 'ViewController' in Main.storyboard: \(error.localizedDescription)")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let editProfileVC = segue.destination as? EditProfileTVC {
            editProfileVC.user = self.user
        }
    }
        
    @IBAction func unwindtoProfileSettingVC(_ segue: UIStoryboardSegue) {
        _ = segue.source
        return
    }
    
    @IBAction func logoutDidPress(_ sender: UIButton) {
        yesOrNoMessage(
            title: "Logout",
            message: "Are you sure you want to logout?",
            onYes: {
                // Sign out from Firebase
                do {
                    try Auth.auth().signOut()
                } catch {
                    self.showAlertMessage(
                        tittle: "Error",
                        message: "Failed to sign out: \(error.localizedDescription). Do you want to try again?",
                        onYes: {
                            // Retry sign-out
                            do {
                                try Auth.auth().signOut()
                                self.completeLogout()
                            } catch {
                                print("❌ Retry sign-out failed: \(error.localizedDescription)")
                                self.completeLogout() // Force logout anyway
                            }
                        },
                        onNo: {
                            print("🚫 Logout retry canceled")
                        }
                    )
                    return
                }
                self.completeLogout()
            },
            onNo: {
                self.showAlertMessage(tittle: "Logout Unsuccessful", message: "Your logout was canceled.")
                print("🚫 Logout canceled")
            }
        )
    }

    func completeLogout() {
        // Sign out from RevenueCat
        Purchases.shared.logOut { info, error in
            if let error = error {
                print("❌ RevenueCat logout error: \(error.localizedDescription)")
            } else {
                print("✅ RevenueCat logged out")
            }
        }
        
        // Clear premium status locally
        UserDefaults.standard.removeObject(forKey: "isPremium")
        
        // Navigate back to login screen
        self.navigateToLogin()
    }
    
    // MARK: - Go Premium Button Action
    @IBAction func goPremiumTapped(_ sender: UIButton) {
        Purchases.shared.getCustomerInfo { [weak self] info, error in
            guard let self = self else { return }
            let isPremium = info?.entitlements["Pro"]?.isActive ?? false
            if isPremium {
                print("📌 User is already premium, no action needed")
                return
            }
            
            // Show paywall for non-premium users
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "PurchaseVC") as? PurchaseVC {
                vc.modalPresentationStyle = .formSheet
                DispatchQueue.main.async {
                    print("📌 Attempting to present PurchaseVC from goPremiumTapped")
                    if let presentedVC = self.presentedViewController {
                        presentedVC.dismiss(animated: true) {
                            self.present(vc, animated: true) {
                                print("📌 PurchaseVC presented successfully")
                            }
                        }
                    } else {
                        self.present(vc, animated: true) {
                            print("📌 PurchaseVC presented successfully")
                        }
                    }
                }
            } else {
                print("❌ Failed to instantiate PurchaseVC — check storyboard identifier 'PurchaseVC' in Main.storyboard")
            }
        }
    }
    
    // MARK: - Alert Helper
    func yesOrNoMessage(title: String, message: String, onYes: @escaping () -> Void, onNo: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            onYes()
        })
        alert.addAction(UIAlertAction(title: "No", style: .cancel) { _ in
            onNo()
        })
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
    }

    func showAlertMessage(tittle: String, message: String, onYes: @escaping () -> Void = {}, onNo: @escaping () -> Void = {}) {
        let alert = UIAlertController(title: tittle, message: message, preferredStyle: .alert)
        if !tittle.contains("Error") || message.contains("try again") {
            alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
                onYes()
            })
            alert.addAction(UIAlertAction(title: "No", style: .cancel) { _ in
                onNo()
            })
        } else {
            alert.addAction(UIAlertAction(title: "OK", style: .default))
        }
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
    }
}
