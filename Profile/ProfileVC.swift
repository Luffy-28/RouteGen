//
//  ProfileVC.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 18/6/2025.
//


import UIKit
import FirebaseFirestore
import FirebaseAuth

class ProfileVC: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var firstnameLabel: UILabel!
    @IBOutlet weak var lastnameLabel: UILabel!
    @IBOutlet weak var routeGeneratedLabel: UILabel!
    @IBOutlet weak var noOfFriendsLabel: UILabel!
    @IBOutlet weak var noOfRunsLabel: UILabel!
    @IBOutlet weak var UIAchievementTableView: UITableView!
    

    // MARK: - Properties
        var service = Repository()
        var achievements = [Achievement]()
        var user: User?

        // MARK: - Lifecycle
        override func viewDidLoad() {
            super.viewDidLoad()
            UIAchievementTableView.delegate = self
            UIAchievementTableView.dataSource = self
            refreshProfileData()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            refreshProfileData() // ✅ reload data when returning from edit screen
        }

        // MARK: - Data Fetching
        func refreshProfileData() {
            loadUserData()
            loadAchievements()
        }

        func loadUserData() {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("❌ No user logged in")
                return
            }

            service.findUserInfo(for: currentUserId) { [weak self] fetchedUser in
                guard let self = self else { return }
                guard let fetchedUser = fetchedUser else {
                    print("❌ User not found in Firestore")
                    return
                }

                self.user = fetchedUser

                DispatchQueue.main.async {
                    self.updateUI()
                }
            }
        }

        func loadAchievements() {
            service.fetchAllAchievements(fromCollection: "Achievement") { [weak self] returnedAchievements in
                guard let self = self else { return }
                self.achievements = returnedAchievements
                DispatchQueue.main.async {
                    self.UIAchievementTableView.reloadData()
                    print("📊 Total achievements: \(self.achievements.count)")
                }
            }
        }

        // MARK: - UI Update
        func updateUI() {
            guard let user = user else {
                print("❌ user is nil inside updateUI")
                return
            }

            let nameParts = user.name.split(separator: " ")
            firstnameLabel.text = nameParts.indices.contains(0) ? String(nameParts[0]) : ""
            lastnameLabel.text = nameParts.indices.contains(1) ? String(nameParts[1]) : ""

            if user.photo.isEmpty {
                profileImage.image = UIImage(systemName: "person.circle.fill")
            } else {
                profileImage.layer.cornerRadius = profileImage.frame.height / 2
                profileImage.clipsToBounds = true
                // Optionally load image from URL if needed
            }
            UIAchievementTableView.reloadData()
        }

        // MARK: - TableView Methods
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            print(" Number of achievements: \(achievements.count)")
            return achievements.count
            
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileAchievementTVCell", for: indexPath) as? ProfileAchievementTVCell else {
                fatalError("❗️Couldn’t dequeue ProfileAchievementTVCell")
            }

            let achievement = achievements[indexPath.row]
            cell.configure(with: achievement)
            return cell
        }
    
}
