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
import PhoneNumberKit

class EditProfileTVC: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var user: User!
    let service = Repository()
    private let phoneNumberKit = PhoneNumberUtility() // parse & format phone numbers (class renamed to avoid Module/Class shadowing)
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var firstnameTextField: UITextField!
    @IBOutlet weak var lastnameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var emergencyContact: PhoneNumberTextField!
    @IBOutlet var ProfileSettingsTVC: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let user = user else {
            print("❌ user is nil in EditProfileTVC")
            ProfileSettingsTVC.reloadData()
            return
        }
        
        // Load image from URL if available
        if user.photo.starts(with: "http"), let url = URL(string: user.photo) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.profileImageView.image = image
                    }
                }
            }.resume()
        } else {
            profileImageView.image = UIImage(systemName: "person.circle.fill")
        }
        
        // Populate text fields
        let nameParts = user.name.split(separator: " ")
        firstnameTextField.text = nameParts.first.map(String.init) ?? ""
        lastnameTextField.text = nameParts.dropFirst().joined(separator: " ")
        emailTextField.text = user.email
        phoneTextField.text = user.phone
        addressTextField.text = user.address
        
        // PhoneNumberKit setup for the emergency-contact field
        emergencyContact.text = user.emergencyContact ?? ""
        emergencyContact.withFlag = true                   // show the country flag
        emergencyContact.withExamplePlaceholder = true     // placeholder hint
        emergencyContact.keyboardType = .phonePad          // numeric keypad
        emergencyContact.withDefaultPickerUI = true        // built-in country picker UI
        
        // Tap gesture to select photo
        let tap = UITapGestureRecognizer(target: self, action: #selector(selectProfileImage))
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(tap)
    }
    
    // MARK: – Photo selection
    @objc func selectProfileImage() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        
        guard let selectedImage = (info[.editedImage] as? UIImage)
                ?? (info[.originalImage] as? UIImage) else {
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
            completion(nil); return
        }
        let storageRef = Storage.storage().reference().child("profileImages/\(userId).jpg")
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("❌ Error uploading image: \(error.localizedDescription)")
                completion(nil); return
            }
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Error getting download URL: \(error.localizedDescription)")
                    completion(nil); return
                }
                completion(url)
            }
        }
    }
    
    // MARK: – Validate before segue
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        var totalInvalid = 0
        if firstnameTextField.text?.isEmpty ?? true {
            totalInvalid += 1; firstnameTextField.showInvalidBorder()
        }
        if lastnameTextField.text?.isEmpty ?? true {
            totalInvalid += 1; lastnameTextField.showInvalidBorder()
        }
        if emailTextField.text?.isEmpty ?? true {
            totalInvalid += 1; emailTextField.showInvalidBorder()
        }
        if phoneTextField.text?.isEmpty ?? true {
            totalInvalid += 1; phoneTextField.showInvalidBorder()
        }
        if totalInvalid > 0 {
            showAlertMessage(tittle: "Error", message: "Please fill all the required fields")
            return false
        }
        
        // Emergency-contact validation
        // intent: early catch invalid numbers to improve UX and prevent bad data
        do {
            _ = try phoneNumberKit.parse(emergencyContact.text ?? "")
        } catch {
            showAlertMessage(tittle: "Invalid Number", message: "Please enter a valid emergency contact number")
            return false
        }
        
        return true
    }
    
    // MARK: – Save Action
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("📦 Saving updated user info...")
        
        user.name    = "\(firstnameTextField.text ?? "") \(lastnameTextField.text ?? "")"
        user.email   = emailTextField.text ?? ""
        user.phone   = phoneTextField.text ?? ""
        user.address = addressTextField.text ?? ""
        
        // Parse & format emergency contact to E.164
        // intent: normalize numbers for consistency and global compatibility
        do {
            let parsedNumber = try phoneNumberKit.parse(emergencyContact.text ?? "")
            let e164String = phoneNumberKit.format(parsedNumber, toType: PhoneNumberFormat.e164)
            user.emergencyContact = e164String
        } catch {
            // fallback if parsing unexpectedly fails
            user.emergencyContact = emergencyContact.text
        }
        
        // Persist update to Firestore
        service.updateUser(withData: user) { success in
            if success {
                self.ProfileSettingsTVC.tableHeaderView?.reloadInputViews()
                print("✅ User updated successfully")
                // optionally perform unwind segue here
            } else {
                print("❌ Failed to update user")
                self.showAlertMessage(tittle: "Save Error", message: "Unable to update profile. Please try again.")
            }
        }
    }
    
 
}
