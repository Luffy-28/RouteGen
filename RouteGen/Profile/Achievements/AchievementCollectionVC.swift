//
//  AchievementCollectionVC.swift
//  RouteGen
//
//  Created by Chanda Shrestha on 3/8/2025.
//
import UIKit
import FirebaseAuth
import FirebaseFirestore

class AchievementCollectionVC: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var AchievementCollectionView: UICollectionView!
    
    // MARK: - Properties
    var service = Repository()
    var allAchievements: [Achievements] = []
    var unlockedAchievementIDs: [String] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("✅ AchievementCollectionVC viewDidLoad")
        setupCollectionView()
        fetchAchievements()
    }
    
    // MARK: - Setup
    func setupCollectionView() {
        AchievementCollectionView.delegate = self
        AchievementCollectionView.dataSource = self
    }
    
    // MARK: - Fetch Achievements
    func fetchAchievements() {
        print("🔄 Fetching achievements...")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ User not logged in")
            return
        }

        // Fetch global achievements first
        service.fetchAllGlobalAchievements(fromCollection: "Achievements") { [weak self] globalAchievements in
            guard let self = self else { return }
            print("✅ Global achievements fetched: \(globalAchievements.count)")
            
            self.allAchievements = globalAchievements

            // Fetch unlocked achievements
            self.service.fetchUnlockedAchievements(forUser: userId) { unlockedIDs in
                print("✅ Unlocked IDs fetched: \(unlockedIDs.count)")
                self.unlockedAchievementIDs = unlockedIDs
                
                DispatchQueue.main.async {
                    print("🔄 Reloading collection view")
                    self.AchievementCollectionView.reloadData()
                }
            }
        }
    }
    
    // MARK: - CollectionView Data Source
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allAchievements.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AchievementCell", for: indexPath) as? AchievementCollectionViewCell else {
            fatalError("❌ Could not dequeue AchievementCollectionViewCell")
        }
        
        let achievement = allAchievements[indexPath.item]
        let isUnlocked = achievement.id != nil && unlockedAchievementIDs.contains(achievement.id!)

        // Debugging before configure
        print("Configuring cell for ID: \(achievement.id ?? "nil"), Unlocked: \(isUnlocked)")

        cell.configure(with: achievement, unlocked: isUnlocked)
        
        return cell
    }

    // MARK: - Layout
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 16
        let totalSpacing = spacing * 3
        let width = (collectionView.bounds.width - totalSpacing) / 2
        return CGSize(width: width, height: 200) // fixed height for uniform grid
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        AchievementCollectionView.collectionViewLayout.invalidateLayout()
    }
}

