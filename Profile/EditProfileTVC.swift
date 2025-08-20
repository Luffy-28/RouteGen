//
//  EditProfileTVC.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 2/7/2025.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class EditProfileTVC: UITableViewController,UIImagePickerControllerDelegate, UINavigationControllerDelegate  {

    var user: User!
    let service = Repository()
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var firstnameTextField: UITextField!
    @IBOutlet weak var lastnameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var addressTextField: UITextField!
    
    @IBOutlet var ProfileSettingsTVC: UITableView!
    
    override func viewDidLoad() {
            super.viewDidLoad()

            guard let user = user else {
                print("❌ user is nil in EditProfileTVC")
                self.ProfileSettingsTVC.reloadData()
                return
                
                
            }
        
        // Load image from URL if available
                if user.photo.starts(with: "http") {
                    if let url = URL(string: user.photo) {
                        URLSession.shared.dataTask(with: url) { data, _, error in
                            if let data = data, let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    self.profileImageView.image = image
                                }
                            }
                        }.resume()
                    }
                } else {
                    profileImageView.image = UIImage(systemName: "person.circle.fill")
                }

//            profileImageView.image = user.photo.isEmpty
//                ? UIImage(systemName: "person.circle.fill")
//                : UIImage(named: user.photo)

            let nameParts = user.name.split(separator: " ")
            firstnameTextField.text = nameParts.first.map { String($0) } ?? " "
            lastnameTextField.text = nameParts.dropFirst().joined(separator: " ")
            emailTextField.text = user.email
            phoneTextField.text = user.phone
            addressTextField.text = user.address
        
        
        // Tap gesture to select photo
                let tap = UITapGestureRecognizer(target: self, action: #selector(selectProfileImage))
                profileImageView.isUserInteractionEnabled = true
                profileImageView.addGestureRecognizer(tap)
        }
    
    // MARK: - Photo selection

    @objc func selectProfileImage() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)

            guard let selectedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage else {
                print("❌ Failed to get image from picker")
                return
            }

            profileImageView.image = selectedImage

            uploadImageToFirebase(selectedImage) { [weak self] url in
                guard let self = self else { return }
                if let downloadURL = url?.absoluteString {
                    print("✅ Image uploaded. URL: \(downloadURL)")
                    self.user.photo = downloadURL
                } else {
                    print("❌ Failed to upload image")
                }
            }
        }

        func uploadImageToFirebase(_ image: UIImage, completion: @escaping (URL?) -> Void) {
            guard let userId = user?.id,
                  let imageData = image.jpegData(compressionQuality: 0.75) else {
                completion(nil)
                return
            }

            let storageRef = Storage.storage().reference().child("profileImages/\(userId).jpg")
            storageRef.putData(imageData, metadata: nil) { _, error in
                if let error = error {
                    print("❌ Error uploading image: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("❌ Error getting download URL: \(error.localizedDescription)")
                        completion(nil)
                        return
                    }
                    completion(url)
                }
            }
        }

    //MARK: - To stop segue if return false
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        
        var totalInvalidComponents: Int = 0
        
        if firstnameTextField.text?.isEmpty ?? true {
            totalInvalidComponents += 1
            firstnameTextField.showInvalidBorder()
        }
        
        if lastnameTextField.text?.isEmpty ?? true {
            totalInvalidComponents += 1
            lastnameTextField.showInvalidBorder()
        }
        if emailTextField.text?.isEmpty ?? true {
            totalInvalidComponents += 1
            emailTextField.showInvalidBorder()
        }
        if phoneTextField.text?.isEmpty ?? true {
            totalInvalidComponents += 1
            phoneTextField.showInvalidBorder()
        }
        if totalInvalidComponents > 0 {
            showAlertMessage(tittle: "Error", message: "Please fill all the required fields")
            return false
        }else{
            return true
        }
        
    }
    
        // MARK: - Save Action



        // Optional: use this only if you're navigating to another screen after editing
        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            print("📦 Saving updated user info...")
            
            user.name = "\(firstnameTextField.text ?? "") \(lastnameTextField.text ?? "")"
                        user.email = emailTextField.text ?? ""
                        user.phone = phoneTextField.text ?? ""
                        user.address = addressTextField.text ?? ""
            
            
            
            
            service.updateUser(withData: user) { success in
                if success {
                    //new 4th july
                    self.ProfileSettingsTVC.tableHeaderView?.reloadInputViews()
                    print("✅ User updated successfully")
//                    DispatchQueue.main.async {
//                        self.performSegue(withIdentifier: "unwindToProfileSettingVC", sender: self)
//                    }
                } else {
                    print("❌ Failed to update user")
                }
            }
        }
    }
