//
//  AppDelegate.swift
//  RouteGen
//
//  Created by 10167 on 5/6/2025.
//

import UIKit
import FirebaseCore
import GoogleSignIn
import FacebookCore
import GameKit
import RevenueCat

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Purchases.logLevel = .debug // Enable for debugging
        Purchases.configure(withAPIKey: "appl_hMGpbqLamZElGgWkOQMrVytlaGe")
        
        FirebaseApp.configure()
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // Use this method to release any resources specific to the discarded scenes.
    }
    
    func application(
            _ app: UIApplication,
            open url: URL,
            options: [UIApplication.OpenURLOptionsKey : Any] = [:]
        ) -> Bool {
            // Handle both Facebook and Google Sign-In
            let handledByFB = ApplicationDelegate.shared.application(app, open: url, options: options)
            let handledByGoogle = GIDSignIn.sharedInstance.handle(url)
            return handledByFB || handledByGoogle
        }
   

        func authenticateGameCenter() {
            GKLocalPlayer.local.authenticateHandler = { viewController, error in
                if let vc = viewController {
                    UIApplication.shared.windows.first?.rootViewController?.present(vc, animated: true)
                } else if GKLocalPlayer.local.isAuthenticated {
                    print("✅ Game Center signed in at launch")
                } else {
                    print("❌ Game Center auth failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }

}


