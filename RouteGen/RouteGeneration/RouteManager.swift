

import FirebaseFirestore
import FirebaseAuth

class RouteManager {
    static let shared = RouteManager()
    private let db = Firestore.firestore()
    
    func getRouteData(completion: @escaping (Int, Int) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(0, 0)
            return
        }
        
        let docRef = db.collection("User").document(uid).collection("stats").document("totals")
        docRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let routeCount = document.get("buttonClick") as? Int ?? 0
                let lastResetMonth = document.get("lastResetMonth") as? Int ?? 0
                completion(routeCount, lastResetMonth)
            } else {
                completion(0, 0)
            }
        }
    }
    
    func incrementRouteCount(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let docRef = db.collection("User").document(uid).collection("stats").document("totals")
        docRef.setData(["buttonClick": FieldValue.increment(Int64(1))], merge: true) { error in
            completion(error == nil)
        }
    }
    
    func resetRouteCount(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let docRef = db.collection("User").document(uid).collection("stats").document("totals")
        docRef.setData([
            "buttonClick": 0,
            "lastResetMonth": currentMonth
        ], merge: true) { error in
            completion(error == nil)
        }
    }
    
    func checkAndResetIfNewMonth(completion: @escaping (Bool) -> Void) {
        getRouteData { (routeCount, lastResetMonth) in
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: Date())
            
            if lastResetMonth != currentMonth {
                self.resetRouteCount { success in
                    completion(success)
                }
            } else {
                completion(true)
            }
        }
    }
}
