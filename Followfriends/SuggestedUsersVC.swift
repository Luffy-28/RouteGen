//
//  SuggestedUsersVC.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 16/7/2025.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SuggestedUsersVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var suggestedFriendCollectionView: UICollectionView!
    
    // MARK: - Properties
        var service = Repository()
        var suggestedUsers: [User] = []

        // MARK: - Lifecycle
        override func viewDidLoad() {
            super.viewDidLoad()
            setupCollectionView()
            fetchUsersToFollow()
        }

        // MARK: - Setup
        func setupCollectionView() {
           suggestedFriendCollectionView.delegate = self
            suggestedFriendCollectionView.dataSource = self
        }

        // MARK: - Fetch Users
        func fetchUsersToFollow() {
            service.fetchSuggestedUsers { users in
                print("Fetched suggested users: \(users.count)")
                self.suggestedUsers = users
                DispatchQueue.main.async {
                    self.suggestedFriendCollectionView.reloadData()
                }
            }
        }

        // MARK: - CollectionView Data Source
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return suggestedUsers.count
        }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = suggestedFriendCollectionView.dequeueReusableCell(withReuseIdentifier: "SuggestedUserCell", for: indexPath) as? FollowFriendsCollectionViewCell else {
            fatalError("❌ Could not dequeue SuggestedUserCell")
        }
        
        
        // MARK: - follow button update
        
        let user = suggestedUsers[indexPath.row]
        cell.configure(with: user)
        
        cell.followButtonAction = {
            guard let currentUserID = Auth.auth().currentUser?.uid else {
                print("❌ Could not get current user ID")
                return
            }
            
            self.service.followUser(followerUid: currentUserID, followingUid: user.id) { result in
                if result {
                    DispatchQueue.main.async {
                        cell.followButton.setTitle("Following", for: .normal)
                        cell.followButton.backgroundColor = .systemGray6
                        cell.followButton.isEnabled = false
                    }
                }
            }
        }
        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 16
        let totalSpacing = spacing * 3
        let width = (collectionView.bounds.width - totalSpacing) / 2
        return CGSize(width: width, height: 200) // Adjusted height for mockup
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        suggestedFriendCollectionView.collectionViewLayout.invalidateLayout()
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
