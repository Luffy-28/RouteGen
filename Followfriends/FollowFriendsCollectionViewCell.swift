//
//  FollowFriendsCollectionViewCell.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 15/7/2025.
//

import UIKit

class FollowFriendsCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var photoImageView: UIImageView!
    
    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var followButton: UIButton!
    @IBOutlet weak var removeXButton: UIButton!
    
    var followButtonAction: (() -> Void)?
        var removeButtonAction: (() -> Void)?
        
        @IBAction func addFriendTapped(_ sender: UIButton) {
            print(" Follow button tapped")
            followButtonAction?()
        }
        
        @IBAction func removeTapped(_ sender: UIButton) {
            removeButtonAction?()
        }
        
        override func prepareForReuse() {
            super.prepareForReuse()
            photoImageView.image = UIImage(systemName: "person.circle.fill")
            fullnameLabel.text = nil
        }
        
        func configure(with user: User) {
            fullnameLabel.text = user.name
            
            photoImageView.image = UIImage(systemName: "person.circle.fill") // placeholder
            
            guard let url = URL(string: user.photo) else {
                return
            }
            
            // Simple image loading — not perfect for async reuse, but OK for now
            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self?.photoImageView.image = UIImage(data: data)
                }
            }.resume()
        }
    }
