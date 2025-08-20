//
//  SignUpVC.swift
//  RouteGen
//
//  Created by Shankar Singh on 8/6/2025.
//

import UIKit
import FirebaseAuth

class SignUpVC: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPassword: UITextField!
    @IBOutlet weak var firstNameTextField: UITextField!
    
    @IBOutlet weak var lastNameTextField: UITextField!
    
    @IBOutlet weak var phoneNumberTextField: UITextField!
    var service = Repository()
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    @IBAction func SignUpButtonDidTap(_ sender: Any) {
        guard !emailTextField.text.isBlank else{
            return showAlertMessage(tittle: "Error", message: "Email is required")
        }
        guard !passwordTextField.text.isBlank else{
            return showAlertMessage(tittle: "Alert", message: "Password is required")
            
        }
        
        guard passwordTextField.text == confirmPassword.text else{
            return showAlertMessage(tittle: "Alert", message: "Password doesnot match")
        }
        
        
        guard let email = emailTextField.text,
              let password = passwordTextField.text,
              let confirmPassword = confirmPassword.text,
            
                password == confirmPassword else {
            return showAlertMessage(tittle: "Alert", message: "Password doesnot match")
        }
        let firstName = firstNameTextField.text ?? ""
        let lastName = lastNameTextField.text ?? ""
        let phone = phoneNumberTextField.text ?? ""
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        // MARK: - Create User in Firebase Auth
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error as NSError? {
                if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    // Check which providers are associated with this email
                    Auth.auth().fetchSignInMethods(forEmail: email) { methods, error in
                        if let error = error {
                            return self.showAlertMessage(tittle: "Error", message: error.localizedDescription)
                        }
                        if let methods = methods {
                            if methods.contains("google.com") {
                                self.showAlertMessage(tittle: "Account Exists", message: "This email is already registered with Google. Please sign in using Google.")
                            } else if methods.contains("facebook.com") {
                                self.showAlertMessage(tittle: "Account Exists", message: "This email is already registered with Facebook. Please sign in using Facebook.")
                            } else if methods.contains("password") {
                                self.showAlertMessage(tittle: "Account Exists", message: "This email is already registered. Please log in.")
                            } else {
                                self.showAlertMessage(tittle: "Account Exists", message: "This email is already registered with another method.")
                            }
                        } else {
                            self.showAlertMessage(tittle: "Account Exists", message: "Email already in use.")
                        }
                    }
                    return
                } else {
                    return self.showAlertMessage(tittle: "Account Creation Failed", message: error.localizedDescription)
                }
            }

                    guard let userAuthId = authResult?.user.uid else {
                        return self.showAlertMessage(tittle: "Error", message: "Unable to retrieve user ID")
                    }

                   // MARK: - Firestore User Object
                   let user = User(
                       id: userAuthId,
                       name: fullName,
                       email: email,
                       phone: phone,
                       address: "",
                       photo: ""
                   )

                   // MARK: - Email Verification
                   Auth.auth().currentUser?.sendEmailVerification { error in
                       if let error = error {
                           return self.showAlertMessage(tittle: "Verification Email Error", message: error.localizedDescription)
                       }

                       self.showAlertMessageHandler(
                           tittle: "Email Sent",
                           message: "A confirmation email has been sent. Please verify before logging in.",
                           onComplete: {
                               self.service.addUser(withData: user) { success in
                                   if success {
                                       print("User added to Firestore: \(user.email)")
                                   } else {
                                       print("Firestore save failed for user: \(user.email)")
                                   }
                               }
                               self.navigationController?.popViewController(animated: true)
                           }
                       )
                   }
               }
           }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
