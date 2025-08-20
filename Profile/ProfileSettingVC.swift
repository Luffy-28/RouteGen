//
//  ProfileSettingViewController.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 2/7/2025.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ProfileSettingVC: UIViewController {
    
    var user : User!
    var service = Repository()
    var userAuthId : String!
    
    @IBOutlet weak var firstnameLabel: UILabel!
    @IBOutlet weak var lastnameLabel: UILabel!
    @IBOutlet weak var profileImageLabel: UIImageView!
    @IBOutlet var ProfileSettingUIView: UIView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userAuthId = Auth.auth().currentUser?.uid
        
        
        loadUserData() // Now this works fine
        
    }

        func loadUserData() {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("❌ No user logged in")
                return
            }
            service.findUserInfo(for: currentUserId) { [weak self] fetchedUser in
                guard let self = self else { return }
                guard let fetchedUser = fetchedUser else {
                    print("❌ User not found in Database")
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

            let nameParts = user.name.split(separator: " ")
            firstnameLabel.text = String(nameParts.first ?? "")
            lastnameLabel.text = String(nameParts.dropFirst().joined(separator: " "))

            if user.photo.isEmpty {
                profileImageLabel.image = UIImage(systemName: "person.circle")
            } else {
                profileImageLabel.layer.cornerRadius = profileImageLabel.frame.height / 2
                profileImageLabel.clipsToBounds = true
            }
            
            self.viewDidLoad()
        }
        
        
        
        // MARK: - Navigation
        
        // In a storyboard-based application, you will often want to do a little preparation before navigation
//        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//            // Get the new view controller using segue.destination.
//            // Pass the selected object to the new view controller.
//            
//            //  if segue.identifier == "editProfileSegue" {
//            
//            //   let destination = segue.destination as! EditProfileVC
//            
//            if let editProfileVC = segue.destination as? EditProfileTVC {
//                editProfileVC.user = self.user
//                
//                // if let editOutgoingRequestTVC = segue.destination as? EditOutgoingRequestTVC {
//                //     editOutgoingRequestTVC.outgoingRequest = self.outgoingRequest
//            }
//        }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
           if let editProfileVC = segue.destination as? EditProfileTVC {
               editProfileVC.user = self.user
           }
       }
        
        //
        
        @IBAction func unwindtoProfileSettingVC(_ segue: UIStoryboardSegue) {
            _ = segue.source
           // self.unwindtoProfileSettingVC.reloadData()
            return
        }
    
    @IBAction func logoutDidPress(_ sender: UIButton) {
        
        yesOrNoMessage(title:  "Logout", message: "Are you sure you want to logout?", onYes: { let profileViewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? UIViewController
            
            self.view.window?.rootViewController = profileViewController
            
            self.view.window?.makeKeyAndVisible()},
                       onNo: {self.showAlertMessage(tittle: "Logout Unsuccessful", message: "Your logout was canceled.")
            print(" Canceled ")}
        )
    
    }
    
    }


