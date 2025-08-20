//
//  extension.swift
//  ecommerceApplication
//
//  Created by shankar singh on 29/03/2025.
//

import Foundation
import UIKit
import GameKit

// create an extension for a String

extension Optional where Wrapped == String {
    
    var isBlank: Bool {
        //if we manage to unwrap it then it menas it not nill, else nill
        guard let notNillBool = self else {
            return true
        }
        //at this point notNillBool is not nil, so we can trim the spaces and check if it's empty\
        return notNillBool.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Optional where Wrapped  == String {
    var isValidEmail: Bool {
        let emailRegEx = "^[\\w\\.-]+@([\\w\\-]+\\.)+[A-Z]{1,4}$"
        let emailTest = NSPredicate(format:"SELF MATCHES[c] %@", emailRegEx)
        return emailTest.evaluate(with: self)
    }
}

extension String {
    var isBlank : Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
extension UIViewController{
    func showAlertMessage(tittle : String, message : String){
        let alert = UIAlertController(title: tittle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        
        present(alert, animated: true , completion: nil)
    }
    //we create a function witha trailing closure so we can passs code to exected wherever the user presses the okay button
    func showAlertMessageHandler(tittle: String, message : String, onComplete : (() -> Void)?){
        let alert = UIAlertController(title : tittle, message: message, preferredStyle: .actionSheet)
        
        let onCompleteAction : UIAlertAction = UIAlertAction(title: "Ok", style: .default) { action in
            onComplete?()
        }
        alert.addAction(onCompleteAction)
        present(alert,animated: true, completion: nil)
    }
    func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func showCheckoutAlert() {
        let alert = UIAlertController(title: "Checkout", message: "Proceeding to checkout...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func deleteConfirmationMessage(title: String, message: String, delete: (() -> Void)?, cancel: (() -> Void)?){
        let alert = UIAlertController(title : title, message: message, preferredStyle: .actionSheet)
        let deleteAction : UIAlertAction = UIAlertAction(title: "Delete", style: .destructive) { action in
            delete?()
        }
        let cancelAction : UIAlertAction = UIAlertAction(title: "cancel", style: .default) { action in
            cancel?()
        }
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert,animated: true)
    }
    func showConfirmationAlert(title: String, message: String, okHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: { _ in
            okHandler()
        }))
        present(alert, animated: true)
    }
    func yesOrNoMessage(title: String, message: String, onYes : (()-> Void)?, onNo : (()-> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        let deleteAction : UIAlertAction = UIAlertAction(title: "Yes", style: .destructive) {action in onYes?()
        }
        let cancelAction : UIAlertAction = UIAlertAction(title: "No", style: .destructive) {action in onNo?()
        }
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
       
       present(alert, animated: true)
    }
    func applyGradient(to view: UIView) {
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [UIColor.systemTeal.cgColor, UIColor.systemBlue.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradient, at: 0)
    }
    
}
extension UITextField {
    func showInvalidBorder() {
        self.layer.borderColor = UIColor.red.cgColor
        self.layer.borderWidth = 0.5
    }
    
    func removeInvalidBorder(){
        self.layer.borderColor = UIColor.lightGray.cgColor
        self.layer.borderWidth = 0.0
    }
}








