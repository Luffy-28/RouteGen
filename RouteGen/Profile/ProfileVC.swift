import UIKit
import FirebaseFirestore
import FirebaseAuth
import GameKit

struct AchievementIDs {
    static let firstSteps = "com.routegen.firststeps"
    static let tenKSteps = "com.routegen.10ksteps"
    static let marathonMaster = "com.routegen.marathonmaster"

    static let orderedList = [
        firstSteps,
        tenKSteps,
        marathonMaster
    ]
}

class ProfileVC: UIViewController, UITableViewDelegate, UITableViewDataSource, GKGameCenterControllerDelegate {

    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var firstnameLabel: UILabel!
    @IBOutlet weak var lastnameLabel: UILabel!
    @IBOutlet weak var routeGeneratedLabel: UILabel!
    @IBOutlet weak var noOfFriendsLabel: UILabel!
    @IBOutlet weak var noOfRunsLabel: UILabel!
    @IBOutlet weak var UIAchievementTableView: UITableView!
    
    var service = Repository()
    var achievements = [GKAchievement]()
    var achievementDescriptions = [String: GKAchievementDescription]()
    var user: User?
    private var testAchievementsReported = false // To avoid spamming GameKit

    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIAchievementTableView.delegate = self
        UIAchievementTableView.dataSource = self
        
        loadUserData()
        authenticateGameCenterAndLoadAchievements()
    }
    
    // MARK: - Game Center Auth + Fetch
    func authenticateGameCenterAndLoadAchievements() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            guard let self = self else { return }
            if let vc = vc {
                self.present(vc, animated: true)
            } else if GKLocalPlayer.local.isAuthenticated {
                print("✅ Game Center Authenticated: \(GKLocalPlayer.local.alias)")
                self.loadGameCenterAchievements()
            } else {
                print("❌ Game Center not authenticated: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func loadGameCenterAchievements() {
        GKAchievementDescription.loadAchievementDescriptions { descs, error in
            if let error = error {
                print("❌ Error loading descriptions: \(error.localizedDescription)")
                return
            }
            
            print("✅ Loaded descriptions: \(descs?.count ?? 0)")
            descs?.forEach { print(" - \($0.identifier): \($0.title)") }
            
            if let descs = descs {
                self.achievementDescriptions = Dictionary(uniqueKeysWithValues: descs.map { ($0.identifier, $0) })
            }

            GKAchievement.loadAchievements { achievements, error in
                if let error = error {
                    print("❌ Error loading achievements: \(error.localizedDescription)")
                    return
                }
                
                print("✅ Loaded achievements from Game Center: \(achievements?.count ?? 0)")

                let achievementsDict = Dictionary(uniqueKeysWithValues: (achievements ?? []).map { ($0.identifier ?? "", $0) })
                
                // Always display in fixed order, even if not yet reported
                self.achievements = AchievementIDs.orderedList.map { id in
                    achievementsDict[id] ?? GKAchievement(identifier: id)
                }
                
                // Report test achievements if not already done
                if !self.testAchievementsReported {
                    self.reportTestAchievements()
                    self.testAchievementsReported = true
                }
                
                DispatchQueue.main.async {
                    self.UIAchievementTableView.reloadData()
                }
            }
        }
    }
    
    // MARK: - Test Achievements Reporter
    private func reportTestAchievements() {
        print("📢 Reporting test achievements to Game Center...")
        
        let first = GKAchievement(identifier: AchievementIDs.firstSteps)
        first.percentComplete = 100.0
        first.showsCompletionBanner = true
        
        let tenK = GKAchievement(identifier: AchievementIDs.tenKSteps)
        tenK.percentComplete = 50.0 // Half progress for testing
        tenK.showsCompletionBanner = true
        
        let marathon = GKAchievement(identifier: AchievementIDs.marathonMaster)
        marathon.percentComplete = 10.0
        marathon.showsCompletionBanner = true
        
        GKAchievement.report([first, tenK, marathon]) { error in
            if let error = error {
                print("❌ Error reporting test achievements: \(error.localizedDescription)")
            } else {
                print("✅ Test achievements reported successfully")
                // Reload to show progress
                self.loadGameCenterAchievements()
            }
        }
    }
    
    // MARK: - Firestore User Data
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
    
    func updateUI() {
        guard let user = user else { return }
        let nameParts = user.name.split(separator: " ")
        firstnameLabel.text = nameParts.indices.contains(0) ? String(nameParts[0]) : ""
        lastnameLabel.text = nameParts.indices.contains(1) ? String(nameParts[1]) : ""
        
        if user.photo.starts(with: "http"), let url = URL(string: user.photo) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.profileImage.image = image
                    }
                }
            }.resume()
        } else {
            profileImage.image = UIImage(systemName: "person.circle.fill")
        }
    }
    
    // MARK: - TableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return achievements.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileAchievementTVCell", for: indexPath) as? ProfileAchievementTVCell else {
            fatalError("❗️Couldn’t dequeue ProfileAchievementTVCell")
        }
        
        let achievement = achievements[indexPath.row]
        let description = achievementDescriptions[achievement.identifier ?? ""]
        cell.configure(with: achievement, description: description)
        
        return cell
    }
    
    // MARK: - Game Center Delegate
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
