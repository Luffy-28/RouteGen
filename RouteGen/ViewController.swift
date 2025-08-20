import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import FacebookLogin
import FBSDKLoginKit
import CryptoKit
import AuthenticationServices
import GameKit
import FirebaseFirestore
import RevenueCat

class ViewController: UIViewController {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    var currentNonce: String?
    let repository = Repository()
    
    // MARK: - Generate Nonce
    func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random) % charset.count])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        authenticateGameCenterUser()
        // Reset RevenueCat and UserDefaults on app start
        resetRevenueCatAndUserDefaults()
    }
    
    // MARK: - Reset RevenueCat and UserDefaults
    func resetRevenueCatAndUserDefaults() {
        // Only attempt logout if a user is logged in
        Purchases.shared.getCustomerInfo { info, _ in
            if info?.originalAppUserId != nil {
                Purchases.shared.logOut { _, error in
                    if let error = error {
                        print("❌ RevenueCat initial logout error: \(error.localizedDescription)")
                    } else {
                        print("✅ RevenueCat initial logout successful")
                    }
                }
            } else {
                print("📌 No RevenueCat user to log out")
            }
        }
        UserDefaults.standard.removeObject(forKey: "isPremium")
        print("✅ Cleared isPremium from UserDefaults")
    }
    
    // MARK: - Authenticate Game Center
    func authenticateGameCenterUser() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                self.present(viewController, animated: true, completion: nil)
            } else if GKLocalPlayer.local.isAuthenticated {
                print("Game Center authenticated")
            } else {
                print("Failed to authenticate Game Center")
            }
        }
    }
   
    // MARK: - Email/Password Login
    @IBAction func loginDidPress(_ sender: Any) {
        guard let email = emailTextField.text, !email.isBlank else {
            return showAlertMessage(tittle: "Error", message: "Please enter your email.")
        }
        guard let password = passwordTextField.text, !password.isBlank else {
            return showAlertMessage(tittle: "Error", message: "Please enter your password.")
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                return self.showAlertMessage(tittle: "Login Failed", message: error.localizedDescription)
            }
            guard let authUser = authResult?.user else {
                return self.showAlertMessage(tittle: "Error", message: "User authentication failed.")
            }
            guard authUser.isEmailVerified else {
                return self.showAlertMessage(tittle: "Email Not Verified", message: "Please verify your email before logging in.")
            }
            self.saveLoggedInUserToFirestore(authUser)
        }
    }

    // MARK: - Forgot Password
    @IBAction func forgetPasswordButtonDidPress(_ sender: Any) {
        guard let email = emailTextField.text, !email.isBlank else {
            return showAlertMessage(tittle: "Email Required", message: "Please enter your email address.")
        }
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                return self.showAlertMessage(tittle: "Error", message: error.localizedDescription)
            }
            self.showAlertMessage(tittle: "Reset Email Sent", message: "A password reset email has been sent.")
        }
    }
    
    // MARK: - Google Sign-In
    @IBAction func goodglesigninDidTap(_ sender: Any) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Missing Firebase client ID")
            return
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: self) { signInResult, error in
            if let error = error {
                print("Google Sign-In error: \(error.localizedDescription)")
                return
            }
            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Failed to get Google user token")
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase login error: \(error.localizedDescription)")
                    return
                }
                if let firebaseUser = authResult?.user {
                    self.saveLoggedInUserToFirestore(firebaseUser)
                }
            }
        }
    }
    
    // MARK: - Save User
    func saveLoggedInUserToFirestore(_ firebaseUser: FirebaseAuth.User) {
        let uid = firebaseUser.uid
        
        // Log out from RevenueCat to clear any previous session
        Purchases.shared.logOut { _, error in
            if let error = error {
                print("❌ RevenueCat pre-login logout error: \(error.localizedDescription)")
            } else {
                print("✅ RevenueCat pre-login logout successful")
            }
            
            // Sync Firebase UID with RevenueCat
            Purchases.shared.logIn(uid) { customerInfo, created, error in
                if let error = error {
                    print("❌ RevenueCat login error: \(error.localizedDescription)")
                    self.presentPaywall()
                    return
                }
                print("✅ RevenueCat logged in user \(uid), created: \(created)")
                
                self.repository.findUserInfo(for: uid) { existingUser in
                    if let existingUser = existingUser {
                        print("Found existing user: \(existingUser.toString())")
                        self.checkPremiumStatus(user: existingUser)
                    } else {
                        // New user
                        let name = firebaseUser.displayName ?? "No Name"
                        let email = firebaseUser.email ?? "No Email"
                        let phone = firebaseUser.phoneNumber ?? ""
                        let address = ""
                        let photo = firebaseUser.photoURL?.absoluteString ?? ""
                        let newUser = User(id: uid, name: name, email: email, phone: phone, address: address, photo: photo)
                        
                        // Reset premium status for new accounts
                        Firestore.firestore().collection("User").document(uid).setData([
                            "isPremium": false
                        ], merge: true) { error in
                            if let error = error {
                                print("❌ Failed to set isPremium in Firestore: \(error.localizedDescription)")
                            } else {
                                print("✅ Set isPremium to false in Firestore for new user")
                                UserDefaults.standard.set(false, forKey: "isPremium")
                                self.repository.addUser(withData: newUser) { success in
                                    if success {
                                        self.checkPremiumStatus(user: newUser)
                                    } else {
                                        print("❌ Failed to add user to Firestore")
                                        self.presentPaywall()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Facebook Sign-In
    @IBAction func facebook(_ sender: Any) {
        let loginManager = LoginManager()
        loginManager.logIn(permissions: ["public_profile", "email"], from: self) { result, error in
            if let error = error {
                print("Facebook login error: \(error.localizedDescription)")
                return
            }
            guard let result = result, !result.isCancelled, let token = AccessToken.current else {
                print("Facebook login cancelled or failed")
                return
            }
            let credential = FacebookAuthProvider.credential(withAccessToken: token.tokenString)
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase login error: \(error.localizedDescription)")
                    return
                }
                if let firebaseUser = authResult?.user {
                    self.saveLoggedInUserToFirestore(firebaseUser)
                }
            }
        }
    }
    
    // MARK: - Premium Check
    func checkPremiumStatus(user: User) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user ID found in checkPremiumStatus")
            self.presentPaywall()
            return
        }
        
        Purchases.shared.getCustomerInfo { info, error in
            if let error = error {
                print("❌ RevenueCat error: \(error.localizedDescription)")
                // Fallback to non-premium and show paywall
                self.updateFirestoreIsPremium(false)
                UserDefaults.standard.set(false, forKey: "isPremium")
                self.presentPaywall {
                    self.navigateToProfile(with: user)
                }
                return
            }
            
            print("📌 RevenueCat CustomerInfo: \(String(describing: info))")
            let isPremium = info?.entitlements["Pro"]?.isActive ?? false
            print("📌 RevenueCat isPremium: \(isPremium)")
            if isPremium {
                print("📌 Entitlement details: \(String(describing: info?.entitlements["Pro"]))")
            }
            
            // Update Firestore and UserDefaults
            self.updateFirestoreIsPremium(isPremium)
            UserDefaults.standard.set(isPremium, forKey: "isPremium")
            
            if isPremium {
                print("✅ User is premium — skipping paywall")
                self.navigateToProfile(with: user)
            } else {
                print("❌ User is not premium — showing paywall")
                self.presentPaywall {
                    self.navigateToProfile(with: user)
                }
            }
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
    
    func presentPaywall(completion: (() -> Void)? = nil) {
        // Always rely on RevenueCat for premium status
        Purchases.shared.getCustomerInfo { info, error in
            let isPremium = info?.entitlements["Pro"]?.isActive ?? false
            print("presentPaywall: isPremium = \(isPremium), error = \(String(describing: error))")
            if isPremium {
                print("Premium user — not showing paywall")
                DispatchQueue.main.async {
                    completion?()
                }
                return
            }
            
            print("Showing paywall for non-premium user")
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "PurchaseVC") as? PurchaseVC {
                vc.modalPresentationStyle = .formSheet
                DispatchQueue.main.async {
                    print("Attempting to present PurchaseVC")
                    // Ensure no other modal is presented
                    if let presentedVC = self.presentedViewController {
                        presentedVC.dismiss(animated: true) {
                            self.present(vc, animated: true) {
                                print("PurchaseVC presented successfully")
                                completion?()
                            }
                        }
                    } else {
                        self.present(vc, animated: true) {
                            print("PurchaseVC presented successfully")
                            completion?()
                        }
                    }
                }
            } else {
                print("Failed to instantiate PurchaseVC — check storyboard identifier 'PurchaseVC' in Main.storyboard")
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }

    // MARK: - Navigation
    func navigateToProfile(with user: User) {
        print("Navigating to ProfileViewController")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let profileVC = storyboard.instantiateViewController(withIdentifier: "ProfileViewController") as? UITabBarController {
            DispatchQueue.main.async {
                self.view.window?.rootViewController = profileVC
                self.view.window?.makeKeyAndVisible()
                print("ProfileViewController set as root")
            }
        } else {
            print("Failed to instantiate ProfileViewController — verify storyboard identifier 'ProfileViewController' and class type in Main.storyboard")
        }
    }

    // MARK: - Apple Sign-In
    @IBAction func apple(_ sender: Any) {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
    }
    
    // MARK: - Alert Helper (Placeholder for yesOrNoMessage)
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
}

extension ViewController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                print("Unable to fetch identity token")
                return
            }
            guard let nonce = currentNonce else {
                print("Missing nonce")
                return
            }
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: tokenString, rawNonce: nonce)
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Apple Sign-In error: \(error.localizedDescription)")
                    return
                }
                guard let firebaseUser = authResult?.user else { return }
                let name = appleIDCredential.fullName?.givenName ?? "Apple User"
                let email = firebaseUser.email ?? ""
                let uid = firebaseUser.uid
                let user = User(id: uid, name: name, email: email, phone: firebaseUser.phoneNumber ?? "", address: "", photo: "")
                self.repository.findUserInfo(for: uid) { existingUser in
                    if existingUser == nil {
                        // Reset premium for new Apple sign-in users
                        Firestore.firestore().collection("User").document(uid).setData([
                            "isPremium": false
                        ], merge: true)
                        UserDefaults.standard.set(false, forKey: "isPremium")
                        self.repository.addUser(withData: user) { success in
                            if success {
                                self.checkPremiumStatus(user: user)
                            } else {
                                print("❌ Failed to add user to Firestore")
                                self.presentPaywall()
                            }
                        }
                    } else {
                        self.checkPremiumStatus(user: existingUser!)
                    }
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error.localizedDescription)")
    }
}
