//
//  SuggestedUsersVC.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 16/7/2025.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SuggestedUsersVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {
    

    @IBOutlet weak var followerSearchBar: UISearchBar!
    @IBOutlet weak var suggestedFriendCollectionView: UICollectionView!
    
    // MARK: - Properties
        var service = Repository()
        var suggestedUsers: [User] = []
        var filteredUsers: [User] = []
        var isSearching = false

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
    //MARK: - Fetch Users by searching
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredUsers.removeAll()
        } else {
            isSearching = true
            filteredUsers = suggestedUsers.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        suggestedFriendCollectionView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        isSearching = false
        searchBar.text = ""
        searchBar.resignFirstResponder()
        suggestedFriendCollectionView.reloadData()
    }


        // MARK: - CollectionView Data Source
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isSearching ? filteredUsers.count : suggestedUsers.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SuggestedUserCell", for: indexPath) as? FollowFriendsCollectionViewCell else {
            fatalError("❌ Could not dequeue SuggestedUserCell")
        }
        
        let user = isSearching ? filteredUsers[indexPath.row] : suggestedUsers[indexPath.row]
        cell.configure(with: user)
        
        cell.removeButtonAction = {
            // Get correct index
            if self.isSearching {
                self.filteredUsers.remove(at: indexPath.row)
            } else {
                self.suggestedUsers.remove(at: indexPath.row)
            }
            
            // Update collection view
            self.suggestedFriendCollectionView.deleteItems(at: [indexPath])
        }

        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 16
        let totalSpacing = spacing * 3
        let width = (collectionView.bounds.width - totalSpacing) / 2
        return CGSize(width: width, height: 180) // Adjusted height for mockup
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
