//
//  LeaderboardVC.swift
//  RouteGen
//
//  Created by Shankar Singh on 13/8/2025.
//

import UIKit
import GameKit
import FirebaseAuth
import FirebaseFirestore

class LeaderboardVC: UIViewController, GKGameCenterControllerDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var scopeControl: UISegmentedControl!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    // MARK: - Config
    private let leaderboardID = "com.routegen.friends" // <-- UPDATE to your Leaderboard ID
    private let firestore = Firestore.firestore()
    private var isGCAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Leaderboard"
        statusLabel.text = ""
        spinner.hidesWhenStopped = true
        
        scopeControl.selectedSegmentIndex = 0
        scopeControl.addTarget(self, action: #selector(scopeChanged), for: .valueChanged)
        submitButton.addTarget(self, action: #selector(onShowLeaderboard), for: .touchUpInside)
        
        authenticateGameCenter()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadAndSubmitForCurrentScope(autoPresent: false, animated: false)
    }
    
    // MARK: - Actions
    @objc private func scopeChanged() {
        loadAndSubmitForCurrentScope(autoPresent: false, animated: true)
    }
    
    @objc private func onShowLeaderboard() {
        loadAndSubmitForCurrentScope(autoPresent: true, animated: true)
    }
    
    // MARK: - Game Center Auth
    private func authenticateGameCenter() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            guard let self = self else { return }
            if let vc = vc {
                self.present(vc, animated: true)
            } else if let error = error {
                self.status("❌ Game Center unavailable: \(error.localizedDescription)", animated: true)
            } else if self.isGCAuthenticated {
                self.status("✅ Signed in as \(GKLocalPlayer.local.alias)", animated: true)
            } else {
                self.status("⚠️ Game Center not authenticated.", animated: true)
            }
        }
    }
    
    // MARK: - Fetch + Submit
    private func loadAndSubmitForCurrentScope(autoPresent: Bool, animated: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else {
            status("⚠️ No Firebase user logged in.", animated: animated)
            return
        }
        guard isGCAuthenticated else {
            status("⚠️ Sign into Game Center to submit scores.", animated: animated)
            return
        }
        
        spinner.startAnimating()
        status("Fetching steps…", animated: animated)
        
        let selected = scopeControl.selectedSegmentIndex
        fetchSteps(uid: uid, scopeIndex: selected) { [weak self] steps, err in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            
            if let err = err {
                self.status("❌ Failed to fetch steps: \(err.localizedDescription)", animated: animated)
                return
            }
            
            let stepsInt64 = Int64(steps)
            self.status("Submitting \(stepsInt64) steps…", animated: animated)
            self.reportScore(stepsInt64) { error in
                if let error = error {
                    self.status("❌ Submission failed: \(error.localizedDescription)", animated: animated)
                } else {
                    self.status("✅ Submitted \(stepsInt64) steps.", animated: animated)
                    if autoPresent {
                        self.presentGameCenterLeaderboard(scope: selected)
                    }
                }
            }
        }
    }
    
    private func fetchSteps(uid: String, scopeIndex: Int, completion: @escaping (Int, Error?) -> Void) {
        let (collection, docID): (String, String) = {
            switch scopeIndex {
            case 0: return ("daily", todayKey())
            case 1: return ("weekly", currentWeekKey())
            default: return ("monthly", currentMonthKey())
            }
        }()
        
        let ref = firestore
            .collection("User").document(uid)
            .collection("metrics").document("healthMetrics")
            .collection(collection).document(docID)
        
        ref.getDocument { snapshot, error in
            if let error = error {
                completion(0, error)
                return
            }
            let steps = snapshot?.data()?["steps"] as? Int ?? 0
            completion(steps, nil)
        }
    }
    
    private func reportScore(_ value: Int64, completion: @escaping (Error?) -> Void) {
        let score = GKScore(leaderboardIdentifier: leaderboardID)
        score.value = value
        GKScore.report([score], withCompletionHandler: completion)
    }
    
    private func presentGameCenterLeaderboard(scope: Int) {
        let gcVC = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: timeScope(for: scope)
        )
        gcVC.gameCenterDelegate = self
        present(gcVC, animated: true)
    }
    
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
    
    // MARK: - Helpers
    private func status(_ text: String, animated: Bool) {
        if animated {
            UIView.transition(with: statusLabel, duration: 0.3, options: .transitionCrossDissolve, animations: {
                self.statusLabel.text = text
            })
        } else {
            statusLabel.text = text
        }
        print(text)
    }
    
    private func timeScope(for scopeIndex: Int) -> GKLeaderboard.TimeScope {
        switch scopeIndex {
        case 0: return .today
        case 1: return .week
        default: return .allTime // monthly mapped to allTime
        }
    }
    
    private func todayKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
    
    private func currentWeekKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "YYYY-'W'ww"
        return df.string(from: Date())
    }
    
    private func currentMonthKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM"
        return df.string(from: Date())
    }
}
